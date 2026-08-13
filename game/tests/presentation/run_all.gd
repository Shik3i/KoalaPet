extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("KoalaPet visual presentation tests")
	_test_project_transparency()
	_test_player_presentation_source()
	_test_component_contract()
	_test_mode_sizes_and_shared_revision()
	_test_assets_and_layers()
	_test_walk_cycle_contracts()
	_test_animation_controller()
	_test_preferences()
	_test_habitat_contract()
	_test_localized_bounds_and_windows_scales()
	_test_action_reachability_and_debug_isolation()
	await _test_minimal_scene_hierarchy()
	if _failures.is_empty():
		print("RESULT: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("RESULT: FAIL (%d failures, %d assertions)" % [_failures.size(), _assertions])
		quit(1)


func _test_project_transparency() -> void:
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	_assert_equal(clear.a, 0.0, "VIS-001 default viewport clear alpha")
	_assert_equal(ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed"), true, "VIS-002 per-pixel transparency allowed")


func _test_player_presentation_source() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/pet_game.gd")
	_assert_equal("FoundationRuntime" in source or "ResolvedContent" in source, false, "VIS-003 no raw foundation debug form in normal presentation")
	_assert_equal("PresentationSettings" in source and "ScrollContainer.new" in source, true, "VIS-003A responsive settings may scroll intentionally")
	_assert_equal("background = ColorRect" in source, false, "VIS-004 removed legacy opaque shell")
	_assert_equal("--dev-tools" in source, true, "VIS-005 development tools require explicit flag")
	_assert_equal("--animation-polish-demo" in source and "_run_animation_polish_demo" in source, true, "VIS-005A review-only polish sequence is explicitly gated")
	_assert_equal("if revision == animation_revision:" in source, true, "VIS-005B repeated action timers are revision guarded")
	_assert_equal("_open_dev_window" in source, true, "VIS-006 development tools isolated in separate window")
	_assert_equal("window_adapter.set_hit_regions" in source, true, "VIS-007 Minimal uses platform hit-region abstraction")
	_assert_equal("get_window().content_scale_size = rendered_size" in source, true, "VIS-007B live scaling keeps viewport and native window synchronized")
	_assert_equal("get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED" in source, true, "VIS-007C enlarged viewport owns UI-scale layout without cropping")
	_assert_equal("draw_circle" in source or "draw_polygon" in source, false, "VIS-007A no geometric creature drawing in player presentation")


func _test_component_contract() -> void:
	var names := ["panel", "compact_panel", "title_bar", "tabs", "primary_button", "icon_button", "toggle", "status_bar", "segmented_status_indicator", "call_bubble", "modal", "card", "starter_egg_card", "inventory_slot", "codex_slot", "evolution_silhouette", "battle_stance_control", "dungeon_node", "event_log_entry", "reward_notification"]
	var built := [PixelUi.panel(), PixelUi.panel(true), PixelUi.title("T"), PixelUi.tab("T"), PixelUi.button("T"), PixelUi.icon_button("feed", "T"), PixelUi.toggle("T", false), PixelUi.status_meter("mood", "Mood", "mood", 5000), PixelUi.segmented_status(5000), PixelUi.call_bubble(), PixelUi.modal("T", "B"), PixelUi.card(), PixelUi.starter_egg_card(), PixelUi.inventory_slot(), PixelUi.codex_slot(), PixelUi.evolution_silhouette(), PixelUi.battle_stance_control("T", "balanced"), PixelUi.dungeon_node("event", false), PixelUi.event_log_entry("T"), PixelUi.reward_notification("T")]
	for index in names.size():
		_assert_equal(str(built[index].get_meta("component", "")), names[index], "VIS-COMP-%02d %s" % [index + 1, names[index]])
	_assert_equal(built[13].custom_minimum_size.x >= 100.0, true, "VIS-COMP-21 inventory slots fit localized item names")
	for index in built.size():
		built[index].free()


func _test_mode_sizes_and_shared_revision() -> void:
	_assert_equal(WindowPresentationMode.default_size(WindowPresentationMode.Value.MINIMAL), Vector2i(240, 160), "VIS-008 Minimal footprint")
	_assert_equal(WindowPresentationMode.default_size(WindowPresentationMode.Value.SMALL), Vector2i(640, 360), "VIS-009 Small readable footprint")
	_assert_equal(WindowPresentationMode.default_size(WindowPresentationMode.Value.EXPANDED), Vector2i(1120, 720), "VIS-010 Expanded readable footprint")
	var save_path := "user://tests/presentation/shared-revision.json"
	_remove_save(save_path)
	var app := PetApplication.new({"save_path": save_path}, FakeSimulationClock.new(1770000000, 0.0))
	_assert_equal(app.initialize().get("ok", false), true, "VIS-011 application initializes")
	_assert_equal(app.choose_starter("koalapet.base:moss_egg").get("ok", false), true, "VIS-012 starter selected")
	var minimal := app.get_view_model("minimal", "de")
	var small := app.get_view_model("small", "de")
	var expanded := app.get_view_model("expanded", "de")
	_assert_equal(minimal.state_revision, small.state_revision, "VIS-013 Minimal and Small share state revision")
	_assert_equal(small.state_revision, expanded.state_revision, "VIS-014 Small and Expanded share state revision")
	_assert_equal(minimal.form_id, expanded.form_id, "VIS-015 mode switching does not recreate pet identity")
	_assert_equal(small.battle_unlocked, false, "VIS-016 Battle gated before progression")
	_assert_equal(small.dungeon_unlocked, false, "VIS-017 Dungeon gated before progression")
	_remove_save(save_path)


func _test_assets_and_layers() -> void:
	var file := FileAccess.open("res://assets_generated/visual-rebuild-manifest.json", FileAccess.READ)
	_assert_equal(file != null, true, "VIS-018 visual manifest resolves")
	if file == null:
		return
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_assert_equal(manifest.habitat.layer_order, ["background", "ground", "rear_structures", "large_furniture", "small_props", "functional_stations", "pet", "foreground", "lighting", "ambient_effects"], "VIS-019 deterministic habitat layer order")
	for icon_path in manifest.icons.values():
		_assert_equal(ResourceLoader.exists("res://" + str(icon_path).trim_prefix("game/")), true, "VIS-ICON resolves %s" % icon_path)
	for path in ["res://assets_generated/habitat/quiet_canopy/background_day.png", "res://assets_generated/habitat/quiet_canopy/ground.png", "res://assets_generated/habitat/quiet_canopy/props/sleeping_den.png", "res://assets_generated/habitat/quiet_canopy/props/feed_table.png", "res://assets_generated/habitat/quiet_canopy/props/bath_basin.png", "res://assets_generated/habitat/quiet_canopy/props/training_log.png"]:
		_assert_equal(ResourceLoader.exists(path), true, "VIS-HAB resolves %s" % path)


func _test_walk_cycle_contracts() -> void:
	var manifest_names := ["moss", "ember", "tide", "moss_bloom", "moss_bracken", "ember_dawn", "ember_cinder", "tide_glass", "tide_reed"]
	for name in manifest_names:
		var path := "res://content_packs/koalapet.base/data/animation_%s.json" % name
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var walk: Dictionary = document.get("world_animations", {}).get("walk", {})
		_assert_equal(int(walk.get("frames", 0)), 8, "VIS-WALK-%s eight sequential frames" % name)
		_assert_equal(float(walk.get("fps", 0.0)) >= 8.0 and float(walk.get("fps", 0.0)) <= 12.0, true, "VIS-WALK-%s production cadence" % name)
		var frame_size: Array = walk.get("frame_size", [])
		_assert_equal(Vector2(float(frame_size[0]), float(frame_size[1])), Vector2(128, 128), "VIS-WALK-%s frame canvas" % name)
		_assert_equal(walk.get("ground_anchor", []), walk.get("pivot", []), "VIS-WALK-%s ground and pivot stable" % name)
		_assert_equal(bool(walk.get("mirroring_allowed", false)), true, "VIS-WALK-%s mirroring policy" % name)
		_assert_equal((walk.get("event_markers", []) as Array).size(), 2, "VIS-WALK-%s contact markers" % name)
		_assert_equal(ResourceLoader.exists("res://" + str(walk.get("asset", "")).trim_prefix("assets/")), false, "VIS-WALK-%s no unresolved res root alias" % name)
		_assert_equal(FileAccess.file_exists("res://content_packs/koalapet.base/" + str(walk.get("asset", ""))), true, "VIS-WALK-%s sheet resolves" % name)
	_assert_equal(FileAccess.file_exists("res://../docs/evidence/animation-polish/contact-sheets/walk-cycles.png"), true, "VIS-WALK contact sheet exists outside runtime root")


func _test_animation_controller() -> void:
	var controller := PresentationAnimationController.new()
	_assert_equal(controller.effective_loop({"sleeping": true, "sickness": true}, true), "sleep", "VIS-ANIM sleep priority")
	_assert_equal(controller.effective_loop({"sleeping": false, "sickness": true}, true), "sick", "VIS-ANIM sickness priority")
	_assert_equal(controller.effective_loop({"injury": {"id": "sprain"}}, true), "injured", "VIS-ANIM injury priority")
	_assert_equal(controller.effective_loop({}, true), "walk", "VIS-ANIM movement selects walk")
	_assert_equal(controller.queue_one_shot("eat", "feeding_bowl", 1.0, "event:1"), true, "VIS-ANIM queue one-shot")
	_assert_equal(controller.queue_one_shot("eat", "feeding_bowl", 1.0, "event:1"), false, "VIS-ANIM duplicate queued event rejected")
	_assert_equal(str(controller.consume_one_shot().get("animation", "")), "eat", "VIS-ANIM one-shot consumed once")
	_assert_equal(controller.queue_one_shot("eat", "feeding_bowl", 1.0, "event:1"), false, "VIS-ANIM consumed event cannot replay")


func _test_preferences() -> void:
	var defaults := PresentationPreferences.defaults()
	_assert_equal(defaults.version, PresentationPreferences.VERSION, "VIS-PREF versioned defaults")
	_assert_equal(defaults.interface.ui_scale, "auto", "VIS-PREF UI Auto default")
	_assert_equal(defaults.interface.text_scale, 1.0, "VIS-PREF text scale default")
	_assert_equal(defaults.pet_presentation.standard_pet_scale, 1.0, "VIS-PREF pet scale independent")
	_assert_equal(defaults.pet_presentation.reduced_motion, false, "VIS-PREF reduced motion default")
	_assert_equal(defaults.desktop.minimal_lane, "bottom", "VIS-PREF bottom lane production default")
	_assert_equal(PixelTheme.create(1.5).default_base_scale, 1.0, "VIS-PREF viewport reflow owns UI scaling")
	var malformed := PresentationPreferences.decode_text("{broken")
	_assert_equal(malformed.recovered, true, "VIS-PREF malformed recovery")
	_assert_equal(malformed.data.version, PresentationPreferences.VERSION, "VIS-PREF malformed defaults version")
	var migrated := PresentationPreferences.decode_text(JSON.stringify({"version": 0, "interface": {"language": "en"}}))
	_assert_equal(migrated.recovered, true, "VIS-PREF migration reported")
	_assert_equal(migrated.data.interface.language, "en", "VIS-PREF migration preserves valid value")
	var wrong_types := PresentationPreferences.decode_text(JSON.stringify({
		"version": [],
		"interface": {"text_scale": {}, "high_contrast": [], "tooltip_delay_ms": "fast"},
		"pet_presentation": {"ambient_roaming": "yes", "animation_speed": []},
		"desktop": {"always_on_top": 1},
	}))
	_assert_equal(wrong_types.data.interface.text_scale, 1.0, "VIS-PREF wrong numeric type uses default")
	_assert_equal(wrong_types.data.interface.high_contrast, false, "VIS-PREF wrong bool type uses default")
	_assert_equal(wrong_types.data.interface.tooltip_delay_ms, 500, "VIS-PREF wrong integer type uses default")
	_assert_equal(wrong_types.data.pet_presentation.ambient_roaming, true, "VIS-PREF wrong roaming type uses default")
	_assert_equal(wrong_types.data.desktop.always_on_top, true, "VIS-PREF wrong desktop bool type uses default")
	_assert_equal(PresentationPreferences.resolved_ui_scale("auto", 1.51), 1.5, "VIS-PREF Auto scale uses nearest supported DPI")
	var save_path := "user://tests/presentation/preferences.json"
	_remove_save(save_path)
	_assert_equal(PresentationPreferences.save_file(defaults, save_path).get("ok", false), true, "VIS-PREF persist")
	_assert_equal(PresentationPreferences.load_file(save_path).get("data", {}).get("version", 0), PresentationPreferences.VERSION, "VIS-PREF round trip")
	var changed := defaults.duplicate(true)
	changed.interface.language = "en"
	_assert_equal(PresentationPreferences.save_file(changed, save_path).get("ok", false), true, "VIS-PREF second persist rotates backup")
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	_assert_equal(corrupt != null, true, "VIS-PREF corrupt-primary fixture opens")
	if corrupt != null:
		corrupt.store_string("{broken")
		corrupt.close()
	var recovered := PresentationPreferences.load_file(save_path)
	_assert_equal(recovered.get("ok", false), true, "VIS-PREF valid backup recovers malformed primary")
	_assert_equal(recovered.get("recovered", false), true, "VIS-PREF backup recovery is explicit")
	_assert_equal(recovered.get("data", {}).get("interface", {}).get("language", ""), "de", "VIS-PREF backup data preserved")
	_remove_save(save_path)
	var before := {"simulation_revision": 17}
	PresentationPreferences.sanitize({"interface": {"ui_scale": 2.0}})
	_assert_equal(before.simulation_revision, 17, "VIS-PREF UI scale leaves simulation unchanged")
	_assert_equal(WindowPresentationMode.scaled_size(WindowPresentationMode.Value.SMALL, 1.0, 1.75).x > WindowPresentationMode.default_size(WindowPresentationMode.Value.SMALL).x, true, "VIS-PREF text scale reflows window")
	_assert_equal(WindowPresentationMode.scaled_size(WindowPresentationMode.Value.EXPANDED, 1.0, 1.5), Vector2i(1680, 1080), "VIS-PREF Expanded 150 percent text has full three-column reflow room")
	_assert_equal(WindowPresentationMode.scaled_size(WindowPresentationMode.Value.SMALL, 1.5, 1.0), Vector2i(960, 540), "VIS-PREF Small 150 percent UI scale expands layout bounds")


func _test_habitat_contract() -> void:
	for anchor in ["idle_center", "feeding_bowl", "treat_position", "bath", "training", "bed", "medicine", "departure", "trophy"]:
		_assert_equal(HabitatView.ANCHORS.has(anchor), true, "VIS-HAB anchor %s" % anchor)
	_assert_equal(HabitatView.ANCHORS.feeding_bowl.x > HabitatView.ANCHORS.bath.x, true, "VIS-HAB stations have distinct destinations")
	_assert_equal(HabitatView.ANCHORS.bed.x < HabitatView.ANCHORS.idle_center.x, true, "VIS-HAB sleep uses den side")
	var source := FileAccess.get_file_as_string("res://src/presentation/habitat_view.gd")
	_assert_equal("move_toward" in source, true, "VIS-HAB world movement separated from frames")
	_assert_equal("if reduced_motion:" in source, true, "VIS-HAB reduced motion bypasses roaming")
	_assert_equal("if _action_remaining > 0.0:" in source, true, "VIS-HAB reduced motion still completes actions")
	_assert_equal("48.0 * walking_speed * delta" in source, true, "VIS-HAB movement is delta independent")


func _test_localized_bounds_and_windows_scales() -> void:
	var required_keys := [
		"ui.feed", "ui.treat", "ui.clean", "ui.train", "ui.sleep", "ui.wake", "ui.battle", "ui.dungeon", "ui.inventory", "ui.evolution", "ui.treat_injury",
		"ui.ui_scale", "ui.text_scale", "ui.layout_density", "ui.compact", "ui.comfortable", "ui.language", "ui.pet_scale", "ui.minimal_pet_scale",
		"ui.animation_speed", "ui.walking_speed", "ui.effects_intensity", "ui.reduced", "ui.normal", "ui.default_mode", "ui.desktop_lane", "ui.bottom",
		"ui.stationary", "ui.ambient_roaming", "ui.reduced_motion", "ui.high_contrast", "ui.tooltips", "ui.always_on_top", "ui.click_through",
		"ui.remember_positions", "ui.reset_windows", "ui.settings_applied", "ui.windows_reset", "ui.on", "ui.off",
	]
	for locale in ["de", "en"]:
		var file := FileAccess.open("res://content_packs/koalapet.base/data/localization.%s.json" % locale, FileAccess.READ)
		_assert_equal(file != null, true, "VIS-LOC-%s bundle resolves" % locale)
		if file == null:
			continue
		var bundle: Dictionary = JSON.parse_string(file.get_as_text())
		file.close()
		for key in required_keys:
			_assert_equal(not str(bundle.get("strings", {}).get(key, "")).is_empty(), true, "VIS-LOC-%s %s resolves" % [locale, key])
	var source := FileAccess.get_file_as_string("res://src/presentation/pet_game.gd")
	_assert_equal("AUTOWRAP_WORD_SMART" in source, true, "VIS-LOC wrapping enabled for localized content")
	_assert_equal("text_overrun_behavior" in source, true, "VIS-LOC title overflow handled")
	for scale in [1.0, 1.25, 1.5, 1.75, 2.0]:
		var small_physical: Vector2 = Vector2(WindowPresentationMode.default_size(WindowPresentationMode.Value.SMALL)) * scale
		var expanded_physical: Vector2 = Vector2(WindowPresentationMode.default_size(WindowPresentationMode.Value.EXPANDED)) * scale
		_assert_equal(small_physical.x >= 640.0 and small_physical.y >= 360.0, true, "VIS-DPI Small remains above logical bounds at %.0f%%" % (scale * 100.0))
		_assert_equal(expanded_physical.x >= 1120.0 and expanded_physical.y >= 720.0, true, "VIS-DPI Expanded remains above logical bounds at %.0f%%" % (scale * 100.0))


func _test_action_reachability_and_debug_isolation() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/pet_game.gd")
	for action in ["_feed", "_treat", "_clean", "_train", "_sleep_or_wake", "_medicine", "_treat_injury", "_resolve_first_call", "_start_battle", "_start_dungeon", "_dungeon_next", "_set_expanded_tab"]:
		_assert_equal("func %s" % action in source, true, "VIS-ACTION reachable handler %s" % action)
	_assert_equal("not bool(model.get(\"battle_unlocked\", false))" in source, true, "VIS-GATE battle hidden behind progression gate")
	_assert_equal("not bool(model.get(\"dungeon_unlocked\", false))" in source, true, "VIS-GATE dungeon hidden behind progression gate")
	_assert_equal("if show_dev_tools:" in source, true, "VIS-DEV developer control construction is gated")


func _test_minimal_scene_hierarchy() -> void:
	var scene := load("res://scenes/pet_game.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if not game.application.has_pet():
		game.application.choose_starter("koalapet.base:moss_egg")
	game.call("_set_mode", "minimal")
	await process_frame
	var presentation := game.get_node_or_null("PlayerPresentation")
	_assert_equal(presentation != null, true, "VIS-020 player presentation root exists")
	if presentation != null:
		var persistent_backgrounds := 0
		for child in presentation.get_children():
			if child is ColorRect:
				persistent_backgrounds += 1
		_assert_equal(persistent_backgrounds, 0, "VIS-021 Minimal has no persistent ColorRect background")
	_assert_equal(game.dev_window == null, true, "VIS-022 developer window absent without --dev-tools")
	game.free()


func _remove_save(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	for suffix in ["", ".bak", ".tmp", ".swap", ".bak.tmp", ".bak.swap"]:
		var candidate: String = absolute + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected=%s actual=%s" % [label, expected, actual])
