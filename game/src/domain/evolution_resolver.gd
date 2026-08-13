class_name EvolutionResolver
extends RefCounted

const MAX_EVIDENCE_ROUTES := 16


func evaluate(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var evidence := _evidence(state)
	var graph_id := _family_graph_id(state, catalog)
	var graph := _data(catalog, graph_id)
	var candidates: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	if graph.is_empty():
		return {"ok": true, "eligible": false, "graph_id": graph_id, "evidence": evidence, "candidates": [], "diagnostics": [{"code": "GRAPH_MISSING", "reason": "No evolution graph is available"}]}
	for rule in graph.get("rules", []):
		if not rule is Dictionary:
			continue
		var rule_data: Dictionary = rule
		if str(rule_data.get("from_form_id", "")) != str(state.get("current_form_id", state.get("definition_id", ""))):
			continue
		var evaluation := _evaluate_rule(rule_data, evidence)
		var diagnostic := {"rule_id": str(rule_data.get("id", "")), "priority": int(rule_data.get("priority", 0)), "to_form_id": str(rule_data.get("to_form_id", "")), "passed": evaluation.passed, "conditions": evaluation.conditions, "evidence": evidence.duplicate(true)}
		if evaluation.passed and int(rule_data.get("minimum_stage_seconds", 0)) <= int(evidence.stage_seconds) and _max_age_allows(rule_data, int(evidence.stage_seconds)):
			candidates.append(diagnostic.merged({"rule": rule_data.duplicate(true)}, true))
		else:
			rejected.append(diagnostic)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_priority := int(left.get("priority", 0))
			var right_priority := int(right.get("priority", 0))
			return str(left.get("rule_id", "")) < str(right.get("rule_id", "")) if left_priority == right_priority else left_priority > right_priority
	)
	return {"ok": true, "eligible": not candidates.is_empty(), "graph_id": graph_id, "evidence": evidence, "candidates": candidates, "rejected": rejected, "selected": candidates[0] if not candidates.is_empty() else {}}


