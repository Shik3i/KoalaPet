class_name SaveRepository
extends RefCounted

var save_path: String
var clock: SimulationClock
var migrations: SaveMigrationRegistry


func _init(path: String, simulation_clock: SimulationClock, migration_registry: SaveMigrationRegistry) -> void:
	save_path = path
	clock = simulation_clock
	migrations = migration_registry


func save(envelope: Dictionary) -> Dictionary:
	var payload := envelope.duplicate(true)
	if int(payload.get("save_format_version", -1)) != SaveEnvelope.CURRENT_VERSION:
		return _failure("UNSUPPORTED_WRITE_VERSION", "Migrate the save envelope before writing")
	if str(payload.get("created_at_utc", "")).is_empty():
		payload["created_at_utc"] = clock.utc_now_text()
	payload["updated_at_utc"] = clock.utc_now_text()
	var validation := SaveEnvelope.validate(payload)
	if not validation.ok:
		return validation.merged({"data": payload})
	var absolute := ProjectSettings.globalize_path(save_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return _failure("DIRECTORY_CREATE_FAILED", error_string(directory_error))
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var backup_temporary := absolute + ".bak.tmp"
	var backup_swap := absolute + ".bak.swap"
	var swap := absolute + ".swap"
	_cleanup_file(temporary)
	_cleanup_file(backup_temporary)
	_cleanup_file(backup_swap)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("TEMP_WRITE_FAILED", "Could not open temporary save")
	file.store_string(JSON.stringify(payload, "\t", true, true) + "\n")
	file.flush()
	file.close()
	var written := _decode_path(temporary)
	if not written.ok:
		_cleanup_file(temporary)
		return _failure("TEMP_VALIDATION_FAILED", written.reason)
	if FileAccess.file_exists(absolute):
		var current := _decode_path(absolute)
		if current.ok:
			var copy_error := DirAccess.copy_absolute(absolute, backup_temporary)
			if copy_error != OK:
				_cleanup_file(temporary)
				return _failure("BACKUP_COPY_FAILED", error_string(copy_error))
			if FileAccess.file_exists(backup):
				var old_backup_error := DirAccess.rename_absolute(backup, backup_swap)
				if old_backup_error != OK:
					_cleanup_file(temporary)
					_cleanup_file(backup_temporary)
					return _failure("BACKUP_ROTATE_FAILED", error_string(old_backup_error))
			var backup_error := DirAccess.rename_absolute(backup_temporary, backup)
			if backup_error != OK:
				if FileAccess.file_exists(backup_swap):
					DirAccess.rename_absolute(backup_swap, backup)
				_cleanup_file(temporary)
				return _failure("BACKUP_REPLACE_FAILED", error_string(backup_error))
			_cleanup_file(backup_swap)
		_cleanup_file(swap)
		var rotate_error := DirAccess.rename_absolute(absolute, swap)
		if rotate_error != OK:
			_cleanup_file(temporary)
			return _failure("PRIMARY_ROTATE_FAILED", error_string(rotate_error))
	var replace_error := DirAccess.rename_absolute(temporary, absolute)
	if replace_error != OK:
		if FileAccess.file_exists(swap):
			DirAccess.rename_absolute(swap, absolute)
		_cleanup_file(temporary)
		return _failure("PRIMARY_REPLACE_FAILED", error_string(replace_error))
	_cleanup_file(swap)
	return {"ok": true, "error_code": "", "reason": "Save written through validated temporary replacement", "data": payload, "backup_path": save_path + ".bak"}


func load() -> Dictionary:
	var absolute := ProjectSettings.globalize_path(save_path)
	var primary := _decode_path(absolute)
	if primary.ok:
		return _migrate_loaded(primary.data, "primary", false)
	var backup := _decode_path(absolute + ".bak")
	if backup.ok:
		var recovered := _migrate_loaded(backup.data, "backup", true)
		recovered["primary_error_code"] = primary.error_code
		return recovered
	var swap := _decode_path(absolute + ".swap")
	if swap.ok:
		var recovered := _migrate_loaded(swap.data, "swap", true)
		recovered["primary_error_code"] = primary.error_code
		return recovered
	if primary.error_code == "NOT_FOUND" and backup.error_code == "NOT_FOUND" and swap.error_code == "NOT_FOUND":
		return _failure("NOT_FOUND", "No save or recovery file exists")
	return {"ok": false, "error_code": "NO_VALID_SAVE", "reason": "Primary and all recovery files are invalid", "primary_error": primary, "backup_error": backup, "swap_error": swap}


func _migrate_loaded(data: Dictionary, source: String, recovered: bool) -> Dictionary:
	var migration := migrations.migrate(data, SaveEnvelope.CURRENT_VERSION)
	if not migration.ok:
		return migration.merged({"source": source, "recovered": recovered})
	var validation := SaveEnvelope.validate(migration.data)
	if not validation.ok:
		return validation.merged({"source": source, "recovered": recovered})
	var loaded: Dictionary = migration.data
	loaded.recovery_metadata["last_load_source"] = source
	loaded.recovery_metadata["recovered_from_backup"] = recovered
	return {"ok": true, "error_code": "", "reason": "Save loaded", "data": loaded, "source": source, "recovered": recovered, "applied_migrations": migration.applied_migrations}


func _decode_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("NOT_FOUND", "File does not exist")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("READ_FAILED", "Could not open save file")
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK or not parser.data is Dictionary:
		return _failure("MALFORMED_JSON", "JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	var version := int(parser.data.get("save_format_version", -1))
	if version < 1:
		return _failure("INVALID_SAVE_VERSION", "Save format version is missing or invalid")
	return {"ok": true, "error_code": "", "reason": "Decoded", "data": parser.data}


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _failure(code: String, reason: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason}
