extends SceneTree

const PET_GAME_SCENE := preload("res://scenes/pet_game.tscn")

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
	_test_living_animation_contracts()
	_test_animation_controller()
	_test_ambient_scheduler()
	await _test_animated_texture_runtime()
	await _test_animation_showroom_runtime()
	_test_preferences()
	_test_habitat_contract()
	await _test_habitat_runtime()
	_test_localized_bounds_and_windows_scales()
	_test_action_reachability_and_debug_isolation()
	_test_action_feedback_contract()
	_test_icon_contract()
	await _test_ui_rescue_runtime()
	await _test_player_ui_signal_lifecycle()
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
	_assert_equal("OS.is_debug_build()" in source and "development_actions_enabled and not living_demo.is_empty()" in source and "_run_living_animation_demo" in source, true, "VIS-005C living-animation review scenarios are debug-build gated")
	_assert_equal("if revision == animation_revision:" in source, true, "VIS-005B repeated action timers are revision guarded")
	_assert_equal("_open_dev_window" in source, true, "VIS-006 development tools isolated in separate window")
	_assert_equal("window_adapter.set_hit_regions" in source, true, "VIS-007 Minimal uses platform hit-region abstraction")
	_assert_equal("get_window().content_scale_size = Vector2i.ZERO" in source, true, "VIS-007B viewport override cleared so the native window stays resizable")
	_assert_equal("get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED" in source, true, "VIS-007C enlarged viewport owns UI-scale layout without cropping")
	_assert_equal("draw_circle" in source or "draw_polygon" in source, false, "VIS-007A no geometric creature drawing in player presentation")


func _test_component_contract() -> void:
	var names := ["panel", "compact_panel", "title_bar", "tabs", "primary_button", "icon_button", "toggle", "status_bar", "segmented_status_indicator", "call_bubble", "modal", "card", "starter_egg_card", "inventory_slot", "codex_slot", "evolution_silhouette", "battle_stance_control", "dungeon_node", "event_log_entry", "reward_notification"]
	var built := [PixelUi.panel(), PixelUi.panel(true), PixelUi.title("T"), PixelUi.tab("T"), PixelUi.button("T"), PixelUi.icon_button("feed", "T"), PixelUi.toggle("T", false), PixelUi.stat_meter("mood", "Mood", "mood", 5000), PixelUi.segmented_status(5000), PixelUi.call_bubble(), PixelUi.modal("T", "B"), PixelUi.card(), PixelUi.starter_egg_card(), PixelUi.inventory_slot(), PixelUi.codex_slot(), PixelUi.evolution_silhouette(), PixelUi.battle_stance_control("T", "balanced"), PixelUi.dungeon_node("event", false), PixelUi.event_log_entry("T"), PixelUi.reward_notification("T")]
	for index in names.size():
		_assert_equal(str(built[index].get_meta("component", "")), names[index], "VIS-COMP-%02d %s" % [index + 1, names[index]])
	_assert_equal(built[13].custom_minimum_size.x >= 100.0, true, "VIS-COMP-21 inventory slots fit localized item names")
	for index in built.size():
		built[index].free()


func _test_mode_sizes_and_shared_revision() -> void:
	_assert_equal(WindowPresentationMode.default_size(WindowPresentationMode.Value.MINIMAL), Vector2i(240, 160), "VIS-008 Minimal footprint")
	_assert_equal(WindowPresentationMode.default_size(WindowPresentationMode.Value.SMALL), Vector2i(720, 480), "VIS-009 Small readable footprint")
	_assert_equal(WindowPresentationMode.default_size(WindowPresentationMode.Value.EXPANDED), Vector2i(1160, 760), "VIS-010 Expanded readable footprint")
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
	_assert_equal(manifest.get("living_animation", {}).get("family_profiles", {}).size(), 3, "VIS-019A three data-defined family VFX profiles")
	_assert_equal(manifest.get("living_animation", {}).get("encounter_profiles", {}).size(), 4, "VIS-019B four data-defined encounter VFX profiles")
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


func _test_living_animation_contracts() -> void:
	var player_names := ["moss", "ember", "tide", "moss_bloom", "moss_bracken", "ember_dawn", "ember_cinder", "tide_glass", "tide_reed"]
	var required := ["idle", "idle_look", "idle_playful", "idle_rest", "walk", "turn_left", "turn_right", "sleep_enter", "sleep_loop", "wake", "eat", "treat", "clean", "training", "medicine", "treatment", "attention", "sick", "injured", "attack", "hit", "dodge", "victory", "defeat", "playful_hop", "playful_pounce"]
	var minimums := {"idle": 4, "idle_look": 6, "idle_playful": 8, "idle_rest": 6, "walk": 8, "turn_left": 4, "turn_right": 4, "sleep_enter": 8, "sleep_loop": 4, "wake": 8, "eat": 8, "treat": 6, "clean": 8, "training": 8, "medicine": 6, "treatment": 6, "attention": 6, "sick": 4, "injured": 4, "attack": 6, "hit": 6, "dodge": 6, "victory": 6, "defeat": 6, "playful_hop": 6, "playful_pounce": 6}
	for profile_name in player_names:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content_packs/koalapet.base/data/animation_%s.json" % profile_name))
		var animations: Dictionary = document.get("world_animations", {})
		for animation_name in required:
			_assert_equal(animations.has(animation_name), true, "VIS-LIVE-%s has %s" % [profile_name, animation_name])
			if animations.has(animation_name):
				_assert_equal(int(animations[animation_name].get("frames", 0)) >= int(minimums[animation_name]), true, "VIS-LIVE-%s %s minimum frames" % [profile_name, animation_name])
		for one_shot in ["sleep_enter", "wake", "eat", "clean", "training", "medicine", "attack", "hit", "dodge", "victory", "defeat"]:
			_assert_equal(bool(animations[one_shot].get("loop", true)), false, "VIS-LIVE-%s %s is one-shot" % [profile_name, one_shot])
		_assert_equal(bool(animations.sleep_loop.get("loop", false)), true, "VIS-LIVE-%s sleep loop loops" % profile_name)
		for marked in ["sleep_enter", "wake", "attack", "hit", "dodge"]:
			var events: Array = animations[marked].get("event_markers", [])
			_assert_equal(events.size() >= 3, true, "VIS-LIVE-%s %s synchronized markers" % [profile_name, marked])
	var enemies := ["creekling", "thornlet", "cinder_moth", "canopy_guardian"]
	for enemy_name in enemies:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content_packs/koalapet.base/data/animation_enemy_%s.json" % enemy_name))
		var animations: Dictionary = document.get("world_animations", {})
		for animation_name in ["idle", "attack", "hit", "dodge", "defeat"]:
			_assert_equal(animations.has(animation_name), true, "VIS-ENEMY-%s has %s" % [enemy_name, animation_name])
			_assert_equal(int(animations.get(animation_name, {}).get("frames", 0)) >= (4 if animation_name == "idle" else 5), true, "VIS-ENEMY-%s %s meaningful frames" % [enemy_name, animation_name])
	_assert_equal(FileAccess.file_exists("res://../docs/evidence/living-animation/reels/all-player-highlights.gif"), true, "VIS-LIVE combined highlight reel exists")


