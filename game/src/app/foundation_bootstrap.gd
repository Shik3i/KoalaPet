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
	if load_result.ok:
		var reconciler := ContentBindingReconciler.new(clock)
		var reconciliation := reconciler.reconcile(load_result.data, content_registry)
		current_save = reconciliation.data
	elif load_result.error_code == "NOT_FOUND":
		current_save = SaveEnvelope.create(clock, content_snapshot)
	else:
		return {"ok": false, "stage": "save_repository", "save_error_code": load_result.error_code, "save_reason": load_result.reason}
	return {
		"ok": true,
		"stage": "ready",
		"resolved_pack_ids": _resolved_pack_ids(),
		"content_snapshot_fingerprint": content_snapshot.snapshot_fingerprint,
		"save_source": load_result.get("source", "new"),
		"save_recovered": bool(load_result.get("recovered", false)),
		"content_diagnostics": content_registry.diagnostics(),
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
