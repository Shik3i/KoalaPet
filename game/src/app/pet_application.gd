class_name PetApplication
extends RefCounted

var foundation: FoundationBootstrap
var simulation := PetSimulation.new()
var catalog: Dictionary = {}
var pet_state: Dictionary = {}
var last_offline_result: Dictionary = {}
var last_command_result: Dictionary = {}
var initialized := false
var evolution_resolver := EvolutionResolver.new()
var battle_service := BattleService.new()
var dungeon_service := DungeonService.new()


func _init(config: Dictionary = {}, injected_clock: SimulationClock = null) -> void:
	foundation = FoundationBootstrap.new(config, injected_clock)


func initialize() -> Dictionary:
	var result := foundation.initialize()
	if not result.ok:
		return result
	_refresh_catalog()
	var records: Array = foundation.current_save.simulation_state.get("records", [])
	if not records.is_empty() and records[0] is Dictionary:
		var shape_error := _pet_record_shape_error(records[0])
		if not shape_error.is_empty():
			return _failure("INVALID_PET_RECORD", "Active pet record has invalid field: %s" % shape_error).merged({"stage": "pet_record_validation"})
		pet_state = _normalize_pet_state(records[0])
		var sync_result := _sync_now()
		if not sync_result.get("ok", false):
			return sync_result.merged({"stage": "offline_sync"})
	else:
		pet_state = {}
	initialized = true
	_refresh_progression()
	return result.merged({"pet_ready": not pet_state.is_empty(), "starter_count": get_starter_eggs().size()})


func get_starter_eggs() -> Array[Dictionary]:
	var pool := _first_document("starter-pool")
	var result: Array[Dictionary] = []
	if pool.is_empty():
		return result
	for egg_id in pool.data.get("egg_ids", []):
		var egg := _record(str(egg_id))
		if not egg.is_empty():
			result.append(egg)
	return result


func choose_starter(egg_id: String) -> Dictionary:
	if not initialized:
		return _failure("APP_NOT_READY", "Pet application is not initialized")
	if not pet_state.is_empty():
		return _failure("PET_ALREADY_EXISTS", "A single-pet save already exists")
	var egg := _record(egg_id)
	if egg.is_empty() or egg.schema_name != "egg.schema.json":
		return _failure("INVALID_STARTER", "The selected starter egg is unavailable")
	var egg_data: Dictionary = egg.data
	var form := _record(str(egg_data.get("hatch_form_id", "")))
	var form_data: Dictionary = form.get("data", {})
	var profile_id := str(form_data.get("care_profile_id", ""))
	if profile_id.is_empty():
		profile_id = str(_first_document("care-profile").get("id", ""))
	var profile := _record(profile_id)
	if form.is_empty() or profile.is_empty():
		return _failure("STARTER_BINDING_MISSING", "Starter references are unavailable")
	var now_unix := foundation.clock.utc_now_unix_seconds()
	var now_text := foundation.clock.utc_now_text()
	var transaction := _snapshot_transaction()
	pet_state = simulation.create_new(egg, form, profile, str(egg.owner_pack_id), now_unix, now_text, _stable_seed(egg_id))
	var save_result := _write_save()
	if not save_result.ok:
		_restore_transaction(transaction)
		return save_result
	return {"ok": true, "state": pet_state.duplicate(true), "summary": {"event": "egg_selected"}}


func complete_hatch() -> Dictionary:
	return command({"type": "complete_hatch"})