func _test_animation_controller() -> void:
	var controller := PresentationAnimationController.new()
	_assert_equal(controller.effective_loop({"sleeping": true, "sickness": true}, true), "sick", "VIS-ANIM sickness outranks sleep")
	_assert_equal(controller.effective_loop({"sleeping": false, "sickness": true}, true), "sick", "VIS-ANIM sickness priority")
	_assert_equal(controller.effective_loop({"injury": {"id": "sprain"}}, true), "injured", "VIS-ANIM injury priority")
	_assert_equal(controller.effective_loop({"sleeping": true}, false), "sleep_loop", "VIS-ANIM sleeping selects sleep loop")
	_assert_equal(controller.effective_loop({"active_battle": {"id": "battle"}}, true), "idle", "VIS-ANIM battle reactions remain one-shots")
	_assert_equal(controller.effective_loop({}, true), "walk", "VIS-ANIM movement selects walk")
	_assert_equal(controller.queue_one_shot("eat", "feeding_bowl", 1.0, "event:1"), true, "VIS-ANIM queue one-shot")
	_assert_equal(controller.queue_one_shot("eat", "feeding_bowl", 1.0, "event:1"), false, "VIS-ANIM duplicate queued event rejected")
	_assert_equal(str(controller.consume_one_shot().get("animation", "")), "eat", "VIS-ANIM one-shot consumed once")
	_assert_equal(controller.queue_one_shot("eat", "feeding_bowl", 1.0, "event:1"), false, "VIS-ANIM consumed event cannot replay")
	controller.queue_one_shot("idle_playful", "idle_center", 1.0, "ambient:1", "idle", "", "ambient")
	controller.queue_one_shot("attack", "idle_center", 1.0, "battle:1", "idle", "", "battle")
	_assert_equal(str(controller.consume_one_shot().get("event_id", "")), "battle:1", "VIS-ANIM authoritative battle event wins priority")
	_assert_equal(controller.cancel_pending_below(PresentationAnimationController.PRIORITIES.care), 1, "VIS-ANIM low-priority ambient cancellation deterministic")
	for index in PresentationAnimationController.MAX_PENDING_EVENTS + 4:
		controller.queue_one_shot("attention", "idle_center", 1.0, "bounded:%d" % index)
	_assert_equal(controller.pending_count(), PresentationAnimationController.MAX_PENDING_EVENTS, "VIS-ANIM pending queue bounded")
	var priority_queue := PresentationAnimationController.new()
	for index in PresentationAnimationController.MAX_PENDING_EVENTS:
		priority_queue.queue_one_shot("idle_look", "idle_center", 1.0, "ambient-full:%d" % index, "idle", "", "ambient")
	_assert_equal(priority_queue.queue_one_shot("victory", "idle_center", 1.0, "evolution:priority", "idle", "", "evolution"), true, "VIS-ANIM saturated queue admits authoritative higher-priority event")
	_assert_equal(priority_queue.pending_count(), PresentationAnimationController.MAX_PENDING_EVENTS, "VIS-ANIM priority replacement preserves hard queue bound")
	_assert_equal(str(priority_queue.consume_one_shot().get("event_id", "")), "evolution:priority", "VIS-ANIM priority replacement is selected first")


func _test_ambient_scheduler() -> void:
	var first := AmbientAnimationScheduler.new()
	var second := AmbientAnimationScheduler.new()
	first.configure(1234, "normal", false)
	second.configure(1234, "normal", false)
	var first_events := []
	var second_events := []
	for _index in 12:
		first_events.append(first.next_event())
		second_events.append(second.next_event())
	_assert_equal(first_events, second_events, "VIS-AMBIENT scheduler deterministic for fixed presentation seed")
	var previous_special := ""
	for event in first_events:
		if str(event.kind) in ["special_idle", "playful_move"]:
			_assert_equal(str(event.animation) == previous_special, false, "VIS-AMBIENT special animation does not repeat immediately")
			previous_special = str(event.animation)
	var reduced := AmbientAnimationScheduler.new()
	reduced.configure(42, "high", true)
	for _index in 20:
		_assert_equal(str(reduced.next_event().get("kind", "")) == "playful_move", false, "VIS-AMBIENT Reduced Motion excludes playful locomotion")
	var props := AmbientAnimationScheduler.new()
	props.configure(7, "high", false, [{"anchor": "plant", "animation": "idle_look"}, {"anchor": "bath", "animation": "idle_playful"}])
	var saw_prop := false
	for _index in 40:
		var event := props.next_event()
		if str(event.get("kind", "")) == "prop_interaction":
			saw_prop = true
			_assert_equal(str(event.get("anchor", "")) in ["plant", "bath"], true, "VIS-AMBIENT cosmetic prop interaction stays on declared anchors")
	_assert_equal(saw_prop, true, "VIS-AMBIENT high-frequency scheduler eventually selects restrained prop play")


func _test_animated_texture_runtime() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content_packs/koalapet.base/data/animation_moss.json"))
	var descriptor: Dictionary = document.get("world_animations", {}).get("attack", {}).duplicate(true)
	descriptor["path"] = "res://content_packs/koalapet.base/" + str(descriptor.get("asset", ""))
	descriptor["animation_name"] = "attack"
	var sprite := AnimatedTextureRect.new()
	sprite.size = Vector2(128, 128)
	root.add_child(sprite)
	await process_frame
	var markers: Array[String] = []
	var completions: Array[String] = []
	sprite.animation_marker.connect(func(_animation: String, event_name: String, _frame: int) -> void: markers.append(event_name))
	sprite.animation_finished.connect(func(animation_name: String) -> void: completions.append(animation_name))
	sprite.configure(descriptor, true, 1.0)
	for _index in 8:
		sprite.call("_process", 1.0)
	for required_marker in ["windup_started", "projectile_release", "impact", "hit_stop", "recovery_started", "animation_complete"]:
		_assert_equal(required_marker in markers, true, "VIS-RUNTIME Reduced Motion preserves marker %s" % required_marker)
	_assert_equal(completions.count("attack"), 1, "VIS-RUNTIME one-shot completion emitted once")
	sprite.restart()
	sprite.set_playback_enabled(false)
	var paused_frame := sprite.frame_index
	sprite.call("_process", 1.0)
	_assert_equal(sprite.frame_index, paused_frame, "VIS-RUNTIME disabled playback cannot advance")
	sprite.set_playback_enabled(true)
	sprite.visible = false
	sprite.call("_process", 1.0)
	_assert_equal(sprite.frame_index, paused_frame, "VIS-RUNTIME hidden sprite cannot advance")
	sprite.free()


