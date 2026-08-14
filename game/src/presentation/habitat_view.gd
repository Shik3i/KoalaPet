class_name HabitatView
extends Control

const ROOT := "res://assets_generated/habitat/quiet_canopy/"
const VISUAL_MANIFEST := "res://assets_generated/visual-rebuild-manifest.json"
const FRAME_GROUND := Vector2(64, 116)
const ANCHORS := {
	"idle_center": Vector2(270, 170),
	"feeding_bowl": Vector2(238, 170),
	"treat_position": Vector2(286, 170),
	"bath": Vector2(132, 170),
	"training": Vector2(420, 170),
	"bed": Vector2(72, 170),
	"medicine": Vector2(320, 170),
	"departure": Vector2(468, 170),
	"trophy": Vector2(354, 170),
	"plant": Vector2(172, 170),
	"roam_left": Vector2(180, 170),
	"roam_right": Vector2(342, 170),
}

var pet_sprite: AnimatedTextureRect
var opponent_sprite: AnimatedTextureRect
var effect_sprite: AnimatedTextureRect
var call_layer: Control
var reduced_motion := false
var roaming_enabled := true
var effects_intensity := "normal"
var ambient_frequency := "normal"
var hit_shake_enabled := true
var damage_flash_enabled := true
var pet_scale := 1.0
var animation_speed := 1.0
var walking_speed := 1.0
var _animations: Dictionary = {}
var _authoritative_loop := "idle"
var _world_ground := Vector2(270, 170)
var _target_ground := Vector2(270, 170)
var _opponent_ground := Vector2(400, 170)
var _turn_remaining := 0.0
var _moving := false
var _action: Dictionary = {}
var _action_remaining := 0.0
var _pause_remaining := 3.5
var _facing := 1.0
var _event_queue: Array[Dictionary] = []
var _ambient_action := false
var _scheduler := AmbientAnimationScheduler.new()
var _visual_manifest: Dictionary = {}
var _family_profile: Dictionary = {}
var _encounter_profile: Dictionary = {}
var _hit_stop_remaining := 0.0
var _hit_stop_sprite: AnimatedTextureRect
var _shake_remaining := 0.0
var _shake_sprite: AnimatedTextureRect
var _flash_remaining := 0.0
var _flash_sprite: AnimatedTextureRect
var _ambient_effects: Array[AnimatedTextureRect] = []


func _ready() -> void:
	custom_minimum_size = Vector2(512, 192)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_visual_manifest()
	_build_layers()
	visibility_changed.connect(_on_visibility_changed)
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
	_build_ambient_effect("AmbientWater", "tide", "wave_arc", Vector2(80, 82), Vector2(72, 72), 0.34)
	_build_ambient_effect("AmbientLeaves", "moss", "pollen_sparkle", Vector2(138, 46), Vector2(64, 64), 0.28)
	_build_ambient_effect("AmbientEmbers", "ember", "ember_particles", Vector2(342, 24), Vector2(58, 58), 0.24)
	pet_sprite = AnimatedTextureRect.new()
	pet_sprite.name = "PetSprite"
	pet_sprite.animation_finished.connect(_on_pet_animation_finished)
	pet_sprite.animation_marker.connect(_on_animation_marker.bind(pet_sprite, "pet"))
	add_child(pet_sprite)
	opponent_sprite = AnimatedTextureRect.new()
	opponent_sprite.name = "OpponentSprite"
	opponent_sprite.position = _opponent_ground - FRAME_GROUND
	opponent_sprite.size = Vector2(128, 128)
	opponent_sprite.visible = false
	opponent_sprite.animation_finished.connect(_on_opponent_animation_finished)
	opponent_sprite.animation_marker.connect(_on_animation_marker.bind(opponent_sprite, "enemy"))
	add_child(opponent_sprite)
	effect_sprite = AnimatedTextureRect.new()
	effect_sprite.name = "CombatEffect"
	effect_sprite.size = Vector2(128, 128)
	effect_sprite.visible = false
	effect_sprite.animation_finished.connect(func(_name: String) -> void: effect_sprite.visible = false)
	effect_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect_sprite)
	_add_texture("Foreground", ROOT + "effects/foreground_grass.png", Vector2(0, 84), Vector2(128, 128))
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
	ambient_frequency = str(options.get("ambient_frequency", "normal"))
	hit_shake_enabled = bool(options.get("hit_shake", true))
	damage_flash_enabled = bool(options.get("damage_flash", true))
	_family_profile = _profile_for("family_profiles", str(options.get("family_id", "")))
	var prop_interactions: Array = _family_profile.get("ambient_interactions", []) if _family_profile.get("ambient_interactions", []) is Array else []
	_scheduler.configure(int(options.get("ambient_seed", 1)), ambient_frequency, reduced_motion, prop_interactions)
	_update_ambient_effects()
	pet_sprite.size = Vector2(128, 128) * pet_scale
	if _authoritative_loop == "sleep_loop" and _action.is_empty():
		_world_ground = ANCHORS["bed"]
	_place_pet()
	if _action.is_empty() and not _moving:
		_play(_authoritative_loop)


