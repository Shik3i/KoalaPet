class_name WindowModeController
extends RefCounted

var adapter: DesktopWindowAdapter
var current_mode := WindowPresentationMode.Value.SMALL
var active_presentation_count := 1
var transition_count := 0
var _transitioning := false
var _placements: Dictionary = {}


func _init(window_adapter: DesktopWindowAdapter) -> void:
	adapter = window_adapter


func transition_to(next_mode: int) -> OverlayApplyResult:
	if next_mode not in WindowPresentationMode.LABELS:
		return OverlayApplyResult.failure("INVALID_MODE", "Unknown presentation mode: %s" % next_mode)
	if _transitioning:
		return OverlayApplyResult.failure("TRANSITION_IN_PROGRESS", "A presentation transition is already in progress")
	_transitioning = true
	if transition_count > 0:
		remember_placement(adapter.get_current_placement(current_mode))
	var requested: OverlayPlacement = _placements.get(next_mode, _default_placement(next_mode))
	var result := adapter.apply_mode(next_mode, requested)
	if result.success:
		current_mode = next_mode
		transition_count += 1
		active_presentation_count = 1
	_transitioning = false
	return result


func remember_placement(placement: OverlayPlacement) -> void:
	_placements[placement.mode] = placement.duplicate_value()


func restore_placements(serialized: Variant) -> void:
	if typeof(serialized) != TYPE_DICTIONARY:
		return
	for label in serialized:
		var mode := WindowPresentationMode.from_label(str(label), -1)
		if mode >= 0:
			var placement := OverlayPlacement.from_dict(serialized[label])
			placement.mode = mode
			_placements[mode] = placement


func serialize_placements() -> Dictionary:
	var serialized := {}
	for mode in _placements:
		serialized[WindowPresentationMode.label(mode)] = _placements[mode].to_dict()
	return serialized


func assert_invariants() -> bool:
	return active_presentation_count == 1 and not _transitioning and current_mode in WindowPresentationMode.LABELS


func _default_placement(mode: int) -> OverlayPlacement:
	var placement := OverlayPlacement.new()
	placement.mode = mode
	placement.size = WindowPresentationMode.default_size(mode)
	placement.normalized_position = Vector2.ONE
	placement.absolute_position = Vector2i(2_000_000, 2_000_000)
	return placement
