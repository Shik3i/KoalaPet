class_name OverlayPlacementSanitizer
extends RefCounted

const EDGE_MARGIN := 24
const MIN_VISIBLE := Vector2i(48, 48)


static func sanitize(requested: OverlayPlacement, monitors: Array[OverlayMonitorInfo]) -> OverlayPlacement:
	var result := requested.duplicate_value()
	if monitors.is_empty():
		result.absolute_position = Vector2i(EDGE_MARGIN, EDGE_MARGIN)
		result.size = _positive_size(result.size, WindowPresentationMode.default_size(result.mode))
		return result

	var target := _monitor_by_index(monitors, result.monitor_index)
	var requested_rect := Rect2i(result.absolute_position, _positive_size(result.size, WindowPresentationMode.default_size(result.mode)))
	if target == null:
		target = _best_intersection_monitor(requested_rect, monitors)
	if target == null:
		target = _primary_monitor(monitors)

	var usable := target.usable_rect
	result.monitor_index = target.index
	result.size = Vector2i(
		clampi(requested_rect.size.x, MIN_VISIBLE.x, maxi(MIN_VISIBLE.x, usable.size.x)),
		clampi(requested_rect.size.y, MIN_VISIBLE.y, maxi(MIN_VISIBLE.y, usable.size.y))
	)

	if _meaningfully_visible(Rect2i(result.absolute_position, result.size), monitors):
		result.absolute_position = _clamp_position(result.absolute_position, result.size, usable)
	elif _valid_normalized(result.normalized_position):
		result.absolute_position = position_from_normalized(result.normalized_position, result.size, usable)
	else:
		result.absolute_position = bottom_right_default(result.size, usable)

	result.absolute_position = _clamp_position(result.absolute_position, result.size, usable)
	result.normalized_position = normalized_position(result.absolute_position, result.size, usable)
	result.saved_scale = target.scale
	result.saved_dpi = target.dpi
	result.version = OverlayPlacement.VERSION
	return result


static func bottom_right_default(size: Vector2i, usable: Rect2i) -> Vector2i:
	return Vector2i(
		usable.end.x - size.x - EDGE_MARGIN,
		usable.end.y - size.y - EDGE_MARGIN
	)


static func normalized_position(position: Vector2i, size: Vector2i, usable: Rect2i) -> Vector2:
	var span := usable.size - size
	return Vector2(
		0.0 if span.x <= 0 else clampf(float(position.x - usable.position.x) / float(span.x), 0.0, 1.0),
		0.0 if span.y <= 0 else clampf(float(position.y - usable.position.y) / float(span.y), 0.0, 1.0)
	)


static func position_from_normalized(normalized: Vector2, size: Vector2i, usable: Rect2i) -> Vector2i:
	var span := usable.size - size
	return usable.position + Vector2i(
		roundi(maxi(0, span.x) * clampf(normalized.x, 0.0, 1.0)),
		roundi(maxi(0, span.y) * clampf(normalized.y, 0.0, 1.0))
	)


static func intersection_area(first: Rect2i, second: Rect2i) -> int:
	var intersection := first.intersection(second)
	return maxi(0, intersection.size.x) * maxi(0, intersection.size.y)


static func _meaningfully_visible(rect: Rect2i, monitors: Array[OverlayMonitorInfo]) -> bool:
	for monitor in monitors:
		var intersection := rect.intersection(monitor.usable_rect)
		if intersection.size.x >= mini(MIN_VISIBLE.x, rect.size.x) and intersection.size.y >= mini(MIN_VISIBLE.y, rect.size.y):
			return true
	return false


static func _best_intersection_monitor(rect: Rect2i, monitors: Array[OverlayMonitorInfo]) -> OverlayMonitorInfo:
	var best: OverlayMonitorInfo = null
	var best_area := 0
	for monitor in monitors:
		var area := intersection_area(rect, monitor.usable_rect)
		if area > best_area:
			best = monitor
			best_area = area
	return best


static func _primary_monitor(monitors: Array[OverlayMonitorInfo]) -> OverlayMonitorInfo:
	for monitor in monitors:
		if monitor.primary:
			return monitor
	return monitors[0]


static func _monitor_by_index(monitors: Array[OverlayMonitorInfo], index: int) -> OverlayMonitorInfo:
	for monitor in monitors:
		if monitor.index == index:
			return monitor
	return null


static func _clamp_position(position: Vector2i, size: Vector2i, usable: Rect2i) -> Vector2i:
	var maximum := usable.end - size
	return Vector2i(
		clampi(position.x, usable.position.x, maxi(usable.position.x, maximum.x)),
		clampi(position.y, usable.position.y, maxi(usable.position.y, maximum.y))
	)


static func _positive_size(value: Vector2i, fallback: Vector2i) -> Vector2i:
	if value.x <= 0 or value.y <= 0:
		return fallback
	return value


static func _valid_normalized(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) and value.x >= 0.0 and value.x <= 1.0 and value.y >= 0.0 and value.y <= 1.0
