class_name OverlaySpikePlaceholder
extends Control

signal hit_region_changed(region: OverlayHitRegion)

var animate := true
var lane_width := 180.0
var interaction_padding := 10
var _elapsed := 0.0
var _lane_origin := Vector2(24, 72)


func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _process(delta: float) -> void:
	if not animate:
		return
	_elapsed += delta
	var lane_offset := (sin(_elapsed * 0.8) * 0.5 + 0.5) * lane_width
	position = _lane_origin + Vector2(lane_offset, 0)
	hit_region_changed.emit(OverlayHitRegion.single(window_hit_polygon(), interaction_padding, "moving-placeholder"))


func window_hit_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := position + Vector2(48, 52)
	var radius := Vector2(38 + interaction_padding, 34 + interaction_padding)
	for index in 20:
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


func _draw() -> void:
	# Original code-generated technical silhouette; not product art.
	draw_circle(Vector2(48, 58), 31, Color(0.31, 0.80, 0.65, 0.96))
	draw_circle(Vector2(27, 37), 17, Color(0.22, 0.63, 0.57, 0.92))
	draw_circle(Vector2(69, 37), 17, Color(0.22, 0.63, 0.57, 0.92))
	draw_circle(Vector2(48, 61), 19, Color(0.55, 0.91, 0.76, 0.82))
	draw_circle(Vector2(39, 53), 3, Color(0.08, 0.14, 0.17, 1.0))
	draw_circle(Vector2(57, 53), 3, Color(0.08, 0.14, 0.17, 1.0))
	draw_circle(Vector2(48, 63), 5, Color(0.14, 0.25, 0.28, 1.0))
	draw_arc(Vector2(48, 58), 39, 0.0, TAU, 40, Color(0.72, 1.0, 0.92, 0.45), 2.0)
	draw_circle(Vector2(84, 18), 6, Color(1.0, 0.77, 0.31, 0.9))
