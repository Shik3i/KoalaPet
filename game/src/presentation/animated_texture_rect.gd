class_name AnimatedTextureRect
extends TextureRect

signal animation_finished(animation_name: String)

var frame_count := 1
var frame_fps := 1.0
var frame_loop := true
var frame_index := 0
var reduced_motion := false
var playback_scale := 1.0
var animation_name := "idle"
var mirroring_allowed := true
var interaction_bounds := Rect2(14, 12, 100, 108)
var ground_anchor := Vector2(64, 116)
var _elapsed := 0.0
var _source: Texture2D
var _atlas := AtlasTexture.new()
var _descriptor_key := ""
var _facing := 1.0


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(descriptor: Dictionary, reduce_motion := false, speed_scale := 1.0) -> void:
	reduced_motion = reduce_motion
	playback_scale = clampf(speed_scale, 0.25, 2.0)
	var next_key := "%s|%d|%.3f|%s" % [str(descriptor.get("path", "")), int(descriptor.get("frames", 1)), float(descriptor.get("fps", 1.0)), str(descriptor.get("animation_name", "idle"))]
	if next_key == _descriptor_key and _source != null:
		set_process(frame_count > 1 and not reduced_motion)
		return
	_descriptor_key = next_key
	frame_count = maxi(1, int(descriptor.get("frames", 1)))
	frame_fps = maxf(0.1, float(descriptor.get("fps", 1.0)))
	frame_loop = bool(descriptor.get("loop", true))
	animation_name = str(descriptor.get("animation_name", "idle"))
	mirroring_allowed = bool(descriptor.get("mirroring_allowed", true))
	var bounds: Array = descriptor.get("interaction_bounds", [14, 12, 100, 108])
	if bounds.size() == 4:
		interaction_bounds = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
	var anchor: Array = descriptor.get("ground_anchor", [64, 116])
	if anchor.size() == 2:
		ground_anchor = Vector2(float(anchor[0]), float(anchor[1]))
	frame_index = 0
	_elapsed = 0.0
	_source = load(str(descriptor.get("path", ""))) as Texture2D
	if _source == null:
		texture = null
		return
	_atlas.atlas = _source
	texture = _atlas
	_update_region()
	set_process(frame_count > 1 and not reduced_motion)


func set_facing(direction: float) -> void:
	var requested := -1.0 if direction < 0.0 else 1.0
	if requested < 0.0 and not mirroring_allowed:
		requested = 1.0
	_facing = requested
	pivot_offset = size * 0.5
	var magnitude := maxf(0.001, absf(scale.x))
	scale.x = magnitude * _facing


func interaction_polygon() -> PackedVector2Array:
	var frame_size := Vector2(128, 128)
	var factor := Vector2(size.x / frame_size.x, size.y / frame_size.y)
	var local_rect := Rect2(interaction_bounds.position * factor, interaction_bounds.size * factor)
	var transform := get_global_transform()
	return PackedVector2Array([
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	])


func _process(delta: float) -> void:
	if _source == null or frame_count <= 1 or reduced_motion:
		return
	_elapsed += delta
	if _elapsed < 1.0 / (frame_fps * playback_scale):
		return
	_elapsed = 0.0
	frame_index += 1
	if frame_index >= frame_count:
		frame_index = 0 if frame_loop else frame_count - 1
		if not frame_loop:
			set_process(false)
			animation_finished.emit(animation_name)
	_update_region()


func _update_region() -> void:
	if _source == null:
		return
	var frame_width := float(_source.get_width()) / float(frame_count)
	_atlas.region = Rect2(frame_width * frame_index, 0.0, frame_width, float(_source.get_height()))
	texture = _atlas