func start_action(anchor_name: String, animation_name: String, duration := 1.1, loop_after := "idle", event := {}) -> void:
	var resolved_anchor := anchor_name if ANCHORS.has(anchor_name) else "idle_center"
	_action = {
		"animation": animation_name,
		"loop_after": loop_after,
		"return": loop_after not in ["sleep", "sleep_loop"],
		"event_id": str(event.get("event_id", "")) if event is Dictionary else "",
		"kind": str(event.get("kind", "care")) if event is Dictionary else "care",
		"payload": event.get("payload", {}).duplicate(true) if event is Dictionary and event.get("payload", {}) is Dictionary else {},
	}
	_action_remaining = maxf(0.35, duration + 0.5)
	_begin_move(ANCHORS[resolved_anchor])


func start_sequence(events: Array[Dictionary]) -> void:
	for event in events:
		if _event_queue.size() < PresentationAnimationController.MAX_PENDING_EVENTS:
			_event_queue.append(event.duplicate(true))
	if _action.is_empty() and not _moving:
		_start_next_event()


func set_world_anchor(anchor_name: String) -> void:
	if ANCHORS.has(anchor_name):
		_world_ground = ANCHORS[anchor_name]
		_place_pet()


func set_opponent(descriptor: Dictionary, encounter_id := "") -> void:
	opponent_sprite.visible = not descriptor.is_empty()
	_encounter_profile = _profile_for("encounter_profiles", encounter_id)
	if opponent_sprite.visible:
		opponent_sprite.configure(descriptor, reduced_motion, animation_speed)
		opponent_sprite.set_facing(-1.0)
		opponent_sprite.position = _opponent_ground - FRAME_GROUND


func set_opponent_animations(animations: Dictionary, encounter_id := "") -> void:
	opponent_sprite.set_meta("animations", animations.duplicate(true))
	set_opponent(animations.get("idle", {}), encounter_id)


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


func pending_event_count() -> int:
	return _event_queue.size() + (0 if _action.is_empty() else 1)


func active_animation_processor_count() -> int:
	var count := 0
	for child in get_children():
		if child is AnimatedTextureRect and child.is_processing():
			count += 1
	return count


func _process(delta: float) -> void:
	if pet_sprite == null or not is_visible_in_tree():
		return
	_update_feedback(delta)
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
			_play(str(_action.get("move_animation", "walk")), walking_speed)
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
	if not _event_queue.is_empty():
		_start_next_event()
		return
	if _authoritative_loop != "idle" or not roaming_enabled:
		return
	_pause_remaining -= delta
	if _pause_remaining <= 0.0:
		_start_ambient_event(_scheduler.next_event())


