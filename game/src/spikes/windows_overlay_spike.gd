class_name DesktopOverlaySpike
extends Control

const INTERACTION_SECONDS := 10.0

var adapter: DesktopWindowAdapter
var mode_controller: WindowModeController
var placeholder: OverlaySpikePlaceholder
var debug_panel: PanelContainer
var debug_label: Label
var technical_panel: PanelContainer
var toolbar: HBoxContainer
var interaction_timer: Timer
var current_input_policy := DesktopWindowAdapter.INPUT_INTERACTIVE
var always_on_top := false
var last_result := OverlayApplyResult.ok("Spike initialized")
var _placement_load_reason := ""
var event_history: Array[Dictionary] = []
var overlay_click_count := 0
var hit_region_update_count := 0
var evidence_auto := false
var _evidence_elapsed := 0.0
var _debug_elapsed := 0.0


func _ready() -> void:
	set_process(true)
	set_process_unhandled_key_input(true)
	get_window().title = "KoalaPet Overlay Spike [%s]" % OS.get_name()
	get_window().close_requested.connect(_quit_spike)
	adapter = DesktopWindowAdapterFactory.create_for_current_host(get_window())
	mode_controller = WindowModeController.new(adapter)
	_build_interface()
	_load_placements()
	if adapter.is_host_supported():
		_initialize_native_host.call_deferred()
	else:
		var block_code := "BLOCKED_NON_NATIVE_DISPLAY" if DisplayServer.get_name() == "headless" else "BLOCKED_UNSUPPORTED_HOST"
		last_result = OverlayApplyResult.failure(block_code, "Interactive native validation is unavailable on %s using %s" % [OS.get_name(), DisplayServer.get_name()])
		_apply_preview_layout(WindowPresentationMode.Value.SMALL)
		_record_event("ready", {"adapter_host": OS.get_name(), "supported": false})
	_update_debug_text()
	queue_redraw()


func _initialize_native_host() -> void:
	if adapter.detect_capabilities().status_indicator:
		_create_status_indicator()
	_apply_mode(mode_controller.current_mode)
	_apply_user_arguments()
	_record_event("ready", {"adapter_host": OS.get_name(), "supported": true})


func _process(delta: float) -> void:
	_debug_elapsed += delta
	if debug_panel.visible and _debug_elapsed >= 0.25:
		_debug_elapsed = 0.0
		_update_debug_text()
	if evidence_auto:
		_evidence_elapsed += delta
		if _evidence_elapsed >= 1.0:
			_evidence_elapsed = 0.0
			OverlaySpikeReporter.write_diagnostics(adapter, _diagnostic_extra())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		overlay_click_count += 1
		_record_event("overlay_click", {"button": event.button_index, "position": [event.position.x, event.position.y]})


