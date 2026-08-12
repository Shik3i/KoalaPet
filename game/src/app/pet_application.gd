class_name PetApplication
extends RefCounted

var foundation: FoundationBootstrap
var simulation := PetSimulation.new()
var catalog: Dictionary = {}
var pet_state: Dictionary = {}
var last_offline_result: Dictionary = {}
var last_command_result: Dictionary = {}
var initialized := false


func _init(config: Dictionary = {}, injected_clock: SimulationClock = null) -> void:
	foundation = FoundationBootstrap.new(config, injected_clock)


func initialize() -> Dictionary:
	var result := foundation.initialize()
	if not result.ok:
		return result
	_refresh_catalog()
	var records: Array = foundation.current_save.simulation_state.get("records", [])
	if not records.is_empty() and records[0] is Dictionary:
		pet_state = records[0].duplicate(true)
		_sync_now()
	else:
		pet_state = {}
	initialized = true
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
	pet_state = simulation.create_new(egg, form, profile, str(egg.owner_pack_id), now_unix, now_text, _stable_seed(egg_id))
	var save_result := _write_save()
	if not save_result.ok:
		pet_state = {}
		return save_result
	return {"ok": true, "state": pet_state.duplicate(true), "summary": {"event": "egg_selected"}}


func complete_hatch() -> Dictionary:
	return command({"type": "complete_hatch"})


func command(command_data: Dictionary) -> Dictionary:
	if pet_state.is_empty():
		return _failure("NO_PET", "Select a starter egg first")
	_sync_now()
	var now_unix := foundation.clock.utc_now_unix_seconds()
	var now_text := foundation.clock.utc_now_text()
	last_command_result = simulation.apply_command(pet_state, command_data, now_unix, now_text, catalog)
	if not last_command_result.ok:
		return last_command_result
	pet_state = last_command_result.state
	var save_result := _write_save()
	if not save_result.ok:
		return save_result
	return last_command_result


func advance_simulated(seconds: int) -> Dictionary:
	if pet_state.is_empty():
		return _failure("NO_PET", "Select a starter egg first")
	var accepted := maxi(0, seconds)
	var start_unix := int(pet_state.get("current_simulation_unix", foundation.clock.utc_now_unix_seconds()))
	var end_unix := start_unix + accepted
	var result := simulation.advance(pet_state, accepted, end_unix, Time.get_datetime_string_from_unix_time(end_unix, false) + "Z", catalog)
	if result.ok:
		pet_state = result.state
		var save_result := _write_save()
		if not save_result.ok:
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


func get_asset_path(animation_name := "idle", egg := false) -> String:
	var animation_id := str(pet_state.get("animation_profile_id", ""))
	if egg and not pet_state.is_empty():
		var egg_record := _record(str(pet_state.get("egg_definition_id", "")))
		animation_id = str(egg_record.data.get("animation_profile_id", animation_id))
	var animation := _record(animation_id)
	if animation.is_empty():
		return ""
	var animation_data: Dictionary = animation.data
	var entry: Dictionary = animation_data.get("world_animations", {}).get(animation_name, animation_data.get("world_animations", {}).get("idle", {}))
	var relative_asset := str(entry.get("asset", ""))
	if relative_asset.is_empty():
		return ""
	return str(animation.get("pack_root", "")).path_join(relative_asset.trim_prefix("res://"))


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
		"current_simulation_unix": int(pet_state.get("current_simulation_unix", 0)),
		"sleeping": bool(pet_state.get("sleeping", false)),
		"sickness": not pet_state.get("sickness", {}).is_empty(),
		"open_calls": open_calls,
		"care": care.duplicate(true),
		"aggregate": pet_state.get("aggregate", {}).duplicate(true),
		"history": pet_state.get("history", []).duplicate(true),
	}
	if mode == "minimal":
		return {"screen": model.screen, "mode": mode, "name": model.name, "hatched": model.hatched, "sleeping": model.sleeping, "sickness": model.sickness, "open_calls": model.open_calls}
	if mode == "small":
		return {"screen": model.screen, "mode": mode, "name": model.name, "form_name": model.form_name, "hatched": model.hatched, "sleeping": model.sleeping, "sickness": model.sickness, "open_calls": model.open_calls, "care": {"satiety_bps": care.get("satiety_bps", 0), "mood_bps": care.get("mood_bps", 0), "energy_bps": care.get("energy_bps", 0), "hygiene_bps": care.get("hygiene_bps", 0)}}
	return model


func _sync_now() -> void:
	if pet_state.is_empty():
		return
	var now_unix := foundation.clock.utc_now_unix_seconds()
	var now_text := foundation.clock.utc_now_text()
	var profile := _record(str(pet_state.get("care_profile_id", "")))
	var cap := int(profile.get("data", {}).get("offline_cap_seconds", 7 * 24 * 60 * 60))
	var policy := OfflineProgressPolicy.new(cap)
	last_offline_result = policy.evaluate(str(pet_state.get("current_simulation_utc", "")), now_text)
	var accepted := int(last_offline_result.get("accepted_simulation_seconds", 0))
	if accepted == 0 and str(pet_state.get("current_simulation_utc", "")) == now_text:
		return
	var result := simulation.advance(pet_state, accepted, now_unix, now_text, catalog)
	if result.ok:
		pet_state = result.state
		_write_save()


func _write_save() -> Dictionary:
	if foundation.current_save.is_empty():
		return _failure("APP_NOT_READY", "Foundation save is not initialized")
	foundation.current_save.simulation_state.records = [] if pet_state.is_empty() else [pet_state.duplicate(true)]
	foundation.current_save.recovery_metadata["last_offline_progress"] = last_offline_result.duplicate(true)
	return foundation.save_current()


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