func apply_at_safe_point(state: Dictionary, catalog: Dictionary, now_unix: int, now_text: String, content_fingerprint := "", forced_rule_id := "") -> Dictionary:
	var result := state.duplicate(true)
	var evaluation := evaluate(result, catalog)
	if not bool(evaluation.get("eligible", false)):
		return {"ok": true, "state": result, "changed": false, "evaluation": evaluation}
	var selected: Dictionary = evaluation.selected
	if not forced_rule_id.is_empty():
		selected = {}
		for candidate in evaluation.get("candidates", []):
			if str(candidate.get("rule_id", "")) == forced_rule_id:
				selected = candidate
				break
		if selected.is_empty():
			return {"ok": false, "state": result, "changed": false, "error_code": "RULE_NOT_ELIGIBLE", "reason": "The requested evolution rule is not eligible", "evaluation": evaluation}
		evaluation.selected = selected
	var rule: Dictionary = selected.get("rule", {})
	if _already_applied(result, str(selected.get("rule_id", "")), str(selected.get("to_form_id", ""))):
		return {"ok": true, "state": result, "changed": false, "evaluation": evaluation, "reason": "already_applied"}
	if not _safe_for_transition(result):
		result.pending_evolution = {
			"rule_id": str(selected.get("rule_id", "")),
			"source_form_id": str(result.get("current_form_id", "")),
			"target_form_id": str(selected.get("to_form_id", "")),
			"evaluated_at_unix": now_unix,
			"evaluated_at_utc": now_text,
			"evidence": evaluation.evidence.duplicate(true),
			"content_fingerprint": content_fingerprint,
		}
		return {"ok": true, "state": result, "changed": false, "pending": true, "evaluation": evaluation}
	var target_id := str(selected.get("to_form_id", ""))
	var target := _record(catalog, target_id)
	if target.is_empty():
		result.pending_evolution = {"rule_id": str(selected.get("rule_id", "")), "target_form_id": target_id, "evidence": evaluation.evidence.duplicate(true), "error_code": "MISSING_TARGET_FORM"}
		return {"ok": false, "state": result, "error_code": "MISSING_TARGET_FORM", "reason": "Evolution target is unavailable", "evaluation": evaluation}
	var target_data: Dictionary = _data(catalog, target_id)
	var source_id := str(result.get("current_form_id", result.get("definition_id", "")))
	var required: Array = result.get("required_content_ids", []).duplicate()
	for content_id in [target_id, str(target_data.get("family_id", "")), str(target_data.get("animation_profile_id", ""))]:
		if not content_id.is_empty() and content_id not in required:
			required.append(content_id)
	var record := {
		"rule_id": str(selected.get("rule_id", "")),
		"source_form_id": source_id,
		"target_form_id": target_id,
		"timestamp_unix": now_unix,
		"timestamp_utc": now_text,
		"evidence_snapshot": evaluation.evidence.duplicate(true),
		"content_fingerprint": content_fingerprint,
		"priority": int(rule.get("priority", 0)),
		"tie_break": str(selected.get("rule_id", "")),
	}
	result.current_form_id = target_id
	result.definition_id = target_id
	result.family_id = str(target_data.get("family_id", result.get("family_id", "")))
	result.stage = str(target_data.get("stage", "juvenile"))
	result.traits = target_data.get("traits", result.get("traits", [])).duplicate(true)
	result.stage_started_at_unix = now_unix
	result.stage_started_at_utc = now_text
	result.animation_profile_id = str(target_data.get("animation_profile_id", result.get("animation_profile_id", "")))
	result.care_profile_id = str(target_data.get("care_profile_id", result.get("care_profile_id", "")))
	result.required_content_ids = required
	result.evolution_history.append(record)
	result.pending_evolution = {}
	if target_id not in result.discovered_forms:
		result.discovered_forms.append(target_id)
	if target_id not in result.codex.forms:
		result.codex.forms.append(target_id)
	result.discovered_routes.append({"source_form_id": source_id, "target_form_id": target_id, "rule_id": record.rule_id, "evidence_snapshot": record.evidence_snapshot.duplicate(true)})
	_trim_array(result.evolution_history, MAX_EVIDENCE_ROUTES)
	_trim_array(result.discovered_routes, MAX_EVIDENCE_ROUTES)
	_append_history(result, "evolved", now_unix, now_text, {"rule_id": record.rule_id, "source_form_id": source_id, "target_form_id": target_id})
	return {"ok": true, "state": result, "changed": true, "pending": false, "record": record, "evaluation": evaluation}


func _evaluate_rule(rule: Dictionary, evidence: Dictionary) -> Dictionary:
	var conditions: Array[Dictionary] = []
	var passed := true
	for condition in rule.get("all", []):
		if not condition is Dictionary:
			passed = false
			continue
		var metric := str(condition.get("metric", ""))
		var actual: Variant = evidence.get(metric, null)
		var condition_passed := _compare(actual, str(condition.get("operator", "eq")), condition.get("value", null))
		conditions.append({"metric": metric, "operator": str(condition.get("operator", "eq")), "expected": condition.get("value", null), "actual": actual, "passed": condition_passed})
		if not condition_passed:
			passed = false
	return {"passed": passed, "conditions": conditions}


