class_name OverlayPlacement
extends RefCounted

const VERSION := 1

var version := VERSION
var mode := WindowPresentationMode.Value.SMALL
var monitor_index := 0
var absolute_position := Vector2i.ZERO
var normalized_position := Vector2(1.0, 1.0)
var size := WindowPresentationMode.default_size(WindowPresentationMode.Value.SMALL)
var anchor := "bottom_right"
var saved_scale := 1.0
var saved_dpi := 96
var timestamp := ""


static func from_dict(value: Variant) -> OverlayPlacement:
	var placement := OverlayPlacement.new()
	if typeof(value) != TYPE_DICTIONARY:
		return placement
	placement.version = int(value.get("version", VERSION))
	placement.mode = WindowPresentationMode.from_label(str(value.get("mode", "SMALL")))
	placement.monitor_index = int(value.get("monitor_index", 0))
	placement.absolute_position = _vector2i(value.get("absolute_position", []), Vector2i.ZERO)
	placement.normalized_position = _vector2(value.get("normalized_position", []), Vector2(1.0, 1.0))
	placement.size = _vector2i(value.get("size", []), WindowPresentationMode.default_size(placement.mode))
	placement.anchor = str(value.get("anchor", "bottom_right"))
	placement.saved_scale = float(value.get("saved_scale", 1.0))
	placement.saved_dpi = int(value.get("saved_dpi", 96))
	placement.timestamp = str(value.get("timestamp", ""))
	return placement


func duplicate_value() -> OverlayPlacement:
	return from_dict(to_dict())


func to_dict() -> Dictionary:
	return {
		"version": version,
		"mode": WindowPresentationMode.label(mode),
		"monitor_index": monitor_index,
		"absolute_position": [absolute_position.x, absolute_position.y],
		"normalized_position": [normalized_position.x, normalized_position.y],
		"size": [size.x, size.y],
		"anchor": anchor,
		"saved_scale": saved_scale,
		"saved_dpi": saved_dpi,
		"timestamp": timestamp,
	}


static func _vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