func _draw() -> void:
	match mode_controller.current_mode:
		WindowPresentationMode.Value.MINIMAL:
			pass
		WindowPresentationMode.Value.SMALL:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.075, 0.09, 0.96), true)
			draw_rect(Rect2(12, 48, maxf(0.0, size.x - 24), maxf(0.0, size.y - 60)), Color(0.10, 0.16, 0.18, 0.92), true)
		WindowPresentationMode.Value.EXPANDED:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.06, 0.075, 0.97), true)
			draw_rect(Rect2(16, 56, maxf(0.0, size.x - 32), maxf(0.0, size.y - 72)), Color(0.09, 0.12, 0.15, 0.94), true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_F1:
			_apply_mode(WindowPresentationMode.Value.MINIMAL)
		KEY_F2:
			_apply_mode(WindowPresentationMode.Value.SMALL)
		KEY_F3:
			_apply_mode(WindowPresentationMode.Value.EXPANDED)
		KEY_F4:
			debug_panel.visible = not debug_panel.visible
		KEY_F5:
			_temporarily_enable_interaction()
		KEY_F6:
			last_result = adapter.reset_to_safe_default(mode_controller.current_mode)
		KEY_F7:
			_toggle_always_on_top()
		KEY_F8:
			_cycle_input_policy()
		KEY_F9:
			_capture_diagnostics()
		KEY_F10:
			_minimize_window()
		KEY_F11:
			_hide_window()
		KEY_ESCAPE:
			_quit_spike()


func _build_interface() -> void:
	placeholder = OverlaySpikePlaceholder.new()
	placeholder.name = "TechnicalPlaceholder"
	placeholder.hit_region_changed.connect(_on_hit_region_changed)
	add_child(placeholder)

	technical_panel = PanelContainer.new()
	technical_panel.name = "TechnicalPanel"
	technical_panel.position = Vector2(250, 64)
	technical_panel.size = Vector2(210, 120)
	var technical_label := Label.new()
	technical_label.text = "TECHNICAL FOOTPRINT\nPanel A   Panel B\nInput and resize targets"
	technical_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	technical_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	technical_panel.add_child(technical_label)
	add_child(technical_panel)

	toolbar = HBoxContainer.new()
	toolbar.name = "SpikeToolbar"
	toolbar.position = Vector2(12, 10)
	toolbar.add_child(_button("Minimal [F1]", func() -> void: _apply_mode(WindowPresentationMode.Value.MINIMAL)))
	toolbar.add_child(_button("Small [F2]", func() -> void: _apply_mode(WindowPresentationMode.Value.SMALL)))
	toolbar.add_child(_button("Expanded [F3]", func() -> void: _apply_mode(WindowPresentationMode.Value.EXPANDED)))
	toolbar.add_child(_drag_button("Drag"))
	toolbar.add_child(_button("Reset [F6]", func() -> void: last_result = adapter.reset_to_safe_default(mode_controller.current_mode)))
	add_child(toolbar)

	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(12, 190)
	debug_panel.size = Vector2(620, 300)
	debug_label = Label.new()
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_panel.add_child(debug_label)
	add_child(debug_panel)

	interaction_timer = Timer.new()
	interaction_timer.one_shot = true
	interaction_timer.wait_time = INTERACTION_SECONDS
	interaction_timer.timeout.connect(_restore_minimal_guarded_input)
	add_child(interaction_timer)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _drag_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.button_down.connect(_begin_drag)
	return button


func _load_placements() -> void:
	var loaded := OverlayPlacementStore.load_envelope()
	_placement_load_reason = loaded.reason
	var data: Dictionary = loaded.data
	mode_controller.current_mode = WindowPresentationMode.from_label(str(data.get("last_mode", "SMALL")))
	mode_controller.restore_placements(data.get("placements", {}))
	always_on_top = bool(data.get("always_on_top", false))


func _save_placements() -> void:
	if adapter.is_host_supported():
		mode_controller.remember_placement(adapter.get_current_placement(mode_controller.current_mode))
	var envelope := {
		"version": OverlayPlacementStore.VERSION,
		"last_mode": WindowPresentationMode.label(mode_controller.current_mode),
		"always_on_top": always_on_top,
		"placements": mode_controller.serialize_placements(),
	}
	last_result = OverlayPlacementStore.save_envelope(envelope)


func _apply_mode(mode: int) -> void:
	if not adapter.is_host_supported():
		mode_controller.current_mode = mode
		_apply_preview_layout(mode)
		return
	last_result = mode_controller.transition_to(mode)
	if not last_result.success:
		return
	_apply_preview_layout(mode)
	adapter.set_always_on_top(always_on_top)
	if mode == WindowPresentationMode.Value.MINIMAL:
		current_input_policy = DesktopWindowAdapter.INPUT_HIT_REGION
		adapter.set_input_policy(current_input_policy)
		adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "mode-transition")])
	else:
		current_input_policy = DesktopWindowAdapter.INPUT_INTERACTIVE
		adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NORMAL)
		adapter.set_input_policy(current_input_policy)
	adapter.update_status_indicator("KoalaPet overlay spike — %s" % WindowPresentationMode.label(mode))
	_record_event("mode", {"value": WindowPresentationMode.label(mode)})
	_save_placements()


