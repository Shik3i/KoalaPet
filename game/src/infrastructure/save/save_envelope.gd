class_name SaveEnvelope
extends RefCounted

const CURRENT_VERSION := 2


static func create(clock: SimulationClock, content_snapshot: Dictionary) -> Dictionary:
	var now := clock.utc_now_text()
	return {
		"save_format_version": CURRENT_VERSION,
		"created_at_utc": now,
		"updated_at_utc": now,
		"content_snapshot": content_snapshot.duplicate(true),
		"simulation_state": {"records": []},
		"progression_state": {"facts": {}},
		"feature_gate_state": {"unlock_ledger": {}},
		"quarantined_records": [],
		"migration_metadata": {"history": []},
		"recovery_metadata": {},
	}


static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return _invalid("INVALID_ENVELOPE", "Save root must be an object", "$")
	var required := [
		"save_format_version", "created_at_utc", "updated_at_utc", "content_snapshot",
		"simulation_state", "progression_state", "feature_gate_state",
		"quarantined_records", "migration_metadata", "recovery_metadata",
	]
	for field in required:
		if not data.has(field):
			return _invalid("MISSING_SAVE_FIELD", "Required save field is missing", "$.%s" % field)
	if (not data.save_format_version is float and not data.save_format_version is int) or float(data.save_format_version) != floorf(float(data.save_format_version)):
		return _invalid("INVALID_SAVE_VERSION", "save_format_version must be an integer", "$.save_format_version")
	if not data.content_snapshot is Dictionary:
		return _invalid("INVALID_CONTENT_SNAPSHOT", "content_snapshot must be an object", "$.content_snapshot")
	if not data.simulation_state is Dictionary or not data.simulation_state.get("records") is Array:
		return _invalid("INVALID_SIMULATION_STATE", "simulation_state.records must be an array", "$.simulation_state.records")
	if not data.quarantined_records is Array:
		return _invalid("INVALID_QUARANTINE", "quarantined_records must be an array", "$.quarantined_records")
	return {"ok": true, "error_code": "", "reason": "Save envelope is valid", "json_path": "$"}


static func _invalid(code: String, reason: String, json_path: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason, "json_path": json_path}