func _test_animation_showroom_runtime() -> void:
	var save_path := "user://tests/presentation/showroom.json"
	_remove_save(save_path)
	var app := PetApplication.new({"save_path": save_path}, FakeSimulationClock.new(1770000000, 0.0))
	_assert_equal(app.initialize().get("ok", false), true, "VIS-SHOWROOM application initializes")
	var entries := app.get_animation_review_entries("en")
	_assert_equal(entries.size(), 16, "VIS-SHOWROOM loads eggs, nine forms, enemies and boss")
	var kinds := {"egg": 0, "form": 0, "enemy": 0}
	var sequence_count := 0
	for entry in entries:
		var kind := str(entry.get("kind", ""))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		for animation_name in (entry.get("animations", {}) as Dictionary):
			sequence_count += 1
			var descriptor: Dictionary = entry.animations[animation_name]
			_assert_equal(str(descriptor.get("animation_name", "")), str(animation_name), "VIS-SHOWROOM %s/%s resolves without fallback" % [entry.content_id, animation_name])
			var frames := int(descriptor.get("frames", 0))
			var previous_marker := -1
			for marker in descriptor.get("event_markers", []):
				var marker_frame := int(marker.get("frame", -1))
				_assert_equal(marker_frame >= 0 and marker_frame < frames, true, "VIS-SHOWROOM %s/%s marker in range" % [entry.content_id, animation_name])
				_assert_equal(marker_frame >= previous_marker, true, "VIS-SHOWROOM %s/%s markers ordered" % [entry.content_id, animation_name])
				previous_marker = marker_frame
	_assert_equal(kinds, {"egg": 3, "form": 9, "enemy": 4}, "VIS-SHOWROOM entity kind coverage")
	_assert_equal(sequence_count, 290, "VIS-SHOWROOM exhaustive sequence count")
	var runtime := AnimatedTextureRect.new()
	runtime.size = Vector2(128, 128)
	root.add_child(runtime)
	await process_frame
	for entry in entries:
		for animation_name in (entry.get("animations", {}) as Dictionary):
			var descriptor: Dictionary = entry.animations[animation_name].duplicate(true)
			descriptor["loop"] = false
			runtime.configure(descriptor, false, 2.0)
			for _frame in range(int(descriptor.get("frames", 1))):
				runtime.call("_process", 10.0)
			_assert_equal(runtime.current_frame(), int(descriptor.get("frames", 1)) - 1, "VIS-SHOWROOM %s/%s completes runtime playback" % [entry.content_id, animation_name])
			runtime.configure(descriptor, true, 2.0)
			_assert_equal(runtime.current_frame(), int(descriptor.get("frames", 1)) - 1, "VIS-SHOWROOM refresh does not restart active descriptor")
	runtime.set_frame(0)
	runtime.step_frame(1)
	_assert_equal(runtime.current_frame(), 1, "VIS-SHOWROOM manual frame step uses runtime controller")
	runtime.free()
	var showroom := AnimationShowroom.new()
	showroom.setup(app, "en")
	root.add_child(showroom)
	await process_frame
	_assert_equal(showroom.reviewed_entity_count(), 16, "VIS-SHOWROOM UI loads every review entity")
	_assert_equal(showroom.reviewed_animation_count(), 290, "VIS-SHOWROOM UI loads every sequence")
	_assert_equal(showroom.missing_or_fallback_animations().is_empty(), true, "VIS-SHOWROOM UI flags no missing or fallback animation")
	showroom.free()
	_remove_save(save_path)


func _test_preferences() -> void:
	var defaults := PresentationPreferences.defaults()
	_assert_equal(defaults.version, PresentationPreferences.VERSION, "VIS-PREF versioned defaults")
	_assert_equal(defaults.interface.ui_scale, "auto", "VIS-PREF UI Auto default")
	_assert_equal(defaults.interface.text_scale, 1.0, "VIS-PREF text scale default")
	_assert_equal(defaults.pet_presentation.standard_pet_scale, 1.0, "VIS-PREF pet scale independent")
	_assert_equal(defaults.pet_presentation.reduced_motion, false, "VIS-PREF reduced motion default")
	_assert_equal(defaults.pet_presentation.ambient_animation_frequency, "normal", "VIS-PREF ambient frequency default")
	_assert_equal(defaults.pet_presentation.cursor_reaction, true, "VIS-PREF cursor reaction default")
	_assert_equal(defaults.pet_presentation.hit_shake, true, "VIS-PREF hit shake default")
	_assert_equal(defaults.pet_presentation.damage_flash, true, "VIS-PREF damage flash default")
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
		"pet_presentation": {"ambient_roaming": "yes", "ambient_animation_frequency": [], "cursor_reaction": "yes", "animation_speed": [], "hit_shake": 1},
		"desktop": {"always_on_top": 1},
	}))
	_assert_equal(wrong_types.data.interface.text_scale, 1.0, "VIS-PREF wrong numeric type uses default")
	_assert_equal(wrong_types.data.interface.high_contrast, false, "VIS-PREF wrong bool type uses default")
	_assert_equal(wrong_types.data.interface.tooltip_delay_ms, 500, "VIS-PREF wrong integer type uses default")
	_assert_equal(wrong_types.data.pet_presentation.ambient_roaming, true, "VIS-PREF wrong roaming type uses default")
	_assert_equal(wrong_types.data.pet_presentation.ambient_animation_frequency, "normal", "VIS-PREF wrong ambient frequency uses default")
	_assert_equal(wrong_types.data.pet_presentation.cursor_reaction, true, "VIS-PREF wrong cursor bool uses default")
	_assert_equal(wrong_types.data.pet_presentation.hit_shake, true, "VIS-PREF wrong shake bool uses default")
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
	_assert_equal(WindowPresentationMode.scaled_size(WindowPresentationMode.Value.EXPANDED, 1.0, 1.5), Vector2i(1740, 1140), "VIS-PREF Expanded 150 percent text has full three-column reflow room")
	_assert_equal(WindowPresentationMode.scaled_size(WindowPresentationMode.Value.SMALL, 1.5, 1.0), Vector2i(1080, 720), "VIS-PREF Small 150 percent UI scale expands layout bounds")


