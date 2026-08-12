class_name FoundationBootstrap
extends RefCounted

var configuration: Dictionary
var content_registry: ContentPackRegistry
var content_snapshot: Dictionary
var clock: SimulationClock
var save_repository: SaveRepository
var migration_registry: SaveMigrationRegistry
var feature_gate_service: FeatureGateService
var current_save: Dictionary


func _init(config: Dictionary = {}, injected_clock: SimulationClock = null) -> void:
	configuration = _default_configuration().merged(config, true)
	clock = injected_clock if injected_clock != null else SystemSimulationClock.new()


func initialize() -> Dictionary:
	var roots: Array[Dictionary] = configuration.content_roots
	content_registry = ContentPackRegistry.new(roots, configuration.disabled_pack_ids)
	var content_result := content_registry.discover_and_resolve()
	if not content_result.success:
		return {"ok": false, "stage": "content_registry", "content": content_result, "diagnostics": content_registry.diagnostics()}
	content_snapshot = content_registry.deterministic_snapshot()
	migration_registry = FoundationSaveMigrations.create_registry()
	save_repository = SaveRepository.new(configuration.save_path, clock, migration_registry)
	feature_gate_service = FeatureGateService.new(content_registry)
	var load_result := save_repository.load()
	var save_source: String = str(load_result.get("source", "new"))
	var save_recovered := bool(load_result.get("recovered", false))
	var content_snapshot_match := true
	var content_snapshot_status := "NEW"
	var save_persisted := false
	var save_persistence_required := false
	var reconciliation := {"quarantined_count": 0, "restored_count": 0, "active_count": 0, "quarantine_count": 0}
	if load_result.ok:
		var loaded_snapshot: Dictionary = load_result.data.content_snapshot.duplicate(true)
		content_snapshot_match = _snapshots_equal(loaded_snapshot, content_snapshot)
		content_snapshot_status = "MATCH" if content_snapshot_match else "MISMATCH"
		var reconciler := ContentBindingReconciler.new(clock)
		var reconciliation_result: Dictionary = reconciler.reconcile(load_result.data, content_registry)
		reconciliation = _reconciliation_summary(reconciliation_result)
		current_save = reconciliation_result.data
		current_save.recovery_metadata["content_snapshot_status"] = content_snapshot_status
		current_save.recovery_metadata["reconciliation"] = reconciliation.duplicate(true)
		if not content_snapshot_match:
			current_save.recovery_metadata["loaded_content_snapshot"] = loaded_snapshot
			current_save.recovery_metadata["active_content_snapshot"] = content_snapshot.duplicate(true)
		var applied_migrations: Array = load_result.get("applied_migrations", [])
		var state_changed: bool = not content_snapshot_match or not applied_migrations.is_empty() or int(reconciliation.get("quarantined_count", 0)) > 0 or int(reconciliation.get("restored_count", 0)) > 0
		if state_changed:
			if save_recovered:
				save_persistence_required = true
			else:
				var persist_result := save_repository.save(current_save)
				if not persist_result.ok:
					return {"ok": false, "stage": "save_repository", "save_error_code": persist_result.error_code, "save_reason": persist_result.reason}
				current_save = persist_result.data
				save_persisted = true
	elif load_result.error_code == "NOT_FOUND":
		current_save = SaveEnvelope.create(clock, content_snapshot)
	else:
		return {"ok": false, "stage": "save_repository", "save_error_code": load_result.error_code, "save_reason": load_result.reason}
	return {
		"ok": true,
		"stage": "ready",
		"resolved_pack_ids": _resolved_pack_ids(),
		"content_snapshot_fingerprint": content_snapshot.snapshot_fingerprint,
		"content_snapshot_match": content_snapshot_match,
		"content_snapshot_status": content_snapshot_status,
		"save_source": save_source,
		"save_recovered": save_recovered,
		"save_persisted": save_persisted,
		"save_persistence_required": save_persistence_required,
		"reconciliation": reconciliation,
		"content_diagnostics": content_registry.diagnostics(),
	}


func save_current() -> Dictionary:
	if save_repository == null or current_save.is_empty():
		return {"ok": false, "error_code": "BOOTSTRAP_NOT_READY", "reason": "Foundation bootstrap has not been initialized"}
	var payload := current_save.duplicate(true)
	payload["content_snapshot"] = content_snapshot.duplicate(true)
	payload.recovery_metadata["content_snapshot_status"] = "MATCH"
	payload.recovery_metadata.erase("loaded_content_snapshot")
	payload.recovery_metadata.erase("active_content_snapshot")
	var result := save_repository.save(payload)
	if result.ok:
		current_save = result.data
	return result


func _snapshots_equal(left: Dictionary, right: Dictionary) -> bool:
	return JSON.stringify(left, "", true, true) == JSON.stringify(right, "", true, true)


func _reconciliation_summary(result: Dictionary) -> Dictionary:
	return {
		"quarantined_count": int(result.get("quarantined_count", 0)),
		"restored_count": int(result.get("restored_count", 0)),
		"active_count": int(result.get("active_count", 0)),
		"quarantine_count": int(result.get("quarantine_count", 0)),
	}


func _resolved_pack_ids() -> Array[String]:
	var result: Array[String] = []
	for pack in content_registry.list_resolved_packs():
		result.append(pack.pack_id)
	return result


func _default_configuration() -> Dictionary:
	return {
		"content_roots": ContentPackRegistry.default_roots(),
		"disabled_pack_ids": [],
		"save_path": "user://saves/foundation.json",
	}
