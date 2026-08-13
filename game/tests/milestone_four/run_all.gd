extends SceneTree

const TEST_ROOT := "user://milestone_four_tests"
var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("KoalaPet Milestone 4 evolution/battle/dungeon tests")
	_remove_save()
	var clock := FakeSimulationClock.new(1767225600, 0.0)
	var config := {"content_roots": [ContentPackRegistry.root("res://content_packs", "bundled", "bundled")], "save_path": TEST_ROOT.path_join("good.json")}
	var app := PetApplication.new(config, clock)
	_assert_true(app.initialize().ok, "M4-001 application initializes with adventure content")
	_assert_equal(app.get_encounters().size(), 4, "M4-002 three normal encounters and one boss are catalogued")
	_assert_equal(app.get_dungeons().size(), 1, "M4-003 one data-defined dungeon is catalogued")
	_assert_true(app.choose_starter("koalapet.base:moss_egg").ok, "M4-004 starter selection uses existing path")
	_assert_true(app.complete_hatch().ok, "M4-005 hatch uses existing path")
	_assert_true(app.command({"type": "train", "activity_id": app.get_training_activity_id(), "input_bps": 5000}).ok, "M4-006 training contributes to evolution evidence")
	var evolved := app.advance_simulated(60)
	_assert_true(evolved.ok and evolved.summary.has("evolution"), "M4-007 good-care evolution applies automatically")
	var evolved_state := app.get_current_state()
	_assert_equal(str(evolved_state.current_form_id), "koalapet.base:moss_bloom_juvenile", "M4-008 good-care route selects the data-defined moss branch")
	_assert_equal(evolved_state.evolution_history.size(), 1, "M4-009 evolution transition is recorded once")
	_assert_equal(evolved_state.instance_id, app.get_current_state().instance_id, "M4-010 evolution preserves pet identity")
	_assert_true(app.is_feature_unlocked("koalapet.base:battle"), "M4-011 battle gate is unlocked after hatching")
	var encounter_id := "koalapet.base:creekling_encounter"
	_assert_true(app.command({"type": "start_battle", "encounter_id": encounter_id, "stance": "balanced"}).ok, "M4-012 normal battle starts with a stance")
	_assert_true(not app.get_current_state().active_battle.is_empty(), "M4-013 battle session is persisted while active")
	var mid_battle := PetApplication.new(config, clock)
	var mid_battle_result := mid_battle.initialize()
	_assert_true(mid_battle_result.ok and not mid_battle.get_current_state().active_battle.is_empty(), "M4-014 save/reload preserves an active battle (%s: %s)" % [mid_battle_result.get("error_code", ""), mid_battle_result.get("reason", "")])
	var rounds := 0
	while not app.get_current_state().active_battle.is_empty() and rounds < 8:
		var round_result := app.command({"type": "battle_round"})
		_assert_true(round_result.ok, "M4-015 deterministic battle round executes (%s: %s)" % [round_result.get("error_code", ""), round_result.get("reason", "")])
		if not round_result.ok:
			break
		rounds += 1
	_assert_true(app.get_current_state().get("last_battle_result", {}).get("status", "") == "win", "M4-016 normal battle resolves as a win")
	_assert_true(int(app.get_current_state().experience) > 0 and int(app.get_current_state().battle_history_summary.wins) == 1, "M4-017 win grants experience and history")
	_assert_true(app.command({"type": "start_battle", "encounter_id": "koalapet.base:thornlet_encounter", "stance": "aggressive"}).ok, "M4-018 second encounter starts")
	_assert_true(app.command({"type": "battle_resolve", "outcome": "win"}).ok, "M4-019 deterministic development resolution uses battle service")
	_assert_true(app.is_feature_unlocked("koalapet.base:dungeon"), "M4-020 dungeon gate uses battle history")
	var injury := app.command({"type": "start_battle", "encounter_id": "koalapet.base:cinder_moth_encounter"})
	_assert_true(injury.ok, "M4-021 injury fixture battle starts")
	var lost := app.command({"type": "battle_resolve", "outcome": "loss"})
	_assert_true(lost.ok and not app.get_current_state().injury.is_empty(), "M4-022 defeat creates explicit recoverable injury")
	var treated := app.command({"type": "treat_injury", "item_id": "koalapet.base:restorative_wrap"})
	_assert_true(treated.ok and app.get_current_state().injury.is_empty(), "M4-023 baseline injury treatment is available without inventory")
	_assert_true(app.command({"type": "start_dungeon", "dungeon_id": "koalapet.base:quiet_canopy"}).ok, "M4-024 first dungeon starts")
	for node_index in range(5):
		var next := app.command({"type": "dungeon_choice", "choice_id": "quiet_pool"}) if node_index == 1 else app.command({"type": "dungeon_next"})
		_assert_true(next.ok, "M4-025 dungeon node %d resolves or starts" % node_index)
		if not app.get_current_state().active_battle.is_empty():
			_assert_true(app.command({"type": "battle_resolve", "outcome": "win"}).ok, "M4-026 dungeon encounter %d wins" % node_index)
	_assert_true(app.get_current_state().active_dungeon_run.is_empty(), "M4-028 boss clear closes dungeon run")
	_assert_true(app.get_current_state().dungeon_flags.has("koalapet.base:quiet_canopy"), "M4-029 first clear flag is persistent")
	_assert_true(app.get_current_state().unlock_ids.has("koalapet.base:canopy_theme"), "M4-030 first clear stores future habitat theme unlock")
	_assert_true(app.foundation.current_save.feature_gate_state.unlock_ledger.has("koalapet.base:canopy_trophy"), "M4-030B first clear stores future trophy in unlock ledger")
	_assert_true(app.get_current_state().reward_grants.has("dungeon:first_clear:koalapet.base:quiet_canopy"), "M4-030A first-clear reward ledger is idempotency-backed")
	var reloaded := PetApplication.new(config, clock)
	_assert_true(reloaded.initialize().ok and reloaded.get_current_state().dungeon_flags.has("koalapet.base:quiet_canopy"), "M4-031 dungeon rewards survive save/reload")
	_remove_save()
	var poor_config := {"content_roots": [ContentPackRegistry.root("res://content_packs", "bundled", "bundled")], "save_path": TEST_ROOT.path_join("poor.json")}
	var poor := PetApplication.new(poor_config, clock)
	_assert_true(poor.initialize().ok and poor.choose_starter("koalapet.base:tide_egg").ok and poor.complete_hatch().ok, "M4-032 poor-care branch uses the same starter path")
	for cycle in range(2):
		poor.command({"type": "force_sickness"})
		poor.advance_simulated(1)
		poor.advance_simulated(7200)
		poor.command({"type": "medicine", "item_id": poor.find_item_by_kind("medicine")})
	_assert_true(int(poor.get_current_state().aggregate.care_mistakes) >= 2, "M4-033 poor-care evidence comes from missed calls")
	var poor_evolved := poor.advance_simulated(60)
	_assert_true(poor_evolved.ok and poor.get_current_state().current_form_id == "koalapet.base:tide_reed_juvenile", "M4-034 poor-care route remains a viable data-defined form")
	_test_all_family_routes(clock)
	_test_pending_evolution(clock)
	_test_identical_battle_seed(clock)
	if failures.is_empty():
		print("RESULT: PASS (%d assertions)" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RESULT: FAIL (%d failures, %d assertions)" % [failures.size(), assertions])
	quit(1)


func _test_all_family_routes(clock: FakeSimulationClock) -> void:
	var routes := [
		{"name": "moss", "starter": "koalapet.base:moss_egg", "good": "koalapet.base:moss_bloom_juvenile", "poor": "koalapet.base:moss_bracken_juvenile"},
		{"name": "ember", "starter": "koalapet.base:ember_egg", "good": "koalapet.base:ember_dawn_juvenile", "poor": "koalapet.base:ember_cinder_juvenile"},
		{"name": "tide", "starter": "koalapet.base:tide_egg", "good": "koalapet.base:tide_glass_juvenile", "poor": "koalapet.base:tide_reed_juvenile"},
	]
	for route in routes:
		var good := _new_route_app(clock, "route_%s_good.json" % route.name)
		_assert_true(good.initialize().ok and good.choose_starter(route.starter).ok and good.complete_hatch().ok, "M4-035 %s good route initializes" % route.name)
		good.command({"type": "train", "activity_id": good.get_training_activity_id(), "input_bps": 5000})
		var good_result := good.advance_simulated(60)
		_assert_true(good_result.ok and good.get_current_state().current_form_id == route.good, "M4-036 %s good-care branch resolves" % route.name)
		var poor := _new_route_app(clock, "route_%s_poor.json" % route.name)
		_assert_true(poor.initialize().ok and poor.choose_starter(route.starter).ok and poor.complete_hatch().ok, "M4-037 %s poor route initializes" % route.name)
		for cycle in range(2):
			poor.command({"type": "force_sickness"})
			poor.advance_simulated(1)
			poor.advance_simulated(7200)
			poor.command({"type": "medicine", "item_id": poor.find_item_by_kind("medicine")})
		var poor_result := poor.advance_simulated(60)
		_assert_true(poor_result.ok and poor.get_current_state().current_form_id == route.poor, "M4-038 %s poor-care branch resolves" % route.name)
	_remove_save()


func _test_pending_evolution(clock: FakeSimulationClock) -> void:
	var pending := _new_route_app(clock, "pending.json")
	_assert_true(pending.initialize().ok and pending.choose_starter("koalapet.base:ember_egg").ok and pending.complete_hatch().ok, "M4-039 pending fixture initializes")
	pending.command({"type": "train", "activity_id": pending.get_training_activity_id(), "input_bps": 5000})
	pending.command({"type": "sleep"})
	var blocked := pending.advance_simulated(60)
	_assert_true(blocked.ok and not pending.get_current_state().pending_evolution.is_empty(), "M4-040 eligible evolution waits at an unsafe sleep state")
	_assert_true(pending.command({"type": "wake"}).ok and pending.get_current_state().pending_evolution.is_empty(), "M4-041 pending evolution applies at the next safe point")
	_remove_save()


func _test_identical_battle_seed(clock: FakeSimulationClock) -> void:
	var first := _new_route_app(clock, "seed_first.json")
	var second := _new_route_app(clock, "seed_second.json")
	for app in [first, second]:
		_assert_true(app.initialize().ok and app.choose_starter("koalapet.base:moss_egg").ok and app.complete_hatch().ok, "M4-042 seeded battle fixture initializes")
		app.advance_simulated(60)
		_assert_true(app.command({"type": "start_battle", "encounter_id": "koalapet.base:creekling_encounter", "stance": "balanced"}).ok, "M4-043 seeded battle starts")
	while not first.get_current_state().active_battle.is_empty() and not second.get_current_state().active_battle.is_empty():
		first.command({"type": "battle_round"})
		second.command({"type": "battle_round"})
	_assert_equal(JSON.stringify(first.get_current_state().last_battle_result), JSON.stringify(second.get_current_state().last_battle_result), "M4-044 identical battle seeds produce identical results")
	_remove_save()


func _new_route_app(clock: FakeSimulationClock, filename: String) -> PetApplication:
	var config := {"content_roots": [ContentPackRegistry.root("res://content_packs", "bundled", "bundled")], "save_path": TEST_ROOT.path_join(filename)}
	return PetApplication.new(config, FakeSimulationClock.new(clock.utc_now_unix_seconds(), 0.0))


func _assert_true(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures.append("FAIL: %s" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assert_true(actual == expected, "%s (actual=%s expected=%s)" % [label, str(actual), str(expected)])


func _remove_save() -> void:
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(root):
		for file in DirAccess.get_files_at(root):
			DirAccess.remove_absolute(root.path_join(file))
		DirAccess.remove_absolute(root)
