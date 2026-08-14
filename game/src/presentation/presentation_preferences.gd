class_name PresentationPreferences
extends RefCounted

const VERSION := 2
const DEFAULT_PATH := "user://preferences.json"
const UI_SCALES := ["auto", 1.0, 1.25, 1.5, 1.75, 2.0]
const TEXT_SCALES := [1.0, 1.25, 1.5, 1.75]
const PET_SCALES := [0.75, 1.0, 1.25, 1.5, 2.0]
const ANIMATION_SCALES := [0.75, 1.0, 1.25]
const WALKING_SCALES := [0.75, 1.0, 1.25, 1.5]
const MODES := ["minimal", "small", "expanded"]
const LANES := ["bottom", "top", "left", "right", "stationary"]
const AMBIENT_FREQUENCIES := ["low", "normal", "high"]
const EFFECT_INTENSITIES := ["off", "reduced", "normal"]


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"interface": {
			"ui_scale": "auto",
			"text_scale": 1.0,
			"layout_density": "comfortable",
			"language": "de",
			"high_contrast": false,
			"tooltips_enabled": true,
			"tooltip_delay_ms": 500,
		},
		"pet_presentation": {
			"standard_pet_scale": 1.0,
			"minimal_pet_scale": 1.0,
			"ambient_roaming": true,
			"ambient_animation_frequency": "normal",
			"cursor_reaction": true,
			"animation_speed": 1.0,
			"walking_speed": 1.0,
			"reduced_motion": false,
			"effects_intensity": "normal",
			"hit_shake": true,
			"damage_flash": true,
		},
		"desktop": {
			"default_launch_mode": "small",
			"always_on_top": true,
			"minimal_click_through": true,
			"minimal_lane": "bottom",
			"remember_window_positions": true,
		},
	}


static func decode_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"recovered": true,
			"reason": "Malformed preferences recovered with defaults",
			"data": defaults(),
		}
	var source: Dictionary = parser.data
	var version := _safe_int(source.get("version", 0), 0)
	if version > VERSION:
		return {
			"ok": false,
			"recovered": true,
			"reason": "Unsupported preferences version recovered with defaults: %d" % version,
			"data": defaults(),
		}
	return {
		"ok": true,
		"recovered": version != VERSION,
		"reason": "Preferences loaded" if version == VERSION else "Preferences migrated to version %d" % VERSION,
		"data": sanitize(source),
	}


static func load_file(path := DEFAULT_PATH) -> Dictionary:
	var primary := _decode_file(path)
	if primary.get("ok", false):
		return primary
	var backup := _decode_file(path + ".bak")
	if backup.get("ok", false):
		backup["recovered"] = true
		backup["reason"] = "Preferences recovered from backup"
		backup["primary_reason"] = primary.get("reason", "")
		return backup
	if str(primary.get("reason", "")) == "Preferences file does not exist" and str(backup.get("reason", "")) == "Preferences file does not exist":
		return {"ok": true, "recovered": false, "reason": "Preferences absent; defaults used", "data": defaults()}
	primary["recovered"] = true
	primary["data"] = defaults()
	return primary


static func save_file(value: Dictionary, path := DEFAULT_PATH) -> Dictionary:
	var payload := sanitize(value)
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return {"ok": false, "reason": "Could not create preferences directory: %s" % error_string(error)}
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var backup_swap := absolute + ".bak.swap"
	_cleanup_file(temporary)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "Could not open temporary preferences file"}
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.flush()
	file.close()
	var written := _decode_file(temporary)
	if not written.get("ok", false):
		_cleanup_file(temporary)
		return {"ok": false, "reason": "Temporary preferences validation failed: %s" % written.get("reason", "unknown error")}
	if FileAccess.file_exists(absolute):
		_cleanup_file(backup_swap)
		if FileAccess.file_exists(backup):
			error = DirAccess.rename_absolute(backup, backup_swap)
			if error != OK:
				_cleanup_file(temporary)
				return {"ok": false, "reason": "Could not preserve preferences backup: %s" % error_string(error)}
		error = DirAccess.rename_absolute(absolute, backup)
		if error != OK:
			if FileAccess.file_exists(backup_swap):
				DirAccess.rename_absolute(backup_swap, backup)
			_cleanup_file(temporary)
			return {"ok": false, "reason": "Could not rotate preferences backup: %s" % error_string(error)}
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		if FileAccess.file_exists(backup_swap):
			DirAccess.rename_absolute(backup_swap, backup)
		_cleanup_file(temporary)
		return {"ok": false, "reason": "Could not replace preferences: %s" % error_string(error)}
	_cleanup_file(backup_swap)
	return {"ok": true, "reason": "Preferences saved", "data": payload}


