class_name PetSimulation
extends RefCounted

const STATE_VERSION := 1
const BASIS_POINTS := 10000
const MAX_HISTORY := 128
const MAX_CALLS := 32
const MAX_WEIGHT_GRAMS := 2000


func create_new(egg: Dictionary, form: Dictionary, profile: Dictionary, owner_pack_id: String, now_unix: int, now_text: String, seed: int) -> Dictionary:
	var safe_seed := seed if seed > 0 else 1
	var form_data: Dictionary = form.data
	var profile_data: Dictionary = profile.data
	var egg_data: Dictionary = egg.data
	var instance_id := "pet-%08x-%08x" % [safe_seed & 0xffffffff, now_unix & 0xffffffff]
	var state := {
		"pet_state_version": STATE_VERSION,
		"instance_id": instance_id,
		"definition_id": str(form_data.id),
		"required_pack_id": owner_pack_id,
		"required_content_ids": [str(egg_data.id), str(form_data.id), str(form_data.family_id), str(form_data.animation_profile_id), str(profile_data.id)],
		"egg_definition_id": str(egg_data.id),
		"family_id": str(form_data.family_id),
		"current_form_id": str(form_data.id),
		"care_profile_id": str(profile_data.id),
		"animation_profile_id": str(form_data.animation_profile_id),
		"nickname": "",
		"created_at_utc": now_text,
		"selected_at_utc": now_text,
		"selected_at_unix": now_unix,
		"hatched_at_utc": "",
		"hatch_due_unix": now_unix + int(profile_data.hatch_duration_seconds),
		"hatched": false,
		"sleeping": false,
		"sickness": {},
		"waste": [],
		"pending_digestion": [],
		"attention_calls": [],
		"history": [],
		"aggregate": _initial_aggregate(),
		"care": {
			"satiety_bps": 7000,
			"mood_bps": 6500,
			"energy_bps": 8000,
			"hygiene_bps": 9000,
			"health_bps": BASIS_POINTS,
			"weight_grams": 420,
			"discipline_bps": 5000,
			"effort_bps": int(form_data.base_stats.get("effort", 1)) * 500,
			"dirty_seconds": 0,
			"severe_hunger_seconds": 0,
			"last_feed_unix": 0,
			"last_sleep_start_unix": 0,
			"last_wake_unix": 0
		},
		"random_state": safe_seed & 0x7fffffff,
		"current_simulation_unix": now_unix,
		"current_simulation_utc": now_text,
		"revision": 0
	}
	_record_event(state, "egg_selected", now_unix, now_text, {"egg_id": egg_data.id})
	return state