func command(command_data: Dictionary) -> Dictionary:
	if pet_state.is_empty():
		return _failure("NO_PET", "Select a starter egg first")
	var sync_result := _sync_now()
	if not sync_result.get("ok", false):
		return sync_result
	var transaction := _snapshot_transaction()
	var now_unix := foundation.clock.utc_now_unix_seconds()
	var now_text := foundation.clock.utc_now_text()
	var command_type := str(command_data.get("type", ""))
	if command_type in ["start_battle", "battle_stance", "battle_round", "battle_resolve", "treat_injury"] and not is_feature_unlocked("koalapet.base:battle"):
		return _failure("FEATURE_LOCKED", "Battle is not unlocked yet")
	if command_type in ["start_dungeon", "dungeon_next", "dungeon_choice", "dungeon_abandon"] and not is_feature_unlocked("koalapet.base:dungeon"):
		return _failure("FEATURE_LOCKED", "The dungeon is not unlocked yet")
	var adventure_time := _safe_nonnegative_int(command_data.get("adventure_seconds", 0))
	if adventure_time > 0:
		var adventure_result := _advance_internal(adventure_time, false)
		if not adventure_result.get("ok", false):
			_restore_transaction(transaction)
			return adventure_result
	match command_type:
		"start_battle":
			last_command_result = battle_service.start(pet_state, str(command_data.get("encounter_id", "")), catalog, now_unix, now_text, str(command_data.get("stance", "balanced")))
		"battle_stance":
			last_command_result = battle_service.set_stance(pet_state, str(command_data.get("stance", "balanced")))
		"battle_round":
			last_command_result = battle_service.advance_round(pet_state, catalog, now_unix, now_text)
		"battle_resolve":
			last_command_result = battle_service.resolve(pet_state, catalog, str(command_data.get("outcome", "draw")), now_unix, now_text)
		"treat_injury":
			last_command_result = battle_service.treat_injury(pet_state, catalog, now_unix, now_text, str(command_data.get("item_id", find_item_by_kind("injury_treatment"))))
		"start_dungeon":
			last_command_result = dungeon_service.start(pet_state, str(command_data.get("dungeon_id", "")), catalog, now_unix, now_text)
		"dungeon_next":
			last_command_result = dungeon_service.resolve_current_node(pet_state, catalog, now_unix, now_text)
		"dungeon_choice":
			last_command_result = dungeon_service.choose_event(pet_state, catalog, str(command_data.get("choice_id", "")), now_unix, now_text)
		"dungeon_abandon":
			last_command_result = dungeon_service.abandon(pet_state, now_unix, now_text)
		"force_evolution":
			last_command_result = _force_evolution(str(command_data.get("rule_id", "")), now_unix, now_text)
		"resolve_pending_evolution":
			last_command_result = _apply_evolution(now_unix, now_text)
		_:
			last_command_result = simulation.apply_command(pet_state, command_data, now_unix, now_text, catalog)
	if not last_command_result.ok:
		var failed_result := last_command_result.duplicate(true)
		_restore_transaction(transaction)
		return failed_result
	pet_state = last_command_result.state
	var dungeon_post := dungeon_service.after_battle(pet_state, catalog, now_unix, now_text)
	if dungeon_post.ok and bool(dungeon_post.get("changed", true)) and not dungeon_post.get("state", {}).is_empty():
		pet_state = dungeon_post.state
		last_command_result.summary["dungeon_follow_up"] = dungeon_post.summary
	var evolution := _apply_evolution(now_unix, now_text)
	if evolution.ok:
		pet_state = evolution.state
		if evolution.get("changed", false):
			last_command_result.summary["evolution"] = evolution.record
	_refresh_progression()
	var save_result := _write_save()
	if not save_result.ok:
		_restore_transaction(transaction)
		return save_result
	return last_command_result


func advance_simulated(seconds: int) -> Dictionary:
	if pet_state.is_empty():
		return _failure("NO_PET", "Select a starter egg first")
	var transaction := _snapshot_transaction()
	var result := _advance_internal(maxi(0, seconds), true)
	if result.ok:
		var evolution := _apply_evolution(int(pet_state.get("current_simulation_unix", 0)), str(pet_state.get("current_simulation_utc", "")))
		if evolution.ok:
			pet_state = evolution.state
			if evolution.get("changed", false):
				result.summary["evolution"] = evolution.record
		_refresh_progression()
		var save_result := _write_save()
		if not save_result.ok:
			_restore_transaction(transaction)
			return save_result
	return result


func save() -> Dictionary:
	return _write_save()


func has_pet() -> bool:
	return not pet_state.is_empty()


func is_hatched() -> bool:
	return bool(pet_state.get("hatched", false))


func get_current_state() -> Dictionary:
	return pet_state.duplicate(true)


