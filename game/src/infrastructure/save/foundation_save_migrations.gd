class_name FoundationSaveMigrations
extends RefCounted


static func create_registry() -> SaveMigrationRegistry:
	var registry := SaveMigrationRegistry.new()
	registry.register(1, 2, "foundation.v1_to_v2", _migrate_v1_to_v2)
	return registry


static func _migrate_v1_to_v2(old: Dictionary) -> Dictionary:
	var migrated := old.duplicate(true)
	migrated["save_format_version"] = 2
	if not migrated.has("quarantined_records"):
		migrated["quarantined_records"] = []
	if not migrated.has("feature_gate_state"):
		migrated["feature_gate_state"] = {"unlock_ledger": {}}
	if not migrated.has("migration_metadata"):
		migrated["migration_metadata"] = {"history": []}
	if not migrated.has("recovery_metadata"):
		migrated["recovery_metadata"] = {}
	return migrated