func _start_next_event() -> void:
	if _event_queue.is_empty() or not _action.is_empty():
		return
	var event: Dictionary = _event_queue.pop_front()
	var payload: Dictionary = event.get("payload", {})
	var actor := str(payload.get("actor", "pet"))
	if str(event.get("kind", "")) == "battle" and actor == "enemy":
		_start_actor_event(opponent_sprite, event)
		return
	var from_anchor := str(event.get("from_anchor", ""))
	if not from_anchor.is_empty():
		set_world_anchor(from_anchor)
	if str(event.get("kind", "")) == "battle":
		_start_actor_event(pet_sprite, event)
	else:
		start_action(str(event.get("anchor", "idle_center")), str(event.get("animation", "happy")), float(event.get("duration", 1.1)), str(event.get("loop_after", "idle")), event)


func _start_actor_event(sprite: AnimatedTextureRect, event: Dictionary) -> void:
	_action = event.duplicate(true)
	_action["actor_sprite"] = sprite
	_action_remaining = maxf(0.5, float(event.get("duration", 1.0)) + 0.4)
	var animation := str(event.get("animation", "idle"))
	var descriptor: Dictionary = _animations.get(animation, _animations.get("idle", {})) if sprite == pet_sprite else _opponent_descriptor(animation)
	sprite.configure(descriptor, reduced_motion, animation_speed)
	sprite.restart()
	if sprite == opponent_sprite:
		sprite.set_facing(-1.0)


func _start_ambient_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", "walk"))
	_pause_remaining = float(event.get("pause", 4.0))
	if kind == "prop_interaction":
		var anchor_name := str(event.get("anchor", "idle_center"))
		if not ANCHORS.has(anchor_name):
			anchor_name = "idle_center"
		_ambient_action = true
		_action = {"animation": str(event.get("animation", "idle_look")), "loop_after": "idle", "return": true, "kind": "ambient"}
		_action_remaining = float(event.get("duration", 1.2)) + 0.5
		_begin_move(ANCHORS[anchor_name])
		return
	if kind == "walk":
		var factor := float(event.get("distance_factor", 0.5))
		var direction := -1.0 if _world_ground.x > ANCHORS["idle_center"].x else 1.0
		var target_x := clampf(_world_ground.x + direction * 160.0 * factor, ANCHORS["roam_left"].x, ANCHORS["roam_right"].x)
		_begin_move(Vector2(target_x, _world_ground.y))
		return
	_ambient_action = true
	_action = {"animation": str(event.get("animation", "idle_look")), "loop_after": "idle", "return": false, "kind": "ambient"}
	_action_remaining = float(event.get("duration", 1.2)) + 0.5
	if kind == "playful_move":
		_action["move_animation"] = str(event.get("animation", "playful_hop"))
		var distance := 90.0 * float(event.get("distance_factor", 0.2))
		var destination := Vector2(clampf(_world_ground.x + _facing * distance, ANCHORS["roam_left"].x, ANCHORS["roam_right"].x), _world_ground.y)
		_begin_move(destination)
	else:
		_play(str(_action.animation))


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
		_turn_remaining = 0.12
		_play("turn_left" if _facing < 0.0 else "turn_right")
	else:
		_moving = true
		_play(str(_action.get("move_animation", "walk")), walking_speed)


func _arrived() -> void:
	if not _action.is_empty():
		_play(str(_action.get("animation", "happy")))
		return
	_play(_authoritative_loop)


func _finish_action() -> void:
	if _action.is_empty():
		return
	var actor_sprite: AnimatedTextureRect = _action.get("actor_sprite") as AnimatedTextureRect
	var payload: Dictionary = _action.get("payload", {})
	var terminal := bool(payload.get("terminal", false))
	var loop_after := str(_action.get("loop_after", _authoritative_loop))
	var should_return := bool(_action.get("return", true))
	_action.clear()
	_action_remaining = 0.0
	_ambient_action = false
	if actor_sprite == opponent_sprite and not terminal:
		_play_opponent("idle")
	if terminal:
		pass
	elif loop_after in ["sleep", "sleep_loop"]:
		_authoritative_loop = "sleep_loop"
		_play("sleep_loop")
	elif should_return and _world_ground.distance_to(ANCHORS["idle_center"]) > 1.0:
		_begin_move(ANCHORS["idle_center"])
	else:
		_play(_authoritative_loop)
	if not _event_queue.is_empty() and not _moving:
		_start_next_event()