func _apply_preview_layout(mode: int) -> void:
	mode_controller.current_mode = mode
	technical_panel.visible = mode != WindowPresentationMode.Value.MINIMAL
	debug_panel.visible = mode != WindowPresentationMode.Value.MINIMAL
	toolbar.visible = mode != WindowPresentationMode.Value.MINIMAL
	placeholder.lane_width = 100.0 if mode == WindowPresentationMode.Value.MINIMAL else 180.0
	queue_redraw()


func _on_hit_region_changed(region: OverlayHitRegion) -> void:
	hit_region_update_count += 1
	if adapter.is_host_supported() and mode_controller.current_mode == WindowPresentationMode.Value.MINIMAL and current_input_policy == DesktopWindowAdapter.INPUT_HIT_REGION:
		last_result = adapter.set_hit_regions([region])


func _temporarily_enable_interaction() -> void:
	if not adapter.is_host_supported():
		return
	adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NORMAL)
	last_result = adapter.set_input_policy(DesktopWindowAdapter.INPUT_INTERACTIVE)
	current_input_policy = DesktopWindowAdapter.INPUT_INTERACTIVE
	_record_event("temporary_interaction", {"seconds": INTERACTION_SECONDS})
	interaction_timer.start()


func _restore_minimal_guarded_input() -> void:
	if mode_controller.current_mode != WindowPresentationMode.Value.MINIMAL:
		return
	adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NO_FOCUS)
	current_input_policy = DesktopWindowAdapter.INPUT_HIT_REGION
	adapter.set_input_policy(current_input_policy)
	last_result = adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "interaction-timeout")])
	_record_event("interaction_timeout", {"input": current_input_policy})


func _cycle_input_policy() -> void:
	if not adapter.is_host_supported() or mode_controller.current_mode != WindowPresentationMode.Value.MINIMAL:
		return
	match current_input_policy:
		DesktopWindowAdapter.INPUT_INTERACTIVE:
			current_input_policy = DesktopWindowAdapter.INPUT_HIT_REGION
			last_result = adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "manual-cycle")])
		DesktopWindowAdapter.INPUT_HIT_REGION:
			current_input_policy = DesktopWindowAdapter.INPUT_FULL_PASSTHROUGH
			last_result = adapter.set_input_policy(current_input_policy)
		_:
			current_input_policy = DesktopWindowAdapter.INPUT_INTERACTIVE
			last_result = adapter.set_input_policy(current_input_policy)
	_record_event("input_policy", {"value": current_input_policy})


func _toggle_always_on_top() -> void:
	always_on_top = not always_on_top
	last_result = adapter.set_always_on_top(always_on_top)
	_record_event("always_on_top", {"enabled": always_on_top})


func _begin_drag() -> void:
	last_result = adapter.begin_native_drag()
	_record_event("native_drag_requested")


func _create_status_indicator() -> void:
	last_result = adapter.create_status_indicator({
		"Show Small Mode": func() -> void: _apply_mode(WindowPresentationMode.Value.SMALL),
		"Show Expanded Mode": func() -> void: _apply_mode(WindowPresentationMode.Value.EXPANDED),
		"Toggle Always on Top": _toggle_always_on_top,
		"Temporarily Enable Interaction": _temporarily_enable_interaction,
		"Reset Window Position": func() -> void: last_result = adapter.reset_to_safe_default(mode_controller.current_mode),
		"Capture Diagnostics": _capture_diagnostics,
		"Minimize Window": _minimize_window,
		"Hide Window": _hide_window,
		"Quit Spike": _quit_spike,
	})
	_record_event("status_indicator_created")


