class_name SaveRepository
extends RefCounted

const MAX_SAVE_BYTES := 16 * 1024 * 1024
const STALE_LOCK_SECONDS := 300

var save_path: String
var clock: SimulationClock
var migrations: SaveMigrationRegistry
var _primary_observed := false
var _expected_primary_fingerprint := ""


func _init(path: String, simulation_clock: SimulationClock, migration_registry: SaveMigrationRegistry) -> void:
	save_path = path
	clock = simulation_clock
	migrations = migration_registry


func save(envelope: Dictionary) -> Dictionary:
	var payload := envelope.duplicate(true)
	var version_value: Variant = payload.get("save_format_version", -1)
	if not _is_integer_number(version_value) or int(version_value) != SaveEnvelope.CURRENT_VERSION:
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
	var lock_result := _acquire_lock(absolute)
	if not lock_result.ok:
		return lock_result
	var result := _save_locked(payload, absolute)
	_release_lock(absolute)
	return result


func _save_locked(payload: Dictionary, absolute: String) -> Dictionary:
	if _primary_observed:
		var current_fingerprint := FileAccess.get_sha256(absolute) if FileAccess.file_exists(absolute) else ""
		if current_fingerprint != _expected_primary_fingerprint:
			return _failure("CONCURRENT_SAVE_CONFLICT", "Primary save changed after it was loaded")
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
	_primary_observed = true
	_expected_primary_fingerprint = str(written.get("fingerprint", ""))
	return {"ok": true, "error_code": "", "reason": "Save written through validated temporary replacement", "data": payload, "backup_path": save_path + ".bak"}


func load() -> Dictionary:
	var absolute := ProjectSettings.globalize_path(save_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return _failure("DIRECTORY_CREATE_FAILED", error_string(directory_error))
	var lock_result := _acquire_lock(absolute)
	if not lock_result.ok:
		return lock_result
	var result := _load_locked(absolute)
	_release_lock(absolute)
	return result


func _load_locked(absolute: String) -> Dictionary:
	var primary := _decode_path(absolute)
	_primary_observed = true
	_expected_primary_fingerprint = str(primary.get("fingerprint", ""))
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
	var fingerprint := FileAccess.get_sha256(path)
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return _failure("SAVE_SIZE_LIMIT", "Save file exceeds %d bytes" % MAX_SAVE_BYTES).merged({"fingerprint": fingerprint})
	var parser := JSON.new()
	var text := file.get_as_text()
	file.close()
	var parse_error := parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		return _failure("MALFORMED_JSON", "JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]).merged({"fingerprint": fingerprint})
	var version_value: Variant = parser.data.get("save_format_version", -1)
	if not _is_integer_number(version_value):
		return _failure("INVALID_SAVE_VERSION", "Save format version must be an integer").merged({"fingerprint": fingerprint})
	var version := int(version_value)
	if version < 1:
		return _failure("INVALID_SAVE_VERSION", "Save format version is missing or invalid").merged({"fingerprint": fingerprint})
	return {"ok": true, "error_code": "", "reason": "Decoded", "data": parser.data, "fingerprint": fingerprint}


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _is_integer_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value))


func _acquire_lock(absolute: String) -> Dictionary:
	var lock_path := absolute + ".lock"
	var marker_path := lock_path.path_join("owner.json")
	if DirAccess.dir_exists_absolute(lock_path):
		var modified_path := marker_path if FileAccess.file_exists(marker_path) else lock_path
		var modified_time := FileAccess.get_modified_time(modified_path)
		var age := Time.get_unix_time_from_system() - modified_time
		if modified_time > 0 and (age > STALE_LOCK_SECONDS or age < -STALE_LOCK_SECONDS):
			_cleanup_file(marker_path)
			DirAccess.remove_absolute(lock_path)
	var lock_error := DirAccess.make_dir_absolute(lock_path)
	if lock_error != OK:
		return _failure("SAVE_LOCKED", "Another save operation owns the lock")
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker == null:
		DirAccess.remove_absolute(lock_path)
		return _failure("SAVE_LOCK_FAILED", "Could not write save lock marker")
	marker.store_string(JSON.stringify({"created_at_utc": clock.utc_now_text()}))
	marker.close()
	return {"ok": true}


func _release_lock(absolute: String) -> void:
	var lock_path := absolute + ".lock"
	_cleanup_file(lock_path.path_join("owner.json"))
	DirAccess.remove_absolute(lock_path)


func _failure(code: String, reason: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason}
