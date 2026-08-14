class_name HabitatFrame
extends Control

## Responsive holder for the fixed 512x192 habitat scene.
##
## `HabitatView` positions its layers, anchors and pet with absolute habitat
## coordinates, so it cannot reflow. Wrapping it in this frame keeps the habitat
## authoritative while letting Small and Expanded resize freely: the frame keeps
## the aspect ratio, scales the habitat to the largest whole area that fits and
## centres it, so the pet stays the visual focus at every window size.

const HABITAT_SIZE := Vector2(512, 192)
const MIN_SCALE := 0.5
const MAX_SCALE := 3.0

const ASPECT := HABITAT_SIZE.x / HABITAT_SIZE.y

var habitat: HabitatView
## When false the frame claims only the height its width actually needs, so the
## surrounding column keeps the leftover space instead of showing an empty band
## above and below a letterboxed habitat.
var expand_vertical := true
var _applied_scale := 0.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = HABITAT_SIZE * MIN_SCALE


func set_expand_vertical(enabled: bool) -> void:
	expand_vertical = enabled
	size_flags_vertical = Control.SIZE_EXPAND_FILL if enabled else Control.SIZE_FILL
	_relayout()


func attach(view: HabitatView) -> void:
	habitat = view
	habitat.position = Vector2.ZERO
	habitat.size = HABITAT_SIZE
	add_child(habitat)
	resized.connect(_relayout)
	_relayout()


func current_scale() -> float:
	return _applied_scale


func _relayout() -> void:
	if habitat == null or not is_instance_valid(habitat):
		return
	var available := size
	if available.x <= 0.0 or available.y <= 0.0:
		return
	if not expand_vertical:
		var wanted := clampf(available.x / ASPECT, HABITAT_SIZE.y * MIN_SCALE, HABITAT_SIZE.y * MAX_SCALE)
		if absf(custom_minimum_size.y - wanted) > 1.0:
			custom_minimum_size.y = wanted
			update_minimum_size()
			return
	var factor := clampf(minf(available.x / HABITAT_SIZE.x, available.y / HABITAT_SIZE.y), MIN_SCALE, MAX_SCALE)
	_applied_scale = factor
	habitat.scale = Vector2(factor, factor)
	habitat.size = HABITAT_SIZE
	habitat.position = ((available - HABITAT_SIZE * factor) * 0.5).floor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()