func _on_pet_animation_finished(_animation_name: String) -> void:
	if not _action.is_empty() and (_action.get("actor_sprite") == pet_sprite or not _action.has("actor_sprite")):
		_finish_action()


func _on_opponent_animation_finished(_animation_name: String) -> void:
	if not _action.is_empty() and _action.get("actor_sprite") == opponent_sprite:
		_finish_action()


func _on_animation_marker(animation_name: String, event_name: String, _frame: int, sprite: AnimatedTextureRect, actor: String) -> void:
	if event_name == "projectile_release":
		_play_combat_effect(actor, false)
	elif event_name == "impact":
		if animation_name == "hit":
			_apply_hit_feedback(sprite)
		else:
			_play_combat_effect(actor, true)
	elif event_name == "hit_stop":
		_hit_stop_sprite = sprite
		_hit_stop_remaining = 0.055 if not reduced_motion else 0.0
		if _hit_stop_remaining > 0.0:
			sprite.set_playback_enabled(false)
	elif event_name == "animation_complete" and animation_name not in _runtime_loops():
		if not _action.is_empty():
			_finish_action()


func _apply_hit_feedback(sprite: AnimatedTextureRect) -> void:
	if hit_shake_enabled and not reduced_motion:
		_shake_sprite = sprite
		_shake_remaining = 0.09
	if damage_flash_enabled and effects_intensity != "off":
		_flash_sprite = sprite
		_flash_remaining = 0.10 if effects_intensity == "normal" else 0.06
		sprite.modulate = Color(1.35, 1.35, 1.35, 1.0)


func _update_feedback(delta: float) -> void:
	if _hit_stop_remaining > 0.0:
		_hit_stop_remaining -= delta
		if _hit_stop_remaining <= 0.0 and _hit_stop_sprite != null:
			_hit_stop_sprite.set_playback_enabled(true)
			_hit_stop_sprite = null
	if _shake_remaining > 0.0:
		_shake_remaining -= delta
		var offset := Vector2(2 if int(_shake_remaining * 1000.0) % 2 == 0 else -2, 0)
		if _shake_sprite == pet_sprite:
			_place_pet(offset)
		elif _shake_sprite == opponent_sprite:
			opponent_sprite.position = _opponent_ground - FRAME_GROUND + offset
		if _shake_remaining <= 0.0:
			_place_pet()
			opponent_sprite.position = _opponent_ground - FRAME_GROUND
			_shake_sprite = null
	if _flash_remaining > 0.0:
		_flash_remaining -= delta
		if _flash_remaining <= 0.0 and _flash_sprite != null:
			_flash_sprite.modulate = Color.WHITE
			_flash_sprite = null


func _play_combat_effect(actor: String, impact: bool) -> void:
	if effects_intensity == "off" or effect_sprite == null:
		return
	var profile := _family_profile if actor == "pet" else _encounter_profile
	if profile.is_empty():
		return
	var effect_set := str(profile.get("effect_set", ""))
	var effect_name := str(profile.get("impact_effect" if impact else "attack_effect", "impact"))
	var descriptor := _effect_descriptor(effect_set, effect_name)
	if descriptor.is_empty():
		return
	effect_sprite.visible = true
	effect_sprite.size = Vector2(96, 96) if effects_intensity == "reduced" else Vector2(128, 128)
	var target := _opponent_ground if actor == "pet" else _world_ground
	effect_sprite.position = target - effect_sprite.size * 0.5 - Vector2(0, 22)
	effect_sprite.configure(descriptor, reduced_motion, animation_speed)
	effect_sprite.restart()


func _play(animation_name: String, locomotion_scale := 1.0) -> void:
	var descriptor: Dictionary = _animations.get(animation_name, {})
	if descriptor.is_empty():
		return
	pet_sprite.configure(descriptor, reduced_motion, animation_speed * locomotion_scale)
	pet_sprite.set_facing(_facing)


