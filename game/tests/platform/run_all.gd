extends SceneTree

class FakeAdapter extends DesktopWindowAdapter:
	var monitors: Array[OverlayMonitorInfo] = []
	var current := OverlayPlacement.new()
	var apply_count := 0

	func _init(test_monitors: Array[OverlayMonitorInfo]) -> void:
		monitors = test_monitors

	func enumerate_monitors() -> Array[OverlayMonitorInfo]:
		return monitors

	func apply_mode(mode: int, requested: OverlayPlacement) -> OverlayApplyResult:
		current = OverlayPlacementSanitizer.sanitize(requested, monitors)
		current.mode = mode
		apply_count += 1
		return OverlayApplyResult.ok("Fake mode applied")

	func get_current_placement(mode: int) -> OverlayPlacement:
		var result := current.duplicate_value()
		result.mode = mode
		return result


var _failures: Array[String] = []
var _assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("KoalaPet platform-neutral overlay tests")
	print("ENV: os=%s version=%s display_server=%s rendering_method=%s rendering_driver=%s video_adapter=%s" % [
		OS.get_name(), OS.get_version(), DisplayServer.get_name(),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(),
	])
	_test_monitor_geometry()
	_test_valid_placement()
	_test_partial_and_full_offscreen_recovery()
	_test_negative_coordinate_monitor()
	_test_removed_monitor_fallback()
	_test_resolution_and_taskbar_changes()
	_test_oversized_window()
	_test_corrupted_and_future_store()
	_test_per_mode_persistence()
	_test_mode_transition_invariants()
	_test_mode_switch_near_edge()
	_test_hit_region_bounds()
	if _failures.is_empty():
		print("RESULT: PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("RESULT: FAIL (%d failures, %d assertions)" % [_failures.size(), _assertions])
		quit(1)


func _test_monitor_geometry() -> void:
	var monitors := _standard_monitors()
	_assert_equal(monitors.size(), 2, "GEO-001 monitor inventory")
	_assert_equal(monitors[1].full_rect.position, Vector2i(-1280, 0), "GEO-002 negative virtual-desktop coordinate")
	_assert_equal(OverlayPlacementSanitizer.intersection_area(Rect2i(-100, 0, 200, 100), Rect2i(0, 0, 200, 100)), 10000, "GEO-003 intersection area")


func _test_valid_placement() -> void:
	var placement := _placement(WindowPresentationMode.Value.SMALL, 0, Vector2i(100, 120), Vector2i(480, 240))
	var result := OverlayPlacementSanitizer.sanitize(placement, _standard_monitors())
	_assert_equal(result.absolute_position, Vector2i(100, 120), "PST-001 valid position retained")
	_assert_equal(result.size, Vector2i(480, 240), "PST-002 valid size retained")


func _test_partial_and_full_offscreen_recovery() -> void:
	var partial := _placement(WindowPresentationMode.Value.SMALL, 0, Vector2i(1900, 100), Vector2i(480, 240))
	partial.normalized_position = Vector2.ONE
	var recovered_partial := OverlayPlacementSanitizer.sanitize(partial, [_standard_monitors()[0]])
	_assert_equal(recovered_partial.absolute_position, Vector2i(1440, 800), "REC-001 partial off-screen placement recovered")

	var outside := _placement(WindowPresentationMode.Value.SMALL, 0, Vector2i(5000, 5000), Vector2i(480, 240))
	outside.normalized_position = Vector2(-1, -1)
	var recovered_outside := OverlayPlacementSanitizer.sanitize(outside, [_standard_monitors()[0]])
	_assert_equal(recovered_outside.absolute_position, Vector2i(1416, 776), "REC-002 fully off-screen placement uses safe bottom-right")


func _test_negative_coordinate_monitor() -> void:
	var placement := _placement(WindowPresentationMode.Value.SMALL, 1, Vector2i(-1200, 100), Vector2i(480, 240))
	var result := OverlayPlacementSanitizer.sanitize(placement, _standard_monitors())
	_assert_equal(result.monitor_index, 1, "MON-002 negative-coordinate monitor retained")
	_assert_equal(result.absolute_position, Vector2i(-1200, 100), "MON-002 negative-coordinate position retained")


func _test_removed_monitor_fallback() -> void:
	var placement := _placement(WindowPresentationMode.Value.SMALL, 1, Vector2i(-1000, 200), Vector2i(480, 240))
	placement.normalized_position = Vector2(0.25, 0.5)
	var result := OverlayPlacementSanitizer.sanitize(placement, [_standard_monitors()[0]])
	_assert_equal(result.monitor_index, 0, "REC-003 removed monitor falls back to primary")
	_assert_equal(result.absolute_position, Vector2i(360, 400), "REC-004 normalized placement restored on fallback")


func _test_resolution_and_taskbar_changes() -> void:
	var reduced := OverlayMonitorInfo.synthetic(0, Rect2i(0, 0, 1280, 720), Rect2i(0, 0, 1280, 680), 1.25, 120, true)
	var placement := _placement(WindowPresentationMode.Value.SMALL, 0, Vector2i(1400, 700), Vector2i(480, 240))
	placement.normalized_position = Vector2.ONE
	var result := OverlayPlacementSanitizer.sanitize(placement, [reduced])
	_assert_equal(result.absolute_position, Vector2i(800, 440), "REC-005 changed resolution clamps placement")
	_assert_equal(result.saved_dpi, 120, "DPI-LOGIC-001 saved DPI refreshed")

	var taskbar_changed := OverlayMonitorInfo.synthetic(0, Rect2i(0, 0, 1920, 1080), Rect2i(0, 80, 1920, 1000), 1.0, 96, true)
	var lower := _placement(WindowPresentationMode.Value.SMALL, 0, Vector2i(1400, 900), Vector2i(480, 240))
	var taskbar_result := OverlayPlacementSanitizer.sanitize(lower, [taskbar_changed])
	_assert_equal(taskbar_result.absolute_position.y, 840, "TSK-LOGIC-001 changed usable rect excludes taskbar")


func _test_oversized_window() -> void:
	var placement := _placement(WindowPresentationMode.Value.EXPANDED, 0, Vector2i(0, 0), Vector2i(3000, 2000))
	var result := OverlayPlacementSanitizer.sanitize(placement, [_standard_monitors()[0]])
	_assert_equal(result.size, Vector2i(1920, 1040), "REC-006 oversized window shrinks to usable area")
	_assert_equal(result.absolute_position, Vector2i.ZERO, "REC-007 oversized window remains recoverable")


func _test_corrupted_and_future_store() -> void:
	var corrupted := OverlayPlacementStore.decode_text("{not-json")
	_assert_equal(corrupted.ok, false, "REC-008 corrupted placement rejected")
	_assert_equal(corrupted.error_code, "CORRUPTED_JSON", "REC-009 corrupted placement diagnostic")
	var future := OverlayPlacementStore.decode_text('{"version":999,"placements":{}}')
	_assert_equal(future.ok, false, "REC-010 future placement version rejected")
	_assert_equal(future.error_code, "UNSUPPORTED_VERSION", "REC-011 future placement diagnostic")


func _test_per_mode_persistence() -> void:
	var fake := FakeAdapter.new(_standard_monitors())
	var controller := WindowModeController.new(fake)
	for mode in WindowPresentationMode.LABELS:
		var placement := _placement(mode, 0, Vector2i(100 + mode * 20, 120 + mode * 20), WindowPresentationMode.default_size(mode))
		controller.remember_placement(placement)
	var serialized := controller.serialize_placements()
	var restored := WindowModeController.new(fake)
	restored.restore_placements(serialized)
	_assert_equal(restored.serialize_placements().size(), 3, "PST-003 all per-mode placements restored")
	_assert_equal(restored.serialize_placements()["EXPANDED"].size, [960, 540], "PST-004 expanded size restored")


func _test_mode_transition_invariants() -> void:
	var fake := FakeAdapter.new(_standard_monitors())
	var controller := WindowModeController.new(fake)
	var sequence := [
		WindowPresentationMode.Value.MINIMAL,
		WindowPresentationMode.Value.SMALL,
		WindowPresentationMode.Value.EXPANDED,
		WindowPresentationMode.Value.SMALL,
		WindowPresentationMode.Value.MINIMAL,
		WindowPresentationMode.Value.EXPANDED,
	]
	for mode in sequence:
		var result := controller.transition_to(mode)
		_assert_equal(result.success, true, "MOD-001 transition to %s" % WindowPresentationMode.label(mode))
		_assert_equal(controller.assert_invariants(), true, "MOD-002 single active presentation invariant")
	for index in 100:
		var mode: int = index % 3
		controller.transition_to(mode)
		if not controller.assert_invariants():
			_failures.append("MOD-003 rapid transition invariant at iteration %d" % index)
	_assert_equal(controller.active_presentation_count, 1, "MOD-004 rapid transitions do not duplicate presentation")
	_assert_equal(fake.apply_count, 106, "MOD-005 every requested transition applied once")


func _test_mode_switch_near_edge() -> void:
	var fake := FakeAdapter.new([_standard_monitors()[0]])
	var controller := WindowModeController.new(fake)
	var minimal := _placement(WindowPresentationMode.Value.MINIMAL, 0, Vector2i(1870, 1000), Vector2i(260, 180))
	minimal.normalized_position = Vector2.ONE
	controller.remember_placement(minimal)
	var result := controller.transition_to(WindowPresentationMode.Value.MINIMAL)
	_assert_equal(result.success, true, "MOD-006 near-edge mode switch succeeds")
	_assert_equal(fake.current.absolute_position, Vector2i(1660, 860), "MOD-007 near-edge mode switch clamps inside usable rect")


func _test_hit_region_bounds() -> void:
	var polygon := PackedVector2Array([Vector2(10, 10), Vector2(30, 10), Vector2(30, 30), Vector2(10, 30)])
	var region := OverlayHitRegion.single(polygon, 5, "test")
	_assert_equal(region.bounds(), Rect2(5, 5, 30, 30), "INP-LOGIC-001 hit-region bounds include padding")


func _standard_monitors() -> Array[OverlayMonitorInfo]:
	return [
		OverlayMonitorInfo.synthetic(0, Rect2i(0, 0, 1920, 1080), Rect2i(0, 0, 1920, 1040), 1.0, 96, true),
		OverlayMonitorInfo.synthetic(1, Rect2i(-1280, 0, 1280, 1024), Rect2i(-1280, 0, 1280, 984), 1.25, 120, false),
	]


func _placement(mode: int, monitor_index: int, position: Vector2i, size: Vector2i) -> OverlayPlacement:
	var placement := OverlayPlacement.new()
	placement.mode = mode
	placement.monitor_index = monitor_index
	placement.absolute_position = position
	placement.size = size
	return placement


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual == expected:
		print("PASS: %s" % label)
	else:
		_failures.append("%s — expected %s, got %s" % [label, expected, actual])
