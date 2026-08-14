class_name AnimationShowroomStage
extends Control

signal frame_changed(frame: int)

var sprite: AnimatedTextureRect
var effect_sprite: AnimatedTextureRect
var descriptor: Dictionary = {}
var effect_descriptor: Dictionary = {}
var background_name := "dark"
var pet_scale := 1.0
var direction := 1.0
var show_vfx := true
var show_frame_number := true
var show_ground_anchor := false
var show_pivot := false
var show_visual_bounds := false
var show_interaction_bounds := false
var show_markers := true
var _last_frame := -1


func _ready() -> void:
	custom_minimum_size = Vector2(420, 360)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite = AnimatedTextureRect.new()
	sprite.name = "RuntimeAnimation"
	add_child(sprite)
	effect_sprite = AnimatedTextureRect.new()
	effect_sprite.name = "RuntimeEffect"
	effect_sprite.visible = false
	add_child(effect_sprite)
	resized.connect(_place_sprites)
	set_process(true)
	queue_redraw()


func configure_animation(value: Dictionary, reduce_motion: bool, speed: float, loop_override: bool) -> void:
	descriptor = value.duplicate(true)
	descriptor["loop"] = loop_override
	sprite.configure(descriptor, reduce_motion, speed)
	sprite.restart()
	sprite.set_facing(direction)
	_place_sprites()
	_last_frame = -1
	queue_redraw()


func configure_effect(value: Dictionary, reduce_motion: bool, speed: float, intensity: String) -> void:
	effect_descriptor = value.duplicate(true)
	effect_sprite.visible = show_vfx and intensity != "off" and not effect_descriptor.is_empty()
	if effect_sprite.visible:
		effect_sprite.configure(effect_descriptor, reduce_motion, speed)
		effect_sprite.restart()
		var effect_size := 96.0 if intensity == "reduced" else 128.0
		effect_sprite.size = Vector2.ONE * effect_size
	_place_sprites()


func set_direction(value: float) -> void:
	direction = -1.0 if value < 0.0 else 1.0
	if sprite != null:
		sprite.set_facing(direction)


func set_pet_scale(value: float) -> void:
	pet_scale = clampf(value, 0.5, 2.0)
	_place_sprites()


func play() -> void:
	sprite.set_playback_enabled(true)


func pause() -> void:
	sprite.set_playback_enabled(false)


func restart() -> void:
	sprite.restart()
	if effect_sprite.visible:
		effect_sprite.restart()


func step_frame(offset: int) -> void:
	sprite.set_playback_enabled(false)
	sprite.step_frame(offset)
	queue_redraw()


func current_frame() -> int:
	return sprite.current_frame() if sprite != null else 0


func _process(_delta: float) -> void:
	if sprite == null:
		return
	var frame := sprite.current_frame()
	if frame != _last_frame:
		_last_frame = frame
		frame_changed.emit(frame)
		queue_redraw()


func _place_sprites() -> void:
	if sprite == null:
		return
	var sprite_size := Vector2(128, 128) * pet_scale
	sprite.size = sprite_size
	sprite.position = Vector2((size.x - sprite_size.x) * 0.5, size.y * 0.72 - sprite_size.y)
	sprite.set_facing(direction)
	if effect_sprite != null:
		effect_sprite.position = Vector2((size.x - effect_sprite.size.x) * 0.5, sprite.position.y + 12.0)
	queue_redraw()


func _draw() -> void:
	var background := Color("#f4ead2") if background_name == "light" else Color("#101820")
	draw_rect(Rect2(Vector2.ZERO, size), background)
	if sprite == null:
		return
	var factor := pet_scale
	var origin := sprite.position
	var ground: Array = descriptor.get("ground_anchor", [64, 116])
	var pivot: Array = descriptor.get("pivot", [64, 116])
	var interaction: Array = descriptor.get("interaction_bounds", [14, 12, 100, 104])
	if show_ground_anchor and ground.size() == 2:
		var ground_point := origin + Vector2(float(ground[0]), float(ground[1])) * factor
		draw_line(Vector2(12, ground_point.y), Vector2(size.x - 12, ground_point.y), Color("#72a85d"), 2)
	if show_pivot and pivot.size() == 2:
		var pivot_point := origin + Vector2(float(pivot[0]), float(pivot[1])) * factor
		draw_line(pivot_point - Vector2(8, 0), pivot_point + Vector2(8, 0), Color("#e6bd67"), 2)
		draw_line(pivot_point - Vector2(0, 8), pivot_point + Vector2(0, 8), Color("#e6bd67"), 2)
	if show_visual_bounds:
		var visual := sprite.current_visual_bounds()
		draw_rect(Rect2(origin + visual.position * factor, visual.size * factor), Color("#55d7ff"), false, 2)
	if show_interaction_bounds and interaction.size() == 4:
		var interaction_rect := Rect2(float(interaction[0]), float(interaction[1]), float(interaction[2]), float(interaction[3]))
		draw_rect(Rect2(origin + interaction_rect.position * factor, interaction_rect.size * factor), Color("#e36b58"), false, 2)
	var labels: Array[String] = []
	if show_frame_number:
		labels.append("Frame %d / %d" % [sprite.current_frame() + 1, sprite.frame_count])
	if show_markers:
		var markers := sprite.markers_for_frame(sprite.current_frame())
		if not markers.is_empty():
			labels.append("Markers: " + ", ".join(markers))
	if not labels.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, 24), "  ".join(labels), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#101820") if background_name == "light" else Color("#f3e2b8"))
