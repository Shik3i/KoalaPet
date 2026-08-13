class_name FoundationSaveMigrations
extends RefCounted


static func create_registry() -> SaveMigrationRegistry:
	var registry := SaveMigrationRegistry.new()
	registry.register(1, 2, "foundation.v1_to_v2", _migrate_v1_to_v2)
	registry.register(2, 3, "milestone4.pet_adventure_state", _migrate_v2_to_v3)
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


static func _migrate_v2_to_v3(old: Dictionary) -> Dictionary:
	var migrated := old.duplicate(true)
	for record in migrated.get("simulation_state", {}).get("records", []):
		if not record is Dictionary:
			continue
		var current_form := str(record.get("current_form_id", record.get("definition_id", "")))
		var aggregate: Dictionary = record.get("aggregate", {})
		aggregate.merge({"active_stage_seconds": 0, "offline_stage_seconds": 0, "stage_seconds": 0, "event_sequence": int(aggregate.get("event_sequence", 0))}, false)
		record.aggregate = aggregate
		var defaults := {
			"pet_state_version": 2, "stage": "hatchling", "traits": [], "stage_started_at_unix": int(record.get("hatched_at_unix", record.get("selected_at_unix", 0))), "stage_started_at_utc": str(record.get("hatched_at_utc", record.get("selected_at_utc", ""))), "evolution_history": [], "pending_evolution": {}, "discovered_forms": [current_form], "discovered_routes": [],
			"battle_history_summary": {"battle_count": 0, "wins": 0, "losses": 0, "draws": 0, "current_win_streak": 0, "longest_win_streak": 0, "defeated_encounters": [], "opponent_history": []},
			"experience": 0, "level": 1, "active_battle": {}, "last_battle_result": {}, "injury": {}, "inventory": {}, "used_item_ids": [], "reward_grants": {}, "unlock_ids": [], "dungeon_flags": [], "boss_flags": [], "dungeon_history": [], "active_dungeon_run": {},
			"codex": {"forms": [current_form], "encounters": [], "defeated_encounters": [], "dungeons": [], "bosses": []}
		}
		for key in defaults:
			if not record.has(key):
				record[key] = defaults[key]
	migrated["save_format_version"] = 3
	return migrated