func _play_opponent(animation_name: String) -> void:
	var descriptor := _opponent_descriptor(animation_name)
	if descriptor.is_empty():
		return
	opponent_sprite.configure(descriptor, reduced_motion, animation_speed)
	opponent_sprite.restart()
	opponent_sprite.set_facing(-1.0)


func _opponent_descriptor(animation_name: String) -> Dictionary:
	var current: Dictionary = opponent_sprite.get_meta("animations", {})
	return current.get(animation_name, current.get("idle", {}))


func _place_pet(offset := Vector2.ZERO) -> void:
	if pet_sprite != null:
		pet_sprite.position = _world_ground - FRAME_GROUND * pet_scale + offset
	if call_layer != null:
		for bubble in call_layer.get_children():
			if bubble is Control:
				bubble.position.x = clampf(_world_ground.x - 8.0, 16.0, 456.0)


func _load_visual_manifest() -> void:
	var file := FileAccess.open(VISUAL_MANIFEST, FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
		_visual_manifest = parser.data.get("living_animation", {}).duplicate(true)
	file.close()


func _profile_for(section: String, content_id: String) -> Dictionary:
	var profiles: Dictionary = _visual_manifest.get(section, {})
	return profiles.get(content_id, {}).duplicate(true)


func _effect_descriptor(effect_set: String, effect_name: String) -> Dictionary:
	var families: Dictionary = _visual_manifest.get("family_effects", {})
	var entry: Dictionary = families.get(effect_set, {}).get(effect_name, {})
	if entry.is_empty():
		return {}
	var path := str(entry.get("path", ""))
	if path.begins_with("game/"):
		path = "res://" + path.trim_prefix("game/")
	return {
		"path": path,
		"frames": int(entry.get("frames", 1)),
		"fps": float(entry.get("fps", 8.0)),
		"loop": bool(entry.get("loop", false)),
		"frame_size": entry.get("frame_size", [128, 128]),
		"pivot": entry.get("pivot", [64, 64]),
		"ground_anchor": [64, 116],
		"interaction_bounds": [0, 0, 128, 128],
		"event_markers": entry.get("event_markers", []),
		"animation_name": effect_name,
	}


func _build_ambient_effect(node_name: String, effect_set: String, effect_name: String, position_value: Vector2, size_value: Vector2, alpha: float) -> void:
	var descriptor := _effect_descriptor(effect_set, effect_name)
	if descriptor.is_empty():
		return
	descriptor["loop"] = true
	var value := AnimatedTextureRect.new()
	value.name = node_name
	value.position = position_value
	value.size = size_value
	value.modulate = Color(1, 1, 1, alpha)
	value.configure(descriptor, false, 0.35)
	_ambient_effects.append(value)
	add_child(value)


func _update_ambient_effects() -> void:
	var names := ["AmbientWater", "AmbientLeaves", "AmbientEmbers"]
	for index in names.size():
		var effect := get_node_or_null(names[index]) as AnimatedTextureRect
		if effect == null:
			continue
		var visible_by_frequency := ambient_frequency == "high" or ambient_frequency == "normal" and index < 2 or ambient_frequency == "low" and index == 0
		effect.visible = effects_intensity != "off" and not reduced_motion and visible_by_frequency
		effect.set_playback_enabled(effect.visible)


func _on_visibility_changed() -> void:
	var active := is_visible_in_tree()
	if pet_sprite != null:
		pet_sprite.set_playback_enabled(active and pet_sprite != _hit_stop_sprite)
	if opponent_sprite != null:
		opponent_sprite.set_playback_enabled(active and opponent_sprite.visible)
	if effect_sprite != null:
		effect_sprite.set_playback_enabled(active and effect_sprite.visible)
	for ambient_effect in _ambient_effects:
		if is_instance_valid(ambient_effect):
			ambient_effect.set_playback_enabled(active and ambient_effect.visible)
	set_process(active)


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


func _runtime_loops() -> Array[String]:
	return ["idle", "idle_look", "idle_rest", "walk", "sleep", "sleep_loop", "sick", "injured", "call"]
