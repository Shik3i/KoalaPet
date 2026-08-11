class_name SaveMigrationRegistry
extends RefCounted

var _migrations: Dictionary = {}


func register(from_version: int, to_version: int, migration_id: String, migrate: Callable) -> Dictionary:
	if to_version != from_version + 1:
		return {"ok": false, "error_code": "NON_SEQUENTIAL_MIGRATION", "reason": "Migrations must advance exactly one version"}
	if _migrations.has(from_version):
		return {"ok": false, "error_code": "DUPLICATE_MIGRATION", "reason": "A migration is already registered from version %d" % from_version}
	if not migrate.is_valid():
		return {"ok": false, "error_code": "INVALID_MIGRATION", "reason": "Migration callback is invalid"}
	_migrations[from_version] = {"to_version": to_version, "migration_id": migration_id, "migrate": migrate}
	return {"ok": true, "error_code": "", "reason": "Migration registered"}


func migrate(envelope: Dictionary, target_version: int) -> Dictionary:
	var current := envelope.duplicate(true)
	var version := int(current.get("save_format_version", -1))
	if version > target_version:
		return {"ok": false, "error_code": "FUTURE_SAVE_VERSION", "reason": "Save version %d is newer than supported %d" % [version, target_version], "data": envelope.duplicate(true)}
	var applied: Array[String] = []
	while version < target_version:
		if not _migrations.has(version):
			return {"ok": false, "error_code": "MIGRATION_NOT_FOUND", "reason": "No migration registered from version %d" % version, "data": envelope.duplicate(true)}
		var step: Dictionary = _migrations[version]
		var result: Variant = step.migrate.call(current.duplicate(true))
		if not result is Dictionary:
			return {"ok": false, "error_code": "MIGRATION_FAILED", "reason": "Migration %s returned invalid data" % step.migration_id, "data": envelope.duplicate(true)}
		current = result
		version = int(step.to_version)
		current["save_format_version"] = version
		applied.append(step.migration_id)
	if current.get("migration_metadata") is Dictionary:
		var history: Array = current.migration_metadata.get("history", [])
		for migration_id in applied:
			if migration_id not in history:
				history.append(migration_id)
		current.migration_metadata["history"] = history
	return {"ok": true, "error_code": "", "reason": "Migration complete", "data": current, "applied_migrations": applied}
