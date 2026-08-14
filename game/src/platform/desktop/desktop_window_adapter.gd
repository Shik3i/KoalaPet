class_name DesktopWindowAdapter
extends RefCounted

const INPUT_INTERACTIVE := "interactive"
const INPUT_FULL_PASSTHROUGH := "full_passthrough"
const INPUT_HIT_REGION := "hit_region"
const FOCUS_NORMAL := "normal"
const FOCUS_NO_FOCUS := "no_focus"

var target_window: Window


func _init(window: Window = null) -> void:
	target_window = window


func detect_capabilities() -> OverlayCapabilities:
	return OverlayCapabilities.new()


func is_host_supported() -> bool:
	return false


func enumerate_monitors() -> Array[OverlayMonitorInfo]:
	return []


func apply_mode(_mode: int, _requested_placement: OverlayPlacement) -> OverlayApplyResult:
	return _unsupported("apply_mode")


func set_transparency(_enabled: bool) -> OverlayApplyResult:
	return _unsupported("set_transparency")


func set_always_on_top(_enabled: bool) -> OverlayApplyResult:
	return _unsupported("set_always_on_top")


func set_focus_policy(_policy: String) -> OverlayApplyResult:
	return _unsupported("set_focus_policy")


func set_input_policy(_policy: String) -> OverlayApplyResult:
	return _unsupported("set_input_policy")


func set_hit_regions(_regions: Array[OverlayHitRegion]) -> OverlayApplyResult:
	return _unsupported("set_hit_regions")


func begin_native_drag() -> OverlayApplyResult:
	return _unsupported("begin_native_drag")


func set_position(_position: Vector2i) -> OverlayApplyResult:
	return _unsupported("set_position")


func set_size(_size: Vector2i) -> OverlayApplyResult:
	return _unsupported("set_size")


func set_size_bounds(_minimum: Vector2i, _maximum: Vector2i) -> OverlayApplyResult:
	return _unsupported("set_size_bounds")


func get_current_placement(_mode: int) -> OverlayPlacement:
	return OverlayPlacement.new()


func sanitize_placement(saved: OverlayPlacement) -> OverlayPlacement:
	return OverlayPlacementSanitizer.sanitize(saved, enumerate_monitors())


func hide_window() -> OverlayApplyResult:
	return _unsupported("hide_window")


func show_window() -> OverlayApplyResult:
	return _unsupported("show_window")


func minimize_window() -> OverlayApplyResult:
	return _unsupported("minimize_window")


func restore_window() -> OverlayApplyResult:
	return _unsupported("restore_window")


func reset_to_safe_default(_mode: int) -> OverlayApplyResult:
	return _unsupported("reset_to_safe_default")


func create_status_indicator(_actions: Dictionary) -> OverlayApplyResult:
	return _unsupported("create_status_indicator")


func update_status_indicator(_tooltip: String) -> OverlayApplyResult:
	return _unsupported("update_status_indicator")


func remove_status_indicator() -> OverlayApplyResult:
	return _unsupported("remove_status_indicator")


func capture_diagnostics() -> Dictionary:
	return {}


func _unsupported(operation: String) -> OverlayApplyResult:
	return OverlayApplyResult.failure("UNSUPPORTED", "%s is unsupported by this adapter" % operation)