func get_quarantine_count() -> int:
	return foundation.current_save.get("quarantined_records", []).size()


func get_display_name(content_id: String, locale := "de") -> String:
	var record := _record(content_id)
	if record.is_empty():
		return content_id
	var key := str(record.data.get("display_name_key", content_id))
	var value: Variant = foundation.content_registry.get_localization_value(locale, key)
	return str(value) if value != null else key


func text(key: String, fallback := "", locale := "de") -> String:
	var value: Variant = foundation.content_registry.get_localization_value(locale, key)
	return str(value) if value != null else fallback


func find_item_by_kind(kind: String) -> String:
	for record in catalog.values():
		if record.get("schema_name", "") != "item.schema.json":
			continue
		if str(record.data.get("use", {}).get("kind", "")) == kind:
			return str(record.id)
	return ""


func get_training_activity_id() -> String:
	return str(_first_document("training-activity").get("id", ""))


func is_feature_unlocked(feature_id: String) -> bool:
	if foundation == null or foundation.feature_gate_service == null:
		return false
	var gate_id := _gate_for_feature(feature_id)
	if gate_id.is_empty():
		return false
	var ledger := UnlockLedger.new(foundation.current_save.get("feature_gate_state", {}).get("unlock_ledger", {}))
	if ledger.has_reward(feature_id):
		return true
	return bool(foundation.feature_gate_service.evaluate_gate(gate_id, ProgressionFacts.new(_progression_facts())).get("passed", false))


func get_evolution_evaluation() -> Dictionary:
	return evolution_resolver.evaluate(pet_state, catalog) if not pet_state.is_empty() else {}


func get_encounters() -> Array[Dictionary]:
	return _documents_of_kind("enemy-encounter")


func get_dungeons() -> Array[Dictionary]:
	return _documents_of_kind("dungeon")


func get_asset_path_for_content(content_id: String, animation_name := "idle") -> String:
	return str(get_animation_descriptor(animation_name, content_id).get("path", ""))


func get_animation_descriptor(animation_name := "idle", content_id := "", egg := false) -> Dictionary:
	var animation_id := ""
	if not content_id.is_empty():
		var content_record := _record(content_id)
		animation_id = str(content_record.get("data", {}).get("animation_profile_id", ""))
	else:
		animation_id = str(pet_state.get("animation_profile_id", ""))
		if egg and not pet_state.is_empty():
			var egg_record := _record(str(pet_state.get("egg_definition_id", "")))
			animation_id = str(egg_record.get("data", {}).get("animation_profile_id", animation_id))
	var animation := _record(animation_id)
	if animation.is_empty():
		return {}
	var animations: Dictionary = animation.get("data", {}).get("world_animations", {})
	var entry: Dictionary = animations.get(animation_name, animations.get("idle", {})).duplicate(true)
	var relative_asset := str(entry.get("asset", ""))
	if relative_asset.is_empty():
		return {}
	entry["path"] = str(animation.get("pack_root", "")).path_join(relative_asset.trim_prefix("res://"))
	entry["animation_name"] = animation_name if animations.has(animation_name) else "idle"
	entry["profile_id"] = animation_id
	return entry


func get_animation_descriptors(content_id := "", egg := false) -> Dictionary:
	var animation_id := ""
	if not content_id.is_empty():
		animation_id = str(_record(content_id).get("data", {}).get("animation_profile_id", ""))
	else:
		animation_id = str(pet_state.get("animation_profile_id", ""))
		if egg and not pet_state.is_empty():
			animation_id = str(_record(str(pet_state.get("egg_definition_id", ""))).get("data", {}).get("animation_profile_id", animation_id))
	var profile := _record(animation_id)
	var result := {}
	for animation_name in profile.get("data", {}).get("world_animations", {}):
		result[animation_name] = get_animation_descriptor(str(animation_name), content_id, egg)
	return result