func _evidence(state: Dictionary) -> Dictionary:
	var aggregate: Dictionary = state.get("aggregate", {})
	var care: Dictionary = state.get("care", {})
	var history: Array = state.get("history", [])
	var stage_start := int(state.get("stage_started_at_unix", state.get("hatched_at_unix", 0)))
	if stage_start <= 0:
		stage_start = int(state.get("selected_at_unix", state.get("current_simulation_unix", 0)))
	var stage_seconds := maxi(0, int(state.get("current_simulation_unix", stage_start)) - stage_start)
	var battle_history: Dictionary = state.get("battle_history_summary", {})
	var dungeon_flags: Array = state.get("dungeon_flags", [])
	var used_items: Array = state.get("used_item_ids", [])
	return {
		"stage_seconds": stage_seconds,
		"stage_hours": stage_seconds / 3600,
		"active_stage_seconds": stage_seconds,
		"offline_stage_seconds": int(aggregate.get("offline_stage_seconds", 0)),
		"care_mistakes": int(aggregate.get("care_mistakes", 0)),
		"resolved_calls": int(aggregate.get("resolved_calls", 0)),
		"training_count": int(aggregate.get("training_count", 0)),
		"excellent_training_count": int(aggregate.get("training_outcomes", {}).get("excellent", 0)),
		"effort_bps": int(care.get("effort_bps", 0)),
		"discipline_bps": int(care.get("discipline_bps", 0)),
		"mood_bps": int(care.get("mood_bps", 0)),
		"satiety_bps": int(care.get("satiety_bps", 0)),
		"weight_grams": int(care.get("weight_grams", 0)),
		"overfeed_count": int(aggregate.get("overfeed_count", 0)),
		"dirty_seconds": int(care.get("dirty_seconds", 0)),
		"waste_cleaned": int(aggregate.get("waste_cleaned", 0)),
		"sleep_seconds": int(aggregate.get("sleep_seconds", 0)),
		"sleep_disturbances": int(aggregate.get("sleep_disturbances", 0)),
		"sickness_count": int(aggregate.get("sickness_count", 0)),
		"treatment_count": int(aggregate.get("treatment_count", 0)),
		"battle_count": int(battle_history.get("battle_count", aggregate.get("battle_count", 0))),
		"battle_wins": int(battle_history.get("wins", aggregate.get("battle_wins", 0))),
		"battle_losses": int(battle_history.get("losses", aggregate.get("battle_losses", 0))),
		"win_ratio_bps": int(int(battle_history.get("wins", 0)) * 10000 / maxi(1, int(battle_history.get("wins", 0)) + int(battle_history.get("losses", 0)))),
		"experience": int(state.get("experience", 0)),
		"level": int(state.get("level", 1)),
		"defeated_encounters": battle_history.get("defeated_encounters", []).duplicate(true),
		"dungeon_clears": dungeon_flags.duplicate(true),
		"boss_defeated": "koalapet.base:canopy_guardian" in dungeon_flags,
		"used_items": used_items.duplicate(true),
		"traits": _form_traits(state),
		"history_event_count": history.size(),
	}


func _form_traits(state: Dictionary) -> Array:
	return state.get("traits", []).duplicate(true)


func _family_graph_id(state: Dictionary, catalog: Dictionary) -> String:
	var family := _data(catalog, str(state.get("family_id", "")))
	return str(family.get("evolution_graph_id", ""))


func _safe_for_transition(state: Dictionary) -> bool:
	return not bool(state.get("sleeping", false)) and state.get("sickness", {}).is_empty() and state.get("injury", {}).is_empty() and state.get("active_battle", {}).is_empty() and state.get("active_dungeon_run", {}).is_empty()


func _already_applied(state: Dictionary, rule_id: String, target_id: String) -> bool:
	for record in state.get("evolution_history", []):
		if str(record.get("rule_id", "")) == rule_id and str(record.get("target_form_id", "")) == target_id:
			return true
	return false


func _max_age_allows(rule: Dictionary, stage_seconds: int) -> bool:
	var maximum := int(rule.get("maximum_stage_seconds", 0))
	return maximum <= 0 or stage_seconds <= maximum


func _compare(actual: Variant, operator: String, expected: Variant) -> bool:
	if actual == null:
		return false
	match operator:
		"lt": return actual < expected
		"lte": return actual <= expected
		"eq": return actual == expected
		"gte": return actual >= expected
		"gt": return actual > expected
		"contains": return actual is Array and expected in actual
	return false


func _record(catalog: Dictionary, content_id: String) -> Dictionary:
	return catalog.get(content_id, {}).duplicate(true)


func _data(catalog: Dictionary, content_id: String) -> Dictionary:
	var record: Dictionary = _record(catalog, content_id)
	return record.get("data", record) if record is Dictionary else {}


func _append_history(state: Dictionary, event_type: String, now_unix: int, now_text: String, payload: Dictionary) -> void:
	var aggregate: Dictionary = state.get("aggregate", {})
	var sequence := int(aggregate.get("event_sequence", 0)) + 1
	aggregate.event_sequence = sequence
	state.history.append({"sequence": sequence, "type": event_type, "timestamp_utc": now_text, "timestamp_unix": now_unix, "payload": payload.duplicate(true)})
	if state.history.size() > 128:
		state.history.pop_front()


func _trim_array(values: Array, maximum: int) -> void:
	while values.size() > maximum:
		values.pop_front()
