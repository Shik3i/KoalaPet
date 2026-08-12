class_name ContentSchemaValidator
extends RefCounted

const NAMESPACED_ID_PATTERN := "^[a-z][a-z0-9_.-]*:[a-z][a-z0-9_.-]*$"
const FACT_PATTERN := "^[a-z][a-z0-9_.-]*$"
const LOCALIZATION_KEY_PATTERN := "^[a-z0-9_.-]+$"
const LOCALE_PATTERN := "^[a-z]{2,3}(?:-[A-Z]{2})?$"


static func validate(schema_name: String, data: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	if data.has("$schema") and not data["$schema"] is String:
		_add_error(errors, "SCHEMA_TYPE", "$.$schema", "$schema must be a string")
	match schema_name:
		"ailment.schema.json":
			_validate_ailment(data, errors)
		"animation-profile.schema.json":
			_validate_animation_profile(data, errors)
		"care-profile.schema.json":
			_validate_care_profile(data, errors)
		"dungeon.schema.json":
			_validate_dungeon(data, errors)
		"egg.schema.json":
			_validate_egg(data, errors)
		"enemy-encounter.schema.json":
			_validate_enemy_encounter(data, errors)
		"evolution-graph.schema.json":
			_validate_evolution_graph(data, errors)
		"farm-job.schema.json":
			_validate_farm_job(data, errors)
		"feature-gate.schema.json":
			_validate_feature_gate(data, errors)
		"form.schema.json":
			_validate_form(data, errors)
		"furniture-prop.schema.json":
			_validate_furniture(data, errors)
		"habitat-theme.schema.json":
			_validate_habitat_theme(data, errors)
		"item.schema.json":
			_validate_item(data, errors)
		"localization-bundle.schema.json":
			_validate_localization(data, errors)
		"move.schema.json":
			_validate_move(data, errors)
		"species-family.schema.json":
			_validate_species_family(data, errors)
		"starter-pool.schema.json":
			_validate_starter_pool(data, errors)
		"training-activity.schema.json":
			_validate_training_activity(data, errors)
		_:
			_add_error(errors, "UNSUPPORTED_SCHEMA", "$.$schema", "Unsupported content schema")
	return errors


static func _validate_animation_profile(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "preview", "portrait", "world_animations"], ["$schema", "id", "preview", "portrait", "world_animations"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("preview"), "$.preview", errors)
	_validate_string(data.get("portrait"), "$.portrait", errors)
	if not _validate_dictionary(data.get("world_animations"), "$.world_animations", errors):
		return
	var animations: Dictionary = data.world_animations
	if not animations.has("idle"):
		_add_error(errors, "SCHEMA_REQUIRED_FIELD", "$.world_animations.idle", "Required animation is missing")
	for animation_name in animations:
		var path := "$.world_animations.%s" % str(animation_name)
		var animation: Variant = animations[animation_name]
		if not _validate_dictionary(animation, path, errors):
			continue
		var animation_data: Dictionary = animation
		_object_shape(animation_data, ["asset", "frames", "fps"], ["asset", "frames", "fps", "loop"], errors, path)
		_validate_string(animation_data.get("asset"), path + ".asset", errors)
		_validate_integer(animation_data.get("frames"), path + ".frames", errors, 1)
		_validate_number(animation_data.get("fps"), path + ".fps", errors, 0.0, true)
		if animation_data.has("loop"):
			_validate_bool(animation_data.loop, path + ".loop", errors)


static func _validate_ailment(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "treatment_item_id", "health_loss_per_hour", "recovery_health_per_hour", "critical_health_threshold_bps", "probability_basis_points"], ["$schema", "id", "display_name_key", "treatment_item_id", "health_loss_per_hour", "recovery_health_per_hour", "critical_health_threshold_bps", "probability_basis_points"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_id(data.get("treatment_item_id"), "$.treatment_item_id", errors)
	for field in ["health_loss_per_hour", "recovery_health_per_hour"]:
		_validate_integer(data.get(field), "$.%s" % field, errors, 0)
	for field in ["critical_health_threshold_bps", "probability_basis_points"]:
		_validate_integer(data.get(field), "$.%s" % field, errors, 0)
		if data.get(field) is int and int(data.get(field)) > 10000:
			_add_error(errors, "SCHEMA_CONSTRAINT", "$.%s" % field, "Basis points must be at most 10000")


static func _validate_care_profile(data: Dictionary, errors: Array[Dictionary]) -> void:
	var fields := ["id", "display_name_key", "profile_kind", "hatch_duration_seconds", "offline_cap_seconds", "satiety_decay_per_hour", "energy_use_per_hour", "sleep_recovery_per_hour", "hygiene_decay_per_hour", "weight_min_grams", "weight_max_grams", "meal_satiety_bps", "treat_satiety_bps", "meal_mood_bps", "treat_mood_bps", "meal_weight_grams", "treat_weight_grams", "fullness_cap_bps", "digestion_seconds", "max_waste_units", "waste_hygiene_loss_per_hour", "hunger_call_threshold_bps", "tired_call_threshold_bps", "hygiene_call_threshold_bps", "sickness_call_threshold_bps", "call_response_seconds", "severe_hunger_threshold_bps", "illness_dirt_seconds", "illness_hunger_seconds", "illness_probability_bps", "sleep_energy_threshold_bps", "wake_energy_threshold_bps", "sleep_disturbance_bps", "training_energy_cost_bps", "training_effort_gain_bps", "training_mood_gain_bps"]
	_object_shape(data, fields, ["$schema"] + fields, errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_enum(data.get("profile_kind"), ["standard", "fast_test"], "$.profile_kind", errors)
	for field in fields.slice(3):
		_validate_integer(data.get(field), "$.%s" % field, errors, 0)
	for field in ["fullness_cap_bps", "hunger_call_threshold_bps", "tired_call_threshold_bps", "hygiene_call_threshold_bps", "sickness_call_threshold_bps", "severe_hunger_threshold_bps", "illness_probability_bps", "sleep_energy_threshold_bps", "wake_energy_threshold_bps", "sleep_disturbance_bps"]:
		if data.get(field) is int and int(data.get(field)) > 10000:
			_add_error(errors, "SCHEMA_CONSTRAINT", "$.%s" % field, "Basis points must be at most 10000")
	if data.get("weight_max_grams") is int and data.get("weight_min_grams") is int and int(data.weight_max_grams) < int(data.weight_min_grams):
		_add_error(errors, "SCHEMA_CONSTRAINT", "$.weight_max_grams", "Maximum weight must not be below minimum weight")


static func _validate_dungeon(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "encounter_ids", "boss_encounter_id", "reward_item_ids", "unlock_ids"], ["$schema", "id", "display_name_key", "encounter_ids", "boss_encounter_id", "reward_item_ids", "unlock_ids"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_id_array(data.get("encounter_ids"), "$.encounter_ids", errors, 1, false)
	_validate_id(data.get("boss_encounter_id"), "$.boss_encounter_id", errors)
	_validate_id_array(data.get("reward_item_ids"), "$.reward_item_ids", errors)
	_validate_id_array(data.get("unlock_ids"), "$.unlock_ids", errors)


static func _validate_egg(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "family_id", "hatch_form_id", "animation_profile_id"], ["$schema", "id", "display_name_key", "family_id", "hatch_form_id", "animation_profile_id"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_id(data.get("family_id"), "$.family_id", errors)
	_validate_id(data.get("hatch_form_id"), "$.hatch_form_id", errors)
	_validate_id(data.get("animation_profile_id"), "$.animation_profile_id", errors)


static func _validate_enemy_encounter(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "level", "move_ids", "drops"], ["$schema", "id", "display_name_key", "level", "move_ids", "drops"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_integer(data.get("level"), "$.level", errors, 1)
	_validate_id_array(data.get("move_ids"), "$.move_ids", errors, 1, true)
	if not _validate_array(data.get("drops"), "$.drops", errors):
		return
	for index in data.drops.size():
		var path := "$.drops[%d]" % index
		var drop: Variant = data.drops[index]
		if not _validate_dictionary(drop, path, errors):
			continue
		var drop_data: Dictionary = drop
		_object_shape(drop_data, ["item_id", "weight"], ["item_id", "weight"], errors, path)
		_validate_id(drop_data.get("item_id"), path + ".item_id", errors)
		_validate_integer(drop_data.get("weight"), path + ".weight", errors, 1)


static func _validate_evolution_graph(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "rules"], ["$schema", "id", "rules"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	if not _validate_array(data.get("rules"), "$.rules", errors, 1):
		return
	for index in data.rules.size():
		var path := "$.rules[%d]" % index
		var rule: Variant = data.rules[index]
		if not _validate_dictionary(rule, path, errors):
			continue
		var rule_data: Dictionary = rule
		_object_shape(rule_data, ["id", "from_form_id", "to_form_id", "priority", "all"], ["id", "from_form_id", "to_form_id", "priority", "all"], errors, path)
		_validate_id(rule_data.get("id"), path + ".id", errors)
		_validate_id(rule_data.get("from_form_id"), path + ".from_form_id", errors)
		_validate_id(rule_data.get("to_form_id"), path + ".to_form_id", errors)
		_validate_integer(rule_data.get("priority"), path + ".priority", errors)
		if not _validate_array(rule_data.get("all"), path + ".all", errors, 1):
			continue
		for condition_index in rule_data.all.size():
			var condition_path := "%s.all[%d]" % [path, condition_index]
			var condition: Variant = rule_data.all[condition_index]
			if not _validate_dictionary(condition, condition_path, errors):
				continue
			var condition_data: Dictionary = condition
			_object_shape(condition_data, ["metric", "operator", "value"], ["metric", "operator", "value"], errors, condition_path)
			_validate_string(condition_data.get("metric"), condition_path + ".metric", errors, false, FACT_PATTERN)
			_validate_enum(condition_data.get("operator"), ["lt", "lte", "eq", "gte", "gt", "contains"], condition_path + ".operator", errors)


static func _validate_farm_job(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "station_id", "output_item_id", "base_units_per_hour", "offline_cap_hours", "stat_weights"], ["$schema", "id", "display_name_key", "station_id", "output_item_id", "base_units_per_hour", "offline_cap_hours", "stat_weights"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_id(data.get("station_id"), "$.station_id", errors)
	_validate_id(data.get("output_item_id"), "$.output_item_id", errors)
	_validate_number(data.get("base_units_per_hour"), "$.base_units_per_hour", errors, 0.0, true)
	_validate_number(data.get("offline_cap_hours"), "$.offline_cap_hours", errors, 0.0)
	_validate_number_dictionary(data.get("stat_weights"), "$.stat_weights", errors, 0.0)


static func _validate_feature_gate(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "feature", "presentation_before_unlock", "reward_ids", "condition"], ["$schema", "id", "feature", "presentation_before_unlock", "reward_ids", "condition"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_id(data.get("feature"), "$.feature", errors)
	_validate_enum(data.get("presentation_before_unlock"), ["hidden", "hinted", "locked"], "$.presentation_before_unlock", errors)
	_validate_id_array(data.get("reward_ids"), "$.reward_ids", errors, -1, true)
	_validate_feature_condition(data.get("condition"), "$.condition", errors)


static func _validate_feature_condition(condition: Variant, path: String, errors: Array[Dictionary]) -> void:
	if not _validate_dictionary(condition, path, errors):
		return
	var data: Dictionary = condition
	var branches := 0
	if data.has("all"):
		branches += 1
	if data.has("any"):
		branches += 1
	if data.has("not"):
		branches += 1
	if data.has("fact") or data.has("operator") or data.has("value"):
		branches += 1
	if branches != 1:
		_add_error(errors, "SCHEMA_ONE_OF", path, "Condition must contain exactly one leaf, all, any, or not branch")
		return
	if data.has("fact") or data.has("operator") or data.has("value"):
		_object_shape(data, ["fact", "operator", "value"], ["fact", "operator", "value"], errors, path)
		_validate_string(data.get("fact"), path + ".fact", errors, false, FACT_PATTERN)
		_validate_enum(data.get("operator"), ["eq", "neq", "gte", "lte", "gt", "lt", "contains", "has"], path + ".operator", errors)
		return
	if data.has("all") or data.has("any"):
		var branch_name := "all" if data.has("all") else "any"
		_object_shape(data, [branch_name], [branch_name], errors, path)
		var branch_path := path + "." + branch_name
		if not _validate_array(data.get(branch_name), branch_path, errors, 1):
			return
		for index in data[branch_name].size():
			_validate_feature_condition(data[branch_name][index], "%s[%d]" % [branch_path, index], errors)
		return
	_object_shape(data, ["not"], ["not"], errors, path)
	_validate_feature_condition(data.get("not"), path + ".not", errors)


static func _validate_form(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "family_id", "display_name_key", "stage", "animation_profile_id", "base_stats", "traits"], ["$schema", "id", "family_id", "display_name_key", "stage", "animation_profile_id", "care_profile_id", "base_stats", "traits"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_id(data.get("family_id"), "$.family_id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_enum(data.get("stage"), ["hatchling", "juvenile", "mature", "legacy"], "$.stage", errors)
	_validate_id(data.get("animation_profile_id"), "$.animation_profile_id", errors)
	if data.has("care_profile_id"):
		_validate_id(data.get("care_profile_id"), "$.care_profile_id", errors)
	_validate_number_dictionary(data.get("base_stats"), "$.base_stats", errors, 0.0, 1)
	_validate_string_array(data.get("traits"), "$.traits", errors, true, FACT_PATTERN)


static func _validate_furniture(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "asset", "kind", "footprint"], ["$schema", "id", "display_name_key", "asset", "kind", "footprint"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_string(data.get("asset"), "$.asset", errors)
	_validate_enum(data.get("kind"), ["furniture", "prop", "station", "trophy"], "$.kind", errors)
	if not _validate_dictionary(data.get("footprint"), "$.footprint", errors):
		return
	var footprint: Dictionary = data.footprint
	_object_shape(footprint, ["width", "height"], ["width", "height"], errors, "$.footprint")
	_validate_integer(footprint.get("width"), "$.footprint.width", errors, 1)
	_validate_integer(footprint.get("height"), "$.footprint.height", errors, 1)


static func _validate_habitat_theme(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "background_asset", "ground_asset", "furniture_ids", "unlock_gate_id"], ["$schema", "id", "display_name_key", "background_asset", "ground_asset", "furniture_ids", "unlock_gate_id"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_string(data.get("background_asset"), "$.background_asset", errors)
	_validate_string(data.get("ground_asset"), "$.ground_asset", errors)
	_validate_id_array(data.get("furniture_ids"), "$.furniture_ids", errors, -1, true)
	_validate_id(data.get("unlock_gate_id"), "$.unlock_gate_id", errors)


static func _validate_item(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "category", "baseline_available", "effects"], ["$schema", "id", "display_name_key", "category", "baseline_available", "effects", "use"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_enum(data.get("category"), ["food", "medicine", "training", "material", "key"], "$.category", errors)
	_validate_bool(data.get("baseline_available"), "$.baseline_available", errors)
	_validate_number_dictionary(data.get("effects"), "$.effects", errors)
	if data.has("use"):
		if not _validate_dictionary(data.use, "$.use", errors):
			return
		_object_shape(data.use, ["kind"], ["kind", "satiety_bps", "mood_bps", "energy_bps", "weight_grams", "health_bps", "hygiene_bps"], errors, "$.use")
		_validate_enum(data.use.get("kind"), ["meal", "treat", "medicine"], "$.use.kind", errors)
		for field in ["satiety_bps", "mood_bps", "energy_bps", "weight_grams", "health_bps", "hygiene_bps"]:
			if data.use.has(field):
				_validate_integer(data.use[field], "$.use.%s" % field, errors)


static func _validate_localization(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["locale", "strings"], ["$schema", "locale", "strings"], errors)
	_validate_string(data.get("locale"), "$.locale", errors, false, LOCALE_PATTERN)
	if not _validate_dictionary(data.get("strings"), "$.strings", errors, 1):
		return
	var strings: Dictionary = data.strings
	for key in strings:
		var path := "$.strings.%s" % str(key)
		_validate_string(str(key), path, errors, false, LOCALIZATION_KEY_PATTERN)
		_validate_string(strings[key], path, errors)


static func _validate_move(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "power", "energy_cost", "tags"], ["$schema", "id", "display_name_key", "power", "energy_cost", "tags"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_integer(data.get("power"), "$.power", errors, 0)
	_validate_integer(data.get("energy_cost"), "$.energy_cost", errors, 0)
	_validate_string_array(data.get("tags"), "$.tags", errors, true)


static func _validate_species_family(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "form_ids", "evolution_graph_id"], ["$schema", "id", "display_name_key", "form_ids", "evolution_graph_id"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	_validate_id_array(data.get("form_ids"), "$.form_ids", errors, 2, true)
	_validate_id(data.get("evolution_graph_id"), "$.evolution_graph_id", errors)


static func _validate_starter_pool(data: Dictionary, errors: Array[Dictionary]) -> void:
	_object_shape(data, ["id", "display_name_key", "egg_ids"], ["$schema", "id", "display_name_key", "egg_ids"], errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors, true)
	_validate_id_array(data.get("egg_ids"), "$.egg_ids", errors, 1, true)


static func _validate_training_activity(data: Dictionary, errors: Array[Dictionary]) -> void:
	var fields := ["id", "display_name_key", "duration_seconds", "energy_cost_bps", "effort_gain_bps", "mood_gain_bps", "target_bps", "excellent_window_bps", "good_window_bps"]
	_object_shape(data, fields, ["$schema"] + fields, errors)
	_validate_id(data.get("id"), "$.id", errors)
	_validate_string(data.get("display_name_key"), "$.display_name_key", errors)
	for field in fields.slice(2):
		_validate_integer(data.get(field), "$.%s" % field, errors, 0)
	for field in ["target_bps", "excellent_window_bps", "good_window_bps"]:
		if data.get(field) is int and int(data.get(field)) > 10000:
			_add_error(errors, "SCHEMA_CONSTRAINT", "$.%s" % field, "Basis points must be at most 10000")


static func _object_shape(data: Dictionary, required: Array, allowed: Array, errors: Array[Dictionary], path := "$") -> void:
	for field in required:
		if not data.has(field):
			_add_error(errors, "SCHEMA_REQUIRED_FIELD", "%s.%s" % [path, field], "Required field is missing")
	for key in data:
		if str(key) not in allowed:
			_add_error(errors, "SCHEMA_ADDITIONAL_PROPERTY", "%s.%s" % [path, str(key)], "Additional property is not allowed")


static func _validate_dictionary(value: Variant, path: String, errors: Array[Dictionary], min_properties := -1) -> bool:
	if not value is Dictionary:
		_add_error(errors, "SCHEMA_TYPE", path, "Expected an object")
		return false
	if min_properties >= 0 and value.size() < min_properties:
		_add_error(errors, "SCHEMA_CONSTRAINT", path, "Object requires at least %d property/properties" % min_properties)
	return true


static func _validate_array(value: Variant, path: String, errors: Array[Dictionary], min_items := -1, unique := false) -> bool:
	if not value is Array:
		_add_error(errors, "SCHEMA_TYPE", path, "Expected an array")
		return false
	if min_items >= 0 and value.size() < min_items:
		_add_error(errors, "SCHEMA_CONSTRAINT", path, "Array requires at least %d item(s)" % min_items)
	if unique:
		var seen: Dictionary = {}
		for index in value.size():
			var serialized := JSON.stringify(value[index], "", true, true)
			if seen.has(serialized):
				_add_error(errors, "SCHEMA_UNIQUE_ITEMS", "%s[%d]" % [path, index], "Array items must be unique")
			seen[serialized] = true
	return true


static func _validate_id(value: Variant, path: String, errors: Array[Dictionary]) -> void:
	_validate_string(value, path, errors, false, NAMESPACED_ID_PATTERN)


static func _validate_id_array(value: Variant, path: String, errors: Array[Dictionary], min_items := -1, unique := false) -> void:
	if not _validate_array(value, path, errors, min_items, unique):
		return
	for index in value.size():
		_validate_id(value[index], "%s[%d]" % [path, index], errors)


static func _validate_string_array(value: Variant, path: String, errors: Array[Dictionary], unique := false, pattern := "") -> void:
	if not _validate_array(value, path, errors, -1, unique):
		return
	for index in value.size():
		_validate_string(value[index], "%s[%d]" % [path, index], errors, false, pattern)


static func _validate_number_dictionary(value: Variant, path: String, errors: Array[Dictionary], minimum: Variant = null, min_properties := -1) -> void:
	if not _validate_dictionary(value, path, errors, min_properties):
		return
	for key in value:
		_validate_number(value[key], "%s.%s" % [path, str(key)], errors, minimum)


static func _validate_string(value: Variant, path: String, errors: Array[Dictionary], non_empty := false, pattern := "") -> void:
	if not value is String:
		_add_error(errors, "SCHEMA_TYPE", path, "Expected a string")
		return
	if non_empty and value.is_empty():
		_add_error(errors, "SCHEMA_CONSTRAINT", path, "String must not be empty")
	if not pattern.is_empty() and not _matches(value, pattern):
		_add_error(errors, "SCHEMA_PATTERN", path, "String does not match the required pattern")


static func _validate_bool(value: Variant, path: String, errors: Array[Dictionary]) -> void:
	if not value is bool:
		_add_error(errors, "SCHEMA_TYPE", path, "Expected a boolean")


static func _validate_integer(value: Variant, path: String, errors: Array[Dictionary], minimum: Variant = null) -> void:
	if not value is int and not value is float:
		_add_error(errors, "SCHEMA_TYPE", path, "Expected an integer")
		return
	if float(value) != floorf(float(value)):
		_add_error(errors, "SCHEMA_TYPE", path, "Expected an integer")
		return
	if minimum != null and float(value) < float(minimum):
		_add_error(errors, "SCHEMA_CONSTRAINT", path, "Value is below the minimum")


static func _validate_number(value: Variant, path: String, errors: Array[Dictionary], minimum: Variant = null, exclusive_minimum := false) -> void:
	if not value is int and not value is float:
		_add_error(errors, "SCHEMA_TYPE", path, "Expected a number")
		return
	if minimum != null:
		var invalid := float(value) < float(minimum)
		if exclusive_minimum:
			invalid = float(value) <= float(minimum)
		if invalid:
			_add_error(errors, "SCHEMA_CONSTRAINT", path, "Value is below the minimum")


static func _validate_enum(value: Variant, allowed: Array, path: String, errors: Array[Dictionary]) -> void:
	if value not in allowed:
		_add_error(errors, "SCHEMA_ENUM", path, "Value is not one of the allowed values")


static func _matches(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null


static func _add_error(errors: Array[Dictionary], code: String, path: String, message: String) -> void:
	errors.append({"code": code, "json_path": path, "message": message})