func get_animation_review_entries(locale := "en") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in ["egg", "form", "enemy-encounter"]:
		for record in _documents_of_kind(kind):
			var content_id := str(record.get("id", ""))
			var animation_profile_id := str(record.get("data", {}).get("animation_profile_id", ""))
			if content_id.is_empty() or animation_profile_id.is_empty():
				continue
			var descriptors := get_animation_descriptors(content_id, kind == "egg")
			if descriptors.is_empty():
				continue
			result.append({
				"content_id": content_id,
				"display_name": get_display_name(content_id, locale),
				"kind": "enemy" if kind == "enemy-encounter" else kind,
				"animation_profile_id": animation_profile_id,
				"family_id": str(record.get("data", {}).get("family_id", "")),
				"animations": descriptors,
			})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := "%s|%s" % [str(left.get("kind", "")), str(left.get("content_id", ""))]
		var right_key := "%s|%s" % [str(right.get("kind", "")), str(right.get("content_id", ""))]
		return left_key < right_key
	)
	return result


func get_active_family_id() -> String:
	if pet_state.is_empty():
		return ""
	var form := _record(str(pet_state.get("current_form_id", pet_state.get("definition_id", ""))))
	return str(form.get("data", {}).get("family_id", ""))


func get_move_presentation(move_id: String) -> Dictionary:
	var move: Dictionary = _record(move_id).get("data", {})
	var tags: Array = move.get("tags", []) if move.get("tags", []) is Array else []
	return {"id": move_id, "tags": tags.duplicate(true)} if not move.is_empty() else {}


func get_encounter_presentation(encounter_id: String, locale := "de") -> Dictionary:
	var record := _record(encounter_id)
	if record.is_empty():
		return {}
	var data: Dictionary = record.get("data", {})
	return {
		"id": encounter_id,
		"name": get_display_name(encounter_id, locale),
		"description": text(str(data.get("description_key", "")), "", locale),
		"level": int(data.get("level", 1)),
		"animation": get_animation_descriptor("idle", encounter_id),
	}


func get_dungeon_presentation(dungeon_id: String, locale := "de") -> Dictionary:
	var record := _record(dungeon_id)
	if record.is_empty():
		return {}
	var data: Dictionary = record.get("data", {})
	var nodes: Array[Dictionary] = []
	for source_node in data.get("nodes", []):
		var node: Dictionary = source_node.duplicate(true)
		var choices: Array[Dictionary] = []
		for source_choice in node.get("choices", []):
			var choice: Dictionary = source_choice.duplicate(true)
			choice["name"] = text(str(choice.get("display_name_key", "")), str(choice.get("id", "")), locale)
			choices.append(choice)
		node["choices"] = choices
		nodes.append(node)
	return {
		"id": dungeon_id,
		"name": get_display_name(dungeon_id, locale),
		"description": text(str(data.get("description_key", "")), "", locale),
		"nodes": nodes,
		"boss_encounter_id": str(data.get("boss_encounter_id", "")),
	}


func get_asset_path(animation_name := "idle", egg := false) -> String:
	return str(get_animation_descriptor(animation_name, "", egg).get("path", ""))


func get_preview_asset_path(content_id: String) -> String:
	var record := _record(content_id)
	if record.is_empty():
		return ""
	var animation_id := str(record.data.get("animation_profile_id", ""))
	var animation := _record(animation_id)
	if animation.is_empty():
		return ""
	return str(animation.get("pack_root", "")).path_join(str(animation.data.get("preview", "")).trim_prefix("res://"))


