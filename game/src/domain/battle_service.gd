class_name BattleService
extends RefCounted

const MAX_ROUNDS := 6
const MAX_HISTORY := 32


func start(state: Dictionary, encounter_id: String, catalog: Dictionary, now_unix: int, now_text: String, stance := "balanced", dungeon_id := "", dungeon_node_index := -1) -> Dictionary:
	var result := state.duplicate(true)
	if not bool(result.get("hatched", false)):
		return _failure("EGG_NOT_HATCHED", "Battle requires a hatched pet")
	if bool(result.get("sleeping", false)) or not result.get("sickness", {}).is_empty() or not result.get("injury", {}).is_empty():
		return _failure("BATTLE_NOT_ALLOWED", "The pet needs to be awake, healthy, and recovered")
	if not result.get("active_battle", {}).is_empty() or (not result.get("active_dungeon_run", {}).is_empty() and str(dungeon_id).is_empty()):
		return _failure("BATTLE_ALREADY_ACTIVE", "Another adventure is already active")
	var encounter := _data(catalog, encounter_id)
	if encounter.is_empty() or not _kind(catalog, encounter_id, "enemy-encounter"):
		return _failure("ENCOUNTER_NOT_FOUND", "The encounter is unavailable")
	var pet_stats := _pet_stats(result, catalog)
	var enemy_stats := _enemy_stats(encounter)
	var safe_stance := stance if stance in ["aggressive", "balanced", "defensive", "auto"] else "balanced"
	var session := {
		"battle_instance_id": "battle-%08x-%d" % [int(result.get("random_state", 1)), int(result.get("aggregate", {}).get("battle_count", 0)) + 1],
		"encounter_id": encounter_id,
		"seed": int(result.get("random_state", 1)),
		"random_state": int(result.get("random_state", 1)),
		"current_round": 0,
		"selected_stance": safe_stance,
		"pet_transient_hp": int(pet_stats.vitality),
		"pet_transient_max_hp": int(pet_stats.vitality),
		"opponent_transient_hp": int(enemy_stats.vitality),
		"opponent_transient_max_hp": int(enemy_stats.vitality),
		"active_effects": {"pet_power": 0, "pet_defense": 0, "opponent_power": 0, "opponent_defense": 0},
		"turn_event_log": [],
		"result_status": "in_progress",
		"reward_state": {"applied": false, "items": [], "experience": 0},
		"started_at_unix": now_unix,
		"started_at_utc": now_text,
		"dungeon_id": str(dungeon_id),
		"dungeon_node_index": int(dungeon_node_index),
	}
	result.active_battle = session
	if encounter_id not in result.required_content_ids:
		result.required_content_ids.append(encounter_id)
	result.last_battle_result = {}
	return {"ok": true, "state": result, "summary": {"event": "battle_started", "encounter_id": encounter_id}}


func set_stance(state: Dictionary, stance: String) -> Dictionary:
	var result := state.duplicate(true)
	if result.get("active_battle", {}).is_empty() or str(result.active_battle.result_status) != "in_progress":
		return _failure("NO_ACTIVE_BATTLE", "No battle is in progress")
	if stance not in ["aggressive", "balanced", "defensive", "auto"]:
		return _failure("INVALID_STANCE", "Unknown battle stance")
	result.active_battle.selected_stance = stance
	return {"ok": true, "state": result, "summary": {"event": "stance_changed", "stance": stance}}


