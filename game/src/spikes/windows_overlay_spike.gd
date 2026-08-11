class_name WindowsOverlaySpike
extends Control

const INTERACTION_SECONDS := 10.0

var adapter: WindowsDesktopWindowAdapter
var mode_controller: WindowModeController
var placeholder: OverlaySpikePlaceholder
var debug_panel: PanelContainer
var debug_label: Label
var technical_panel: PanelContainer
var interaction_timer: Timer
var current_input_policy := WindowsDesktopWindowAdapter.INPUT_INTERACTIVE
var always_on_top := false
var last_result := OverlayApplyResult.ok("Spike initialized")
var _placement_load_reason := ""


func _ready() -> void:
	set_process(true)
	set_process_unhandled_key_input(true)
	get_window().close_requested.connect(_quit_spike)
	adapter = WindowsDesktopWindowAdapter.new(get_window())
	mode_controller = WindowModeController.new(adapter)
	_build_interface()
	_load_placements()
	if OS.get_name() == "Windows":
		_create_status_indicator()
		_apply_mode(mode_controller.current_mode)
	else:
		last_result = OverlayApplyResult.failure("BLOCKED_NOT_WINDOWS", "Interactive Windows validation is required; current host is %s" % OS.get_name())
		_apply_preview_layout(WindowPresentationMode.Value.SMALL)
	_update_debug_text()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_debug_text()


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

	var toolbar := HBoxContainer.new()
	toolbar.name = "SpikeToolbar"
	toolbar.position = Vector2(12, 10)
	toolbar.add_child(_button("Minimal [F1]", func() -> void: _apply_mode(WindowPresentationMode.Value.MINIMAL)))
	toolbar.add_child(_button("Small [F2]", func() -> void: _apply_mode(WindowPresentationMode.Value.SMALL)))
	toolbar.add_child(_button("Expanded [F3]", func() -> void: _apply_mode(WindowPresentationMode.Value.EXPANDED)))
	toolbar.add_child(_button("Drag", _begin_drag))
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


func _load_placements() -> void:
	var loaded := OverlayPlacementStore.load_envelope()
	_placement_load_reason = loaded.reason
	var data: Dictionary = loaded.data
	mode_controller.current_mode = WindowPresentationMode.from_label(str(data.get("last_mode", "SMALL")))
	mode_controller.restore_placements(data.get("placements", {}))
	always_on_top = bool(data.get("always_on_top", false))


func _save_placements() -> void:
	if OS.get_name() == "Windows":
		mode_controller.remember_placement(adapter.get_current_placement(mode_controller.current_mode))
	var envelope := {
		"version": OverlayPlacementStore.VERSION,
		"last_mode": WindowPresentationMode.label(mode_controller.current_mode),
		"always_on_top": always_on_top,
		"placements": mode_controller.serialize_placements(),
	}
	last_result = OverlayPlacementStore.save_envelope(envelope)


func _apply_mode(mode: int) -> void:
	if OS.get_name() != "Windows":
		mode_controller.current_mode = mode
		_apply_preview_layout(mode)
		return
	last_result = mode_controller.transition_to(mode)
	if not last_result.success:
		return
	_apply_preview_layout(mode)
	adapter.set_always_on_top(always_on_top)
	if mode == WindowPresentationMode.Value.MINIMAL:
		current_input_policy = WindowsDesktopWindowAdapter.INPUT_HIT_REGION
		adapter.set_input_policy(current_input_policy)
		adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "mode-transition")])
	else:
		current_input_policy = WindowsDesktopWindowAdapter.INPUT_INTERACTIVE
		adapter.set_focus_policy(WindowsDesktopWindowAdapter.FOCUS_NORMAL)
		adapter.set_input_policy(current_input_policy)
	adapter.update_status_indicator("KoalaPet overlay spike — %s" % WindowPresentationMode.label(mode))
	_save_placements()


func _apply_preview_layout(mode: int) -> void:
	mode_controller.current_mode = mode
	technical_panel.visible = mode != WindowPresentationMode.Value.MINIMAL
	debug_panel.visible = mode != WindowPresentationMode.Value.MINIMAL
	placeholder.lane_width = 100.0 if mode == WindowPresentationMode.Value.MINIMAL else 180.0
	queue_redraw()