func get_view_model(mode := "small", locale := "de") -> Dictionary:
	if pet_state.is_empty():
		return {"screen": "starter", "mode": mode, "starter_count": get_starter_eggs().size()}
	var form_id := str(pet_state.get("current_form_id", pet_state.get("definition_id", "")))
	var form_name := get_display_name(form_id, locale)
	var care: Dictionary = pet_state.get("care", {})
	var open_calls: Array = []
	for call in pet_state.get("attention_calls", []):
		if str(call.get("status", "")) == "open":
			open_calls.append(call.duplicate(true))
	var model := {
		"screen": "egg" if not is_hatched() else "pet",
		"mode": mode,
		"name": str(pet_state.get("nickname", "")) if not str(pet_state.get("nickname", "")).is_empty() else form_name,
		"form_name": form_name,
		"hatched": is_hatched(),
		"hatch_due_unix": int(pet_state.get("hatch_due_unix", 0)),
		"hatch_progress_bps": _hatch_progress_bps(),
		"current_simulation_unix": int(pet_state.get("current_simulation_unix", 0)),
		"sleeping": bool(pet_state.get("sleeping", false)),
		"sickness": not pet_state.get("sickness", {}).is_empty(),
		"open_calls": open_calls,
		"care": care.duplicate(true),
		"aggregate": pet_state.get("aggregate", {}).duplicate(true),
		"history": pet_state.get("history", []).duplicate(true),
		"offline": last_offline_result.duplicate(true),
		"form_id": form_id,
		"family_id": get_active_family_id(),
		"egg_id": str(pet_state.get("egg_definition_id", "")),
		"state_revision": int(pet_state.get("revision", 0)),
		"stage": str(pet_state.get("stage", "hatchling")),
		"level": int(pet_state.get("level", 1)),
		"experience": int(pet_state.get("experience", 0)),
		"experience_next": _next_level_experience(),
		"pending_evolution": pet_state.get("pending_evolution", {}).duplicate(true),
		"evolution": get_evolution_evaluation(),
		"active_battle": pet_state.get("active_battle", {}).duplicate(true),
		"last_battle_result": pet_state.get("last_battle_result", {}).duplicate(true),
		"battle_history": pet_state.get("battle_history_summary", {}).duplicate(true),
		"injury": pet_state.get("injury", {}).duplicate(true),
		"active_dungeon_run": pet_state.get("active_dungeon_run", {}).duplicate(true),
		"dungeon_history": pet_state.get("dungeon_history", []).duplicate(true),
		"inventory": pet_state.get("inventory", {}).duplicate(true),
		"unlock_ids": pet_state.get("unlock_ids", []).duplicate(true),
		"discovered_forms": pet_state.get("discovered_forms", []).duplicate(true),
		"codex": pet_state.get("codex", {}).duplicate(true),
		"battle_unlocked": is_feature_unlocked("koalapet.base:battle"),
		"dungeon_unlocked": is_feature_unlocked("koalapet.base:dungeon"),
	}
	if mode == "minimal":
		return {"screen": model.screen, "mode": mode, "name": model.name, "hatched": model.hatched, "sleeping": model.sleeping, "sickness": model.sickness, "open_calls": model.open_calls, "hatch_progress_bps": model.hatch_progress_bps, "offline": model.offline, "active_battle": model.active_battle, "active_dungeon_run": model.active_dungeon_run, "injury": model.injury, "pending_evolution": model.pending_evolution, "last_battle_result": model.last_battle_result, "state_revision": model.state_revision, "form_id": model.form_id, "family_id": model.family_id, "egg_id": model.egg_id}
	if mode == "small":
		return {"screen": model.screen, "mode": mode, "name": model.name, "form_name": model.form_name, "hatched": model.hatched, "stage": model.stage, "level": model.level, "experience": model.experience, "experience_next": model.experience_next, "sleeping": model.sleeping, "sickness": model.sickness, "open_calls": model.open_calls, "hatch_progress_bps": model.hatch_progress_bps, "offline": model.offline, "aggregate": model.aggregate, "care": {"satiety_bps": care.get("satiety_bps", 0), "mood_bps": care.get("mood_bps", 0), "energy_bps": care.get("energy_bps", 0), "hygiene_bps": care.get("hygiene_bps", 0), "health_bps": care.get("health_bps", 0), "discipline_bps": care.get("discipline_bps", 0), "effort_bps": care.get("effort_bps", 0), "weight_grams": care.get("weight_grams", 0), "waste_count": pet_state.get("waste", []).size()}, "battle_unlocked": model.battle_unlocked, "dungeon_unlocked": model.dungeon_unlocked, "active_battle": model.active_battle, "active_dungeon_run": model.active_dungeon_run, "injury": model.injury, "pending_evolution": model.pending_evolution, "last_battle_result": model.last_battle_result, "state_revision": model.state_revision, "form_id": model.form_id, "family_id": model.family_id, "egg_id": model.egg_id}
	return model


