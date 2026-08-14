class_name ContentPackRegistry
extends RefCounted

const CONTENT_API_VERSION := "0.1"
const BASE_PACK_ID := "koalapet.base"
const MAX_PACK_FILES := 1024
const MAX_PACK_BYTES := 64 * 1024 * 1024
const MAX_JSON_BYTES := 2 * 1024 * 1024
const SUPPORTED_SCHEMAS := [
	"ailment.schema.json", "animation-profile.schema.json", "care-profile.schema.json", "dungeon.schema.json", "egg.schema.json", "injury.schema.json",
	"enemy-encounter.schema.json", "evolution-graph.schema.json", "farm-job.schema.json",
	"feature-gate.schema.json", "form.schema.json", "furniture-prop.schema.json",
	"habitat-theme.schema.json", "item.schema.json", "localization-bundle.schema.json",
	"move.schema.json", "progression-balance.schema.json", "species-family.schema.json", "starter-pool.schema.json", "training-activity.schema.json",
]
const SKIN_OVERRIDE_SCHEMAS := [
	"animation-profile.schema.json", "furniture-prop.schema.json", "habitat-theme.schema.json",
]

var _roots: Array[Dictionary] = []
var _disabled_pack_ids: Dictionary = {}
var _resolved_packs: Array[Dictionary] = []
var _definitions: Dictionary = {}
var _owners: Dictionary = {}
var _localizations: Dictionary = {}
var _applied_overrides: Array[Dictionary] = []
var _rejected_packs: Array[Dictionary] = []
var _diagnostics: Array[Dictionary] = []


func _init(roots: Array[Dictionary] = [], disabled_pack_ids: Array = []) -> void:
	_roots = roots.duplicate(true)
	for pack_id in disabled_pack_ids:
		_disabled_pack_ids[str(pack_id)] = true


static func root(path: String, label: String, source_type: String) -> Dictionary:
	return {"path": path, "label": label, "source_type": source_type}


static func default_roots(external_path := "user://mods") -> Array[Dictionary]:
	return [
		root("res://content_packs", "bundled", "bundled"),
		root(external_path, "external", "external"),
	]


func discover_and_resolve() -> Dictionary:
	_reset()
	var candidates: Array[Dictionary] = []
	for root_config in _roots:
		candidates.append_array(_discover_root(root_config))
	var unique := _reject_duplicate_pack_ids(candidates)
	unique = _apply_disabled_and_total_conversion_policy(unique)
	unique = _validate_relationships(unique)
	unique = _validate_candidate_references(unique)
	var ordered := _topological_order(unique)
	_apply_ordered_packs(ordered)
	return {
		"success": not _resolved_packs.is_empty(),
		"resolved_pack_count": _resolved_packs.size(),
		"rejected_pack_count": _rejected_packs.size(),
		"diagnostic_count": _diagnostics.size(),
	}


func list_resolved_packs() -> Array[Dictionary]:
	return _resolved_packs.duplicate(true)


func list_documents_by_kind(kind: String) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	for content_id in _definitions:
		var record: Dictionary = _definitions[content_id]
		if record.kind == kind or record.schema_name == kind:
			documents.append(record.duplicate(true))
	documents.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.id < right.id)
	return documents


func list_documents() -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	for content_id in _definitions:
		documents.append(_definitions[content_id].duplicate(true))
	documents.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return documents


func resolve(content_id: String) -> Dictionary:
	var record: Dictionary = _definitions.get(content_id, {})
	return record.duplicate(true)


func identify_owner(content_id: String) -> String:
	return str(_owners.get(content_id, ""))


func inspect_overrides() -> Array[Dictionary]:
	return _applied_overrides.duplicate(true)


func get_localization_value(locale: String, key: String, fallback_locale := "en") -> Variant:
	for candidate_locale in [locale, locale.split("-")[0], fallback_locale]:
		var table: Dictionary = _localizations.get(candidate_locale, {})
		if table.has(key):
			return table[key].value
	return null


func explain_reference(content_id: String, expected_kinds: Array[String] = []) -> Dictionary:
	if not ContentPathPolicy.is_namespaced_id(content_id):
		return {"resolved": false, "code": "INVALID_CONTENT_ID", "reason": "Reference is not a stable namespaced ID", "content_id": content_id}
	if not _definitions.has(content_id):
		return {"resolved": false, "code": "MISSING_CONTENT", "reason": "No enabled resolved pack defines this ID", "content_id": content_id}
	var record: Dictionary = _definitions[content_id]
	if not expected_kinds.is_empty() and record.kind not in expected_kinds and record.schema_name not in expected_kinds:
		return {"resolved": false, "code": "CONTENT_KIND_MISMATCH", "reason": "Reference resolved to %s" % record.kind, "content_id": content_id, "actual_kind": record.kind}
	return {"resolved": true, "code": "OK", "content_id": content_id, "owner_pack_id": record.owner_pack_id, "kind": record.kind}


