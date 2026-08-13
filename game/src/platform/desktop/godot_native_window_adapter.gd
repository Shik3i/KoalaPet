class_name GodotNativeWindowAdapter
extends DesktopWindowAdapter

var _status_indicator: StatusIndicator
var _status_menu: PopupMenu
var _status_actions: Dictionary = {}
var _input_policy := INPUT_INTERACTIVE
var _focus_policy := FOCUS_NORMAL
var supported_host_os := ""


func _init(window: Window = null, host_os := "") -> void:
	super(window)
	supported_host_os = host_os


func detect_capabilities() -> OverlayCapabilities:
	var supported := is_host_supported()
	var capabilities := OverlayCapabilities.new()
	capabilities.native_windows = supported
	capabilities.transparency = supported and bool(ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed", false))
	capabilities.always_on_top = supported
	capabilities.full_mouse_passthrough = supported
	capabilities.polygonal_mouse_passthrough = supported
	capabilities.no_focus = supported
	capabilities.native_drag = supported
	capabilities.status_indicator = supported and ClassDB.class_exists("StatusIndicator")
	capabilities.monitor_enumeration = supported
	capabilities.usable_rect = supported
	capabilities.dpi_query = supported
	# Godot 4.7 exposes no high-level taskbar/Alt+Tab visibility flag.
	capabilities.taskbar_visibility_control = false
	capabilities.alt_tab_visibility_control = false
	return capabilities


func is_host_supported() -> bool:
	return (
		not supported_host_os.is_empty()
		and OS.get_name() == supported_host_os
		and DisplayServer.get_name() != "headless"
	)


func enumerate_monitors() -> Array[OverlayMonitorInfo]:
	var monitors: Array[OverlayMonitorInfo] = []
	if not is_host_supported():
		return monitors
	for screen_index in DisplayServer.get_screen_count():
		monitors.append(OverlayMonitorInfo.from_display(screen_index))
	return monitors


func apply_mode(mode: int, requested_placement: OverlayPlacement) -> OverlayApplyResult:
	var guard := _guard("apply_mode")
	if guard != null:
		return guard
	var placement := requested_placement.duplicate_value()
	placement.mode = mode
	if mode != WindowPresentationMode.Value.EXPANDED:
		placement.size = WindowPresentationMode.default_size(mode)
	elif placement.size.x <= 0 or placement.size.y <= 0:
		placement.size = WindowPresentationMode.default_size(mode)
	placement = sanitize_placement(placement)

	target_window.mode = Window.MODE_WINDOWED
	target_window.borderless = true
	target_window.transparent = true
	target_window.transparent_bg = true
	target_window.unresizable = mode != WindowPresentationMode.Value.EXPANDED
	target_window.size = placement.size
	target_window.position = placement.absolute_position
	target_window.show()

	if mode == WindowPresentationMode.Value.MINIMAL:
		set_focus_policy(FOCUS_NO_FOCUS)
	else:
		set_focus_policy(FOCUS_NORMAL)
		set_input_policy(INPUT_INTERACTIVE)

	return OverlayApplyResult.ok(
		"Applied %s using one native Window" % WindowPresentationMode.label(mode),
		["native_window", "transparent_viewport", "borderless", "placement"]
	)


func set_transparency(enabled: bool) -> OverlayApplyResult:
	var guard := _guard("set_transparency")
	if guard != null:
		return guard
	target_window.transparent = enabled
	target_window.transparent_bg = enabled
	return OverlayApplyResult.ok("Transparency request applied", ["transparency"])


func set_always_on_top(enabled: bool) -> OverlayApplyResult:
	var guard := _guard("set_always_on_top")
	if guard != null:
		return guard
	target_window.always_on_top = enabled
	return OverlayApplyResult.ok("Always-on-top request applied", ["always_on_top"])


func set_focus_policy(policy: String) -> OverlayApplyResult:
	var guard := _guard("set_focus_policy")
	if guard != null:
		return guard
	if policy not in [FOCUS_NORMAL, FOCUS_NO_FOCUS]:
		return OverlayApplyResult.failure("INVALID_FOCUS_POLICY", "Unknown focus policy: %s" % policy)
	_focus_policy = policy
	target_window.unfocusable = policy == FOCUS_NO_FOCUS
	return OverlayApplyResult.ok("Focus policy applied: %s" % policy, ["no_focus"])


func set_input_policy(policy: String) -> OverlayApplyResult:
	var guard := _guard("set_input_policy")
	if guard != null:
		return guard
	if policy not in [INPUT_INTERACTIVE, INPUT_FULL_PASSTHROUGH, INPUT_HIT_REGION]:
		return OverlayApplyResult.failure("INVALID_INPUT_POLICY", "Unknown input policy: %s" % policy)
	_input_policy = policy
	match policy:
		INPUT_INTERACTIVE:
			target_window.mouse_passthrough = false
			target_window.mouse_passthrough_polygon = PackedVector2Array()
		INPUT_FULL_PASSTHROUGH:
			target_window.mouse_passthrough_polygon = PackedVector2Array()
			target_window.mouse_passthrough = true
		INPUT_HIT_REGION:
			target_window.mouse_passthrough = false
	return OverlayApplyResult.ok("Input policy applied: %s" % policy, [policy])


func set_hit_regions(regions: Array[OverlayHitRegion]) -> OverlayApplyResult:
	var guard := _guard("set_hit_regions")
	if guard != null:
		return guard
	if regions.is_empty() or regions[0].is_empty():
		target_window.mouse_passthrough_polygon = PackedVector2Array()
		return OverlayApplyResult.failure("EMPTY_HIT_REGION", "At least one non-empty polygon is required")
	var polygon := regions[0].polygons[0]
	target_window.mouse_passthrough = false
	target_window.mouse_passthrough_polygon = polygon
	_input_policy = INPUT_HIT_REGION
	if regions.size() > 1 or regions[0].polygons.size() > 1:
		return OverlayApplyResult.limited(
			"Godot 4.7 accepts one passthrough polygon; only the first region was applied",
			["polygonal_mouse_passthrough"]
		)
	return OverlayApplyResult.ok("Hit region applied", ["polygonal_mouse_passthrough"])


func begin_native_drag() -> OverlayApplyResult:
	var guard := _guard("begin_native_drag")
	if guard != null:
		return guard
	target_window.start_drag()
	return OverlayApplyResult.ok("Native drag started", ["native_drag"])


func set_position(new_position: Vector2i) -> OverlayApplyResult:
	var guard := _guard("set_position")
	if guard != null:
		return guard
	target_window.position = new_position
	return OverlayApplyResult.ok("Window position applied", ["position"])


func set_size(new_size: Vector2i) -> OverlayApplyResult:
	var guard := _guard("set_size")
	if guard != null:
		return guard
	if new_size.x <= 0 or new_size.y <= 0:
		return OverlayApplyResult.failure("INVALID_SIZE", "Window size must be positive")
	target_window.size = new_size
	return OverlayApplyResult.ok("Window size applied", ["size"])


func get_current_placement(mode: int) -> OverlayPlacement:
	var placement := OverlayPlacement.new()
	placement.mode = mode
	if target_window == null:
		return placement
	placement.absolute_position = target_window.position
	placement.size = target_window.size
	placement.monitor_index = target_window.current_screen
	for monitor in enumerate_monitors():
		if monitor.index == placement.monitor_index:
			placement.normalized_position = OverlayPlacementSanitizer.normalized_position(placement.absolute_position, placement.size, monitor.usable_rect)
			placement.saved_scale = monitor.scale
			placement.saved_dpi = monitor.dpi
			break
	placement.timestamp = Time.get_datetime_string_from_system(true)
	return placement


func hide_window() -> OverlayApplyResult:
	var guard := _guard("hide_window")
	if guard != null:
		return guard
	var scene_tree := target_window.get_tree()
	if scene_tree != null and target_window == scene_tree.root:
		return OverlayApplyResult.failure("MAIN_WINDOW_HIDE_UNSUPPORTED", "Godot 4.7 cannot change visibility of the main Window")
	target_window.hide()
	return OverlayApplyResult.ok("Window hidden", ["hide"])


func show_window() -> OverlayApplyResult:
	var guard := _guard("show_window")
	if guard != null:
		return guard
	target_window.show()
	return OverlayApplyResult.ok("Window shown without explicit focus request", ["show"])


func minimize_window() -> OverlayApplyResult:
	var guard := _guard("minimize_window")
	if guard != null:
		return guard
	target_window.mode = Window.MODE_MINIMIZED
	return OverlayApplyResult.ok("Window minimize requested", ["minimize"])


func restore_window() -> OverlayApplyResult:
	var guard := _guard("restore_window")
	if guard != null:
		return guard
	target_window.mode = Window.MODE_WINDOWED
	target_window.show()
	return OverlayApplyResult.ok("Window restore requested", ["restore"])


func reset_to_safe_default(mode: int) -> OverlayApplyResult:
	var placement := OverlayPlacement.new()
	placement.mode = mode
	placement.size = WindowPresentationMode.default_size(mode)
	placement.monitor_index = DisplayServer.get_primary_screen()
	placement.normalized_position = Vector2.ONE
	placement.absolute_position = Vector2i(2_000_000, 2_000_000)
	return apply_mode(mode, sanitize_placement(placement))


func create_status_indicator(actions: Dictionary) -> OverlayApplyResult:
	var guard := _guard("create_status_indicator")
	if guard != null:
		return guard
	remove_status_indicator()
	_status_actions.clear()
	_status_menu = PopupMenu.new()
	_status_menu.name = "OverlaySpikeStatusMenu"
	_status_menu.prefer_native_menu = true
	target_window.add_child(_status_menu)
	var item_id := 1
	for label in actions:
		var callback: Callable = actions[label]
		if not callback.is_valid():
			continue
		_status_actions[item_id] = callback
		_status_menu.add_item(str(label), item_id)
		item_id += 1
	_status_menu.id_pressed.connect(_on_status_menu_id_pressed)

	_status_indicator = StatusIndicator.new()
	_status_indicator.name = "OverlaySpikeStatusIndicator"
	_status_indicator.tooltip = "KoalaPet desktop overlay spike"
	_status_indicator.icon = _create_status_icon()
	target_window.add_child(_status_indicator)
	_status_indicator.menu = _status_indicator.get_path_to(_status_menu)
	return OverlayApplyResult.ok("Status indicator created", ["status_indicator", "native_menu"])


func update_status_indicator(tooltip: String) -> OverlayApplyResult:
	if _status_indicator == null or not is_instance_valid(_status_indicator):
		return OverlayApplyResult.failure("STATUS_INDICATOR_MISSING", "Status indicator has not been created")
	_status_indicator.tooltip = tooltip
	return OverlayApplyResult.ok("Status indicator updated", ["status_indicator"])


func remove_status_indicator() -> OverlayApplyResult:
	if _status_indicator != null and is_instance_valid(_status_indicator):
		_status_indicator.queue_free()
	if _status_menu != null and is_instance_valid(_status_menu):
		_status_menu.queue_free()
	_status_indicator = null
	_status_menu = null
	_status_actions.clear()
	return OverlayApplyResult.ok("Status indicator removed", ["status_indicator_cleanup"])


func capture_diagnostics() -> Dictionary:
	var monitor_data: Array[Dictionary] = []
	for monitor in enumerate_monitors():
		monitor_data.append(monitor.to_dict())
	var polygon: Array[Array] = []
	if target_window != null:
		for point in target_window.mouse_passthrough_polygon:
			polygon.append([point.x, point.y])
	var status_rect = null
	var status_visible := false
	if _status_indicator != null and is_instance_valid(_status_indicator):
		var rect := _status_indicator.get_rect()
		status_rect = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		status_visible = _status_indicator.visible
	return {
		"schema_version": 1,
		"captured_at_utc": Time.get_datetime_string_from_system(true),
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"adapter_host_os": supported_host_os,
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"engine_max_fps": Engine.max_fps,
		"observed_fps": Engine.get_frames_per_second(),
		"window_position": [target_window.position.x, target_window.position.y] if target_window != null else null,
		"window_size": [target_window.size.x, target_window.size.y] if target_window != null else null,
		"window_focused": target_window.has_focus() if target_window != null else false,
		"window_mode": target_window.mode if target_window != null else null,
		"window_visible": target_window.visible if target_window != null else false,
		"window_borderless": target_window.borderless if target_window != null else false,
		"window_transparent": target_window.transparent if target_window != null else false,
		"viewport_transparent_bg": target_window.transparent_bg if target_window != null else false,
		"window_always_on_top": target_window.always_on_top if target_window != null else false,
		"window_unfocusable": target_window.unfocusable if target_window != null else false,
		"window_mouse_passthrough": target_window.mouse_passthrough if target_window != null else false,
		"window_mouse_passthrough_polygon": polygon,
		"status_indicator_visible": status_visible,
		"status_indicator_rect": status_rect,
		"input_policy": _input_policy,
		"focus_policy": _focus_policy,
		"capabilities": detect_capabilities().to_dict(),
		"monitors": monitor_data,
	}


func _guard(operation: String) -> OverlayApplyResult:
	if not is_host_supported():
		if DisplayServer.get_name() == "headless":
			return OverlayApplyResult.failure("BLOCKED_NON_NATIVE_DISPLAY", "%s requires an interactive %s display; current display server is headless" % [operation, supported_host_os])
		return OverlayApplyResult.failure("BLOCKED_WRONG_HOST", "%s requires an interactive %s host; current host is %s" % [operation, supported_host_os, OS.get_name()])
	if target_window == null:
		return OverlayApplyResult.failure("WINDOW_MISSING", "%s requires a target Window" % operation)
	return null


func _on_status_menu_id_pressed(item_id: int) -> void:
	var callback: Callable = _status_actions.get(item_id, Callable())
	if callback.is_valid():
		callback.call()


func _create_status_icon() -> ImageTexture:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(16, 16)
	for y in 32:
		for x in 32:
			var distance := Vector2(x, y).distance_to(center)
			if distance <= 12.0:
				image.set_pixel(x, y, Color("78d6b0"))
			if distance <= 6.0:
				image.set_pixel(x, y, Color("20353c"))
	return ImageTexture.create_from_image(image)