func _hatch_progress_bps() -> int:
	if bool(pet_state.get("hatched", false)):
		return 10000
	var profile := _record(str(pet_state.get("care_profile_id", "")))
	var duration := int(profile.get("data", {}).get("hatch_duration_seconds", 0))
	if duration <= 0:
		return 0
	var started := int(pet_state.get("selected_at_unix", pet_state.get("current_simulation_unix", 0)))
	var elapsed := maxi(0, int(pet_state.get("current_simulation_unix", started)) - started)
	return clampi(int(float(elapsed) * 10000.0 / float(duration)), 0, 10000)


func _sync_now() -> Dictionary:
	if pet_state.is_empty():
		return {"ok": true, "changed": false}
	var transaction := _snapshot_transaction()
	var now_unix := foundation.clock.utc_now_unix_seconds()
	var now_text := foundation.clock.utc_now_text()
	var profile := _record(str(pet_state.get("care_profile_id", "")))
	var cap := int(profile.get("data", {}).get("offline_cap_seconds", 7 * 24 * 60 * 60))
	var policy := OfflineProgressPolicy.new(cap)
	last_offline_result = policy.evaluate(str(pet_state.get("current_simulation_utc", "")), now_text)
	var accepted := int(last_offline_result.get("accepted_simulation_seconds", 0))
	if accepted == 0:
		return {"ok": true, "changed": false}
	var result := simulation.advance(pet_state, accepted, now_unix, now_text, catalog)
	if not result.get("ok", false):
		_restore_transaction(transaction)
		return result
	pet_state = result.state
	pet_state.aggregate.offline_stage_seconds = int(pet_state.aggregate.get("offline_stage_seconds", 0)) + accepted
	var recovery := battle_service.recover_injury(pet_state, accepted, now_unix, now_text)
	if recovery.ok:
		pet_state = recovery.state
	var evolution := _apply_evolution(now_unix, now_text)
	if evolution.ok:
		pet_state = evolution.state
	_refresh_progression()
	var save_result := _write_save()
	if not save_result.get("ok", false):
		_restore_transaction(transaction)
		return save_result
	return {"ok": true, "changed": true, "accepted_seconds": accepted}


func _advance_internal(seconds: int, offline: bool) -> Dictionary:
	var accepted := maxi(0, seconds)
	var start_unix := int(pet_state.get("current_simulation_unix", foundation.clock.utc_now_unix_seconds()))
	var end_unix := start_unix + accepted
	var end_text := Time.get_datetime_string_from_unix_time(end_unix, false) + "Z"
	var result := simulation.advance(pet_state, accepted, end_unix, end_text, catalog)
	if not result.ok:
		return result
	pet_state = result.state
	if offline:
		pet_state.aggregate.offline_stage_seconds = int(pet_state.aggregate.get("offline_stage_seconds", 0)) + accepted
	var recovery := battle_service.recover_injury(pet_state, accepted, end_unix, end_text)
	if recovery.ok:
		pet_state = recovery.state
	result.state = pet_state
	return result


func _apply_evolution(now_unix: int, now_text: String) -> Dictionary:
	if pet_state.is_empty() or not bool(pet_state.get("hatched", false)):
		return {"ok": true, "changed": false, "state": pet_state}
	var result := evolution_resolver.apply_at_safe_point(pet_state, catalog, now_unix, now_text, str(foundation.content_snapshot.get("snapshot_fingerprint", "")))
	return result


func _force_evolution(rule_id: String, now_unix: int, now_text: String) -> Dictionary:
	var evaluation := evolution_resolver.evaluate(pet_state, catalog)
	if not bool(evaluation.get("eligible", false)):
		return {"ok": false, "error_code": "EVOLUTION_NOT_ELIGIBLE", "reason": "No evolution rule is currently eligible", "evaluation": evaluation}
	if not rule_id.is_empty() and str(evaluation.get("selected", {}).get("rule_id", "")) != rule_id:
		for candidate in evaluation.get("candidates", []):
			if str(candidate.get("rule_id", "")) == rule_id:
				evaluation.selected = candidate
				break
	var result := evolution_resolver.apply_at_safe_point(pet_state, catalog, now_unix, now_text, str(foundation.content_snapshot.get("snapshot_fingerprint", "")), rule_id)
	return result


