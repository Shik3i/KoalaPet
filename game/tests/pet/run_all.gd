extends SceneTree

const TEST_ROOT := "user://pet_vertical_slice_tests"

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("KoalaPet Milestone 3 pet vertical-slice tests")
	_remove_save()
	var clock := FakeSimulationClock.new(1767225600, 0.0)
	var config := {
		"content_roots": [ContentPackRegistry.root("res://content_packs", "bundled", "bundled")],
		"save_path": TEST_ROOT.path_join("pet.json"),
	}
	var app := PetApplication.new(config, clock)
	var boot := app.initialize()
	_assert_true(boot.ok, "PET-001 application initializes with bundled content")
	_assert_equal(app.get_starter_eggs().size(), 3, "PET-002 starter pool exposes three eggs")
	_assert_equal(app.get_quarantine_count(), 0, "PET-003 fresh save has no quarantine")
	var selected := app.choose_starter("koalapet.base:moss_egg")
	_assert_true(selected.ok, "PET-004 starter selection persists an egg")
	_assert_true(not app.is_hatched(), "PET-005 selected starter begins as egg")
	_assert_equal(int(app.get_view_model("small").hatch_progress_bps), 0, "PET-005A hatch progress starts at zero")
	var half_hatch := app.advance_simulated(30)
	_assert_true(half_hatch.ok and not app.is_hatched() and int(app.get_view_model("small").hatch_progress_bps) > 0, "PET-005B hatch progress is deterministic before completion")
	var hatched := app.advance_simulated(60)
	_assert_true(hatched.ok and hatched.summary.hatched, "PET-006 hatch occurs at deterministic duration")
	_assert_true(app.is_hatched(), "PET-007 hatched state is active")
	_assert_true(app.complete_hatch().ok, "PET-007A hatch completion is idempotent after automatic hatching")
	_assert_equal(app.get_current_state().required_content_ids.size(), 5, "PET-008 pet records required content bindings")
	var renamed := app.command({"type": "set_nickname", "nickname": "Moss"})
	_assert_true(renamed.ok, "PET-009 nickname command is accepted")
	_assert_equal(app.get_current_state().nickname, "Moss", "PET-010 nickname is stored")
	var before_invalid := app.get_current_state()
	var invalid_with_time := app.command({"type": "unknown", "adventure_seconds": 10})
	_assert_true(not invalid_with_time.ok, "PET-010A invalid command reports failure")
	_assert_equal(app.get_current_state(), before_invalid, "PET-010B failed command rolls back adventure time")
	var invalid_training := app.command({"type": "train", "activity_id": app.get_training_activity_id(), "input_bps": {"invalid": true}})
	_assert_true(not invalid_training.ok and invalid_training.error_code == "INVALID_COMMAND_VALUE", "PET-010C malformed numeric command value is rejected")
	_assert_equal(app.get_current_state(), before_invalid, "PET-010D malformed numeric command does not mutate state")
	var invalid_item := app.command({"type": "feed", "item_id": "koalapet.base:missing_item"})
	_assert_true(not invalid_item.ok and invalid_item.error_code == "COMMAND_NOT_APPLICABLE", "PET-010E unavailable item command is rejected")
	_assert_equal(app.get_current_state(), before_invalid, "PET-010F unavailable item command does not mutate state")
	var original_save_path: String = app.foundation.save_repository.save_path
	var blocked_save_path := TEST_ROOT.path_join("blocked.json")
	var blocked_temporary := ProjectSettings.globalize_path(blocked_save_path) + ".tmp"
	DirAccess.make_dir_recursive_absolute(blocked_temporary)
	app.foundation.save_repository.save_path = blocked_save_path
	var before_write_failure := app.get_current_state()
	var write_failure := app.command({"type": "set_nickname", "nickname": "Must Roll Back"})
	_assert_true(not write_failure.ok, "PET-010G save failure is returned")
	_assert_equal(app.get_current_state(), before_write_failure, "PET-010H save failure rolls back in-memory state")
	app.foundation.save_repository.save_path = original_save_path
	DirAccess.remove_absolute(blocked_temporary)
	var fed := app.command({"type": "feed", "item_id": app.find_item_by_kind("meal")})
	_assert_true(fed.ok and "fed" in fed.summary.events, "PET-011 meal command updates care")
	var digestion := app.advance_simulated(901)
	_assert_true(digestion.ok and digestion.summary.waste_generated > 0, "PET-012 digestion produces deterministic waste")
	_assert_true(app.get_current_state().waste.size() > 0, "PET-013 waste is visible in state")
	var cleaned := app.command({"type": "clean"})
	_assert_true(cleaned.ok and app.get_current_state().waste.is_empty(), "PET-014 cleaning removes waste")
	var trained := app.command({"type": "train", "activity_id": app.get_training_activity_id(), "input_bps": 5000})
	_assert_true(trained.ok and int(app.get_current_state().aggregate.training_count) == 1, "PET-015 training records one outcome")
	var slept := app.command({"type": "sleep"})
	_assert_true(slept.ok and app.get_current_state().sleeping, "PET-016 sleep command changes state")
	var woke := app.command({"type": "wake"})
	_assert_true(woke.ok and not app.get_current_state().sleeping, "PET-017 wake command changes state")
	var sickness := app.command({"type": "force_sickness"})
	_assert_true(sickness.ok and not app.get_current_state().sickness.is_empty(), "PET-018 development ailment path is deterministic")
	var call_opened := app.advance_simulated(1)
	var has_open_sickness_call := false
	for attention_call in app.get_current_state().attention_calls:
		if str(attention_call.get("reason", "")) == "sickness" and str(attention_call.get("status", "")) == "open":
			has_open_sickness_call = true
	_assert_true(call_opened.ok and has_open_sickness_call, "PET-019 sickness opens an attention call")
	var call_missed := app.advance_simulated(7200)
	var has_missed_call := false
	for attention_call in app.get_current_state().attention_calls:
		if str(attention_call.get("reason", "")) == "sickness" and str(attention_call.get("status", "")) == "missed":
			has_missed_call = true
	_assert_true(call_missed.ok and has_missed_call and int(app.get_current_state().aggregate.care_mistakes) > 0, "PET-020 missed attention call records a care mistake")
	var treated := app.command({"type": "medicine", "item_id": app.find_item_by_kind("medicine")})
	_assert_true(treated.ok and app.get_current_state().sickness.is_empty(), "PET-021 medicine clears ailment")
	var advanced := app.advance_simulated(8 * 60 * 60)
	_assert_true(advanced.ok and app.get_current_state().aggregate.last_accepted_simulation_seconds >= 8 * 60 * 60 + 60 + 901 + 1 + 7200, "PET-022 bounded simulation advances without frame dependence")
	var view_minimal := app.get_view_model("minimal")
	var view_small := app.get_view_model("small")
	var view_expanded := app.get_view_model("expanded")
	_assert_equal(view_minimal.mode, "minimal", "PET-023 minimal presentation mode is explicit")
	_assert_true(view_small.has("care"), "PET-024 small presentation exposes compact care")
	_assert_true(view_expanded.has("history") and view_expanded.history.size() > 0, "PET-025 expanded presentation exposes history")
	var reloaded := PetApplication.new(config, clock)
	var reload_result := reloaded.initialize()
	_assert_true(reload_result.ok and reloaded.has_pet(), "PET-026 save reload restores the active pet")
	_assert_equal(reloaded.get_current_state().nickname, "Moss", "PET-027 save reload preserves nickname")
	var valid_state := reloaded.get_current_state()
	var invalid_shape := valid_state.duplicate(true)
	invalid_shape.care = "invalid"
	reloaded.foundation.current_save.simulation_state.records = [invalid_shape]
	_assert_true(reloaded.foundation.save_current().ok, "PET-027A malformed pet fixture is persisted")
	var invalid_record_app := PetApplication.new(config, clock)
	var invalid_record_result := invalid_record_app.initialize()
	_assert_true(not invalid_record_result.ok and invalid_record_result.error_code == "INVALID_PET_RECORD", "PET-027B malformed pet save fails safely")
	invalid_record_app.foundation.current_save.simulation_state.records = [valid_state]
	var restore_valid_result := invalid_record_app.foundation.save_current()
	_assert_true(restore_valid_result.ok, "PET-027C valid pet fixture is restored (%s: %s)" % [restore_valid_result.get("error_code", ""), restore_valid_result.get("reason", "")])
	var malformed_state: Dictionary = reloaded.foundation.current_save.simulation_state.records[0].duplicate(true)
	malformed_state.definition_id = "missing.pack:removed_form"
	invalid_record_app.foundation.current_save.simulation_state.records = [malformed_state]
	var corrupted_binding_save := invalid_record_app.foundation.save_current()
	_assert_true(corrupted_binding_save.ok, "PET-028 test fixture writes a missing-content binding (%s: %s)" % [corrupted_binding_save.get("error_code", ""), corrupted_binding_save.get("reason", "")])
	var quarantined := PetApplication.new(config, clock)
	var quarantine_result := quarantined.initialize()
	_assert_true(quarantine_result.ok and not quarantined.has_pet(), "PET-029 missing pet content is quarantined")
	_assert_equal(quarantined.get_quarantine_count(), 1, "PET-030 quarantine record is retained")
	_remove_save()
	if failures.is_empty():
		print("RESULT: PASS (%d assertions)" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("RESULT: FAIL (%d failures, %d assertions)" % [failures.size(), assertions])
		quit(1)


func _assert_true(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures.append("FAIL: %s" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (actual=%s expected=%s)" % [label, str(actual), str(expected)])


func _remove_save() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT.path_join("pet.json"))
	for suffix in ["", ".bak", ".tmp", ".swap", ".bak.tmp", ".bak.swap"]:
		var path: String = absolute + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var directory := absolute.get_base_dir()
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