func advance_round(state: Dictionary, catalog: Dictionary, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var session: Dictionary = result.get("active_battle", {})
	if session.is_empty() or str(session.get("result_status", "")) != "in_progress":
		return _failure("NO_ACTIVE_BATTLE", "No battle is in progress")
	var encounter := _data(catalog, str(session.get("encounter_id", "")))
	if encounter.is_empty():
		return _failure("ENCOUNTER_MISSING", "The active encounter is unavailable")
	var pet_stats := _pet_stats(result, catalog)
	var enemy_stats := _enemy_stats(encounter)
	var round := int(session.get("current_round", 0)) + 1
	var events: Array = []
	var stance := str(session.get("selected_stance", "balanced"))
	var pet_move := _select_move(result, catalog, stance)
	var enemy_move := _select_move_from_ids(encounter.get("move_ids", []), catalog, session)
	var pet_hit := _attack(session, pet_stats, enemy_stats, pet_move, stance, false, events, round)
	if int(session.get("opponent_transient_hp", 0)) <= 0:
		_finish(result, catalog, "win", now_unix, now_text, events)
	else:
		_attack(session, enemy_stats, pet_stats, enemy_move, stance, true, events, round)
		if int(session.get("pet_transient_hp", 0)) <= 0:
			_finish(result, catalog, "loss", now_unix, now_text, events)
		elif round >= MAX_ROUNDS:
			_finish(result, catalog, "draw", now_unix, now_text, events)
	session.current_round = round
	session.turn_event_log.append_array(events)
	if session.turn_event_log.size() > 48:
		session.turn_event_log = session.turn_event_log.slice(session.turn_event_log.size() - 48)
	result.active_battle = session if str(session.get("result_status", "in_progress")) == "in_progress" else {}
	result.random_state = int(session.get("random_state", result.get("random_state", 1)))
	result.revision = int(result.get("revision", 0)) + 1
	return {"ok": true, "state": result, "summary": {"event": "battle_round", "round": round, "events": events, "result": result.get("last_battle_result", {})}}


func resolve(state: Dictionary, catalog: Dictionary, outcome: String, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var session: Dictionary = result.get("active_battle", {})
	if session.is_empty():
		return _failure("NO_ACTIVE_BATTLE", "No battle is in progress")
	if outcome not in ["win", "loss", "draw"]:
		return _failure("INVALID_BATTLE_RESULT", "Unknown battle result")
	var events: Array = []
	_finish(result, catalog, outcome, now_unix, now_text, events)
	result.active_battle = {}
	result.random_state = int(session.get("random_state", result.get("random_state", 1)))
	return {"ok": true, "state": result, "summary": {"event": "battle_resolved", "result": result.get("last_battle_result", {})}}


func treat_injury(state: Dictionary, catalog: Dictionary, now_unix: int, now_text: String, item_id: String) -> Dictionary:
	var result := state.duplicate(true)
	var injury: Dictionary = result.get("injury", {})
	if injury.is_empty():
		return _failure("NO_INJURY", "No injury needs treatment")
	var item := _data(catalog, item_id)
	if str(item.get("use", {}).get("kind", "")) != "injury_treatment":
		return _failure("INVALID_INJURY_TREATMENT", "This item does not treat injuries")
	result.injury = {}
	if item_id not in result.used_item_ids:
		result.used_item_ids.append(item_id)
	_append_history(result, "injury_treated", now_unix, now_text, {"injury_id": injury.get("injury_id", ""), "item_id": item_id})
	return {"ok": true, "state": result, "summary": {"event": "injury_treated"}}


func recover_injury(state: Dictionary, seconds: int, now_unix: int, now_text: String) -> Dictionary:
	var result := state.duplicate(true)
	var injury: Dictionary = result.get("injury", {})
	if injury.is_empty() or not bool(result.get("sleeping", false)):
		return {"ok": true, "state": result, "changed": false}
	var remaining := maxi(0, int(injury.get("remaining_seconds", 0)) - maxi(0, seconds))
	result.injury.remaining_seconds = remaining
	if remaining == 0:
		var id := str(injury.get("injury_id", ""))
		result.injury = {}
		_append_history(result, "injury_recovered", now_unix, now_text, {"injury_id": id, "cause": injury.get("cause", "")})
		return {"ok": true, "state": result, "changed": true, "recovered": true}
	return {"ok": true, "state": result, "changed": true, "recovered": false}


func _finish(state: Dictionary, catalog: Dictionary, outcome: String, now_unix: int, now_text: String, events: Array) -> void:
	var session: Dictionary = state.active_battle
	if str(session.get("result_status", "")) != "in_progress":
		return
	session.result_status = outcome
	var summary: Dictionary = state.get("battle_history_summary", {})
	summary.battle_count = int(summary.get("battle_count", 0)) + 1
	if outcome == "win":
		summary.wins = int(summary.get("wins", 0)) + 1
		summary.current_win_streak = int(summary.get("current_win_streak", 0)) + 1
		summary.longest_win_streak = maxi(int(summary.get("longest_win_streak", 0)), int(summary.current_win_streak))
		if str(session.encounter_id) not in summary.defeated_encounters:
			summary.defeated_encounters.append(str(session.encounter_id))
	elif outcome == "loss":
		summary.losses = int(summary.get("losses", 0)) + 1
		summary.current_win_streak = 0
	else:
		summary.draws = int(summary.get("draws", 0)) + 1
	state.battle_history_summary = summary
	var opponent_id := str(session.get("encounter_id", ""))
	if opponent_id not in summary.opponent_history:
		summary.opponent_history.append(opponent_id)
	if opponent_id not in state.codex.encounters:
		state.codex.encounters.append(opponent_id)
	if outcome == "win" and opponent_id not in state.codex.defeated_encounters:
		state.codex.defeated_encounters.append(opponent_id)
	var experience := _experience_for(outcome, _data(catalog, str(session.encounter_id)))
	state.experience = int(state.get("experience", 0)) + experience
	_apply_level_up(state, catalog)
	var rewards: Array = []
	if outcome == "win":
		rewards = _grant_drops(state, _data(catalog, str(session.encounter_id)), session)
	var hp := int(session.get("pet_transient_hp", 0))
	if outcome == "loss" or hp <= maxi(1, int(session.get("pet_transient_max_hp", 1)) / 5):
		_apply_injury(state, catalog, now_unix, now_text, "severe_battle_defeat" if outcome == "loss" else "low_battle_health")
	var result := {"status": outcome, "encounter_id": str(session.get("encounter_id", "")), "experience": experience, "rewards": rewards, "injury": state.get("injury", {}).duplicate(true), "round": int(session.get("current_round", 0)), "dungeon_id": str(session.get("dungeon_id", "")), "dungeon_node_index": int(session.get("dungeon_node_index", -1))}
	state.last_battle_result = result
	session.reward_state = {"applied": true, "items": rewards.duplicate(true), "experience": experience}
	events.append("battle_%s" % outcome)
	_append_history(state, "battle_%s" % outcome, now_unix, now_text, result)


func _apply_injury(state: Dictionary, catalog: Dictionary, now_unix: int, now_text: String, cause: String) -> void:
	if not state.get("injury", {}).is_empty():
		return
	var injury_id := ""
	for record in catalog.values():
		if str(record.get("schema_name", "")) == "injury.schema.json":
			injury_id = str(record.get("id", ""))
			break
	if injury_id.is_empty():
		return
	var definition := _data(catalog, injury_id)
	state.injury = {"injury_id": injury_id, "cause": cause, "started_at_unix": now_unix, "started_at_utc": now_text, "remaining_seconds": int(definition.get("recovery_seconds", 3600)), "treatment_item_id": str(definition.get("treatment_item_id", "")), "blocks_combat": bool(definition.get("blocks_combat", true))}
	if injury_id not in state.required_content_ids:
		state.required_content_ids.append(injury_id)


func _grant_drops(state: Dictionary, encounter: Dictionary, session: Dictionary) -> Array:
	var rewards: Array = []
	for drop in encounter.get("drops", []):
		if not drop is Dictionary:
			continue
		var roll := _next_random(session) % 10000
		if roll >= int(drop.get("weight", 10000)):
			continue
		var item_id := str(drop.get("item_id", ""))
		var quantities: Dictionary = state.get("inventory", {})
		quantities[item_id] = int(quantities.get(item_id, 0)) + int(drop.get("quantity", 1))
		state.inventory = quantities
		rewards.append({"item_id": item_id, "quantity": int(drop.get("quantity", 1)), "source": "battle"})
		if item_id not in state.required_content_ids:
			state.required_content_ids.append(item_id)
	return rewards


func _apply_level_up(state: Dictionary, catalog: Dictionary) -> void:
	var balance := _first_data(catalog, "progression-balance")
	var cap := int(balance.get("level_cap", 5))
	var thresholds: Array = balance.get("level_thresholds", [0, 30, 75, 140, 230, 360])
	var level := clampi(int(state.get("level", 1)), 1, cap)
	while level < cap and level < thresholds.size() and int(state.get("experience", 0)) >= int(thresholds[level]):
		level += 1
	state.level = level


func _experience_for(outcome: String, encounter: Dictionary) -> int:
	if outcome == "loss":
		return maxi(1, int(encounter.get("level", 1)))
	if outcome == "draw":
		return maxi(2, int(encounter.get("level", 1)) * 2)
	return maxi(5, int(encounter.get("level", 1)) * 8)


func _attack(session: Dictionary, attacker: Dictionary, defender: Dictionary, move: Dictionary, stance: String, enemy: bool, events: Array, round: int) -> bool:
	var effects: Dictionary = session.get("active_effects", {})
	var attacker_power := int(attacker.get("power", 1)) + int(effects.get("opponent_power" if enemy else "pet_power", 0))
	var defender_defense := int(defender.get("defense", 1)) + int(effects.get("opponent_defense" if not enemy else "pet_defense", 0))
	var stance_power := 1.15 if not enemy and stance == "aggressive" else 0.9 if not enemy and stance == "defensive" else 1.0
	var stance_defense := 1.2 if not enemy and stance == "defensive" else 0.9 if not enemy and stance == "aggressive" else 1.0
	var accuracy := clampi(int(move.get("accuracy_bps", 9000)) + (500 if not enemy and stance == "aggressive" else 0), 1000, 10000)
	var hit := _next_random(session) % 10000 < accuracy
	if not hit:
		events.append({"round": round, "actor": "enemy" if enemy else "pet", "move_id": move.get("id", ""), "result": "miss"})
		return false
	var power := maxi(1, int(float(move.get("power", 1)) * stance_power) + attacker_power * 2 - int(defender_defense * stance_defense))
	if str(move.get("effect", {}).get("kind", "damage")) == "heal":
		if enemy:
			session.opponent_transient_hp = mini(int(session.opponent_transient_max_hp), int(session.opponent_transient_hp) + power)
		else:
			session.pet_transient_hp = mini(int(session.pet_transient_max_hp), int(session.pet_transient_hp) + power)
			effects.pet_power = int(effects.get("pet_power", 0))
	else:
		if enemy:
			session.pet_transient_hp = maxi(0, int(session.pet_transient_hp) - power)
		else:
			session.opponent_transient_hp = maxi(0, int(session.opponent_transient_hp) - power)
	if move.get("effect", {}).get("kind", "") == "guard":
		effects.pet_defense = int(effects.get("pet_defense", 0)) + int(move.get("effect", {}).get("amount", 1)) if not enemy else int(effects.get("opponent_defense", 0)) + int(move.get("effect", {}).get("amount", 1))
	session.active_effects = effects
	events.append({"round": round, "actor": "enemy" if enemy else "pet", "move_id": move.get("id", ""), "result": "hit", "amount": power})
	return true


func _select_move(state: Dictionary, catalog: Dictionary, stance: String) -> Dictionary:
	var form := _data(catalog, str(state.get("current_form_id", "")))
	var ids: Array = form.get("move_ids", [])
	if ids.is_empty():
		return _first_data(catalog, "move")
	var index := 0 if stance in ["balanced", "auto"] else ids.size() - 1 if stance == "aggressive" else 0
	return _data(catalog, str(ids[index]))


func _select_move_from_ids(ids: Array, catalog: Dictionary, session: Dictionary) -> Dictionary:
	if ids.is_empty():
		return {"id": "fallback", "power": 1, "accuracy_bps": 8000, "effect": {"kind": "damage"}}
	var index := _next_random(session) % ids.size()
	return _data(catalog, str(ids[index]))


func _pet_stats(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var form := _data(catalog, str(state.get("current_form_id", "")))
	var base: Dictionary = form.get("base_stats", {})
	var level := int(state.get("level", 1))
	return {"vitality": maxi(8, int(base.get("vitality", 4)) * 8 + level * 3), "power": maxi(1, int(base.get("power", base.get("effort", 1)))), "defense": maxi(1, int(base.get("defense", base.get("vitality", 1)))), "speed": maxi(1, int(base.get("speed", 3))), "focus": maxi(1, int(base.get("focus", 4)))}


func _enemy_stats(encounter: Dictionary) -> Dictionary:
	var stats: Dictionary = encounter.get("stats", {})
	return {"vitality": maxi(5, int(stats.get("vitality", 10)) + int(encounter.get("level", 1)) * 2), "power": maxi(1, int(stats.get("power", 2))), "defense": maxi(1, int(stats.get("defense", 1))), "speed": maxi(1, int(stats.get("speed", 2))), "focus": maxi(1, int(stats.get("focus", 3)))}


func _next_random(session: Dictionary) -> int:
	var value := int(session.get("random_state", 1))
	value = int((value * 1103515245 + 12345) & 0x7fffffff)
	session.random_state = value
	return value


func _first_data(catalog: Dictionary, kind: String) -> Dictionary:
	var ids: Array = []
	for content_id in catalog:
		if str(catalog[content_id].get("schema_name", "")).trim_suffix(".schema.json") == kind:
			ids.append(str(content_id))
	ids.sort()
	return _data(catalog, ids[0]) if not ids.is_empty() else {}


func _data(catalog: Dictionary, content_id: String) -> Dictionary:
	var record: Dictionary = catalog.get(content_id, {})
	return record.get("data", record) if record is Dictionary else {}


func _kind(catalog: Dictionary, content_id: String, kind: String) -> bool:
	var record: Dictionary = catalog.get(content_id, {})
	return str(record.get("schema_name", "")).trim_suffix(".schema.json") == kind


func _append_history(state: Dictionary, event_type: String, now_unix: int, now_text: String, payload: Dictionary) -> void:
	var aggregate: Dictionary = state.get("aggregate", {})
	var sequence := int(aggregate.get("event_sequence", 0)) + 1
	aggregate.event_sequence = sequence
	state.history.append({"sequence": sequence, "type": event_type, "timestamp_utc": now_text, "timestamp_unix": now_unix, "payload": payload.duplicate(true)})
	if state.history.size() > 128:
		state.history.pop_front()


func _failure(code: String, reason: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason}
