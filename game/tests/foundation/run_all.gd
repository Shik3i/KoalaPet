extends SceneTree

const TEST_ROOT := "user://foundation_tests"

var _failures: Array[String] = []
var _assertions := 0
var _example_registry: ContentPackRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("KoalaPet Milestone 2 foundation tests")
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
	_test_real_pack_discovery_and_snapshot()
	_test_external_pack_discovery()
	_test_snapshot_tracks_safe_media()
	_test_dependency_and_priority_order()
	_test_missing_and_optional_dependencies()
	_test_conflicts_and_disabled_packs()
	_test_total_conversion_policy()
	_test_overrides_and_skin_policy()
	_test_duplicate_and_invalid_ids()
	_test_incompatible_and_malformed_content()
	_test_path_and_payload_security()
	_test_reference_and_localization_queries()
	_test_offline_progress_policy()
	_test_fake_clock()
	_test_save_round_trip_and_backup()
	_test_save_corruption_recovery()
	_test_save_migration_fixture()
	_test_missing_content_quarantine_and_restore()
	_test_invalid_record_quarantine()
	_test_feature_gate_evaluation_and_grants()
	_test_application_bootstrap()
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
	if _failures.is_empty():
		print("RESULT: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("RESULT: FAIL (%d failures, %d assertions)" % [_failures.size(), _assertions])
		quit(1)


func _test_real_pack_discovery_and_snapshot() -> void:
	var repository_fixture_root := ProjectSettings.globalize_path("res://../mods/examples")
	var roots: Array[Dictionary] = [
		ContentPackRegistry.root("res://content_packs", "bundled", "bundled"),
		ContentPackRegistry.root(repository_fixture_root, "development", "fixture"),
	]
	_example_registry = ContentPackRegistry.new(roots)
	var result := _example_registry.discover_and_resolve()
	_assert_equal(result.success, true, "CONTENT-001 bundled and external-style fixture registry resolves")
	_assert_equal(_pack_ids(_example_registry), ["koalapet.base", "example.neutral"], "CONTENT-002 official and fixture packs share deterministic loader")
	_assert_equal(_example_registry.list_documents_by_kind("feature-gate").size(), 5, "CONTENT-003 feature-gate documents indexed")
	_assert_equal(_example_registry.identify_owner("example.neutral:meadow_hatchling"), "example.neutral", "CONTENT-004 owning pack query")
	var first_snapshot := _example_registry.deterministic_snapshot()
	var repeated := ContentPackRegistry.new(roots)
	repeated.discover_and_resolve()
	var second_snapshot := repeated.deterministic_snapshot()
	_assert_equal(first_snapshot, second_snapshot, "CONTENT-005 deterministic content snapshot")
	_assert_equal(first_snapshot.packs.size(), 2, "CONTENT-006 snapshot records enabled packs")
	_assert_true(str(first_snapshot.snapshot_fingerprint).length() == 64, "CONTENT-007 snapshot has stable SHA-256 fingerprint")


func _test_dependency_and_priority_order() -> void:
	var root := _case_root("dependency_order")
	_create_pack(root, "fixture.alpha", {"load_priority": 0})
	_create_pack(root, "fixture.beta", {"load_priority": -100, "dependencies": [{"pack_id": "fixture.alpha", "version": ">=1.0.0"}]})
	_create_pack(root, "fixture.gamma", {"load_priority": 50})
	var registry := _registry_for(root)
	registry.discover_and_resolve()
	_assert_equal(_pack_ids(registry), ["fixture.alpha", "fixture.beta", "fixture.gamma"], "CONTENT-008 dependency topology precedes priority")


func _test_external_pack_discovery() -> void:
	var external_root := TEST_ROOT.path_join("external_mods")
	_create_pack(external_root, "fixture.external", {"load_priority": 100, "documents": [_document("data/item.json", _item("fixture.external:item"))]})
	var roots: Array[Dictionary] = [
		ContentPackRegistry.root("res://content_packs", "bundled", "bundled"),
		ContentPackRegistry.root(external_root, "external", "external"),
	]
	var registry := ContentPackRegistry.new(roots)
	registry.discover_and_resolve()
	_assert_equal(_pack_ids(registry), ["koalapet.base", "fixture.external"], "CONTENT-007A bundled and external packs use one registry")
	_assert_equal(registry.list_resolved_packs()[1].source_type, "external", "CONTENT-007B external source classification is retained")


func _test_snapshot_tracks_safe_media() -> void:
	var root := _case_root("snapshot_media")
	_create_pack(root, "fixture.media", {"asset_roots": ["assets"], "documents": [_document("data/animation.json", _animation("fixture.media:animation", "assets/probe.png"))], "extra_files": {"assets/probe.png": "first-safe-media-fingerprint"}})
	var first := _registry_for(root)
	first.discover_and_resolve()
	var first_fingerprint: String = first.deterministic_snapshot().snapshot_fingerprint
	_write_text(root.path_join("fixture.media/assets/probe.png"), "second-safe-media-fingerprint")
	var second := _registry_for(root)
	second.discover_and_resolve()
	_assert_true(first_fingerprint != second.deterministic_snapshot().snapshot_fingerprint, "CONTENT-007C safe-media changes alter content snapshot fingerprint")


func _test_missing_and_optional_dependencies() -> void:
	var missing_root := _case_root("missing_dependency")
	_create_pack(missing_root, "fixture.dependent", {"dependencies": [{"pack_id": "fixture.absent", "version": "*"}]})
	var missing := _registry_for(missing_root)
	missing.discover_and_resolve()
	_assert_equal(missing.list_resolved_packs().size(), 0, "CONTENT-009 missing required dependency rejects pack")
	_assert_diagnostic(missing, "MISSING_REQUIRED_DEPENDENCY", "$.dependencies", "CONTENT-010 dependency diagnostic is actionable")

	var optional_root := _case_root("optional_dependency")
	_create_pack(optional_root, "fixture.optional", {"optional_dependencies": [{"pack_id": "fixture.absent", "version": "*"}]})
	var optional := _registry_for(optional_root)
	optional.discover_and_resolve()
	_assert_equal(_pack_ids(optional), ["fixture.optional"], "CONTENT-011 missing optional dependency does not reject pack")


func _test_conflicts_and_disabled_packs() -> void:
	var conflict_root := _case_root("conflicts")
	_create_pack(conflict_root, "fixture.left", {"incompatibilities": [{"pack_id": "fixture.right", "version": "*"}]})
	_create_pack(conflict_root, "fixture.right")
	var conflict := _registry_for(conflict_root)
	conflict.discover_and_resolve()
	_assert_equal(conflict.list_resolved_packs().size(), 0, "CONTENT-012 conflict rejects both enabled packs")
	_assert_equal(conflict.rejected_packs().size(), 2, "CONTENT-013 conflict rejection inventory")

	var disabled_root := _case_root("disabled")
	_create_pack(disabled_root, "fixture.disabled", {"enabled": false})
	var disabled := _registry_for(disabled_root)
	disabled.discover_and_resolve()
	_assert_equal(disabled.rejected_packs()[0].reason, "DISABLED", "CONTENT-014 disabled pack is classified without loading")


func _test_total_conversion_policy() -> void:
	var root := _case_root("total_conversion")
	_create_pack(root, "koalapet.base", {"version": "0.0.0"})
	_create_pack(root, "fixture.total", {"type": "total_conversion", "base_pack_enabled": false})
	var registry := _registry_for(root)
	registry.discover_and_resolve()
	_assert_equal(_pack_ids(registry), ["fixture.total"], "CONTENT-015 total conversion may explicitly disable base pack")
	_assert_equal(registry.rejected_packs()[0].pack_id, "koalapet.base", "CONTENT-016 disabled base remains visible in rejected inventory")


func _test_overrides_and_skin_policy() -> void:
	var allowed_root := _case_root("allowed_override")
	_create_pack(allowed_root, "fixture.owner", {"documents": [_document("data/item.json", _item("fixture.owner:shared", "owner"))]})
	_create_pack(allowed_root, "fixture.replacement", {"load_priority": 100, "overrides": ["fixture.owner:shared"], "documents": [_document("data/replacement.json", _item("fixture.owner:shared", "replacement"))]})
	var allowed := _registry_for(allowed_root)
	allowed.discover_and_resolve()
	_assert_equal(allowed.identify_owner("fixture.owner:shared"), "fixture.replacement", "CONTENT-017 explicit later override replaces owner deterministically")
	_assert_equal(allowed.resolve("fixture.owner:shared").data.effects.marker, 2, "CONTENT-018 resolved override data")
	_assert_equal(allowed.inspect_overrides().size(), 1, "CONTENT-019 override audit record")

	var denied_root := _case_root("denied_override")
	_create_pack(denied_root, "fixture.owner", {"documents": [_document("data/item.json", _item("fixture.owner:shared"))]})
	_create_pack(denied_root, "fixture.intruder", {"load_priority": 100, "documents": [_document("data/item.json", _item("fixture.owner:shared"))]})
	var denied := _registry_for(denied_root)
	denied.discover_and_resolve()
	_assert_equal(denied.identify_owner("fixture.owner:shared"), "fixture.owner", "CONTENT-020 unauthorized override cannot replace definition")
	_assert_diagnostic(denied, "UNAUTHORIZED_NAMESPACE", "$.id", "CONTENT-021 unauthorized namespace diagnostic")

	var skin_root := _case_root("skin_mechanics")
	_create_pack(skin_root, "fixture.owner", {"documents": [_document("data/item.json", _item("fixture.owner:shared"))]})
	_create_pack(skin_root, "fixture.skin", {"type": "skin", "load_priority": 100, "overrides": ["fixture.owner:shared"], "documents": [_document("data/item.json", _item("fixture.owner:shared"))]})
	var skin := _registry_for(skin_root)
	skin.discover_and_resolve()
	_assert_diagnostic(skin, "SKIN_MECHANICS_OVERRIDE", "$.id", "CONTENT-022 skin cannot override mechanics")


func _test_duplicate_and_invalid_ids() -> void:
	var duplicate_root := _case_root("duplicate_ids")
	_create_pack(duplicate_root, "fixture.duplicate", {"documents": [_document("data/a.json", _item("fixture.duplicate:same")), _document("data/b.json", _item("fixture.duplicate:same"))]})
	var duplicate := _registry_for(duplicate_root)
	duplicate.discover_and_resolve()
	_assert_diagnostic(duplicate, "DUPLICATE_ID_IN_PACK", "$.id", "CONTENT-023 duplicate ID rejection")

	var duplicate_pack_root := _case_root("duplicate_packs")
	_create_pack(duplicate_pack_root, "fixture.same", {"directory_name": "one"})
	_create_pack(duplicate_pack_root, "fixture.same", {"directory_name": "two"})
	var duplicate_pack := _registry_for(duplicate_pack_root)
	duplicate_pack.discover_and_resolve()
	_assert_diagnostic(duplicate_pack, "DUPLICATE_PACK_ID", "$.pack_id", "CONTENT-024 duplicate pack ID rejection")

	var invalid_root := _case_root("invalid_id")
	_create_pack(invalid_root, "fixture.invalid", {"documents": [_document("data/item.json", _item("Not Namespaced"))]})
	var invalid := _registry_for(invalid_root)
	invalid.discover_and_resolve()
	_assert_diagnostic(invalid, "INVALID_CONTENT_ID", "$.id", "CONTENT-025 invalid namespaced ID rejection")


func _test_incompatible_and_malformed_content() -> void:
	var manifest_root := _case_root("manifest")
	_create_pack(manifest_root, "fixture.manifest", {"authors": []})
	var invalid_manifest := _registry_for(manifest_root)
	invalid_manifest.discover_and_resolve()
	_assert_diagnostic(invalid_manifest, "INVALID_AUTHORS", "$.authors", "CONTENT-025A manifest fields are validated at runtime")

	var missing_manifest_field_root := _case_root("missing_manifest_field")
	_create_pack(missing_manifest_field_root, "fixture.missing", {"omit_fields": ["entry_points"]})
	var missing_manifest_field := _registry_for(missing_manifest_field_root)
	missing_manifest_field.discover_and_resolve()
	_assert_diagnostic(missing_manifest_field, "MISSING_MANIFEST_FIELD", "$.entry_points", "CONTENT-025B missing manifest fields reject without null dereference")

	var schema_root := _case_root("schema_validation")
	_create_pack(schema_root, "fixture.schema", {"documents": [_document("data/item.json", {"$schema": "item.schema.json", "id": "fixture.schema:invalid_item"})]})
	var schema_registry := _registry_for(schema_root)
	schema_registry.discover_and_resolve()
	_assert_diagnostic(schema_registry, "SCHEMA_REQUIRED_FIELD", "$.display_name_key", "CONTENT-025C runtime schema validation rejects incomplete documents")

	var reference_root := _case_root("reference_validation")
	_create_pack(reference_root, "fixture.references", {"documents": [_document("data/pool.json", {"$schema": "starter-pool.schema.json", "id": "fixture.references:pool", "display_name_key": "pool.fixture.name", "egg_ids": ["fixture.references:missing_egg"]})]})
	var reference_registry := _registry_for(reference_root)
	reference_registry.discover_and_resolve()
	_assert_diagnostic(reference_registry, "UNRESOLVED_REFERENCE", "$.egg_ids[0]", "CONTENT-025D unresolved references reject the pack")

	var invalid_base_root := _case_root("invalid_base_policy")
	_create_pack(invalid_base_root, "fixture.invalid_base", {"base_pack_enabled": false})
	var invalid_base := _registry_for(invalid_base_root)
	invalid_base.discover_and_resolve()
	_assert_diagnostic(invalid_base, "INVALID_BASE_PACK_POLICY", "$.base_pack_enabled", "CONTENT-025E only total conversions may disable base")

	var api_root := _case_root("api")
	_create_pack(api_root, "fixture.future", {"content_api_version": "9.9"})
	var api := _registry_for(api_root)
	api.discover_and_resolve()
	_assert_diagnostic(api, "INCOMPATIBLE_CONTENT_API", "$.content_api_version", "CONTENT-026 incompatible content API rejection")

	var malformed_root := _case_root("malformed")
	_create_pack(malformed_root, "fixture.malformed", {"documents": [_document("data/broken.json", {})], "raw_documents": {"data/broken.json": "{not-json"}})
	var malformed := _registry_for(malformed_root)
	malformed.discover_and_resolve()
	_assert_diagnostic(malformed, "MALFORMED_JSON", "$", "CONTENT-027 malformed document diagnostic")
	var diagnostic: Dictionary = _find_diagnostic(malformed, "MALFORMED_JSON")
	_assert_true(str(diagnostic.source_file).ends_with("/data/broken.json"), "CONTENT-028 diagnostic includes logical source file")


func _test_path_and_payload_security() -> void:
	var traversal_root := _case_root("traversal")
	_create_pack(traversal_root, "fixture.traversal", {"entry_points": ["../escape.json"]})
	var traversal := _registry_for(traversal_root)
	traversal.discover_and_resolve()
	_assert_diagnostic(traversal, "UNSAFE_ENTRY_PATH", "$.entry_points[0]", "CONTENT-029 path traversal rejected")

	var absolute_root := _case_root("absolute_asset")
	_create_pack(absolute_root, "fixture.absolute", {"asset_roots": ["assets"], "documents": [_document("data/animation.json", _animation("fixture.absolute:animation", "/tmp/unsafe.png"))]})
	var absolute := _registry_for(absolute_root)
	absolute.discover_and_resolve()
	_assert_diagnostic(absolute, "UNSAFE_ASSET_PATH", "$.preview", "CONTENT-030 absolute asset path rejected")

	var extension_root := _case_root("asset_extension")
	_create_pack(extension_root, "fixture.extension", {"asset_roots": ["assets"], "documents": [_document("data/animation.json", _animation("fixture.extension:animation", "assets/payload.exe"))]})
	var extension := _registry_for(extension_root)
	extension.discover_and_resolve()
	_assert_diagnostic(extension, "UNSAFE_ASSET_PATH", "$.preview", "CONTENT-031 unsupported media extension rejected")

	var executable_root := _case_root("executable")
	_create_pack(executable_root, "fixture.executable", {"extra_files": {"payload.gd": "extends Node"}})
	var executable := _registry_for(executable_root)
	executable.discover_and_resolve()
	_assert_diagnostic(executable, "EXECUTABLE_PAYLOAD", "$", "CONTENT-032 executable mod payload rejected")

	var symlink_root := _case_root("symlink")
	_create_pack(symlink_root, "fixture.symlink")
	var pack_directory := ProjectSettings.globalize_path(symlink_root.path_join("fixture.symlink"))
	var directory := DirAccess.open(pack_directory)
	var link_error := directory.create_link("manifest.json", "linked-manifest.json") if directory != null else ERR_CANT_OPEN
	if link_error != OK:
		print("SKIP: CONTENT-032 symlink fixture unavailable: %s" % error_string(link_error))
	else:
		_assert_equal(link_error, OK, "CONTENT-032A symlink fixture created")
		var symlink := _registry_for(symlink_root)
		symlink.discover_and_resolve()
		_assert_diagnostic(symlink, "SYMLINK_PAYLOAD", "$", "CONTENT-032B symlink payload rejected before traversal")


func _test_reference_and_localization_queries() -> void:
	var resolved := _example_registry.explain_reference("example.neutral:meadow_hatchling", ["form"])
	_assert_equal(resolved.resolved, true, "CONTENT-033 typed content reference resolves")
	var missing := _example_registry.explain_reference("example.neutral:absent", ["form"])
	_assert_equal(missing.code, "MISSING_CONTENT", "CONTENT-034 missing reference explanation")
	var mismatch := _example_registry.explain_reference("example.neutral:meadow_hatchling", ["item"])
	_assert_equal(mismatch.code, "CONTENT_KIND_MISMATCH", "CONTENT-035 kind mismatch explanation")
	_assert_equal(_example_registry.get_localization_value("en-US", "form.hatchling.name"), "Meadow Hatchling", "CONTENT-036 deterministic locale fallback")


func _test_offline_progress_policy() -> void:
	var policy := OfflineProgressPolicy.new(1000, 5, 500)
	_assert_offline(policy.evaluate(1000, 1120), 120, 120, OfflineProgressPolicy.REASON_NONE, "TIME-001 normal elapsed time")
	_assert_offline(policy.evaluate(1000, 1000), 0, 0, OfflineProgressPolicy.REASON_NONE, "TIME-002 zero elapsed time")
	_assert_offline(policy.evaluate(1000, 900), -100, 0, OfflineProgressPolicy.REASON_CLOCK_ROLLBACK, "TIME-003 rollback cannot punish")
	_assert_offline(policy.evaluate(1000, 997), -3, 0, OfflineProgressPolicy.REASON_SMALL_NEGATIVE_DRIFT, "TIME-004 small negative drift")
	_assert_offline(policy.evaluate(1000, 1600), 600, 600, OfflineProgressPolicy.REASON_FORWARD_JUMP, "TIME-005 forward jump is explicit")
	_assert_offline(policy.evaluate(1000, 5000), 4000, 1000, OfflineProgressPolicy.REASON_OFFLINE_CAP, "TIME-006 offline cap")
	var missing := policy.evaluate(null, 1000)
	_assert_equal(missing.reason, OfflineProgressPolicy.REASON_MISSING_TIMESTAMP, "TIME-007 missing timestamp")
	var invalid := policy.evaluate("2026-01-01T00:00:00", "2026-01-01T00:00:10Z")
	_assert_equal(invalid.reason, OfflineProgressPolicy.REASON_INVALID_TIMESTAMP, "TIME-008 persisted timestamp must be UTC")
	_assert_equal(policy.evaluate("not-a-timeZ", "2026-01-01T00:00:10Z").reason, OfflineProgressPolicy.REASON_INVALID_TIMESTAMP, "TIME-008A malformed UTC timestamp is rejected")
	var utc := policy.evaluate("2026-01-01T00:00:00Z", "2026-01-01T00:01:00Z")
	_assert_equal(utc.accepted_simulation_seconds, 60, "TIME-009 UTC text parsing is timezone-independent")


func _test_fake_clock() -> void:
	var clock := FakeSimulationClock.new(1_767_225_600, 42.5)
	var first := [clock.utc_now_text(), clock.monotonic_seconds()]
	clock.advance(30)
	_assert_equal(first, ["2026-01-01T00:00:00Z", 42.5], "TIME-010 fake clock initial reproducibility")
	_assert_equal([clock.utc_now_text(), clock.monotonic_seconds()], ["2026-01-01T00:00:30Z", 72.5], "TIME-011 fake clock advances wall and monotonic time explicitly")


func _test_save_round_trip_and_backup() -> void:
	var path := TEST_ROOT + "/saves/roundtrip.json"
	var clock := FakeSimulationClock.new(1_767_225_600)
	var repository := SaveRepository.new(path, clock, FoundationSaveMigrations.create_registry())
	var envelope := SaveEnvelope.create(clock, _example_registry.deterministic_snapshot())
	envelope.simulation_state.records.append({"instance_id": "neutral-1", "definition_id": "example.neutral:meadow_hatchling", "required_pack_id": "example.neutral", "raw_marker": "first"})
	var first_save := repository.save(envelope)
	_assert_equal(first_save.ok, true, "SAVE-001 save write succeeds")
	var invalid_version := envelope.duplicate(true)
	invalid_version.save_format_version = {"invalid": true}
	_assert_equal(repository.save(invalid_version).error_code, "UNSUPPORTED_WRITE_VERSION", "SAVE-001A malformed write version fails safely")
	var first_load := repository.load()
	_assert_equal(first_load.data.content_snapshot.snapshot_fingerprint, envelope.content_snapshot.snapshot_fingerprint, "SAVE-002 content snapshot persists")
	_assert_true(FoundationBootstrap.new()._snapshots_equal(envelope.content_snapshot, first_load.data.content_snapshot), "SAVE-002A JSON numeric representation does not create a false content mismatch")
	_assert_equal(first_load.data.simulation_state.records[0].raw_marker, "first", "SAVE-003 round trip preserves record")
	clock.advance(60)
	envelope.simulation_state.records[0].raw_marker = "second"
	var second_save := repository.save(envelope)
	_assert_equal(second_save.ok, true, "SAVE-004 atomic replacement succeeds")
	var absolute_path := ProjectSettings.globalize_path(path)
	_assert_true(not FileAccess.file_exists(absolute_path + ".tmp") and not FileAccess.file_exists(absolute_path + ".swap") and not FileAccess.file_exists(absolute_path + ".bak.tmp") and not FileAccess.file_exists(absolute_path + ".bak.swap"), "SAVE-005 temporary replacement artifacts cleaned")
	var backup := _parse_file(path + ".bak")
	_assert_equal(backup.simulation_state.records[0].raw_marker, "first", "SAVE-006 previous valid save preserved as backup")
	var conflict_path := TEST_ROOT + "/saves/concurrent.json"
	var first_writer := SaveRepository.new(conflict_path, clock, FoundationSaveMigrations.create_registry())
	var stale_writer := SaveRepository.new(conflict_path, clock, FoundationSaveMigrations.create_registry())
	_assert_equal(first_writer.load().error_code, "NOT_FOUND", "SAVE-006A first writer observes empty save")
	_assert_equal(stale_writer.load().error_code, "NOT_FOUND", "SAVE-006B second writer observes same empty save")
	_assert_true(first_writer.save(envelope).ok, "SAVE-006C first writer commits")
	_assert_equal(stale_writer.save(envelope).error_code, "CONCURRENT_SAVE_CONFLICT", "SAVE-006D stale writer cannot overwrite newer save")


func _test_save_corruption_recovery() -> void:
	var path := TEST_ROOT + "/saves/recovery.json"
	var clock := FakeSimulationClock.new(1_767_225_600)
	var repository := SaveRepository.new(path, clock, FoundationSaveMigrations.create_registry())
	var first := SaveEnvelope.create(clock, _example_registry.deterministic_snapshot())
	first.progression_state.facts["generation"] = 1
	repository.save(first)
	clock.advance(1)
	var second := first.duplicate(true)
	second.progression_state.facts["generation"] = 2
	repository.save(second)
	_write_text(path, "{broken-primary")
	var recovered := repository.load()
	_assert_equal(recovered.ok, true, "SAVE-007 malformed primary falls back to valid backup")
	_assert_equal(recovered.source, "backup", "SAVE-008 recovery source is explicit")
	_assert_equal(recovered.data.progression_state.facts.generation, 1, "SAVE-009 backup content is unchanged")
	_write_text(path + ".bak", "{broken-backup")
	var failed := repository.load()
	_assert_equal(failed.error_code, "NO_VALID_SAVE", "SAVE-010 both malformed files return explicit failure")
	var invalid_version_path := TEST_ROOT + "/saves/invalid-version.json"
	_write_text(invalid_version_path, '{"save_format_version":{"invalid":true}}')
	var invalid_version_repository := SaveRepository.new(invalid_version_path, clock, FoundationSaveMigrations.create_registry())
	var invalid_version_result := invalid_version_repository.load()
	_assert_equal(invalid_version_result.primary_error.error_code, "INVALID_SAVE_VERSION", "SAVE-010A malformed loaded version fails safely")


func _test_save_migration_fixture() -> void:
	var fixture_text := FileAccess.get_file_as_string("res://tests/fixtures/saves/save_v1.json")
	var path := TEST_ROOT + "/saves/migration.json"
	_write_text(path, fixture_text)
	var repository := SaveRepository.new(path, FakeSimulationClock.new(1_767_225_600), FoundationSaveMigrations.create_registry())
	var loaded := repository.load()
	_assert_equal(loaded.ok, true, "SAVE-011 version-1 fixture migrates")
	_assert_equal(loaded.data.save_format_version, 3, "SAVE-012 migration reaches current version")
	_assert_true("foundation.v1_to_v2" in loaded.data.migration_metadata.history, "SAVE-013 migration history recorded")
	_assert_true("milestone4.pet_adventure_state" in loaded.data.migration_metadata.history, "SAVE-013A adventure migration history recorded")
	_assert_true(loaded.data.simulation_state.records[0].has("active_dungeon_run"), "SAVE-013B adventure fields are added to existing pet records")
	_assert_equal(loaded.data.simulation_state.records[0].unknown_future_field.preserve, true, "SAVE-014 migration preserves unknown raw fields")
	var repeated := FoundationSaveMigrations.create_registry().migrate(loaded.data, SaveEnvelope.CURRENT_VERSION)
	_assert_equal(repeated.data, loaded.data, "SAVE-014A current-version migration is idempotent")


func _test_missing_content_quarantine_and_restore() -> void:
	var clock := FakeSimulationClock.new(1_767_225_600)
	var envelope := SaveEnvelope.create(clock, _example_registry.deterministic_snapshot())
	var raw_record := {"instance_id": "neutral-missing", "definition_id": "example.neutral:meadow_hatchling", "required_pack_id": "example.neutral", "unknown_payload": {"retain": [1, 2, 3]}}
	envelope.simulation_state.records.append(raw_record.duplicate(true))
	var base_only := ContentPackRegistry.new([ContentPackRegistry.root("res://content_packs", "bundled", "bundled")])
	base_only.discover_and_resolve()
	var reconciler := ContentBindingReconciler.new(clock)
	var quarantined := reconciler.reconcile(envelope, base_only)
	_assert_equal(quarantined.quarantined_count, 1, "SAVE-015 removed mod quarantines affected record")
	_assert_equal(quarantined.data.simulation_state.records.size(), 0, "SAVE-016 quarantined record cannot activate")
	_assert_equal(quarantined.data.quarantined_records[0].raw_record, raw_record, "SAVE-017 quarantine preserves complete raw record")
	var restored := reconciler.reconcile(quarantined.data, _example_registry)
	_assert_equal(restored.restored_count, 1, "SAVE-018 returning pack restores record")
	_assert_equal(restored.data.simulation_state.records[0], raw_record, "SAVE-019 restoration is lossless")
	_assert_equal(restored.data.quarantined_records.size(), 0, "SAVE-020 restored quarantine entry removed only after successful binding")


func _test_invalid_record_quarantine() -> void:
	var clock := FakeSimulationClock.new(1_767_225_600)
	var envelope := SaveEnvelope.create(clock, _example_registry.deterministic_snapshot())
	envelope.simulation_state.records = [null, {"instance_id": "bad-shape", "definition_id": "example.neutral:meadow_hatchling", "required_pack_id": "example.neutral", "required_content_ids": {"wrong": true}}]
	var reconciled := ContentBindingReconciler.new(clock).reconcile(envelope, _example_registry)
	_assert_equal(reconciled.quarantined_count, 2, "SAVE-021 invalid active records are quarantined")
	_assert_equal(reconciled.data.simulation_state.records.size(), 0, "SAVE-022 invalid active records never activate")
	_assert_equal(reconciled.data.quarantined_records[0].reason, "INVALID_RECORD_TYPE", "SAVE-023 null record reason is explicit")
	_assert_equal(reconciled.data.quarantined_records[1].reason, "INVALID_REQUIRED_CONTENT_IDS", "SAVE-024 malformed binding reason is explicit")


func _test_feature_gate_evaluation_and_grants() -> void:
	var service := FeatureGateService.new(_example_registry)
	var passing := ProgressionFacts.new({"dungeon_clears": ["example.neutral:quiet_hollow"], "milestone_count": 1, "gates_disabled": false})
	var failing := ProgressionFacts.new({"dungeon_clears": [], "milestone_count": 0, "gates_disabled": true})
	var pass_result := service.evaluate_gate("example.neutral:quiet_hollow_gate", passing)
	var fail_result := service.evaluate_gate("example.neutral:quiet_hollow_gate", failing)
	_assert_equal(pass_result.passed, true, "GATE-001 neutral fixture gate passes")
	_assert_equal(fail_result.passed, false, "GATE-002 neutral fixture gate fails")
	_assert_true(not fail_result.failures.is_empty() and fail_result.failures[0].path.begins_with("$"), "GATE-003 failed conditions explain logical path")
	var evaluator := FeatureGateEvaluator.new()
	var composition := {"all": [{"fact": "counter", "operator": "gte", "value": 2}, {"any": [{"fact": "flag", "operator": "eq", "value": true}, {"not": {"fact": "blocked", "operator": "eq", "value": true}}]}]}
	_assert_equal(evaluator.evaluate(composition, ProgressionFacts.new({"counter": 2, "flag": false, "blocked": false})).passed, true, "GATE-004 all/any/not composition")
	_assert_equal(evaluator.evaluate({"not": {"fact": "blocked", "operator": "unknown", "value": true}}, ProgressionFacts.new({"blocked": false})).passed, false, "GATE-004A invalid negated condition cannot pass")
	var repeated_a := JSON.stringify(service.evaluate_gate("example.neutral:quiet_hollow_gate", passing), "", true, true)
	var repeated_b := JSON.stringify(service.evaluate_gate("example.neutral:quiet_hollow_gate", passing), "", true, true)
	_assert_equal(repeated_a, repeated_b, "GATE-005 repeated evaluation is deterministic")
	var ledger := UnlockLedger.new()
	var first := service.evaluate_and_grant("example.neutral:quiet_hollow_gate", passing, ledger)
	var second := service.evaluate_and_grant("example.neutral:quiet_hollow_gate", passing, ledger)
	_assert_equal(first.grants[0].granted, true, "GATE-006 first reward grant succeeds")
	_assert_equal(second.grants[0].error_code, "ALREADY_GRANTED", "GATE-007 duplicate reward grant prevented")
	_assert_equal(ledger.snapshot().size(), 1, "GATE-008 unlock ledger is idempotent")


func _test_application_bootstrap() -> void:
	var save_path := TEST_ROOT + "/bootstrap/foundation.json"
	var roots: Array[Dictionary] = [
		ContentPackRegistry.root("res://content_packs", "bundled", "bundled"),
		ContentPackRegistry.root(ProjectSettings.globalize_path("res://../mods/examples"), "development", "fixture"),
	]
	var bootstrap := FoundationBootstrap.new({"content_roots": roots, "save_path": save_path}, FakeSimulationClock.new(1_767_225_600))
	var result := bootstrap.initialize()
	_assert_equal(result.ok, true, "APP-001 application bootstrap reaches ready state")
	_assert_equal(result.resolved_pack_ids, ["koalapet.base", "example.neutral"], "APP-002 bootstrap resolves content before save binding")
	_assert_true(bootstrap.save_repository != null and bootstrap.feature_gate_service != null and bootstrap.migration_registry != null, "APP-003 bootstrap injects functional foundation services")
	_assert_equal(DisplayServer.get_name(), "headless", "APP-004 foundation test remains headless and platform-neutral")
	var initial_save := bootstrap.save_current()
	_assert_equal(initial_save.ok, true, "APP-005 explicit save writes the active content snapshot")
	var changed_roots: Array[Dictionary] = [ContentPackRegistry.root("res://content_packs", "bundled", "bundled")]
	var changed := FoundationBootstrap.new({"content_roots": changed_roots, "save_path": save_path}, FakeSimulationClock.new(1_767_225_601))
	var changed_result := changed.initialize()
	_assert_equal(changed_result.content_snapshot_status, "MISMATCH", "APP-006 content snapshot changes are explicit")
	_assert_equal(changed_result.content_snapshot_match, false, "APP-007 changed content cannot be treated as compatible")
	_assert_equal(changed_result.save_persisted, true, "APP-008 primary reconciliation metadata is persisted")
	var persisted := changed.save_repository.load()
	_assert_equal(persisted.data.recovery_metadata.content_snapshot_status, "MISMATCH", "APP-009 persisted mismatch remains visible")
	_assert_true(not persisted.data.recovery_metadata.reconciliation.has("data"), "APP-009A reconciliation metadata stays summary-sized")
	var primary_path := ProjectSettings.globalize_path(save_path)
	_write_text(primary_path, "{malformed")
	var recovered := FoundationBootstrap.new({"content_roots": changed_roots, "save_path": save_path}, FakeSimulationClock.new(1_767_225_602))
	var recovered_result := recovered.initialize()
	_assert_equal(recovered_result.save_source, "backup", "APP-010 bootstrap reports backup recovery source")
	_assert_equal(recovered_result.save_persisted, false, "APP-011 recovered save is not written over malformed primary")
	_assert_equal(recovered_result.save_persistence_required, true, "APP-012 recovered reconciliation requires explicit save")


func _create_pack(root_path: String, pack_id: String, options: Dictionary = {}) -> void:
	var directory_name := str(options.get("directory_name", pack_id))
	var pack_path := root_path.path_join(directory_name)
	var documents: Array = options.get("documents", [])
	var entry_points: Array = options.get("entry_points", [])
	if entry_points.is_empty():
		for document in documents:
			entry_points.append(document.path)
		if not documents.is_empty():
			var strings := {"pack.%s.name" % pack_id.replace(".", "_"): "Fixture Pack"}
			for document in documents:
				var display_name_key: Variant = document.data.get("display_name_key")
				if display_name_key is String:
					strings[display_name_key] = "Fixture Content"
			var localization := {
				"$schema": "localization-bundle.schema.json",
				"locale": "en",
				"strings": strings,
			}
			documents.append(_document("data/localization.en.json", localization))
			entry_points.append("data/localization.en.json")
	var manifest := {
		"$schema": "content-pack-manifest.schema.json",
		"pack_id": pack_id,
		"display_name_key": "pack.%s.name" % pack_id.replace(".", "_"),
		"version": options.get("version", "1.0.0"),
		"content_api_version": options.get("content_api_version", "0.1"),
		"type": options.get("type", "content"),
		"authors": options.get("authors", ["Milestone 2 fixture"]),
		"license": {"code": "TEST_ONLY", "assets": "TEST_ONLY"},
		"dependencies": options.get("dependencies", []),
		"optional_dependencies": options.get("optional_dependencies", []),
		"incompatibilities": options.get("incompatibilities", []),
		"load_priority": options.get("load_priority", 0),
		"base_pack_enabled": options.get("base_pack_enabled", true),
		"entry_points": entry_points,
		"asset_roots": options.get("asset_roots", []),
		"overrides": options.get("overrides", []),
	}
	if options.has("enabled"):
		manifest["enabled"] = options.enabled
	for field in options.get("omit_fields", []):
		manifest.erase(str(field))
	_write_json(pack_path.path_join("manifest.json"), manifest)
	var raw_documents: Dictionary = options.get("raw_documents", {})
	for document in documents:
		if raw_documents.has(document.path):
			_write_text(pack_path.path_join(document.path), raw_documents[document.path])
		else:
			_write_json(pack_path.path_join(document.path), document.data)
	for relative_path in options.get("extra_files", {}):
		_write_text(pack_path.path_join(relative_path), options.extra_files[relative_path])


func _document(path: String, data: Dictionary) -> Dictionary:
	return {"path": path, "data": data}


func _item(content_id: String, marker := "") -> Dictionary:
	var marker_value := 2 if marker == "replacement" else 1 if marker == "owner" else 0
	return {
		"$schema": "item.schema.json",
		"id": content_id,
		"display_name_key": "item.fixture.name",
		"category": "material",
		"baseline_available": false,
		"effects": {"marker": marker_value},
	}


func _animation(content_id: String, asset_path: String) -> Dictionary:
	return {"$schema": "animation-profile.schema.json", "id": content_id, "preview": asset_path, "portrait": asset_path, "world_animations": {"idle": {"asset": asset_path, "frames": 1, "fps": 1}}}


func _registry_for(root_path: String) -> ContentPackRegistry:
	return ContentPackRegistry.new([ContentPackRegistry.root(root_path, "fixture", "fixture")])


func _pack_ids(registry: ContentPackRegistry) -> Array[String]:
	var result: Array[String] = []
	for pack in registry.list_resolved_packs():
		result.append(pack.pack_id)
	return result


func _case_root(case_name: String) -> String:
	return TEST_ROOT.path_join("content").path_join(case_name)


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t", true, true) + "\n")


func _write_text(path: String, text: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_failures.append("TEST SUPPORT: could not write %s" % path)
		return
	file.store_string(text)
	file.flush()
	file.close()


func _parse_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _remove_tree(absolute_path: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			var child := absolute_path.path_join(name)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _find_diagnostic(registry: ContentPackRegistry, code: String) -> Dictionary:
	for diagnostic in registry.diagnostics():
		if diagnostic.code == code:
			return diagnostic
	return {}


func _assert_diagnostic(registry: ContentPackRegistry, code: String, expected_path: String, label: String) -> void:
	var diagnostic := _find_diagnostic(registry, code)
	_assert_true(not diagnostic.is_empty() and diagnostic.json_path == expected_path, label)


func _assert_offline(result: Dictionary, raw: int, accepted: int, reason: String, label: String) -> void:
	_assert_equal([result.raw_observed_seconds, result.accepted_simulation_seconds, result.reason], [raw, accepted, reason], label)


func _assert_true(value: bool, label: String) -> void:
	_assert_equal(value, true, label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual == expected:
		print("PASS: %s" % label)
	else:
		_failures.append("%s — expected %s, got %s" % [label, expected, actual])