static func sanitize(source: Dictionary) -> Dictionary:
	var result := defaults()
	var interface_source: Dictionary = source.get("interface", {}) if typeof(source.get("interface", {})) == TYPE_DICTIONARY else {}
	var pet_source: Dictionary = source.get("pet_presentation", {}) if typeof(source.get("pet_presentation", {})) == TYPE_DICTIONARY else {}
	var desktop_source: Dictionary = source.get("desktop", {}) if typeof(source.get("desktop", {})) == TYPE_DICTIONARY else {}
	var interface: Dictionary = result["interface"]
	var pet: Dictionary = result["pet_presentation"]
	var desktop: Dictionary = result["desktop"]
	interface["ui_scale"] = _choice(interface_source.get("ui_scale", interface["ui_scale"]), UI_SCALES, "auto")
	interface["text_scale"] = _choice_float(interface_source.get("text_scale", interface["text_scale"]), TEXT_SCALES, 1.0)
	interface["layout_density"] = _choice(interface_source.get("layout_density", interface["layout_density"]), ["compact", "comfortable"], "comfortable")
	interface["language"] = _choice(interface_source.get("language", interface["language"]), ["de", "en"], "de")
	interface["high_contrast"] = _safe_bool(interface_source.get("high_contrast", interface["high_contrast"]), interface["high_contrast"])
	interface["tooltips_enabled"] = _safe_bool(interface_source.get("tooltips_enabled", interface["tooltips_enabled"]), interface["tooltips_enabled"])
	interface["tooltip_delay_ms"] = clampi(_safe_int(interface_source.get("tooltip_delay_ms", interface["tooltip_delay_ms"]), interface["tooltip_delay_ms"]), 0, 2000)
	pet["standard_pet_scale"] = _choice_float(pet_source.get("standard_pet_scale", pet["standard_pet_scale"]), PET_SCALES, 1.0)
	pet["minimal_pet_scale"] = _choice_float(pet_source.get("minimal_pet_scale", pet["minimal_pet_scale"]), PET_SCALES, 1.0)
	pet["ambient_roaming"] = _safe_bool(pet_source.get("ambient_roaming", pet["ambient_roaming"]), pet["ambient_roaming"])
	pet["ambient_animation_frequency"] = _choice(pet_source.get("ambient_animation_frequency", pet["ambient_animation_frequency"]), AMBIENT_FREQUENCIES, "normal")
	pet["cursor_reaction"] = _safe_bool(pet_source.get("cursor_reaction", pet["cursor_reaction"]), pet["cursor_reaction"])
	pet["animation_speed"] = _choice_float(pet_source.get("animation_speed", pet["animation_speed"]), ANIMATION_SCALES, 1.0)
	pet["walking_speed"] = _choice_float(pet_source.get("walking_speed", pet["walking_speed"]), WALKING_SCALES, 1.0)
	pet["reduced_motion"] = _safe_bool(pet_source.get("reduced_motion", pet["reduced_motion"]), pet["reduced_motion"])
	pet["effects_intensity"] = _choice(pet_source.get("effects_intensity", pet["effects_intensity"]), EFFECT_INTENSITIES, "normal")
	pet["hit_shake"] = _safe_bool(pet_source.get("hit_shake", pet["hit_shake"]), pet["hit_shake"])
	pet["damage_flash"] = _safe_bool(pet_source.get("damage_flash", pet["damage_flash"]), pet["damage_flash"])
	desktop["default_launch_mode"] = _choice(desktop_source.get("default_launch_mode", desktop["default_launch_mode"]), MODES, "small")
	desktop["always_on_top"] = _safe_bool(desktop_source.get("always_on_top", desktop["always_on_top"]), desktop["always_on_top"])
	desktop["minimal_click_through"] = _safe_bool(desktop_source.get("minimal_click_through", desktop["minimal_click_through"]), desktop["minimal_click_through"])
	desktop["minimal_lane"] = _choice(desktop_source.get("minimal_lane", desktop["minimal_lane"]), LANES, "bottom")
	desktop["remember_window_positions"] = _safe_bool(desktop_source.get("remember_window_positions", desktop["remember_window_positions"]), desktop["remember_window_positions"])
	result["version"] = VERSION
	return result


static func resolved_ui_scale(value: Variant, detected_scale := 1.0) -> float:
	if str(value) == "auto":
		return clampf(_nearest(float(detected_scale), [1.0, 1.25, 1.5, 1.75, 2.0]), 1.0, 2.0)
	return float(_choice_float(value, [1.0, 1.25, 1.5, 1.75, 2.0], 1.0))


static func _choice(value: Variant, choices: Array, fallback: Variant) -> Variant:
	return value if value in choices else fallback


static func _choice_float(value: Variant, choices: Array, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number := float(value)
	for choice in choices:
		if is_equal_approx(number, float(choice)):
			return float(choice)
	return fallback


static func _nearest(value: float, choices: Array) -> float:
	var best := float(choices[0])
	var distance := absf(value - best)
	for choice in choices:
		var candidate := float(choice)
		if absf(value - candidate) < distance:
			best = candidate
			distance = absf(value - candidate)
	return best


static func _safe_bool(value: Variant, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback


static func _safe_int(value: Variant, fallback: int) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


static func _decode_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "recovered": false, "reason": "Preferences file does not exist", "data": defaults()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "recovered": true, "reason": "Preferences file is unreadable", "data": defaults()}
	if file.get_length() > 1024 * 1024:
		file.close()
		return {"ok": false, "recovered": true, "reason": "Preferences file exceeds 1048576 bytes", "data": defaults()}
	var text := file.get_as_text()
	file.close()
	return decode_text(text)


static func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
