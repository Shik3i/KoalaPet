class_name HabitatView
extends Control

const ROOT := "res://assets_generated/habitat/quiet_canopy/"
const FRAME_GROUND := Vector2(64, 116)
const ANCHORS := {
	"idle_center": Vector2(270, 170), "feeding_bowl": Vector2(238, 170),
	"treat_position": Vector2(286, 170), "bath": Vector2(132, 170),
	"training": Vector2(420, 170), "bed": Vector2(72, 170),
	"medicine": Vector2(320, 170), "departure": Vector2(468, 170),
	"trophy": Vector2(354, 170), "roam_left": Vector2(180, 170),
	"roam_right": Vector2(342, 170),
}

var pet_sprite: AnimatedTextureRect
var opponent_sprite: AnimatedTextureRect
var call_layer: Control
var reduced_motion := false
var roaming_enabled := true
var effects_intensity := "normal"
var pet_scale := 1.0
var animation_speed := 1.0
var walking_speed := 1.0
var _animations: Dictionary = {}
var _authoritative_loop := "idle"
var _world_ground := Vector2(270, 170)
var _target_ground := Vector2(270, 170)
var _turn_remaining := 0.0
var _moving := false
var _action: Dictionary = {}
var _action_remaining := 0.0
var _pause_remaining := 3.5
var _roam_index := 0
var _facing := 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(512, 192)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layers()
	set_process(true)


func _build_layers() -> void:
	_add_full_texture("Background", ROOT + "background_day.png")
	_add_texture("Ground", ROOT + "ground.png", Vector2(0, 96), Vector2(512, 96))
	_add_prop("Plants", "plants", Vector2(-8, 60))
	_add_prop("Bath", "bath_basin", Vector2(76, 58))
	_add_prop("Feed", "feed_table", Vector2(196, 62))
	_add_prop("Shelf", "trophy_shelf", Vector2(310, 36))
	_add_prop("Lantern", "lantern", Vector2(354, 0))
	_add_prop("Training", "training_log", Vector2(382, 58))
	_add_prop("Den", "sleeping_den", Vector2(-4, 54))
	_add_prop("Chest", "storage_chest", Vector2(414, 66))
	pet_sprite = AnimatedTextureRect.new()
	pet_sprite.name = "PetSprite"
	add_child(pet_sprite)
	opponent_sprite = AnimatedTextureRect.new()
	opponent_sprite.name = "OpponentSprite"
	opponent_sprite.position = Vector2(350, 52)
	opponent_sprite.size = Vector2(128, 128)
	opponent_sprite.visible = false
	add_child(opponent_sprite)
	_add_texture("Foreground", ROOT + "effects/foreground_grass.png", Vector2(0, 84), Vector2(128, 128))
	var ambience := _add_texture("Ambience", ROOT + "effects/dust_motes.png", Vector2(188, 22), Vector2(128, 128))
	ambience.modulate = Color(1, 1, 1, 0.45)
	call_layer = Control.new()
	call_layer.name = "CallLayer"
	call_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(call_layer)
	_place_pet()


func configure_pet(animations: Dictionary, authoritative_loop: String, options := {}) -> void:
	_animations = animations.duplicate(true)
	_authoritative_loop = authoritative_loop if animations.has(authoritative_loop) else "idle"
	reduced_motion = bool(options.get("reduced_motion", false))
	roaming_enabled = bool(options.get("ambient_roaming", true)) and not reduced_motion
	pet_scale = clampf(float(options.get("pet_scale", 1.0)), 0.75, 2.0)
	animation_speed = clampf(float(options.get("animation_speed", 1.0)), 0.75, 1.25)
	walking_speed = clampf(float(options.get("walking_speed", 1.0)), 0.75, 1.5)
	effects_intensity = str(options.get("effects_intensity", "normal"))
	var ambience := get_node_or_null("Ambience") as TextureRect
	if ambience != null:
		ambience.visible = effects_intensity == "normal" and not reduced_motion
	pet_sprite.size = Vector2(128, 128) * pet_scale
	if _authoritative_loop == "sleep":
		_world_ground = ANCHORS["bed"]
	_place_pet()
	_play(_authoritative_loop)


func start_action(anchor_name: String, animation_name: String, duration := 1.1, loop_after := "idle") -> void:
	var resolved_anchor := anchor_name if ANCHORS.has(anchor_name) else "idle_center"
	_action = {"animation": animation_name, "loop_after": loop_after, "return": loop_after != "sleep"}
	_action_remaining = maxf(0.1, duration)
	_begin_move(ANCHORS[resolved_anchor])


