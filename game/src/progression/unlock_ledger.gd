class_name UnlockLedger
extends RefCounted

var _entries: Dictionary


func _init(entries: Dictionary = {}) -> void:
	_entries = entries.duplicate(true)


func grant(reward_id: String, gate_id: String) -> Dictionary:
	if not ContentPathPolicy.is_namespaced_id(reward_id):
		return {"granted": false, "error_code": "INVALID_REWARD_ID", "reward_id": reward_id}
	if _entries.has(reward_id):
		return {"granted": false, "error_code": "ALREADY_GRANTED", "reward_id": reward_id, "entry": _entries[reward_id].duplicate(true)}
	_entries[reward_id] = {"reward_id": reward_id, "gate_id": gate_id}
	return {"granted": true, "error_code": "", "reward_id": reward_id, "entry": _entries[reward_id].duplicate(true)}


func has_reward(reward_id: String) -> bool:
	return _entries.has(reward_id)


func snapshot() -> Dictionary:
	return _entries.duplicate(true)