func advance(state: Dictionary, accepted_seconds: int, observed_unix: int, observed_text: String, catalog: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	var start_unix := int(result.get("current_simulation_unix", observed_unix))
	var accepted := maxi(0, accepted_seconds)
	var logical_end := start_unix + accepted
	var events: Array = []
	var summary := {"accepted_seconds": accepted, "events": [], "mistakes": 0, "waste_generated": 0, "calls_missed": 0, "sickness_started": false, "hatched": false}
	if not bool(result.get("hatched", false)) and logical_end >= int(result.get("hatch_due_unix", logical_end + 1)):
		result.hatched = true
		result.hatched_at_utc = _utc_text(int(result.hatch_due_unix))
		if str(result.current_form_id) not in result.required_content_ids:
			result.required_content_ids.append(str(result.current_form_id))
		_record_event(result, "egg_hatched", int(result.hatch_due_unix), result.hatched_at_utc, {"form_id": result.current_form_id})
		events.append("egg_hatched")
		summary.hatched = true
	if bool(result.get("hatched", false)) and accepted > 0:
		_advance_care(result, accepted, start_unix, logical_end, catalog, events, summary)
	var previous_unix := int(result.get("current_simulation_unix", observed_unix))
	var next_unix := maxi(previous_unix, observed_unix)
	result.current_simulation_unix = next_unix
	result.current_simulation_utc = observed_text if observed_unix >= previous_unix else _utc_text(next_unix)
	result.revision = int(result.get("revision", 0)) + 1
	result.aggregate.last_accepted_simulation_seconds = int(result.aggregate.get("last_accepted_simulation_seconds", 0)) + accepted
	summary.events = events
	return {"ok": true, "state": result, "summary": summary}


func apply_command(state: Dictionary, command: Dictionary, now_unix: int, now_text: String, catalog: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	var command_name := str(command.get("type", ""))
	var events: Array = []
	var summary := {"accepted_seconds": 0, "events": [], "mistakes": 0, "waste_generated": 0, "calls_missed": 0, "sickness_started": false, "hatched": false}
	if command_name == "complete_hatch":
		if not bool(result.get("hatched", false)):
			result.hatch_due_unix = now_unix
			var completed := advance(result, 0, now_unix, now_text, catalog)
			return completed
	if command_name == "set_nickname":
		var nickname_result := validate_nickname(command.get("nickname", ""))
		if not nickname_result.ok:
			return nickname_result
		result.nickname = nickname_result.nickname
		_record_event(result, "nickname_changed", now_unix, now_text, {"has_nickname": not nickname_result.nickname.is_empty()})
		return _command_success(result, ["nickname_changed"])
	if not bool(result.get("hatched", false)):
		return _failure("EGG_NOT_HATCHED", "This action is available after hatching")
	match command_name:
		"feed":
			_apply_food(result, command, now_unix, now_text, catalog, events, summary)
		"clean":
			_apply_clean(result, now_unix, now_text, events)
		"sleep":
			_apply_sleep(result, now_unix, now_text, events)
		"wake":
			_apply_wake(result, now_unix, now_text, events)
		"medicine":
			_apply_medicine(result, command, now_unix, now_text, catalog, events)
		"train":
			_apply_training(result, command, now_unix, now_text, catalog, events)
		"resolve_call":
			_apply_call_resolution(result, command, now_unix, now_text, events)
		"force_sickness":
			_force_sickness(result, now_unix, now_text, catalog, events)
		_:
			return _failure("UNKNOWN_COMMAND", "Unknown pet command: %s" % command_name)
	result.revision = int(result.get("revision", 0)) + 1
	var previous_unix := int(result.get("current_simulation_unix", now_unix))
	var next_unix := maxi(previous_unix, now_unix)
	result.current_simulation_unix = next_unix
	result.current_simulation_utc = now_text if now_unix >= previous_unix else _utc_text(next_unix)
	summary.events = events
	return {"ok": true, "state": result, "summary": summary}


func validate_nickname(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true, "nickname": ""}
	if not value is String:
		return _failure("INVALID_NICKNAME", "Nickname must be text")
	var nickname: String = value.strip_edges()
	if nickname.length() > 20:
		return _failure("INVALID_NICKNAME", "Nickname must be at most 20 characters")
	for character in nickname:
		if character.unicode_at(0) < 32:
			return _failure("INVALID_NICKNAME", "Nickname contains a control character")
	return {"ok": true, "nickname": nickname}


func _advance_care(state: Dictionary, seconds: int, start_unix: int, end_unix: int, catalog: Dictionary, events: Array, summary: Dictionary) -> void:
	var profile: Dictionary = _definition(catalog, state.care_profile_id)
	if profile.is_empty():
		return
	var care: Dictionary = state.care
	var hours_basis := seconds * 10000 / 3600
	var sleeping := bool(state.get("sleeping", false))
	if sleeping:
		care.energy_bps = _cap(care.energy_bps + int(profile.get("sleep_recovery_per_hour", 0)) * hours_basis / 10000)
		if care.energy_bps >= int(profile.get("wake_energy_threshold_bps", 8500)):
			state.sleeping = false
			care.last_wake_unix = end_unix
			_record_event(state, "woke", end_unix, _utc_text(end_unix), {})
			events.append("woke")
	else:
		care.energy_bps = _cap(care.energy_bps - int(profile.get("energy_use_per_hour", 0)) * hours_basis / 10000)
	care.satiety_bps = _floor_zero(care.satiety_bps - int(profile.get("satiety_decay_per_hour", 0)) * hours_basis / 10000)
	var hygiene_loss := int(profile.get("hygiene_decay_per_hour", 0)) * hours_basis / 10000
	if not state.waste.is_empty():
		hygiene_loss += int(profile.get("waste_hygiene_loss_per_hour", 0)) * state.waste.size() * hours_basis / 10000
	care.hygiene_bps = _floor_zero(care.hygiene_bps - hygiene_loss)
	if care.satiety_bps < int(profile.get("severe_hunger_threshold_bps", 0)):
		care.severe_hunger_seconds += seconds
	else:
		care.severe_hunger_seconds = 0
	if care.hygiene_bps < int(profile.get("hygiene_call_threshold_bps", 0)) or not state.waste.is_empty():
		care.dirty_seconds += seconds
	else:
		care.dirty_seconds = 0
	_process_digestion(state, end_unix, profile, events, summary)
	_update_attention_calls(state, end_unix, _utc_text(end_unix), profile, events, summary)
	_process_illness(state, seconds, end_unix, _utc_text(end_unix), profile, catalog, events, summary)
	if state.sickness is Dictionary and not state.sickness.is_empty():
		var ailment: Dictionary = _definition(catalog, str(state.sickness.ailment_id))
		care.health_bps = _floor_zero(care.health_bps - int(ailment.get("health_loss_per_hour", 0)) * hours_basis / 10000)
		if sleeping:
			care.health_bps = _cap(care.health_bps + int(ailment.get("recovery_health_per_hour", 0)) * hours_basis / 10000)
	_update_attention_calls(state, end_unix, _utc_text(end_unix), profile, events, summary)
	if sleeping:
		state.aggregate.sleep_seconds += seconds
	else:
		state.aggregate.awake_seconds += seconds
	if care.dirty_seconds > 0:
		state.aggregate.dirty_seconds += seconds


func _process_digestion(state: Dictionary, end_unix: int, profile: Dictionary, events: Array, summary: Dictionary) -> void:
	var pending: Array = state.pending_digestion
	var remaining: Array = []
	for entry in pending:
		if int(entry.get("due_unix", 0)) <= end_unix:
			state.aggregate.waste_generated += 1
			summary.waste_generated += 1
			if state.waste.size() < int(profile.get("max_waste_units", 1)):
				state.waste.append({"waste_id": "waste-%d" % state.aggregate.waste_generated, "generated_at_unix": int(entry.due_unix)})
				_record_event(state, "waste_generated", int(entry.due_unix), _utc_text(int(entry.due_unix)), {})
				events.append("waste_generated")
		else:
			remaining.append(entry)
	state.pending_digestion = remaining


func _process_illness(state: Dictionary, seconds: int, end_unix: int, end_text: String, profile: Dictionary, catalog: Dictionary, events: Array, summary: Dictionary) -> void:
	if not state.sickness.is_empty():
		return
	var care: Dictionary = state.care
	var dirty_limit := int(profile.get("illness_dirt_seconds", 0))
	var hunger_limit := int(profile.get("illness_hunger_seconds", 0))
	var risk := false
	if dirty_limit > 0 and int(care.dirty_seconds) >= dirty_limit:
		risk = true
	if hunger_limit > 0 and int(care.severe_hunger_seconds) >= hunger_limit:
		risk = true
	if int(state.aggregate.overfeed_count) >= 3:
		risk = true
	if not risk:
		return
	var checks := maxi(1, seconds / 3600)
	for index in checks:
		var roll := _next_random(state)
		if roll % 10000 < int(profile.get("illness_probability_bps", 0)):
			var ailment_id := _first_definition_id(catalog, "ailment")
			if ailment_id.is_empty():
				return
			state.sickness = {"ailment_id": ailment_id, "started_at_unix": end_unix, "reason": "prolonged_care_stress", "diagnostic": "dirt_or_hunger_threshold"}
			if ailment_id not in state.required_content_ids:
				state.required_content_ids.append(ailment_id)
			state.aggregate.sickness_count += 1
			_record_event(state, "sickness_started", end_unix, end_text, {"ailment_id": ailment_id, "reason": state.sickness.reason})
			events.append("sickness_started")
			summary.sickness_started = true
			return


func _update_attention_calls(state: Dictionary, now_unix: int, now_text: String, profile: Dictionary, events: Array, summary: Dictionary) -> void:
	var conditions := {
		"hungry": int(state.care.satiety_bps) < int(profile.get("hunger_call_threshold_bps", 0)),
		"bedtime": not bool(state.sleeping) and int(state.care.energy_bps) < int(profile.get("tired_call_threshold_bps", 0)),
		"hygiene": not state.waste.is_empty() or int(state.care.hygiene_bps) < int(profile.get("hygiene_call_threshold_bps", 0)),
		"sickness": not state.sickness.is_empty()
	}
	for call in state.attention_calls:
		if call.status == "open" and int(call.deadline_unix) <= now_unix:
			if bool(conditions.get(str(call.reason), false)):
				call.status = "missed"
				call.caused_care_mistake = true
				call.resolved_at_utc = now_text
				state.aggregate.care_mistakes += 1
				summary.mistakes += 1
				summary.calls_missed += 1
				_record_event(state, "care_mistake", now_unix, now_text, {"call_id": call.call_id, "reason": call.reason})
				events.append("care_mistake")
			elif not bool(conditions.get(str(call.reason), false)):
				call.status = "resolved"
				call.resolved_at_utc = now_text
				state.aggregate.resolved_calls += 1
				_record_event(state, "call_resolved", now_unix, now_text, {"call_id": call.call_id, "reason": call.reason})
				events.append("call_resolved")
	for reason in conditions:
		if not conditions[reason] or _has_open_call(state, reason):
			continue
		var call_id := "call-%d" % int(state.aggregate.call_sequence)
		state.aggregate.call_sequence += 1
		var call_deadline := now_unix + int(profile.get("call_response_seconds", 1))
		var call := {"call_id": call_id, "reason": reason, "opened_at_utc": now_text, "opened_at_unix": now_unix, "deadline_unix": call_deadline, "deadline_utc": _utc_text(call_deadline), "status": "open", "resolved_at_utc": "", "caused_care_mistake": false}
		state.attention_calls.append(call)
		if state.attention_calls.size() > MAX_CALLS:
			state.attention_calls.pop_front()
		state.aggregate.call_count += 1
		_record_event(state, "call_opened", now_unix, now_text, {"call_id": call_id, "reason": reason})
		events.append("call_opened")


func _apply_food(state: Dictionary, command: Dictionary, now_unix: int, now_text: String, catalog: Dictionary, events: Array, summary: Dictionary) -> void:
	var item_id := str(command.get("item_id", ""))
	var item: Dictionary = _definition(catalog, item_id)
	var use: Dictionary = item.get("use", {})
	if item.is_empty() or use.is_empty() or str(use.get("kind", "")) not in ["meal", "treat"]:
		return
	var kind := str(use.kind)
	var profile: Dictionary = _definition(catalog, state.care_profile_id)
	var satiety := int(use.get("satiety_bps", profile.get("meal_satiety_bps", 0) if kind == "meal" else profile.get("treat_satiety_bps", 0)))
	var mood := int(use.get("mood_bps", profile.get("meal_mood_bps", 0) if kind == "meal" else profile.get("treat_mood_bps", 0)))
	var weight := int(use.get("weight_grams", profile.get("meal_weight_grams", 0) if kind == "meal" else profile.get("treat_weight_grams", 0)))
	var before := int(state.care.satiety_bps)
	var fullness_cap := int(profile.get("fullness_cap_bps", BASIS_POINTS))
	var overfed := before + satiety > fullness_cap
	state.care.satiety_bps = mini(fullness_cap, before + satiety)
	state.care.mood_bps = _cap(int(state.care.mood_bps) + mood - (500 if overfed else 0))
	state.care.weight_grams = mini(MAX_WEIGHT_GRAMS, int(state.care.weight_grams) + weight)
	state.care.last_feed_unix = now_unix
	state.pending_digestion.append({"due_unix": now_unix + int(profile.get("digestion_seconds", 1)), "item_id": item_id})
	state.aggregate.feed_count += 1 if kind == "meal" else 0
	state.aggregate.treat_count += 1 if kind == "treat" else 0
	_record_event(state, "treat" if kind == "treat" else "fed", now_unix, now_text, {"item_id": item_id, "overfed": overfed})
	events.append("treat" if kind == "treat" else "fed")
	if overfed:
		state.aggregate.overfeed_count += 1
		_record_event(state, "overfed", now_unix, now_text, {"item_id": item_id})
		events.append("overfed")
	_update_attention_calls(state, now_unix, now_text, profile, events, summary)


func _apply_clean(state: Dictionary, now_unix: int, now_text: String, events: Array) -> void:
	var count: int = state.waste.size()
	state.waste.clear()
	state.care.hygiene_bps = _cap(int(state.care.hygiene_bps) + 6000)
	state.care.dirty_seconds = 0
	state.aggregate.waste_cleaned += count
	state.aggregate.clean_count += 1
	_record_event(state, "cleaned", now_unix, now_text, {"waste_units": count})
	events.append("cleaned")


func _apply_sleep(state: Dictionary, now_unix: int, now_text: String, events: Array) -> void:
	if bool(state.sleeping):
		return
	state.sleeping = true
	state.care.last_sleep_start_unix = now_unix
	_record_event(state, "sleep_started", now_unix, now_text, {})
	events.append("sleep_started")


func _apply_wake(state: Dictionary, now_unix: int, now_text: String, events: Array) -> void:
	if not bool(state.sleeping):
		return
	state.sleeping = false
	state.care.last_wake_unix = now_unix
	_record_event(state, "woke", now_unix, now_text, {})
	events.append("woke")


func _apply_medicine(state: Dictionary, command: Dictionary, now_unix: int, now_text: String, catalog: Dictionary, events: Array) -> void:
	var item_id := str(command.get("item_id", ""))
	var item: Dictionary = _definition(catalog, item_id)
	var use: Dictionary = item.get("use", {})
	if item.is_empty() or str(use.get("kind", "")) != "medicine" or state.sickness.is_empty():
		return
	state.care.health_bps = _cap(int(state.care.health_bps) + int(use.get("health_bps", 0)))
	state.sickness = {}
	state.aggregate.treatment_count += 1
	if item_id not in state.required_content_ids:
		state.required_content_ids.append(item_id)
	_record_event(state, "medicine", now_unix, now_text, {"item_id": item_id})
	_record_event(state, "recovered", now_unix, now_text, {})
	events.append("medicine")
	events.append("recovered")


func _apply_training(state: Dictionary, command: Dictionary, now_unix: int, now_text: String, catalog: Dictionary, events: Array) -> void:
	var activity_id := str(command.get("activity_id", _first_definition_id(catalog, "training-activity")))
	var activity: Dictionary = _definition(catalog, activity_id)
	if activity.is_empty() or bool(state.sleeping):
		return
	var data: Dictionary = activity
	var cost: int = int(data.get("energy_cost_bps", 0))
	if int(state.care.energy_bps) < cost:
		return
	var input_bps: int = clampi(int(command.get("input_bps", data.get("target_bps", 0))), 0, BASIS_POINTS)
	var distance: int = abs(input_bps - int(data.get("target_bps", 0)))
	var excellent: bool = distance <= int(data.get("excellent_window_bps", 0))
	var good: bool = distance <= int(data.get("good_window_bps", 0))
	var grade: String = "excellent" if excellent else "good" if good else "miss"
	state.care.energy_bps = _floor_zero(int(state.care.energy_bps) - cost)
	var effort_gain := int(data.get("effort_gain_bps", 0)) if grade == "good" else int(data.get("effort_gain_bps", 0)) * 2 if grade == "excellent" else 0
	state.care.effort_bps = _cap(int(state.care.effort_bps) + effort_gain)
	state.care.mood_bps = _cap(int(state.care.mood_bps) + int(data.get("mood_gain_bps", 0)) if grade != "miss" else _floor_zero(int(state.care.mood_bps) - 150))
	state.aggregate.training_count += 1
	state.aggregate.training_outcomes[grade] = int(state.aggregate.training_outcomes.get(grade, 0)) + 1
	_record_event(state, "training", now_unix, now_text, {"activity_id": activity_id, "grade": grade, "input_bps": input_bps})
	events.append("training")


func _apply_call_resolution(state: Dictionary, command: Dictionary, now_unix: int, now_text: String, events: Array) -> void:
	var call_id := str(command.get("call_id", ""))
	for call in state.attention_calls:
		if str(call.call_id) == call_id and str(call.status) == "open":
			call.status = "resolved"
			call.resolved_at_utc = now_text
			state.aggregate.resolved_calls += 1
			_record_event(state, "call_resolved", now_unix, now_text, {"call_id": call_id, "reason": call.reason})
			events.append("call_resolved")
			return


func _force_sickness(state: Dictionary, now_unix: int, now_text: String, catalog: Dictionary, events: Array) -> void:
	if not state.sickness.is_empty():
		return
	var ailment_id := _first_definition_id(catalog, "ailment")
	if ailment_id.is_empty():
		return
	state.sickness = {"ailment_id": ailment_id, "started_at_unix": now_unix, "reason": "development_control", "diagnostic": "forced"}
	state.aggregate.sickness_count += 1
	if ailment_id not in state.required_content_ids:
		state.required_content_ids.append(ailment_id)
	_record_event(state, "sickness_started", now_unix, now_text, {"ailment_id": ailment_id, "reason": "development_control"})
	events.append("sickness_started")


func _initial_aggregate() -> Dictionary:
	return {"feed_count": 0, "treat_count": 0, "overfeed_count": 0, "training_count": 0, "training_outcomes": {"miss": 0, "good": 0, "excellent": 0}, "waste_generated": 0, "waste_cleaned": 0, "clean_count": 0, "sleep_seconds": 0, "awake_seconds": 0, "sleep_disturbances": 0, "sickness_count": 0, "treatment_count": 0, "care_mistakes": 0, "resolved_calls": 0, "call_count": 0, "call_sequence": 1, "dirty_seconds": 0, "severe_hunger_seconds": 0, "last_accepted_simulation_seconds": 0}


func _record_event(state: Dictionary, event_type: String, timestamp_unix: int, timestamp_text: String, payload: Dictionary) -> void:
	var sequence := int(state.aggregate.get("event_sequence", 0)) + 1
	state.aggregate.event_sequence = sequence
	state.history.append({"sequence": sequence, "type": event_type, "timestamp_utc": timestamp_text, "timestamp_unix": timestamp_unix, "payload": payload.duplicate(true)})
	if state.history.size() > MAX_HISTORY:
		state.history.pop_front()


func _has_open_call(state: Dictionary, reason: String) -> bool:
	for call in state.attention_calls:
		if str(call.reason) == reason and str(call.status) == "open":
			return true
	return false


func _definition(catalog: Dictionary, content_id: String) -> Dictionary:
	var record: Dictionary = catalog.get(content_id, {})
	if record.has("data") and record.data is Dictionary:
		return record.data
	return record


func _first_definition_id(catalog: Dictionary, kind: String) -> String:
	var ids: Array = []
	for content_id in catalog:
		var record: Dictionary = catalog[content_id]
		if str(record.get("schema_name", "")).trim_suffix(".schema.json") == kind or str(record.get("kind", "")) == kind:
			ids.append(str(content_id))
	ids.sort()
	return ids[0] if not ids.is_empty() else ""


func _next_random(state: Dictionary) -> int:
	var value := int(state.get("random_state", 1))
	value = int((value * 1103515245 + 12345) & 0x7fffffff)
	state.random_state = value
	return value


func _cap(value: int) -> int:
	return clampi(value, 0, BASIS_POINTS)


func _floor_zero(value: int) -> int:
	return maxi(0, value)


func _utc_text(unix_seconds: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_seconds, false) + "Z"


func _command_success(state: Dictionary, events: Array) -> Dictionary:
	state.revision = int(state.get("revision", 0)) + 1
	return {"ok": true, "state": state, "summary": {"accepted_seconds": 0, "events": events, "mistakes": 0, "waste_generated": 0, "calls_missed": 0, "sickness_started": false, "hatched": false}}


func _failure(code: String, reason: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason}