func _on_hit_region_changed(region: OverlayHitRegion) -> void:
	if OS.get_name() == "Windows" and mode_controller.current_mode == WindowPresentationMode.Value.MINIMAL and current_input_policy == WindowsDesktopWindowAdapter.INPUT_HIT_REGION:
		last_result = adapter.set_hit_regions([region])


func _temporarily_enable_interaction() -> void:
	if OS.get_name() != "Windows":
		return
	adapter.set_focus_policy(WindowsDesktopWindowAdapter.FOCUS_NORMAL)
	last_result = adapter.set_input_policy(WindowsDesktopWindowAdapter.INPUT_INTERACTIVE)
	current_input_policy = WindowsDesktopWindowAdapter.INPUT_INTERACTIVE
	interaction_timer.start()


func _restore_minimal_guarded_input() -> void:
	if mode_controller.current_mode != WindowPresentationMode.Value.MINIMAL:
		return
	adapter.set_focus_policy(WindowsDesktopWindowAdapter.FOCUS_NO_FOCUS)
	current_input_policy = WindowsDesktopWindowAdapter.INPUT_HIT_REGION
	adapter.set_input_policy(current_input_policy)
	last_result = adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "interaction-timeout")])


func _cycle_input_policy() -> void:
	if OS.get_name() != "Windows" or mode_controller.current_mode != WindowPresentationMode.Value.MINIMAL:
		return
	match current_input_policy:
		WindowsDesktopWindowAdapter.INPUT_INTERACTIVE:
			current_input_policy = WindowsDesktopWindowAdapter.INPUT_HIT_REGION
			last_result = adapter.set_hit_regions([OverlayHitRegion.single(placeholder.window_hit_polygon(), placeholder.interaction_padding, "manual-cycle")])
		WindowsDesktopWindowAdapter.INPUT_HIT_REGION:
			current_input_policy = WindowsDesktopWindowAdapter.INPUT_FULL_PASSTHROUGH
			last_result = adapter.set_input_policy(current_input_policy)
		_:
			current_input_policy = WindowsDesktopWindowAdapter.INPUT_INTERACTIVE
			last_result = adapter.set_input_policy(current_input_policy)


func _toggle_always_on_top() -> void:
	always_on_top = not always_on_top
	last_result = adapter.set_always_on_top(always_on_top)


func _begin_drag() -> void:
	last_result = adapter.begin_native_drag()


func _create_status_indicator() -> void:
	last_result = adapter.create_status_indicator({
		"Show Small Mode": func() -> void: _apply_mode(WindowPresentationMode.Value.SMALL),
		"Show Expanded Mode": func() -> void: _apply_mode(WindowPresentationMode.Value.EXPANDED),
		"Toggle Always on Top": _toggle_always_on_top,
		"Temporarily Enable Interaction": _temporarily_enable_interaction,
		"Reset Window Position": func() -> void: last_result = adapter.reset_to_safe_default(mode_controller.current_mode),
		"Quit Spike": _quit_spike,
	})


func _update_debug_text() -> void:
	if debug_label == null:
		return
	var diagnostics := adapter.capture_diagnostics()
	debug_label.text = "MODE: %s\nHOST: %s %s\nWINDOW: pos=%s size=%s focused=%s\nDISPLAY: %s renderer=%s adapter=%s\nINPUT: %s focus_policy=%s hit_bounds=%s\nALWAYS_ON_TOP: %s\nPLACEMENT_LOAD: %s\nRESULT: success=%s degraded=%s code=%s reason=%s\nSHORTCUTS: F1/F2/F3 modes · F4 debug · F5 temporary interaction · F6 reset · F7 top · F8 input · Esc quit" % [
		WindowPresentationMode.label(mode_controller.current_mode),
		diagnostics.get("os_name", OS.get_name()), diagnostics.get("os_version", OS.get_version()),
		diagnostics.get("window_position", null), diagnostics.get("window_size", null), diagnostics.get("window_focused", false),
		diagnostics.get("display_server", DisplayServer.get_name()), diagnostics.get("rendering_method", "unknown"), diagnostics.get("video_adapter", "unknown"),
		current_input_policy, diagnostics.get("focus_policy", "unknown"), OverlayHitRegion.single(placeholder.window_hit_polygon()).bounds(),
		always_on_top, _placement_load_reason,
		last_result.success, last_result.degraded, last_result.error_code, last_result.reason,
	]


func _quit_spike() -> void:
	_save_placements()
	OverlaySpikeReporter.write_diagnostics(adapter)
	adapter.remove_status_indicator()
	get_tree().quit()