func _refresh_progression() -> void:
	if foundation == null or foundation.feature_gate_service == null or foundation.current_save.is_empty():
		return
	var facts := ProgressionFacts.new(_progression_facts())
	var ledger := UnlockLedger.new(foundation.current_save.get("feature_gate_state", {}).get("unlock_ledger", {}))
	for gate in catalog.values():
		if str(gate.get("schema_name", "")) != "feature-gate.schema.json":
			continue
		foundation.feature_gate_service.evaluate_and_grant(str(gate.id), facts, ledger)
	foundation.current_save.feature_gate_state.unlock_ledger = ledger.snapshot()
	foundation.current_save.progression_state.facts = facts.snapshot()


func _progression_facts() -> Dictionary:
	var battle: Dictionary = pet_state.get("battle_history_summary", {})
	return {
		"hatched": bool(pet_state.get("hatched", false)),
		"training_count": int(pet_state.get("aggregate", {}).get("training_count", 0)),
		"battle_count": int(battle.get("battle_count", 0)),
		"battle_wins": int(battle.get("wins", 0)),
		"battle_losses": int(battle.get("losses", 0)),
		"dungeon_clears": pet_state.get("dungeon_flags", []).duplicate(true),
		"boss_flags": pet_state.get("boss_flags", []).duplicate(true),
		"milestone_count": 1 if bool(pet_state.get("hatched", false)) else 0,
		"unlocked_ids": pet_state.get("unlock_ids", []).duplicate(true),
	}


func _gate_for_feature(feature_id: String) -> String:
	for record in catalog.values():
		if str(record.get("schema_name", "")) == "feature-gate.schema.json" and str(record.data.get("feature", "")) == feature_id:
			return str(record.id)
	return ""


func _next_level_experience() -> int:
	var balance := _first_document("progression-balance")
	var thresholds: Array = balance.get("data", {}).get("level_thresholds", [0, 30, 75, 140, 230, 360])
	var level := int(pet_state.get("level", 1))
	return int(thresholds[level]) if level >= 0 and level < thresholds.size() else int(pet_state.get("experience", 0))