func set_world_anchor(anchor_name: String) -> void:
	if ANCHORS.has(anchor_name):
		_world_ground = ANCHORS[anchor_name]
		_place_pet()


func set_opponent(descriptor: Dictionary) -> void:
	opponent_sprite.visible = not descriptor.is_empty()
	if opponent_sprite.visible:
		opponent_sprite.configure(descriptor, reduced_motion, animation_speed)


func show_call(icon_name: String) -> void:
	for child in call_layer.get_children():
		child.queue_free()
	if icon_name.is_empty():
		return
	var bubble := PixelUi.call_bubble(icon_name)
	bubble.position = Vector2(clampf(_world_ground.x - 8, 16, 456), 24)
	call_layer.add_child(bubble)


func set_trophy_visible(unlocked: bool) -> void:
	var shelf := get_node_or_null("Shelf") as TextureRect
	if shelf != null:
		shelf.modulate = Color.WHITE if unlocked else Color("#809099")


func current_anchor_position() -> Vector2:
	return _world_ground


func current_visual_state() -> String:
	return pet_sprite.animation_name if pet_sprite != null else ""


func is_moving() -> bool:
	return _moving or _turn_remaining > 0.0


func _process(delta: float) -> void:
	if pet_sprite == null:
		return
	if reduced_motion:
		if _action_remaining > 0.0:
			_action_remaining -= delta
			if _action_remaining <= 0.0:
				_finish_action()
		return
	if _turn_remaining > 0.0:
		_turn_remaining -= delta
		if _turn_remaining <= 0.0:
			pet_sprite.set_facing(_facing)
			_moving = true
			_play("walk", walking_speed)
		return
	if _moving:
		_world_ground = _world_ground.move_toward(_target_ground, 48.0 * walking_speed * delta)
		_place_pet()
		if _world_ground.distance_to(_target_ground) <= 0.25:
			_world_ground = _target_ground
			_moving = false
			_place_pet()
			_arrived()
		return
	if _action_remaining > 0.0:
		_action_remaining -= delta
		if _action_remaining <= 0.0:
			_finish_action()
		return
	if _authoritative_loop != "idle" or not roaming_enabled:
		return
	_pause_remaining -= delta
	if _pause_remaining <= 0.0:
		_roam_index = (_roam_index + 1) % 3
		_begin_move(ANCHORS[["roam_left", "idle_center", "roam_right"][_roam_index]])


func _begin_move(destination: Vector2) -> void:
	_target_ground = destination
	if reduced_motion or _world_ground.distance_to(destination) <= 1.0:
		_world_ground = destination
		_place_pet()
		_arrived()
		return
	var next_facing := -1.0 if destination.x < _world_ground.x else 1.0
	if next_facing != _facing:
		_facing = next_facing
		_moving = false
		_turn_remaining = 0.1
		_play("idle")
	else:
		_moving = true
		_play("walk", walking_speed)


func _arrived() -> void:
	if not _action.is_empty():
		_play(str(_action.get("animation", "happy")))
		return
	_play(_authoritative_loop)
	_pause_remaining = 4.0 + float(_roam_index)


func _finish_action() -> void:
	var loop_after := str(_action.get("loop_after", _authoritative_loop))
	var should_return := bool(_action.get("return", true))
	_action.clear()
	if loop_after == "sleep":
		_authoritative_loop = "sleep"
		_play("sleep")
	elif should_return:
		_begin_move(ANCHORS["idle_center"])
	else:
		_play(loop_after)


func _play(animation_name: String, locomotion_scale := 1.0) -> void:
	var descriptor: Dictionary = _animations.get(animation_name, _animations.get("idle", {}))
	pet_sprite.configure(descriptor, reduced_motion, animation_speed * locomotion_scale)
	pet_sprite.set_facing(_facing)


func _place_pet() -> void:
	if pet_sprite != null:
		pet_sprite.position = _world_ground - FRAME_GROUND * pet_scale


func _add_full_texture(node_name: String, path: String) -> TextureRect:
	return _add_texture(node_name, path, Vector2.ZERO, Vector2(512, 192))


func _add_texture(node_name: String, path: String, position_value: Vector2, size_value: Vector2) -> TextureRect:
	var value := TextureRect.new()
	value.name = node_name
	value.texture = load(path) as Texture2D
	value.position = position_value
	value.size = size_value
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value)
	return value


func _add_prop(node_name: String, asset_name: String, position_value: Vector2) -> TextureRect:
	return _add_texture(node_name, ROOT + "props/" + asset_name + ".png", position_value, Vector2(128, 128))