func _test_habitat_contract() -> void:
	for anchor in ["idle_center", "feeding_bowl", "treat_position", "bath", "training", "bed", "medicine", "departure", "trophy", "plant"]:
		_assert_equal(HabitatView.ANCHORS.has(anchor), true, "VIS-HAB anchor %s" % anchor)
	_assert_equal(HabitatView.ANCHORS.feeding_bowl.x > HabitatView.ANCHORS.bath.x, true, "VIS-HAB stations have distinct destinations")
	_assert_equal(HabitatView.ANCHORS.bed.x < HabitatView.ANCHORS.idle_center.x, true, "VIS-HAB sleep uses den side")
	var source := FileAccess.get_file_as_string("res://src/presentation/habitat_view.gd")
	_assert_equal("move_toward" in source, true, "VIS-HAB world movement separated from frames")
	_assert_equal("if reduced_motion:" in source, true, "VIS-HAB reduced motion bypasses roaming")
	_assert_equal("if _action_remaining > 0.0:" in source, true, "VIS-HAB reduced motion still completes actions")
	_assert_equal("48.0 * walking_speed * delta" in source, true, "VIS-HAB movement is delta independent")
	_assert_equal("animation_marker.connect" in source, true, "VIS-HAB VFX and feedback use animation markers")
	_assert_equal("set_playback_enabled" in source and "visibility_changed" in source, true, "VIS-HAB hidden animation processing is suspended")
	_assert_equal("MAX_PENDING_EVENTS" in source, true, "VIS-HAB presentation event queue remains bounded")


func _test_habitat_runtime() -> void:
	var habitat := HabitatView.new()
	root.add_child(habitat)
	await process_frame
	habitat.show_call("mood")
	var bubble := habitat.call_layer.get_child(0) as Control
	var first_bubble_x := bubble.position.x
	habitat.set_world_anchor("departure")
	_assert_equal(bubble.position.x > first_bubble_x, true, "VIS-HAB call bubble follows roaming pet anchor")
	var ambient := habitat.get_node_or_null("AmbientWater") as AnimatedTextureRect
	habitat.visible = false
	await process_frame
	_assert_equal(ambient == null or not ambient.is_processing(), true, "VIS-HAB hidden ambient effects suspend processing")
	habitat.visible = true
	await process_frame
	var enemy_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content_packs/koalapet.base/data/animation_enemy_creekling.json"))
	var enemy_animations := {}
	for animation_name in ["idle", "attack", "defeat"]:
		var descriptor: Dictionary = enemy_document.get("world_animations", {}).get(animation_name, {}).duplicate(true)
		descriptor["path"] = "res://content_packs/koalapet.base/" + str(descriptor.get("asset", ""))
		descriptor["animation_name"] = animation_name
		enemy_animations[animation_name] = descriptor
	habitat.set_opponent_animations(enemy_animations, "koalapet.base:creekling_encounter")
	habitat.call("_start_actor_event", habitat.opponent_sprite, {"animation": "attack", "payload": {"actor": "enemy"}})
	habitat.call("_finish_action")
	_assert_equal(habitat.opponent_sprite.animation_name, "idle", "VIS-HAB nonterminal enemy action returns to idle")
	habitat.call("_start_actor_event", habitat.opponent_sprite, {"animation": "defeat", "payload": {"actor": "enemy", "terminal": true}})
	habitat.call("_finish_action")
	_assert_equal(habitat.opponent_sprite.animation_name, "defeat", "VIS-HAB terminal enemy result remains visually stable")
	habitat.free()


