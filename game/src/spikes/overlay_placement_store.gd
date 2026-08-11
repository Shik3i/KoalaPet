class_name OverlayPlacementStore
extends RefCounted

const VERSION := 1
const DEFAULT_PATH := "user://windows_overlay_spike/placement.json"


static func default_envelope() -> Dictionary:
	return {
		"version": VERSION,
		"last_mode": "SMALL",
		"always_on_top": false,
		"placements": {},
	}


static func decode_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		return {
			"ok": false,
			"error_code": "CORRUPTED_JSON",
			"reason": "JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()],
			"data": default_envelope(),
		}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error_code": "INVALID_ENVELOPE", "reason": "Placement root must be an object", "data": default_envelope()}
	var version := int(parser.data.get("version", -1))
	if version != VERSION:
		return {"ok": false, "error_code": "UNSUPPORTED_VERSION", "reason": "Unsupported placement version: %d" % version, "data": default_envelope()}
	return {"ok": true, "error_code": "", "reason": "Placement loaded", "data": parser.data}


static func load_envelope(path := DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "error_code": "", "reason": "No placement file; defaults used", "data": default_envelope()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": "READ_FAILED", "reason": "Could not open placement file", "data": default_envelope()}
	return decode_text(file.get_as_text())


static func save_envelope(envelope: Dictionary, path := DEFAULT_PATH) -> OverlayApplyResult:
	var payload := envelope.duplicate(true)
	payload["version"] = VERSION
	return write_json_atomic(path, payload)


static func write_json_atomic(path: String, payload: Dictionary) -> OverlayApplyResult:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return OverlayApplyResult.failure("DIRECTORY_CREATE_FAILED", "Could not create placement directory: %s" % error_string(error))
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return OverlayApplyResult.failure("WRITE_FAILED", "Could not open temporary placement file")
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.flush()
	file.close()
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(absolute):
		error = DirAccess.rename_absolute(absolute, backup)
		if error != OK:
			DirAccess.remove_absolute(temporary)
			return OverlayApplyResult.failure("BACKUP_FAILED", "Could not rotate placement backup: %s" % error_string(error))
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute)
		return OverlayApplyResult.failure("REPLACE_FAILED", "Could not replace placement file: %s" % error_string(error))
	return OverlayApplyResult.ok("Placement saved with replaceable write", ["placement_persistence", "backup"])
