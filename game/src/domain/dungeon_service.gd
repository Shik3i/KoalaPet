class_name DungeonService
extends RefCounted


func start(state: Dictionary, dungeon_id: String, catalog: Dictionary, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	if not bool(result.get("hatched", false)) or bool(result.get("sleeping", false)) or not result.get("sickness", {}).is_empty() or not result.get("injury", {}).is_empty():
		return _failure("DUNGEON_NOT_ALLOWED", "The pet needs to be awake, healthy, and recovered")
	if not result.get("active_battle", {}).is_empty() or not result.get("active_dungeon_run", {}).is_empty():
		return _failure("ADVENTURE_ALREADY_ACTIVE", "Another adventure is already active")
	var dungeon := _data(catalog, dungeon_id)
	if dungeon.is_empty() or _kind(catalog, dungeon_id) != "dungeon":
		return _failure("DUNGEON_NOT_FOUND", "The dungeon is unavailable")
	var nodes: Array = dungeon.get("nodes", [])
	if nodes.is_empty():
		return _failure("DUNGEON_EMPTY", "The dungeon has no stages")
	var run := {
		"run_instance_id": "run-%08x-%d" % [int(result.get("random_state", 1)), int(result.get("dungeon_history", []).size()) + 1],
		"dungeon_id": dungeon_id,
		"seed": int(result.get("random_state", 1)),
		"random_state": int(result.get("random_state", 1)),
		"current_node": 0,
		"completed_nodes": [],
		"choices": [],
		"pet_transient_hp": 100,
		"pet_transient_max_hp": 100,
		"encountered_enemies": [],
		"accumulated_rewards": [],
		"result_status": "in_progress",
		"first_clear": false,
		"started_at_unix": now_unix,
		"started_at_utc": now_text,
	}
	result.active_dungeon_run = run
	if dungeon_id not in result.required_content_ids:
		result.required_content_ids.append(dungeon_id)
	return {"ok": true, "state": result, "summary": {"event": "dungeon_started", "dungeon_id": dungeon_id, "node": 0}}


func resolve_current_node(state: Dictionary, catalog: Dictionary, now_unix: int, now_text: String, choice_id := "") -> Dictionary:
	var result := state.duplicate(true)
	var run: Dictionary = result.get("active_dungeon_run", {})
	if run.is_empty() or str(run.get("result_status", "")) != "in_progress":
		return _failure("NO_ACTIVE_DUNGEON", "No dungeon run is active")
	var dungeon := _data(catalog, str(run.get("dungeon_id", "")))
	var nodes: Array = dungeon.get("nodes", [])
	var index := int(run.get("current_node", 0))
	if index < 0 or index >= nodes.size():
		return _failure("DUNGEON_NODE_INVALID", "The active dungeon node is invalid")
	var node: Dictionary = nodes[index]
	var kind := str(node.get("kind", ""))
	if kind in ["encounter", "boss"]:
		var encounter_id := str(node.get("encounter_id", dungeon.get("boss_encounter_id", "")))
		var battle := BattleService.new().start(result, encounter_id, catalog, now_unix, now_text, "balanced", str(run.get("dungeon_id", "")), index)
		if not battle.ok:
			return battle
		result = battle.state
		result.active_battle.dungeon_context = {"dungeon_id": str(run.get("dungeon_id", "")), "node_index": index, "node_kind": kind}
		result.active_battle.dungeon_id = str(run.get("dungeon_id", ""))
		result.active_battle.dungeon_node_index = index
		var encounter_list: Array = run.get("encountered_enemies", [])
		if encounter_id not in encounter_list:
			encounter_list.append(encounter_id)
		run.encountered_enemies = encounter_list
		result.active_dungeon_run = run
		return {"ok": true, "state": result, "summary": {"event": "dungeon_encounter_started", "node": index, "encounter_id": encounter_id}}
	if kind == "event":
		return _resolve_event(result, dungeon, node, choice_id, now_unix, now_text)
	if kind == "rest":
		var heal := int(node.get("heal_percent", 25))
		run.pet_transient_hp = mini(int(run.get("pet_transient_max_hp", 100)), int(run.get("pet_transient_hp", 100)) + heal)
		return _complete_node(result, dungeon, "rest", {"healed_percent": heal}, now_unix, now_text)
	if kind == "hazard":
		var damage := int(node.get("damage_percent", 20))
		run.pet_transient_hp = maxi(0, int(run.get("pet_transient_hp", 100)) - damage)
		if int(run.pet_transient_hp) <= 0:
			return _fail_run(result, "hazard", now_unix, now_text)
		result.active_dungeon_run = run
		return _complete_node(result, dungeon, "hazard", {"damage_percent": damage}, now_unix, now_text)
	return _failure("DUNGEON_NODE_KIND", "Unsupported dungeon node kind")


func choose_event(state: Dictionary, catalog: Dictionary, choice_id: String, now_unix: int, now_text: String) -> Dictionary:
	return resolve_current_node(state, catalog, now_unix, now_text, choice_id)


func after_battle(state: Dictionary, catalog: Dictionary, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var run: Dictionary = result.get("active_dungeon_run", {})
	var battle_result: Dictionary = result.get("last_battle_result", {})
	if run.is_empty() or battle_result.is_empty() or str(battle_result.get("dungeon_id", "")) != str(run.get("dungeon_id", "")):
		return {"ok": true, "state": result, "changed": false}
	if str(battle_result.get("status", "")) != "win":
		return _fail_run(result, "battle_%s" % str(battle_result.get("status", "loss")), now_unix, now_text)
	var node_index := int(battle_result.get("dungeon_node_index", run.get("current_node", 0)))
	if node_index != int(run.get("current_node", 0)):
		return {"ok": true, "state": result, "changed": false}
	var dungeon := _data(catalog, str(run.get("dungeon_id", "")))
	var nodes: Array = dungeon.get("nodes", [])
	var node: Dictionary = nodes[node_index] if node_index >= 0 and node_index < nodes.size() else {}
	return _complete_node(result, dungeon, "battle", {"node_index": node_index, "encounter_id": battle_result.get("encounter_id", ""), "is_boss": str(node.get("kind", "")) == "boss"}, now_unix, now_text)


func abandon(state: Dictionary, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	if result.get("active_dungeon_run", {}).is_empty():
		return _failure("NO_ACTIVE_DUNGEON", "No dungeon run is active")
	return _fail_run(result, "abandoned", now_unix, now_text)


func _resolve_event(state: Dictionary, dungeon: Dictionary, node: Dictionary, choice_id: String, now_unix: int, now_text: String) -> Dictionary:
	var run: Dictionary = state.active_dungeon_run
	var choices: Array = node.get("choices", [])
	var selected: Dictionary = {}
	for choice in choices:
		if str(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty() and not choices.is_empty():
		selected = choices[0]
	if selected.is_empty():
		return _failure("DUNGEON_CHOICE_INVALID", "The event has no valid choice")
	run.choices.append({"node": int(run.get("current_node", 0)), "choice_id": str(selected.get("id", ""))})
	var effect: Dictionary = selected.get("effect", {})
	var heal := int(effect.get("heal_percent", 0))
	var damage := int(effect.get("damage_percent", 0))
	run.pet_transient_hp = mini(int(run.get("pet_transient_max_hp", 100)), int(run.get("pet_transient_hp", 100)) + heal)
	run.pet_transient_hp = maxi(0, int(run.get("pet_transient_hp", 100)) - damage)
	if int(run.pet_transient_hp) <= 0:
		return _fail_run(state, "event", now_unix, now_text)
	state.active_dungeon_run = run
	return _complete_node(state, dungeon, "event", {"choice_id": selected.get("id", ""), "heal_percent": heal, "damage_percent": damage}, now_unix, now_text)


func _complete_node(state: Dictionary, dungeon: Dictionary, node_kind: String, payload: Dictionary, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var run: Dictionary = result.active_dungeon_run
	var node_index := int(run.get("current_node", 0))
	if node_index not in run.completed_nodes:
		run.completed_nodes.append(node_index)
	run.current_node = node_index + 1
	result.active_dungeon_run = run
	var record := {"node": node_index, "kind": node_kind, "payload": payload.duplicate(true)}
	_append_history(result, "dungeon_node_completed", now_unix, now_text, record)
	if bool(payload.get("is_boss", false)):
		return _complete_run(result, dungeon, now_unix, now_text)
	return {"ok": true, "state": result, "summary": {"event": "dungeon_node_completed", "node": node_index, "node_kind": node_kind, "payload": payload}}


func _complete_run(state: Dictionary, dungeon: Dictionary, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var run: Dictionary = result.active_dungeon_run
	var dungeon_id := str(run.get("dungeon_id", ""))
	var first_clear_grant_id := "dungeon:first_clear:%s" % dungeon_id
	var reward_grants: Dictionary = result.get("reward_grants", {})
	var first_clear: bool = dungeon_id not in result.dungeon_flags and not reward_grants.has(first_clear_grant_id)
	var rewards: Array = []
	var item_ids: Array = dungeon.get("reward_item_ids", []) if first_clear else dungeon.get("repeat_reward_item_ids", dungeon.get("reward_item_ids", []))
	for item_id in item_ids:
		var quantities: Dictionary = result.inventory
		quantities[str(item_id)] = int(quantities.get(str(item_id), 0)) + 1
		result.inventory = quantities
		rewards.append({"item_id": str(item_id), "quantity": 1, "source": "dungeon_first_clear" if first_clear else "dungeon_repeat"})
		if str(item_id) not in result.required_content_ids:
			result.required_content_ids.append(str(item_id))
	for unlock_id in dungeon.get("unlock_ids", []):
		var id := str(unlock_id)
		if id not in result.unlock_ids:
			result.unlock_ids.append(id)
	if first_clear:
		result.dungeon_flags.append(dungeon_id)
		reward_grants[first_clear_grant_id] = {"dungeon_id": dungeon_id, "granted_at_unix": now_unix, "status": "granted"}
		if str(dungeon.get("boss_flag_id", "")) not in ["", "null"]:
			result.boss_flags.append(str(dungeon.boss_flag_id))
	result.reward_grants = reward_grants
	if dungeon_id not in result.codex.dungeons:
		result.codex.dungeons.append(dungeon_id)
	var boss_id := str(dungeon.get("boss_encounter_id", ""))
	if first_clear and boss_id not in result.codex.bosses:
		result.codex.bosses.append(boss_id)
	var history_entry := {"dungeon_id": dungeon_id, "status": "clear", "first_clear": first_clear, "rewards": rewards.duplicate(true), "cleared_at_unix": now_unix, "cleared_at_utc": now_text}
	result.dungeon_history.append(history_entry)
	result.active_dungeon_run = {}
	result.experience = int(result.get("experience", 0)) + int(dungeon.get("completion_experience", 25 if first_clear else 12))
	_append_history(result, "dungeon_cleared", now_unix, now_text, history_entry)
	return {"ok": true, "state": result, "summary": {"event": "dungeon_cleared", "first_clear": first_clear, "rewards": rewards, "dungeon_id": dungeon_id}}


func _fail_run(state: Dictionary, reason: String, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var run: Dictionary = result.get("active_dungeon_run", {})
	if run.is_empty():
		return {"ok": true, "state": result, "summary": {"event": "dungeon_failed", "reason": reason}}
	var history_entry := {"dungeon_id": run.get("dungeon_id", ""), "status": "failed", "reason": reason, "cleared_at_unix": now_unix, "cleared_at_utc": now_text}
	result.dungeon_history.append(history_entry)
	result.active_dungeon_run = {}
	_append_history(result, "dungeon_failed", now_unix, now_text, history_entry)
	return {"ok": true, "state": result, "summary": {"event": "dungeon_failed", "reason": reason}}


func _data(catalog: Dictionary, content_id: String) -> Dictionary:
	var record: Dictionary = catalog.get(content_id, {})
	return record.get("data", record) if record is Dictionary else {}


func _kind(catalog: Dictionary, content_id: String) -> String:
	return str(catalog.get(content_id, {}).get("schema_name", "")).trim_suffix(".schema.json")


func _append_history(state: Dictionary, event_type: String, now_unix: int, now_text: String, payload: Dictionary) -> void:
	var aggregate: Dictionary = state.get("aggregate", {})
	var sequence := int(aggregate.get("event_sequence", 0)) + 1
	aggregate.event_sequence = sequence
	state.history.append({"sequence": sequence, "type": event_type, "timestamp_utc": now_text, "timestamp_unix": now_unix, "payload": payload.duplicate(true)})
	if state.history.size() > 128:
		state.history.pop_front()


func _failure(code: String, reason: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason}