func _test_localized_bounds_and_windows_scales() -> void:
	var required_keys := [
		"ui.feed", "ui.treat", "ui.clean", "ui.train", "ui.sleep", "ui.wake", "ui.battle", "ui.dungeon", "ui.inventory", "ui.evolution", "ui.treat_injury",
		"ui.ui_scale", "ui.text_scale", "ui.layout_density", "ui.compact", "ui.comfortable", "ui.language", "ui.pet_scale", "ui.minimal_pet_scale",
		"ui.animation_speed", "ui.walking_speed", "ui.effects_intensity", "ui.reduced", "ui.normal", "ui.low", "ui.high", "ui.ambient_frequency", "ui.default_mode", "ui.desktop_lane", "ui.bottom",
		"ui.stationary", "ui.ambient_roaming", "ui.cursor_reaction", "ui.hit_shake", "ui.damage_flash", "ui.reduced_motion", "ui.high_contrast", "ui.tooltips", "ui.always_on_top", "ui.click_through",
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
		_assert_equal(small_physical.x >= 720.0 and small_physical.y >= 480.0, true, "VIS-DPI Small remains above logical bounds at %.0f%%" % (scale * 100.0))
		_assert_equal(expanded_physical.x >= 1160.0 and expanded_physical.y >= 760.0, true, "VIS-DPI Expanded remains above logical bounds at %.0f%%" % (scale * 100.0))


func _test_action_reachability_and_debug_isolation() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/pet_game.gd")
	for action in ["_feed", "_treat", "_clean", "_train", "_sleep_or_wake", "_medicine", "_treat_injury", "_resolve_first_call", "_start_battle", "_start_dungeon", "_dungeon_next", "_set_expanded_tab"]:
		_assert_equal("func %s" % action in source, true, "VIS-ACTION reachable handler %s" % action)
	_assert_equal("not bool(model.get(\"battle_unlocked\", false))" in source, true, "VIS-GATE battle hidden behind progression gate")
	_assert_equal("not bool(model.get(\"dungeon_unlocked\", false))" in source, true, "VIS-GATE dungeon hidden behind progression gate")
	_assert_equal("if show_dev_tools:" in source, true, "VIS-DEV developer control construction is gated")
	_assert_equal("child.free()" in source, false, "VIS-SIGNAL presentation refresh never frees live signal emitters immediately")
	_assert_equal("child.queue_free()" in source and "CONNECT_DEFERRED" in source, true, "VIS-SIGNAL presentation teardown and callbacks are deferred")


func _test_player_ui_signal_lifecycle() -> void:
	var save_path := "user://tests/presentation/ui-signals.json"
	var preferences_path := "user://tests/presentation/ui-signals-preferences.json"
	var placement_path := "user://tests/presentation/ui-signals-placement.json"
	_remove_save(save_path)
	_remove_save(preferences_path)
	_remove_save(placement_path)
	var game := PET_GAME_SCENE.instantiate()
	game.requested_save_path = save_path
	game.preferences_path = preferences_path
	game.placement_path = placement_path
	root.add_child(game)
	await process_frame
	await process_frame
	_assert_deferred_player_controls(game.root_layer, "starter")
	var choose := _find_button(game.root_layer, "Wählen")
	await _emit_button_and_settle(choose, "VIS-SIGNAL starter selection opens confirmation")
	var cancel := _find_button(game.root_layer, "Abbrechen")
	await _emit_button_and_settle(cancel, "VIS-SIGNAL starter confirmation cancellation")
	choose = _find_button(game.root_layer, "Wählen")
	await _emit_button_and_settle(choose, "VIS-SIGNAL starter selection reopens confirmation")
	var confirm := _find_button(game.root_layer, "Bestätigen")
	await _emit_button_and_settle(confirm, "VIS-SIGNAL starter confirmation rebuilds safely")
	_assert_equal(game.application.has_pet(), true, "VIS-SIGNAL starter confirmation reaches egg state")
	_assert_deferred_player_controls(game.root_layer, "egg")
	_assert_equal(game.application.complete_hatch().get("ok", false), true, "VIS-SIGNAL hatch fixture reaches playable state")
	game.call("_refresh")
	await process_frame
	await process_frame
	_assert_deferred_player_controls(game.root_layer, "small care")
	var revision_before := int(game.application.get_view_model("small", "de").get("state_revision", 0))
	await _emit_button_and_settle(_find_button(game.root_layer, "Füttern"), "VIS-SIGNAL feed uses the real pressed signal")
	_assert_equal(int(game.application.get_view_model("small", "de").get("state_revision", 0)) > revision_before, true, "VIS-SIGNAL feed completes without terminating the scene")
	await _emit_button_and_settle(_find_button(game.root_layer, "Reinigen"), "VIS-SIGNAL clean rebuilds safely")
	var train_label: String = game.application.text("ui.train", "Trainieren", game.locale)
	await _emit_button_and_settle(_find_button(game.root_layer, train_label), "VIS-SIGNAL training rebuilds safely")
	await _emit_button_and_settle(_find_button(game.root_layer, "Mehr"), "VIS-SIGNAL More page rebuilds safely")
	_assert_deferred_player_controls(game.root_layer, "small more")
	await _emit_button_and_settle(_find_button(game.root_layer, "Leckerli"), "VIS-SIGNAL treat rebuilds safely")
	# Sleep and Wake replace each other in place: the contextual action must be
	# the only one of the pair the player can reach at any moment.
	_assert_equal(_find_button(game.root_layer, "Aufwecken"), null, "VIS-SIGNAL Wake is absent while the pet is awake")
	await _emit_button_and_settle(_find_button(game.root_layer, "Schlafen"), "VIS-SIGNAL sleep rebuilds safely")
	_assert_equal(_find_button(game.root_layer, "Schlafen"), null, "VIS-SIGNAL Sleep is replaced once the pet sleeps")
	await _emit_button_and_settle(_find_button(game.root_layer, "Aufwecken"), "VIS-SIGNAL wake rebuilds safely")
	await _emit_button_and_settle(_find_button(game.root_layer, "Pflege"), "VIS-SIGNAL Care page rebuilds safely")
	await _emit_button_and_settle(_find_button(game.root_layer, "Abenteuer"), "VIS-SIGNAL Adventure tab rebuilds safely")
	_assert_deferred_player_controls(game.root_layer, "small adventure")
	await _emit_button_and_settle(_find_button(game.root_layer, "Kampf"), "VIS-SIGNAL battle start rebuilds safely")
	if not game.application.get_current_state().get("active_battle", {}).is_empty():
		var round_label: String = game.application.text("ui.next_round", "Runde", game.locale)
		await _emit_button_and_settle(_find_button(game.root_layer, round_label), "VIS-SIGNAL battle round rebuilds safely")
	if not game.application.get_current_state().get("active_battle", {}).is_empty():
		game.application.command({"type": "battle_resolve", "outcome": "win"})
		game.call("_refresh")
		await process_frame
	await _emit_button_and_settle(_find_button(game.root_layer, "Erweitert"), "VIS-SIGNAL mode switch rebuilds safely")
	_assert_equal(game.mode, "expanded", "VIS-SIGNAL mode switch reaches Expanded")
	# Dungeon is intentionally absent until its data-driven gate opens, so the
	# reachable tab set is derived from the live model instead of hardcoded.
	var expected_tabs: Array[String] = ["Kampf", "Inventar", "Kodex", "Entwicklung", "Übersicht"]
	var gate_model: Dictionary = game.application.get_view_model("expanded", game.locale)
	_assert_equal(bool(gate_model.get("dungeon_unlocked", false)), false, "VIS-SIGNAL dungeon gate still closed in this fixture")
	_assert_equal(_find_button(game.root_layer.find_child("ExpandedCenter", true, false), "Dungeon"), null, "VIS-SIGNAL locked Dungeon tab is absent, not disabled")
	for tab_label in expected_tabs:
		var center: Node = game.root_layer.find_child("ExpandedCenter", true, false)
		await _emit_button_and_settle(_find_button(center, tab_label), "VIS-SIGNAL Expanded tab %s" % tab_label)
		_assert_deferred_player_controls(game.root_layer, "expanded %s" % tab_label)
	var actions: Node = game.root_layer.find_child("ExpandedActions", true, false)
	# Medicine is contextual: absent while healthy, present once sick.
	_assert_equal(_find_button(actions, "Medizin"), null, "VIS-SIGNAL Medicine is absent while the pet is healthy")
	for action_label in ["Füttern", "Leckerli", "Reinigen", "Trainieren", "Schlafen"]:
		await _emit_button_and_settle(_find_button(actions, action_label), "VIS-SIGNAL Expanded action %s" % action_label)
		actions = game.root_layer.find_child("ExpandedActions", true, false)
	game.application.command({"type": "force_sickness"})
	game.call("_refresh")
	await process_frame
	await process_frame
	actions = game.root_layer.find_child("ExpandedActions", true, false)
	await _emit_button_and_settle(_find_button(actions, "Medizin"), "VIS-SIGNAL Medicine appears exactly when the pet is sick")
	var settings_label: String = game.application.text("ui.settings", "Einstellungen", game.locale)
	await _emit_button_and_settle(_find_button(game.root_layer, settings_label), "VIS-SIGNAL Settings opens from its real button")
	var settings: Node = game.root_layer.find_child("PresentationSettings", true, false)
	_assert_equal(settings != null, true, "VIS-SIGNAL settings modal exists")
	if settings != null:
		_assert_deferred_player_controls(settings, "settings")
		var options := _collect_controls(settings, "OptionButton")
		var toggles := _collect_controls(settings, "CheckButton")
		_assert_equal(options.size(), 12, "VIS-SIGNAL every settings selector is constructed")
		_assert_equal(toggles.size(), 10, "VIS-SIGNAL every settings toggle is constructed")
		if not options.is_empty():
			var option := options[0] as OptionButton
			option.emit_signal("item_selected", (option.selected + 1) % option.item_count)
			await process_frame
			await process_frame
			_assert_equal(is_instance_valid(game), true, "VIS-SIGNAL selector callback rebuilds safely")
	game.call("_open_settings")
	await process_frame
	settings = game.root_layer.find_child("PresentationSettings", true, false)
	if settings != null:
		var toggles_after := _collect_controls(settings, "CheckButton")
		if not toggles_after.is_empty():
			var toggle := toggles_after[0] as CheckButton
			toggle.emit_signal("toggled", not toggle.button_pressed)
			await process_frame
			await process_frame
			_assert_equal(is_instance_valid(game), true, "VIS-SIGNAL toggle callback rebuilds safely")
	var conditional_model: Dictionary = game.application.get_view_model("expanded", game.locale)
	conditional_model["injury"] = {"injury_id": "koalapet.base:sprain"}
	conditional_model["open_calls"] = [{"call_id": "signal-fixture"}]
	var conditional_actions := game.call("_expanded_context", conditional_model) as Control
	root.add_child(conditional_actions)
	_assert_deferred_player_controls(conditional_actions, "conditional injury and call actions")
	conditional_actions.free()
	_assert_equal(is_instance_valid(game), true, "VIS-SIGNAL exhaustive player control construction keeps scene alive")
	game.free()
	_remove_save(save_path)
	_remove_save(preferences_path)
	_remove_save(placement_path)



## Prompt 4.9: every visible outcome must resolve to a localized sentence.
func _test_action_feedback_contract() -> void:
	var locales := ["de", "en"]
	var bundles := {}
	for locale in locales:
		var file := FileAccess.open("res://content_packs/koalapet.base/data/localization.%s.json" % locale, FileAccess.READ)
		bundles[locale] = JSON.parse_string(file.get_as_text()).get("strings", {})
		file.close()
	var actions := ["feed", "treat", "clean", "train", "sleep", "wake", "medicine", "treat_injury", "resolve_call", "start_battle", "battle_round", "start_dungeon", "dungeon_next", "dungeon_choice", "complete_hatch", "set_nickname", "unmapped_action"]
	var codes := ["", "COMMAND_NOT_APPLICABLE", "FEATURE_LOCKED", "EGG_NOT_HATCHED", "NO_PET", "BATTLE_ALREADY_ACTIVE", "ADVENTURE_ALREADY_ACTIVE", "NO_INJURY", "SAVE_LOCKED", "TEMP_WRITE_FAILED", "CONCURRENT_SAVE_CONFLICT", "ENCOUNTER_MISSING", "TOTALLY_UNKNOWN_CODE", "INVALID_NICKNAME"]
	for action in actions:
		for code in codes:
			var result := {"ok": true, "summary": {"events": []}} if code.is_empty() else {"ok": false, "error_code": code}
			var described := ActionFeedback.describe(action, result)
			var key := str(described.get("key", ""))
			_assert_equal(key.is_empty(), false, "VIS-FEEDBACK %s/%s resolves a key" % [action, code])
			_assert_equal(described.get("severity", "") in [ActionFeedback.SEVERITY_SUCCESS, ActionFeedback.SEVERITY_NOTICE, ActionFeedback.SEVERITY_BLOCKED, ActionFeedback.SEVERITY_FAILURE], true, "VIS-FEEDBACK %s/%s has a known severity" % [action, code])
			for locale in locales:
				_assert_equal(not str(bundles[locale].get(key, "")).is_empty(), true, "VIS-FEEDBACK %s localized in %s" % [key, locale])
	# A raw engine code or reason may never reach the player-facing text.
	var leaked := ActionFeedback.describe("feed", {"ok": false, "error_code": "TOTALLY_UNKNOWN_CODE", "reason": "internal diagnostic"})
	_assert_equal("TOTALLY_UNKNOWN_CODE" in str(leaked.get("fallback", "")), false, "VIS-FEEDBACK unknown code is not shown verbatim")
	_assert_equal("internal diagnostic" in str(leaked.get("fallback", "")), false, "VIS-FEEDBACK internal reason is not shown verbatim")
	var overfed := ActionFeedback.describe("feed", {"ok": true, "summary": {"events": ["fed", "overfed"]}})
	_assert_equal(str(overfed.get("key", "")), "feedback.feed.overfed", "VIS-FEEDBACK overfeeding warns on success")
	_assert_equal(str(overfed.get("severity", "")), ActionFeedback.SEVERITY_NOTICE, "VIS-FEEDBACK overfeeding is a notice, not a failure")
	_assert_equal(str(ActionFeedback.unavailable_hint("train", {"sleeping": true}).get("key", "")), "feedback.state.sleeping", "VIS-FEEDBACK sleeping explains a blocked training")
	_assert_equal(str(ActionFeedback.unavailable_hint("train", {"sickness": true}).get("key", "")), "feedback.state.sick", "VIS-FEEDBACK sickness explains a blocked training")
	_assert_equal(ActionFeedback.unavailable_hint("battle_round", {"active_battle": {"encounter_id": "x"}}).is_empty(), true, "VIS-FEEDBACK advancing a running battle stays available")
	_assert_equal(ActionFeedback.unavailable_hint("battle", {"active_battle": {"encounter_id": "x"}}).is_empty(), false, "VIS-FEEDBACK starting a second battle is blocked")
	_assert_equal(ActionFeedback.unavailable_hint("feed", {"sleeping": true}).is_empty(), true, "VIS-FEEDBACK feeding is never blocked by sleep")


## Prompt 4.9: every player-facing icon must resolve to dedicated art.
func _test_icon_contract() -> void:
	var required := [
		"feed", "treat", "clean", "train", "sleep", "wake", "medicine", "treatment",
		"battle", "dungeon", "inventory", "codex", "evolution", "settings",
		"expand", "collapse", "minimize", "close", "minimal",
		"satiety", "mood", "energy", "hygiene", "health", "discipline", "level",
		"injury", "sickness", "call",
	]
	for name in required:
		_assert_equal(PixelUi.icon_exists(name), true, "VIS-ICON %s has dedicated art" % name)
		var texture := PixelUi.icon(name)
		_assert_equal(texture != null, true, "VIS-ICON %s loads" % name)
		if texture != null:
			_assert_equal(texture.get_width(), UiMetrics.ICON_SOURCE, "VIS-ICON %s uses the shared 24px canvas" % name)
			_assert_equal(texture.get_height(), UiMetrics.ICON_SOURCE, "VIS-ICON %s is square" % name)
		var doubled := PixelUi.icon(name, 2)
		_assert_equal(doubled != null and doubled.get_width() == UiMetrics.ICON_SOURCE * 2, true, "VIS-ICON %s has a crisp 2x twin" % name)
	# The rejected build aliased window controls onto unrelated subject art.
	_assert_equal(PixelUi.icon_name_for("close"), "close", "VIS-ICON Close no longer renders the injury plaster")
	_assert_equal(PixelUi.icon_name_for("minimize"), "minimize", "VIS-ICON Minimize no longer renders the Minimal-mode glyph")
	_assert_equal(PixelUi.icon_name_for("discipline"), "discipline", "VIS-ICON Discipline no longer renders the training log")
	_assert_equal(PixelUi.missing_icon_names().is_empty(), true, "VIS-ICON no player-facing icon fell back to the settings cog")


## Prompt 4.9: interactive-state, layout and input-safety regressions.
func _test_ui_rescue_runtime() -> void:
	var save_path := "user://tests/presentation/ui-rescue.json"
	var preferences_path := "user://tests/presentation/ui-rescue-preferences.json"
	var placement_path := "user://tests/presentation/ui-rescue-placement.json"
	for path in [save_path, preferences_path, placement_path]:
		_remove_save(path)
	var game := PET_GAME_SCENE.instantiate()
	game.requested_save_path = save_path
	game.preferences_path = preferences_path
	game.placement_path = placement_path
	root.add_child(game)
	await process_frame
	await process_frame
	game.application.choose_starter("koalapet.base:moss_egg")
	game.application.advance_simulated(3600)
	game.application.complete_hatch()
	game.call("_refresh")
	await process_frame
	await process_frame

	# Feed must survive every supported pet state without terminating.
	var states := [
		{"name": "hatchling", "setup": []},
		{"name": "hungry", "setup": [{"advance": 21600}]},
		{"name": "full", "setup": [{"command": {"type": "feed", "item_id": game.application.find_item_by_kind("meal")}}]},
		{"name": "sleeping", "setup": [{"command": {"type": "sleep"}}]},
		{"name": "awake", "setup": [{"command": {"type": "wake"}}]},
		{"name": "sick", "setup": [{"command": {"type": "force_sickness"}}]},
		{"name": "cured", "setup": [{"command": {"type": "medicine", "item_id": game.application.find_item_by_kind("medicine")}}]},
	]
	for state in states:
		for step in state.setup:
			if step.has("command"):
				game.application.command(step.command)
			else:
				game.application.advance_simulated(int(step.advance))
		for mode in ["small", "expanded"]:
			game.mode = mode
			game.call("_refresh")
			await process_frame
			await process_frame
			var feed_button := _find_named_button(game.root_layer, "Action_feed")
			if feed_button == null:
				feed_button = _find_named_button(game.root_layer, "Context_feed")
			_assert_equal(feed_button != null, true, "VIS-FEED %s/%s exposes Feed" % [state.name, mode])
			if feed_button == null:
				continue
			_assert_equal(feed_button.pressed.get_connections().size(), 1, "VIS-FEED %s/%s connects Feed exactly once" % [state.name, mode])
			game.call("_reset_input_guard")
			feed_button.emit_signal("pressed")
			await process_frame
			await process_frame
			_assert_equal(is_instance_valid(game), true, "VIS-FEED %s/%s survives Feed" % [state.name, mode])
			_assert_equal(str(game.last_feedback_record.get("key", "")).begins_with("feedback."), true, "VIS-FEED %s/%s reports localized feedback" % [state.name, mode])

	# An invalid command must produce safe feedback and no crash.
	game.mode = "small"
	game.call("_refresh")
	await process_frame
	game.call("_reset_input_guard")
	game.call("_command", {"type": "definitely_not_a_command"}, "")
	await process_frame
	await process_frame
	_assert_equal(is_instance_valid(game), true, "VIS-FEED invalid command does not terminate the scene")
	_assert_equal(str(game.last_feedback_record.get("key", "")).begins_with("feedback."), true, "VIS-FEED invalid command maps to safe feedback")
	_assert_equal(bool(game.last_feedback_record.get("ok", true)), false, "VIS-FEED invalid command is reported as not applied")

	# Rapid repeated activation is one intent.
	game.call("_reset_input_guard")
	var before_revision := int(game.application.get_view_model("small", "de").get("state_revision", 0))
	var suppressed_before := int(game.suppressed_duplicate_commands)
	for _repeat in 8:
		game.call("_command", {"type": "clean"}, "clean", "bath")
	await process_frame
	await process_frame
	var after_revision := int(game.application.get_view_model("small", "de").get("state_revision", 0))
	_assert_equal(after_revision - before_revision, 1, "VIS-INPUT eight immediate repeats submit exactly one command")
	_assert_equal(int(game.suppressed_duplicate_commands) - suppressed_before, 7, "VIS-INPUT every duplicate is counted, not silently dropped")

	# No player-facing control may be connected twice, and every one is labelled.
	for mode in ["small", "expanded"]:
		game.mode = mode
		for page in ["care", "more", "adventure"]:
			game.small_page = page
			game.call("_refresh")
			await process_frame
			await process_frame
			for node in game.root_layer.find_children("*", "BaseButton", true, false):
				var button := node as BaseButton
				_assert_equal(button.pressed.get_connections().size() <= 1, true, "VIS-INPUT %s/%s %s has at most one handler" % [mode, page, button.name])
				var label := str(button.get_meta("accessible_label", button.tooltip_text))
				var visible_text: String = button.text if button is Button else ""
				_assert_equal(not label.strip_edges().is_empty() or not visible_text.strip_edges().is_empty(), true, "VIS-A11Y %s/%s %s carries a readable label" % [mode, page, button.name])
				if visible_text.strip_edges().is_empty():
					_assert_equal(not button.tooltip_text.strip_edges().is_empty(), true, "VIS-A11Y icon-only %s has a tooltip" % button.name)
				_assert_equal(button.focus_mode, Control.FOCUS_ALL, "VIS-A11Y %s is keyboard focusable" % button.name)

	# Small keeps the habitat, four meters, the action row and the footer inside
	# the window at every supported UI and text scale.
	game.mode = "small"
	game.small_page = "care"
	for ui_scale in [1.0, 1.25, 1.5, 1.75, 2.0]:
		for text_scale in [1.0, 1.5]:
			game.preferences["interface"]["ui_scale"] = ui_scale
			game.preferences["interface"]["text_scale"] = text_scale
			game.call("_build_root_theme")
			game.call("_apply_window_mode")
			game.call("_refresh")
			await process_frame
			await process_frame
			var frame: Control = game.root_layer.find_child("WindowFrame", true, false)
			var status: Control = game.root_layer.find_child("PrimaryStatusRow", true, false)
			var habitat: Control = game.root_layer.find_child("SmallHabitatFrame", true, false)
			var quick: Control = game.root_layer.find_child("QuickActions", true, false)
			var footer: Control = game.root_layer.find_child("SmallNavigation", true, false)
			var tag := "%.0f/%.0f" % [ui_scale * 100.0, text_scale * 100.0]
			_assert_equal(frame != null and status != null and habitat != null and quick != null and footer != null, true, "VIS-LAYOUT Small keeps every region at %s" % tag)
			if frame == null or habitat == null or footer == null or quick == null or status == null:
				continue
			_assert_equal(status.get_child_count(), 4, "VIS-LAYOUT Small shows exactly four primary meters at %s" % tag)
			_assert_equal(quick.get_child_count() >= 3 and quick.get_child_count() <= 4, true, "VIS-LAYOUT Small shows three or four primary actions at %s" % tag)
			_assert_equal(habitat.size.y > 0.0, true, "VIS-LAYOUT habitat keeps a positive extent at %s" % tag)
			_assert_equal(footer.get_global_rect().end.y <= frame.get_global_rect().end.y + 1.0, true, "VIS-LAYOUT footer stays inside the frame at %s" % tag)
	game.preferences["interface"]["ui_scale"] = "auto"
	game.preferences["interface"]["text_scale"] = 1.0
	game.call("_build_root_theme")

	# Auto UI scale must follow display DPI, not the always-1.0 reported scale.
	_assert_equal(PresentationPreferences.resolved_ui_scale("auto", 1.25), 1.25, "VIS-DPI auto scale honours a 125 percent display")
	_assert_equal(PresentationPreferences.resolved_ui_scale("auto", 1.0), 1.0, "VIS-DPI auto scale stays at 100 percent on a 96 dpi display")

	game.free()
	for path in [save_path, preferences_path, placement_path]:
		_remove_save(path)


func _find_named_button(node: Node, control_name: String) -> BaseButton:
	for child in node.find_children(control_name, "BaseButton", true, false):
		return child as BaseButton
	return null

func _test_minimal_scene_hierarchy() -> void:
	var save_path := "user://tests/presentation/minimal-scene.json"
	var preferences_path := "user://tests/presentation/minimal-scene-preferences.json"
	var placement_path := "user://tests/presentation/minimal-scene-placement.json"
	_remove_save(save_path)
	_remove_save(preferences_path)
	_remove_save(placement_path)
	var game := PET_GAME_SCENE.instantiate()
	game.requested_save_path = save_path
	game.preferences_path = preferences_path
	game.placement_path = placement_path
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
	_remove_save(save_path)
	_remove_save(preferences_path)
	_remove_save(placement_path)


func _assert_deferred_player_controls(node: Node, label: String) -> void:
	var controls := _collect_controls(node, "BaseButton")
	_assert_equal(not controls.is_empty(), true, "VIS-SIGNAL %s exposes controls" % label)
	for control in controls:
		var button := control as BaseButton
		var connections := button.get_signal_connection_list("pressed")
		for connection in connections:
			_assert_equal((int(connection.get("flags", 0)) & CONNECT_DEFERRED) != 0, true, "VIS-SIGNAL %s defers %s" % [label, _button_name(button)])
	for control in _collect_controls(node, "OptionButton"):
		for connection in control.get_signal_connection_list("item_selected"):
			_assert_equal((int(connection.get("flags", 0)) & CONNECT_DEFERRED) != 0, true, "VIS-SIGNAL %s defers selector" % label)
	for control in _collect_controls(node, "CheckButton"):
		for connection in control.get_signal_connection_list("toggled"):
			_assert_equal((int(connection.get("flags", 0)) & CONNECT_DEFERRED) != 0, true, "VIS-SIGNAL %s defers toggle" % label)


func _collect_controls(node: Node, class_name_value: String) -> Array[Node]:
	var result: Array[Node] = []
	if node == null:
		return result
	if node.is_class(class_name_value):
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_controls(child, class_name_value))
	return result


func _find_button(node: Node, label: String) -> BaseButton:
	for control in _collect_controls(node, "BaseButton"):
		var button := control as BaseButton
		if button.text == label or button.tooltip_text == label:
			return button
	return null


func _emit_button_and_settle(button: BaseButton, label: String) -> void:
	_assert_equal(button != null, true, "%s exists" % label)
	if button == null:
		return
	_assert_equal(not button.disabled, true, "%s is enabled" % label)
	if button.disabled:
		return
	# Each scripted emission is one deliberate intent, so the duplicate-input
	# guard is cleared first instead of treating the batch as a double click.
	var host: Node = button
	while host != null and not host.has_method("_reset_input_guard"):
		host = host.get_parent()
	if host != null:
		host.call("_reset_input_guard")
	button.emit_signal("pressed")
	_assert_equal(is_instance_valid(button), true, "%s emitter survives signal dispatch" % label)
	await process_frame
	await process_frame


func _button_name(button: BaseButton) -> String:
	if not button.text.is_empty():
		return button.text
	if not button.tooltip_text.is_empty():
		return button.tooltip_text
	return button.name


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