func _update_debug_text() -> void:
	if debug_label == null:
		return
	var diagnostics := adapter.capture_diagnostics()
	debug_label.text = "MODE: %s\nHOST: %s %s\nWINDOW: pos=%s size=%s focused=%s\nDISPLAY: %s renderer=%s adapter=%s\nINPUT: %s focus_policy=%s hit_bounds=%s\nALWAYS_ON_TOP: %s\nPLACEMENT_LOAD: %s\nRESULT: success=%s degraded=%s code=%s reason=%s\nSHORTCUTS: F1/F2/F3 modes · F4 debug · F5 interaction · F6 reset · F7 top · F8 input · F9 evidence · F10 minimize · F11 hide · Esc quit" % [
		WindowPresentationMode.label(mode_controller.current_mode),
		diagnostics.get("os_name", OS.get_name()), diagnostics.get("os_version", OS.get_version()),
		diagnostics.get("window_position", null), diagnostics.get("window_size", null), diagnostics.get("window_focused", false),
		diagnostics.get("display_server", DisplayServer.get_name()), diagnostics.get("rendering_method", "unknown"), diagnostics.get("video_adapter", "unknown"),
		current_input_policy, diagnostics.get("focus_policy", "unknown"), OverlayHitRegion.single(placeholder.window_hit_polygon()).bounds(),
		always_on_top, _placement_load_reason,
		last_result.success, last_result.degraded, last_result.error_code, last_result.reason,
	]


func _apply_user_arguments() -> void:
	if not adapter.is_host_supported():
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			_apply_mode(WindowPresentationMode.from_label(argument.trim_prefix("--mode=")))
		elif argument.begins_with("--input="):
			var policy := argument.trim_prefix("--input=")
			if policy == DesktopWindowAdapter.INPUT_HIT_REGION:
				current_input_policy = policy
				last_result = adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "command-line")])
			else:
				current_input_policy = policy
				last_result = adapter.set_input_policy(policy)
		elif argument.begins_with("--focus="):
			last_result = adapter.set_focus_policy(argument.trim_prefix("--focus="))
		elif argument == "--always-on-top":
			always_on_top = true
			last_result = adapter.set_always_on_top(true)
		elif argument == "--evidence-auto":
			evidence_auto = true
		elif argument.begins_with("--max-fps="):
			Engine.max_fps = maxi(0, int(argument.trim_prefix("--max-fps=")))
		elif argument.begins_with("--position="):
			var components := argument.trim_prefix("--position=").split(",")
			if components.size() == 2:
				last_result = adapter.set_position(Vector2i(int(components[0]), int(components[1])))
	_record_event("arguments_applied", {"arguments": OS.get_cmdline_user_args()})


func _capture_diagnostics() -> void:
	var result := OverlaySpikeReporter.write_diagnostics(adapter, _diagnostic_extra())
	last_result = result
	_record_event("diagnostics_written", {"path": OverlaySpikeReporter.DIAGNOSTICS_PATH, "success": result.success})


func _minimize_window() -> void:
	_record_event("minimize_requested")
	last_result = adapter.minimize_window()


func _hide_window() -> void:
	_record_event("hide_requested")
	last_result = adapter.hide_window()


func _diagnostic_extra() -> Dictionary:
	return {
		"presentation_mode": WindowPresentationMode.label(mode_controller.current_mode),
		"overlay_click_count": overlay_click_count,
		"hit_region_update_count": hit_region_update_count,
		"events": event_history.duplicate(true),
	}


func _record_event(label: String, details := {}) -> void:
	event_history.append({
		"timestamp": Time.get_datetime_string_from_system(true),
		"label": label,
		"details": details,
	})
	if event_history.size() > 100:
		event_history.pop_front()
	print("SPIKE_EVENT %s %s" % [label, JSON.stringify(details)])


func _quit_spike() -> void:
	_save_placements()
	_record_event("quit_requested")
	OverlaySpikeReporter.write_diagnostics(adapter, _diagnostic_extra())
	adapter.remove_status_indicator()
	get_tree().quit()