func deterministic_snapshot() -> Dictionary:
	var packs: Array[Dictionary] = []
	for pack in _resolved_packs:
		packs.append({
			"pack_id": pack.pack_id,
			"version": pack.version,
			"content_api_version": pack.content_api_version,
			"resolved_order": pack.resolved_order,
			"fingerprint": pack.fingerprint,
		})
	var content_ids: Array[String] = []
	for content_id in _definitions:
		content_ids.append(content_id)
	content_ids.sort()
	var core := {"content_api_version": CONTENT_API_VERSION, "packs": packs, "content_ids": content_ids}
	var canonical := JSON.stringify(core, "", true, true)
	core["snapshot_fingerprint"] = canonical.sha256_text()
	return core


func rejected_packs() -> Array[Dictionary]:
	return _rejected_packs.duplicate(true)


func diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


func _reset() -> void:
	_resolved_packs.clear()
	_definitions.clear()
	_owners.clear()
	_localizations.clear()
	_applied_overrides.clear()
	_rejected_packs.clear()
	_diagnostics.clear()


func _discover_root(root_config: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var root_path := str(root_config.get("path", ""))
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	var names: Array[String] = []
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir() and not name.begins_with("."):
			names.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	names.sort()
	for directory_name in names:
		var pack_root := root_path.path_join(directory_name)
		var manifest_path := pack_root.path_join("manifest.json")
		if FileAccess.file_exists(manifest_path):
			var candidate := _load_candidate(pack_root, directory_name, root_config)
			if not candidate.is_empty():
				result.append(candidate)
	return result


func _load_candidate(pack_root: String, directory_name: String, root_config: Dictionary) -> Dictionary:
	var source_prefix := "%s:%s" % [root_config.get("label", "root"), directory_name]
	var manifest_source := "%s/manifest.json" % source_prefix
	var manifest_result := _read_json(pack_root.path_join("manifest.json"), manifest_source, "$", "")
	if not manifest_result.ok:
		_reject("", source_prefix, "MALFORMED_MANIFEST")
		return {}
	var manifest: Dictionary = manifest_result.data
	var pack_id := str(manifest.get("pack_id", ""))
	var start_errors := _error_count()
	_validate_manifest(manifest, manifest_source, pack_id)
	if _error_count() > start_errors:
		_reject(pack_id, source_prefix, "INVALID_MANIFEST")
		return {}
	_validate_pack_file_inventory(pack_root, source_prefix, pack_id)
	if _error_count() > start_errors:
		_reject(pack_id, source_prefix, "INVALID_MANIFEST_OR_PAYLOAD")
		return {}
	var documents: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for index in manifest.entry_points.size():
		var relative_path: String = manifest.entry_points[index]
		var source_file := "%s/%s" % [source_prefix, relative_path]
		var path_error := ContentPathPolicy.validate_relative_path(relative_path, ["json"])
		if not path_error.is_empty():
			_add_error("UNSAFE_ENTRY_PATH", path_error, manifest_source, "$.entry_points[%d]" % index, pack_id)
			continue
		var absolute_path := pack_root.path_join(relative_path)
		if not FileAccess.file_exists(absolute_path):
			_add_error("ENTRY_NOT_FOUND", "Entry point does not exist", manifest_source, "$.entry_points[%d]" % index, pack_id)
			continue
		var document_result := _read_json(absolute_path, source_file, "$", pack_id)
		if not document_result.ok:
			continue
		var document: Dictionary = document_result.data
		var schema_name := str(document.get("$schema", "")).get_file()
		if schema_name not in SUPPORTED_SCHEMAS:
			_add_error("UNSUPPORTED_SCHEMA", "Unsupported or missing content schema", source_file, "$.$schema", pack_id)
			continue
		var kind := schema_name.trim_suffix(".schema.json")
		var record := {"data": document, "schema_name": schema_name, "kind": kind, "source_file": source_file, "relative_path": relative_path}
		if schema_name == "localization-bundle.schema.json":
			_validate_localization_record(record, pack_id)
		else:
			_validate_content_record(record, manifest, pack_id, seen_ids)
		_validate_declared_assets(record, manifest, pack_root, pack_id)
		documents.append(record)
	if _error_count() > start_errors:
		_reject(pack_id, source_prefix, "INVALID_CONTENT")
		return {}
	var fingerprint := _fingerprint_pack_files(pack_root)
	return {
		"pack_id": pack_id,
		"manifest": manifest,
		"documents": documents,
		"pack_root": pack_root,
		"source": source_prefix,
		"source_type": str(root_config.get("source_type", "fixture")),
		"fingerprint": fingerprint,
	}


func _validate_manifest(manifest: Dictionary, source: String, pack_id: String) -> void:
	var required := ["pack_id", "display_name_key", "version", "content_api_version", "type", "authors", "license", "dependencies", "optional_dependencies", "incompatibilities", "load_priority", "base_pack_enabled", "entry_points", "asset_roots", "overrides"]
	var allowed := ["$schema", "pack_id", "display_name_key", "version", "content_api_version", "enabled", "type", "authors", "license", "dependencies", "optional_dependencies", "incompatibilities", "load_priority", "base_pack_enabled", "entry_points", "asset_roots", "overrides"]
	for key in required:
		if not manifest.has(key):
			_add_error("MISSING_MANIFEST_FIELD", "Required manifest field is missing", source, "$.%s" % key, pack_id)
	for key in manifest:
		if str(key) not in allowed:
			_add_error("SCHEMA_ADDITIONAL_PROPERTY", "Additional manifest property is not allowed", source, "$.%s" % str(key), pack_id)
	if manifest.has("$schema") and not manifest["$schema"] is String:
		_add_error("SCHEMA_TYPE", "$schema must be a string", source, "$.$schema", pack_id)
	if not ContentPathPolicy.is_pack_id(manifest.get("pack_id")):
		_add_error("INVALID_PACK_ID", "Pack ID must use lowercase stable characters", source, "$.pack_id", pack_id)
	if not ContentPathPolicy.is_semver(manifest.get("version")):
		_add_error("INVALID_PACK_VERSION", "Pack version must be semantic x.y.z", source, "$.version", pack_id)
	if not manifest.get("display_name_key") is String or str(manifest.get("display_name_key")).is_empty():
		_add_error("INVALID_DISPLAY_NAME_KEY", "display_name_key must be a non-empty string", source, "$.display_name_key", pack_id)
	if manifest.get("content_api_version") != CONTENT_API_VERSION:
		_add_error("INCOMPATIBLE_CONTENT_API", "Expected experimental content API %s" % CONTENT_API_VERSION, source, "$.content_api_version", pack_id)
	if manifest.get("type") not in ["skin", "content", "total_conversion"]:
		_add_error("INVALID_PACK_TYPE", "Unknown pack type", source, "$.type", pack_id)
	if manifest.get("type") != "total_conversion" and manifest.get("base_pack_enabled") == false:
		_add_error("INVALID_BASE_PACK_POLICY", "Only total_conversion packs may disable the bundled base pack", source, "$.base_pack_enabled", pack_id)
	if (not manifest.get("load_priority") is float and not manifest.get("load_priority") is int) or float(manifest.get("load_priority", 0)) != floorf(float(manifest.get("load_priority", 0))):
		_add_error("INVALID_LOAD_PRIORITY", "Load priority must be an integer", source, "$.load_priority", pack_id)
	if not manifest.get("authors") is Array or manifest.get("authors").is_empty():
		_add_error("INVALID_AUTHORS", "authors must contain at least one value", source, "$.authors", pack_id)
	else:
		for index in manifest.authors.size():
			if not manifest.authors[index] is String or str(manifest.authors[index]).is_empty():
				_add_error("INVALID_AUTHOR", "Author names must be non-empty strings", source, "$.authors[%d]" % index, pack_id)
	if not manifest.get("license") is Dictionary or not manifest.get("license").has("code") or not manifest.get("license").has("assets"):
		_add_error("INVALID_LICENSE", "license must declare code and assets", source, "$.license", pack_id)
	else:
		for license_key in manifest.license:
			if str(license_key) not in ["code", "assets", "source"]:
				_add_error("SCHEMA_ADDITIONAL_PROPERTY", "Additional license property is not allowed", source, "$.license.%s" % str(license_key), pack_id)
		for license_key in ["code", "assets"]:
			if not manifest.license[license_key] is String:
				_add_error("SCHEMA_TYPE", "License values must be strings", source, "$.license.%s" % license_key, pack_id)
		if manifest.license.has("source") and not manifest.license.source is String:
			_add_error("SCHEMA_TYPE", "License source must be a string", source, "$.license.source", pack_id)
	if not manifest.get("base_pack_enabled") is bool:
		_add_error("INVALID_BASE_PACK_POLICY", "base_pack_enabled must be boolean", source, "$.base_pack_enabled", pack_id)
	if manifest.has("enabled") and not manifest.enabled is bool:
		_add_error("INVALID_ENABLED_POLICY", "enabled must be boolean", source, "$.enabled", pack_id)
	for field in ["dependencies", "optional_dependencies", "incompatibilities"]:
		if not manifest.get(field) is Array:
			_add_error("INVALID_PACK_RELATIONSHIPS", "%s must be an array" % field, source, "$.%s" % field, pack_id)
			continue
		for index in manifest[field].size():
			var reference: Variant = manifest[field][index]
			if not reference is Dictionary or not ContentPathPolicy.is_pack_id(reference.get("pack_id")) or not _is_version_requirement(reference.get("version")):
				_add_error("INVALID_PACK_REFERENCE", "Pack reference requires pack_id and version", source, "$.%s[%d]" % [field, index], pack_id)
			elif reference.size() != 2:
				_add_error("SCHEMA_ADDITIONAL_PROPERTY", "Pack references may only contain pack_id and version", source, "$.%s[%d]" % [field, index], pack_id)
	for field in ["entry_points", "asset_roots", "overrides"]:
		if not manifest.get(field) is Array:
			_add_error("INVALID_MANIFEST_FIELD", "%s must be an array" % field, source, "$.%s" % field, pack_id)
		elif _has_duplicates(manifest[field]):
			_add_error("DUPLICATE_MANIFEST_VALUE", "%s values must be unique" % field, source, "$.%s" % field, pack_id)
	if manifest.get("entry_points") is Array:
		for index in manifest.entry_points.size():
			var error := ContentPathPolicy.validate_relative_path(manifest.entry_points[index], ["json"])
			if not error.is_empty():
				_add_error("UNSAFE_ENTRY_PATH", error, source, "$.entry_points[%d]" % index, pack_id)
	if manifest.get("asset_roots") is Array:
		for index in manifest.asset_roots.size():
			var error := ContentPathPolicy.validate_relative_path(manifest.asset_roots[index])
			if not error.is_empty():
				_add_error("UNSAFE_ASSET_ROOT", error, source, "$.asset_roots[%d]" % index, pack_id)
	if manifest.get("overrides") is Array:
		for index in manifest.overrides.size():
			if not ContentPathPolicy.is_namespaced_id(manifest.overrides[index]):
				_add_error("INVALID_OVERRIDE_ID", "Override must be a namespaced content ID", source, "$.overrides[%d]" % index, pack_id)


func _validate_content_record(record: Dictionary, manifest: Dictionary, pack_id: String, seen_ids: Dictionary) -> void:
	var document: Dictionary = record.data
	var source: String = record.source_file
	for schema_error in ContentSchemaValidator.validate(record.schema_name, document):
		_add_error(schema_error.code, schema_error.message, source, schema_error.json_path, pack_id)
	var content_id: Variant = document.get("id")
	if not ContentPathPolicy.is_namespaced_id(content_id):
		_add_error("INVALID_CONTENT_ID", "Content ID must be namespaced", source, "$.id", pack_id)
		return
	if seen_ids.has(content_id):
		_add_error("DUPLICATE_ID_IN_PACK", "Content ID is duplicated in this pack", source, "$.id", pack_id)
	else:
		seen_ids[content_id] = source
	var owns_id := str(content_id).begins_with(pack_id + ":")
	if not owns_id and content_id not in manifest.overrides:
		_add_error("UNAUTHORIZED_NAMESPACE", "Pack does not own this ID and did not declare an override", source, "$.id", pack_id)
	if record.schema_name == "feature-gate.schema.json":
		if not document.get("feature") is String or not ContentPathPolicy.is_namespaced_id(document.get("feature")):
			_add_error("INVALID_FEATURE_ID", "Feature ID must be namespaced", source, "$.feature", pack_id)
		if not document.get("reward_ids") is Array:
			_add_error("INVALID_REWARD_IDS", "reward_ids must be an array", source, "$.reward_ids", pack_id)
		else:
			for index in document.reward_ids.size():
				if not ContentPathPolicy.is_namespaced_id(document.reward_ids[index]):
					_add_error("INVALID_REWARD_ID", "Reward ID must be namespaced", source, "$.reward_ids[%d]" % index, pack_id)
		if not document.get("condition") is Dictionary:
			_add_error("INVALID_GATE_CONDITION", "condition must be an object", source, "$.condition", pack_id)
	record["id"] = content_id


func _validate_candidate_references(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var remaining := candidates.duplicate()
	while true:
		var definitions: Dictionary = {}
		var localization_keys: Dictionary = {}
		for candidate in remaining:
			var pack_localization: Dictionary = {}
			for record in candidate.documents:
				if record.schema_name == "localization-bundle.schema.json":
					for key in record.data.strings:
						pack_localization[str(key)] = true
				elif record.has("id"):
					definitions[str(record.id)] = record.schema_name
			localization_keys[candidate.pack_id] = pack_localization

		var invalid_pack_ids: Dictionary = {}
		for candidate in remaining:
			var start_errors := _error_count()
			var pack_localization: Dictionary = localization_keys.get(candidate.pack_id, {})
			var display_name_key := str(candidate.manifest.get("display_name_key", ""))
			if not candidate.manifest.entry_points.is_empty() and not pack_localization.has(display_name_key):
				_add_error("MISSING_LOCALIZATION_KEY", "Pack display name key is not defined by the pack", candidate.source + "/manifest.json", "$.display_name_key", candidate.pack_id)
			for record in candidate.documents:
				if record.schema_name == "localization-bundle.schema.json":
					continue
				_validate_record_localization(record, pack_localization, candidate.pack_id)
				_validate_record_references(record, definitions, candidate.pack_id)
			if _error_count() > start_errors:
				invalid_pack_ids[candidate.pack_id] = true

		if invalid_pack_ids.is_empty():
			return remaining
		var next: Array[Dictionary] = []
		for candidate in remaining:
			if invalid_pack_ids.has(candidate.pack_id):
				_reject(candidate.pack_id, candidate.source, "INVALID_REFERENCES")
			else:
				next.append(candidate)
		remaining = next
	return remaining


func _validate_record_localization(record: Dictionary, localization_keys: Dictionary, pack_id: String) -> void:
	if not record.data.has("display_name_key"):
		return
	var display_name_key := str(record.data.display_name_key)
	if not localization_keys.has(display_name_key):
		_add_error("MISSING_LOCALIZATION_KEY", "Content display name key is not defined by the pack", record.source_file, "$.display_name_key", pack_id)


func _validate_record_references(record: Dictionary, definitions: Dictionary, pack_id: String) -> void:
	var data: Dictionary = record.data
	match record.schema_name:
		"starter-pool.schema.json":
			_validate_reference_array(data.egg_ids, "$.egg_ids", ["egg.schema.json"], record, definitions, pack_id)
		"egg.schema.json":
			_validate_reference(data.family_id, "$.family_id", ["species-family.schema.json"], record, definitions, pack_id)
			_validate_reference(data.hatch_form_id, "$.hatch_form_id", ["form.schema.json"], record, definitions, pack_id)
			_validate_reference(data.animation_profile_id, "$.animation_profile_id", ["animation-profile.schema.json"], record, definitions, pack_id)
		"species-family.schema.json":
			_validate_reference_array(data.form_ids, "$.form_ids", ["form.schema.json"], record, definitions, pack_id)
			_validate_reference(data.evolution_graph_id, "$.evolution_graph_id", ["evolution-graph.schema.json"], record, definitions, pack_id)
		"form.schema.json":
			_validate_reference(data.family_id, "$.family_id", ["species-family.schema.json"], record, definitions, pack_id)
			_validate_reference(data.animation_profile_id, "$.animation_profile_id", ["animation-profile.schema.json"], record, definitions, pack_id)
			if data.has("care_profile_id"):
				_validate_reference(data.care_profile_id, "$.care_profile_id", ["care-profile.schema.json"], record, definitions, pack_id)
			if data.has("move_ids"):
				_validate_reference_array(data.move_ids, "$.move_ids", ["move.schema.json"], record, definitions, pack_id)
		"evolution-graph.schema.json":
			for index in data.rules.size():
				var rule: Dictionary = data.rules[index]
				_validate_reference(rule.from_form_id, "$.rules[%d].from_form_id" % index, ["form.schema.json"], record, definitions, pack_id)
				_validate_reference(rule.to_form_id, "$.rules[%d].to_form_id" % index, ["form.schema.json"], record, definitions, pack_id)
		"enemy-encounter.schema.json":
			_validate_reference_array(data.move_ids, "$.move_ids", ["move.schema.json"], record, definitions, pack_id)
			if data.has("animation_profile_id"):
				_validate_reference(data.animation_profile_id, "$.animation_profile_id", ["animation-profile.schema.json"], record, definitions, pack_id)
			for index in data.drops.size():
				_validate_reference(data.drops[index].item_id, "$.drops[%d].item_id" % index, ["item.schema.json"], record, definitions, pack_id)
		"dungeon.schema.json":
			_validate_reference_array(data.encounter_ids, "$.encounter_ids", ["enemy-encounter.schema.json"], record, definitions, pack_id)
			_validate_reference(data.boss_encounter_id, "$.boss_encounter_id", ["enemy-encounter.schema.json"], record, definitions, pack_id)
			_validate_reference_array(data.reward_item_ids, "$.reward_item_ids", ["item.schema.json"], record, definitions, pack_id)
			_validate_reference_array(data.unlock_ids, "$.unlock_ids", ["habitat-theme.schema.json", "feature-gate.schema.json"], record, definitions, pack_id)
			if data.has("prerequisite_gate_id"):
				_validate_reference(data.prerequisite_gate_id, "$.prerequisite_gate_id", ["feature-gate.schema.json"], record, definitions, pack_id)
			if data.has("boss_flag_id"):
				_validate_reference(data.boss_flag_id, "$.boss_flag_id", ["feature-gate.schema.json"], record, definitions, pack_id)
			for node in data.get("nodes", []):
				if node is Dictionary and node.has("encounter_id"):
					_validate_reference(node.encounter_id, "$.nodes.encounter_id", ["enemy-encounter.schema.json"], record, definitions, pack_id)
		"habitat-theme.schema.json":
			_validate_reference_array(data.furniture_ids, "$.furniture_ids", ["furniture-prop.schema.json"], record, definitions, pack_id)
			_validate_reference(data.unlock_gate_id, "$.unlock_gate_id", ["feature-gate.schema.json"], record, definitions, pack_id)
		"farm-job.schema.json":
			_validate_reference(data.station_id, "$.station_id", ["furniture-prop.schema.json"], record, definitions, pack_id)
			_validate_reference(data.output_item_id, "$.output_item_id", ["item.schema.json"], record, definitions, pack_id)
		"ailment.schema.json":
			_validate_reference(data.treatment_item_id, "$.treatment_item_id", ["item.schema.json"], record, definitions, pack_id)
		"injury.schema.json":
			_validate_reference(data.treatment_item_id, "$.treatment_item_id", ["item.schema.json"], record, definitions, pack_id)
		"progression-balance.schema.json":
			_validate_reference(data.battle_gate_id, "$.battle_gate_id", ["feature-gate.schema.json"], record, definitions, pack_id)
			_validate_reference(data.dungeon_gate_id, "$.dungeon_gate_id", ["feature-gate.schema.json"], record, definitions, pack_id)
			_validate_reference_array(data.injury_ids, "$.injury_ids", ["injury.schema.json"], record, definitions, pack_id)


func _validate_reference_array(values: Array, json_path: String, expected_schemas: Array, record: Dictionary, definitions: Dictionary, pack_id: String) -> void:
	for index in values.size():
		_validate_reference(values[index], "%s[%d]" % [json_path, index], expected_schemas, record, definitions, pack_id)


func _validate_reference(content_id: Variant, json_path: String, expected_schemas: Array, record: Dictionary, definitions: Dictionary, pack_id: String) -> void:
	var id := str(content_id)
	if not definitions.has(id):
		_add_error("UNRESOLVED_REFERENCE", "Referenced content ID is not available", record.source_file, json_path, pack_id)
		return
	if definitions[id] not in expected_schemas:
		_add_error("CONTENT_KIND_MISMATCH", "Referenced content ID resolves to an unexpected schema", record.source_file, json_path, pack_id)


func _validate_localization_record(record: Dictionary, pack_id: String) -> void:
	var document: Dictionary = record.data
	for schema_error in ContentSchemaValidator.validate(record.schema_name, document):
		_add_error(schema_error.code, schema_error.message, record.source_file, schema_error.json_path, pack_id)
	if not document.get("locale") is String or str(document.get("locale")).is_empty():
		_add_error("INVALID_LOCALE", "Localization locale is required", record.source_file, "$.locale", pack_id)
	if not document.get("strings") is Dictionary:
		_add_error("INVALID_LOCALIZATION", "Localization strings must be an object", record.source_file, "$.strings", pack_id)


func _validate_declared_assets(record: Dictionary, manifest: Dictionary, pack_root: String, pack_id: String) -> void:
	var assets: Array[Dictionary] = []
	var data: Dictionary = record.data
	match record.schema_name:
		"animation-profile.schema.json":
			assets.append({"path": data.get("preview", ""), "json_path": "$.preview"})
			assets.append({"path": data.get("portrait", ""), "json_path": "$.portrait"})
			if data.get("world_animations") is Dictionary:
				for animation_name in data.world_animations:
					var animation: Variant = data.world_animations[animation_name]
					if animation is Dictionary:
						assets.append({"path": animation.get("asset", ""), "json_path": "$.world_animations.%s.asset" % animation_name})
		"habitat-theme.schema.json":
			assets.append({"path": data.get("background_asset", ""), "json_path": "$.background_asset"})
			assets.append({"path": data.get("ground_asset", ""), "json_path": "$.ground_asset"})
		"furniture-prop.schema.json":
			assets.append({"path": data.get("asset", ""), "json_path": "$.asset"})
	for asset in assets:
		var location := str(asset.path)
		var error := ContentPathPolicy.validate_relative_path(location, ContentPathPolicy.SAFE_MEDIA_EXTENSIONS)
		if not error.is_empty():
			_add_error("UNSAFE_ASSET_PATH", error, record.source_file, asset.json_path, pack_id)
			continue
		var inside_root := false
		for asset_root in manifest.asset_roots:
			if location == asset_root or location.begins_with(str(asset_root) + "/"):
				inside_root = true
				break
		if not inside_root:
			_add_error("ASSET_OUTSIDE_DECLARED_ROOT", "Asset path is outside declared asset roots", record.source_file, asset.json_path, pack_id)
		elif not FileAccess.file_exists(pack_root.path_join(location)) and not location.begins_with("assets/placeholders/"):
			_add_error("ASSET_NOT_FOUND", "Declared asset does not exist", record.source_file, asset.json_path, pack_id)


func _validate_pack_file_inventory(pack_root: String, source: String, pack_id: String) -> void:
	var inventory: Array[String] = []
	var links: Array[String] = []
	_collect_files(pack_root, "", inventory, links)
	for relative_path in links:
		_add_error("SYMLINK_PAYLOAD", "Symbolic links and reparse points are forbidden in packs", "%s/%s" % [source, relative_path], "$", pack_id)
	if inventory.size() > MAX_PACK_FILES:
		_add_error("PACK_FILE_LIMIT", "Pack exceeds %d files" % MAX_PACK_FILES, source, "$", pack_id)
	var total_bytes := 0
	for relative_path in inventory:
		if ContentPathPolicy.is_forbidden_payload(relative_path):
			_add_error("EXECUTABLE_PAYLOAD", "Executable or archive payload is forbidden", "%s/%s" % [source, relative_path], "$", pack_id)
		var absolute_path := pack_root.path_join(relative_path)
		var file := FileAccess.open(absolute_path, FileAccess.READ)
		if file != null:
			var length := file.get_length()
			file.close()
			total_bytes += length
			if relative_path.get_extension().to_lower() == "json" and length > MAX_JSON_BYTES:
				_add_error("JSON_SIZE_LIMIT", "JSON file exceeds %d bytes" % MAX_JSON_BYTES, "%s/%s" % [source, relative_path], "$", pack_id)
	if total_bytes > MAX_PACK_BYTES:
		_add_error("PACK_SIZE_LIMIT", "Pack exceeds %d bytes" % MAX_PACK_BYTES, source, "$", pack_id)


func _collect_files(root_path: String, relative_path: String, output: Array[String], links: Array[String]) -> void:
	var directory_path := root_path if relative_path.is_empty() else root_path.path_join(relative_path)
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	var names: Array[String] = []
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			names.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	names.sort()
	for child_name in names:
		var child_relative := child_name if relative_path.is_empty() else relative_path.path_join(child_name)
		var child_path := root_path.path_join(child_relative)
		if directory.is_link(child_name):
			links.append(child_relative)
		elif DirAccess.dir_exists_absolute(child_path):
			_collect_files(root_path, child_relative, output, links)
		else:
			output.append(child_relative)


func _fingerprint_pack_files(pack_root: String) -> String:
	var inventory: Array[String] = []
	var links: Array[String] = []
	_collect_files(pack_root, "", inventory, links)
	var source_hashes: Array[Dictionary] = []
	for relative_path in inventory:
		var extension := relative_path.get_extension().to_lower()
		if extension == "json" or extension in ContentPathPolicy.SAFE_MEDIA_EXTENSIONS:
			source_hashes.append({"path": relative_path, "sha256": FileAccess.get_sha256(pack_root.path_join(relative_path))})
	source_hashes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.path < right.path)
	return JSON.stringify(source_hashes, "", true, true).sha256_text()


func _reject_duplicate_pack_ids(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for candidate in candidates:
		grouped.get_or_add(candidate.pack_id, []).append(candidate)
	var result: Array[Dictionary] = []
	var ids: Array = grouped.keys()
	ids.sort()
	for pack_id in ids:
		var group: Array = grouped[pack_id]
		if group.size() > 1:
			for candidate in group:
				_add_error("DUPLICATE_PACK_ID", "Pack ID is discovered more than once", candidate.source + "/manifest.json", "$.pack_id", pack_id)
				_reject(pack_id, candidate.source, "DUPLICATE_PACK_ID")
		else:
			result.append(group[0])
	return result


func _apply_disabled_and_total_conversion_policy(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var disabled := _disabled_pack_ids.duplicate()
	for candidate in candidates:
		if candidate.manifest.type == "total_conversion" and bool(candidate.manifest.get("enabled", true)) and not disabled.has(candidate.pack_id) and not bool(candidate.manifest.base_pack_enabled):
			disabled[BASE_PACK_ID] = true
	var result: Array[Dictionary] = []
	for candidate in candidates:
		if not bool(candidate.manifest.get("enabled", true)) or disabled.has(candidate.pack_id):
			_reject(candidate.pack_id, candidate.source, "DISABLED")
		else:
			result.append(candidate)
	return result


func _validate_relationships(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var active: Dictionary = {}
	for candidate in candidates:
		active[candidate.pack_id] = candidate
	var rejected: Dictionary = {}
	for candidate in candidates:
		for dependency in candidate.manifest.dependencies:
			var required_id := str(dependency.pack_id)
			if not active.has(required_id):
				_add_error("MISSING_REQUIRED_DEPENDENCY", "Required pack %s is unavailable" % required_id, candidate.source + "/manifest.json", "$.dependencies", candidate.pack_id)
				rejected[candidate.pack_id] = "MISSING_REQUIRED_DEPENDENCY"
			elif not _version_matches(str(active[required_id].manifest.version), str(dependency.version)):
				_add_error("DEPENDENCY_VERSION_MISMATCH", "Required pack %s does not match %s" % [required_id, dependency.version], candidate.source + "/manifest.json", "$.dependencies", candidate.pack_id)
				rejected[candidate.pack_id] = "DEPENDENCY_VERSION_MISMATCH"
		for conflict in candidate.manifest.incompatibilities:
			var conflict_id := str(conflict.pack_id)
			if active.has(conflict_id) and _version_matches(str(active[conflict_id].manifest.version), str(conflict.version)):
				rejected[candidate.pack_id] = "PACK_CONFLICT"
				rejected[conflict_id] = "PACK_CONFLICT"
				_add_error("PACK_CONFLICT", "Enabled pack conflicts with %s" % conflict_id, candidate.source + "/manifest.json", "$.incompatibilities", candidate.pack_id)
	var result: Array[Dictionary] = []
	for candidate in candidates:
		if rejected.has(candidate.pack_id):
			_reject(candidate.pack_id, candidate.source, rejected[candidate.pack_id])
		else:
			result.append(candidate)
	return result


func _topological_order(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var remaining: Dictionary = {}
	for candidate in candidates:
		remaining[candidate.pack_id] = candidate
	var ordered: Array[Dictionary] = []
	while not remaining.is_empty():
		var ready: Array[Dictionary] = []
		for pack_id in remaining:
			var candidate: Dictionary = remaining[pack_id]
			var dependencies_satisfied := true
			for relationship in candidate.manifest.dependencies + candidate.manifest.optional_dependencies:
				var dependency_id := str(relationship.pack_id)
				if remaining.has(dependency_id):
					dependencies_satisfied = false
					break
			if dependencies_satisfied:
				ready.append(candidate)
		if ready.is_empty():
			var cycle_ids: Array = remaining.keys()
			cycle_ids.sort()
			for pack_id in cycle_ids:
				var candidate: Dictionary = remaining[pack_id]
				_add_error("DEPENDENCY_CYCLE", "Dependency cycle prevents deterministic ordering", candidate.source + "/manifest.json", "$.dependencies", pack_id)
				_reject(pack_id, candidate.source, "DEPENDENCY_CYCLE")
			return ordered
		ready.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_priority := int(left.manifest.load_priority)
			var right_priority := int(right.manifest.load_priority)
			return left.pack_id < right.pack_id if left_priority == right_priority else left_priority < right_priority
		)
		var selected: Dictionary = ready[0]
		ordered.append(selected)
		remaining.erase(selected.pack_id)
	return ordered


func _apply_ordered_packs(ordered: Array[Dictionary]) -> void:
	var applied_pack_ids: Dictionary = {}
	for candidate in ordered:
		var missing_applied_dependency := ""
		for dependency in candidate.manifest.dependencies:
			if not applied_pack_ids.has(str(dependency.pack_id)):
				missing_applied_dependency = str(dependency.pack_id)
				break
		if not missing_applied_dependency.is_empty():
			_reject(candidate.pack_id, candidate.source, "REJECTED_DEPENDENCY")
			continue
		var pack_error := ""
		for override_id in candidate.manifest.overrides:
			if not _definitions.has(override_id):
				pack_error = "MISSING_OVERRIDE_TARGET"
				_add_error(pack_error, "Declared override target is unavailable", candidate.source + "/manifest.json", "$.overrides", candidate.pack_id)
				break
		for record in candidate.documents:
			if not record.has("id"):
				continue
			var content_id: String = record.id
			if _definitions.has(content_id):
				if content_id not in candidate.manifest.overrides:
					pack_error = "UNAUTHORIZED_OVERRIDE"
					_add_error(pack_error, "Definition collides without an explicit override", record.source_file, "$.id", candidate.pack_id)
					break
				if candidate.manifest.type == "skin" and record.schema_name not in SKIN_OVERRIDE_SCHEMAS:
					pack_error = "SKIN_MECHANICS_OVERRIDE"
					_add_error(pack_error, "Skin packs may override presentation definitions only", record.source_file, "$.id", candidate.pack_id)
					break
		if not pack_error.is_empty():
			_reject(candidate.pack_id, candidate.source, pack_error)
			continue
		for record in candidate.documents:
			if record.has("id"):
				var content_id: String = record.id
				if _definitions.has(content_id):
					_applied_overrides.append({"content_id": content_id, "previous_owner": _owners[content_id], "replacement_owner": candidate.pack_id})
				var public_record: Dictionary = record.duplicate(true)
				public_record["pack_root"] = candidate.pack_root
				public_record["owner_pack_id"] = candidate.pack_id
				_definitions[content_id] = public_record
				_owners[content_id] = candidate.pack_id
			elif record.schema_name == "localization-bundle.schema.json":
				var locale := str(record.data.locale)
				var table: Dictionary = _localizations.get_or_add(locale, {})
				for key in record.data.strings:
					table[key] = {"value": record.data.strings[key], "owner_pack_id": candidate.pack_id, "source_file": record.source_file}
		var public_pack := {
			"pack_id": candidate.pack_id,
			"version": candidate.manifest.version,
			"content_api_version": candidate.manifest.content_api_version,
			"type": candidate.manifest.type,
			"load_priority": candidate.manifest.load_priority,
			"source_type": candidate.source_type,
			"source": candidate.source,
			"resolved_order": _resolved_packs.size(),
			"fingerprint": candidate.fingerprint,
		}
		_resolved_packs.append(public_pack)
		applied_pack_ids[candidate.pack_id] = true


func _version_matches(actual: String, requirement: String) -> bool:
	if requirement in ["", "*"]:
		return true
	if requirement.begins_with(">="):
		return _semver_compare(actual, requirement.trim_prefix(">=")) >= 0
	if requirement.begins_with("^"):
		var base := requirement.trim_prefix("^")
		return _semver_compare(actual, base) >= 0 and actual.get_slice(".", 0) == base.get_slice(".", 0)
	return actual == requirement


func _is_version_requirement(value: Variant) -> bool:
	if not value is String:
		return false
	if value == "*":
		return true
	var candidate: String = value
	if candidate.begins_with(">="):
		candidate = candidate.trim_prefix(">=")
	elif candidate.begins_with("^"):
		candidate = candidate.trim_prefix("^")
	return ContentPathPolicy.is_semver(candidate)


func _has_duplicates(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		var key := JSON.stringify(value, "", true, true)
		if seen.has(key):
			return true
		seen[key] = true
	return false


func _semver_compare(left: String, right: String) -> int:
	for index in 3:
		var left_part := int(left.get_slice(".", index))
		var right_part := int(right.get_slice(".", index))
		if left_part != right_part:
			return 1 if left_part > right_part else -1
	return 0


func _read_json(path: String, source_file: String, json_path: String, pack_id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add_error("FILE_READ_ERROR", "Unable to open JSON file", source_file, json_path, pack_id)
		return {"ok": false}
	if file.get_length() > MAX_JSON_BYTES:
		file.close()
		_add_error("JSON_SIZE_LIMIT", "JSON file exceeds %d bytes" % MAX_JSON_BYTES, source_file, json_path, pack_id)
		return {"ok": false}
	var parser := JSON.new()
	var text := file.get_as_text()
	file.close()
	var parse_error := parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		_add_error("MALFORMED_JSON", "Expected a valid JSON object", source_file, json_path, pack_id)
		return {"ok": false}
	return {"ok": true, "data": parser.data}


func _add_error(code: String, message: String, source: String, json_path: String, pack_id: String) -> void:
	_diagnostics.append(ContentDiagnostic.make(code, message, source, json_path, pack_id))


func _error_count() -> int:
	var count := 0
	for diagnostic in _diagnostics:
		if diagnostic.severity == "error":
			count += 1
	return count


func _reject(pack_id: String, source: String, reason: String) -> void:
	_rejected_packs.append({"pack_id": pack_id, "source": source, "reason": reason})