func _documents_of_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in catalog.values():
		if str(record.get("schema_name", "")).trim_suffix(".schema.json") == kind:
			result.append(record.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return result


func _normalize_pet_state(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	var defaults := {"pet_state_version": 2, "stage": "hatchling", "traits": [], "stage_started_at_unix": int(raw.get("hatched_at_unix", raw.get("selected_at_unix", 0))), "stage_started_at_utc": str(raw.get("hatched_at_utc", raw.get("selected_at_utc", ""))), "evolution_history": [], "pending_evolution": {}, "discovered_forms": [str(raw.get("current_form_id", raw.get("definition_id", "")))], "discovered_routes": [], "battle_history_summary": {"battle_count": 0, "wins": 0, "losses": 0, "draws": 0, "current_win_streak": 0, "longest_win_streak": 0, "defeated_encounters": [], "opponent_history": []}, "experience": 0, "level": 1, "active_battle": {}, "last_battle_result": {}, "injury": {}, "inventory": {}, "used_item_ids": [], "reward_grants": {}, "unlock_ids": [], "dungeon_flags": [], "boss_flags": [], "dungeon_history": [], "active_dungeon_run": {}, "codex": {"forms": [str(raw.get("current_form_id", raw.get("definition_id", "")))], "encounters": [], "defeated_encounters": [], "dungeons": [], "bosses": []}}
	for key in defaults:
		if not result.has(key):
			result[key] = defaults[key]
	var aggregate_defaults := {"training_outcomes": {"miss": 0, "good": 0, "excellent": 0}, "event_sequence": 0, "active_stage_seconds": 0, "offline_stage_seconds": 0, "stage_seconds": 0}
	var aggregate: Dictionary = result.get("aggregate", {})
	aggregate.merge(aggregate_defaults, false)
	result.aggregate = aggregate
	var empty_defaults := {"evolution_history": [], "pending_evolution": {}, "discovered_forms": [str(result.get("current_form_id", ""))], "discovered_routes": [], "battle_history_summary": {"battle_count": 0, "wins": 0, "losses": 0, "draws": 0, "current_win_streak": 0, "longest_win_streak": 0, "defeated_encounters": [], "opponent_history": []}, "experience": 0, "level": 1, "active_battle": {}, "last_battle_result": {}, "injury": {}, "inventory": {}, "used_item_ids": [], "reward_grants": {}, "unlock_ids": [], "dungeon_flags": [], "boss_flags": [], "dungeon_history": [], "active_dungeon_run": {}, "codex": {"forms": result.get("discovered_forms", []), "encounters": [], "defeated_encounters": [], "dungeons": [], "bosses": []}}
	for key in empty_defaults:
		if not result.has(key):
			result[key] = empty_defaults[key]
	var form := _record(str(result.get("current_form_id", "")))
	if not form.is_empty():
		result.stage = str(form.data.get("stage", result.get("stage", "hatchling")))
		result.traits = form.data.get("traits", result.get("traits", [])).duplicate(true)
	return result


func _write_save() -> Dictionary:
	if foundation.current_save.is_empty():
		return _failure("APP_NOT_READY", "Foundation save is not initialized")
	var previous_save := foundation.current_save.duplicate(true)
	foundation.current_save.simulation_state.records = [] if pet_state.is_empty() else [pet_state.duplicate(true)]
	foundation.current_save.recovery_metadata["last_offline_progress"] = last_offline_result.duplicate(true)
	var result := foundation.save_current()
	if not result.get("ok", false):
		foundation.current_save = previous_save
	return result


func _snapshot_transaction() -> Dictionary:
	return {
		"pet_state": pet_state.duplicate(true),
		"current_save": foundation.current_save.duplicate(true),
		"last_offline_result": last_offline_result.duplicate(true),
		"last_command_result": last_command_result.duplicate(true),
	}


func _restore_transaction(snapshot: Dictionary) -> void:
	pet_state = snapshot.get("pet_state", {}).duplicate(true)
	foundation.current_save = snapshot.get("current_save", {}).duplicate(true)
	last_offline_result = snapshot.get("last_offline_result", {}).duplicate(true)
	last_command_result = snapshot.get("last_command_result", {}).duplicate(true)


func _safe_nonnegative_int(value: Variant) -> int:
	return maxi(0, int(value)) if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) else 0


func _pet_record_shape_error(record: Dictionary) -> String:
	for field in ["current_form_id", "care_profile_id", "animation_profile_id", "current_simulation_utc"]:
		if not record.get(field) is String or str(record.get(field, "")).is_empty():
			return field
	for field in ["current_simulation_unix", "revision"]:
		var value: Variant = record.get(field)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return field
	for field in ["care", "aggregate", "sickness"]:
		if not record.get(field) is Dictionary:
			return field
	for field in ["waste", "pending_digestion", "attention_calls", "history"]:
		if not record.get(field) is Array:
			return field
	return ""


func _refresh_catalog() -> void:
	catalog.clear()
	for record in foundation.content_registry.list_documents():
		if record.has("id"):
			catalog[str(record.id)] = record


func _record(content_id: String) -> Dictionary:
	return catalog.get(content_id, {}).duplicate(true)


func _first_document(kind: String) -> Dictionary:
	var records: Array[Dictionary] = []
	for record in catalog.values():
		if str(record.get("kind", "")) == kind or str(record.get("schema_name", "")).trim_suffix(".schema.json") == kind:
			records.append(record)
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return records[0].duplicate(true) if not records.is_empty() else {}


func _stable_seed(value: String) -> int:
	var result := 2166136261
	for character in value:
		result = int((result ^ character.unicode_at(0)) * 16777619) & 0x7fffffff
	return maxi(1, result)


func _failure(code: String, reason: String) -> Dictionary:
	return {"ok": false, "error_code": code, "reason": reason}
