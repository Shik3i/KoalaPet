class_name AnimatedTextureRect
extends TextureRect

const FRAME_LIMIT := 128

signal animation_finished(animation_name: String)
signal animation_marker(animation_name: String, event_name: String, frame: int)

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
var _event_markers: Dictionary = {}
var _emitted_frames: Dictionary = {}
var _frame_bounds: Array[Rect2] = []
var _playback_enabled := true


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
		_update_processing()
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
	_event_markers.clear()
	_emitted_frames.clear()
	for marker in descriptor.get("event_markers", []):
		if marker is Dictionary:
			var marker_frame := int(marker.get("frame", -1))
			if marker_frame >= 0 and marker_frame < frame_count:
				if not _event_markers.has(marker_frame):
					_event_markers[marker_frame] = []
				_event_markers[marker_frame].append(str(marker.get("event", "")))
	_source = load(str(descriptor.get("path", ""))) as Texture2D
	if _source == null:
		texture = null
		set_process(false)
		return
	_atlas.atlas = _source
	texture = _atlas
	_rebuild_frame_bounds()
	_update_region()
	_emit_current_markers()
	_update_processing()


func set_playback_enabled(enabled: bool) -> void:
	_playback_enabled = enabled
	_update_processing()


func restart() -> void:
	if _source == null:
		return
	frame_index = 0
	_elapsed = 0.0
	_emitted_frames.clear()
	_update_region()
	_emit_current_markers()
	_update_processing()


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
	if _source == null or frame_count <= 1 or not _playback_enabled or not is_visible_in_tree():
		return
	_elapsed += delta
	var frame_seconds := 1.0 / (frame_fps * playback_scale * (1.35 if reduced_motion and not frame_loop else 1.0))
	if _elapsed < frame_seconds:
		return
	_elapsed = fmod(_elapsed, frame_seconds)
	# Reduced Motion shortens one-shots through cadence, but every frame is still
	# visited so synchronization markers can never be skipped.
	frame_index += 1
	if frame_index >= frame_count:
		frame_index = 0 if frame_loop else frame_count - 1
		if frame_loop:
			_emitted_frames.clear()
		if not frame_loop:
			set_process(false)
			_update_region()
			_emit_current_markers()
			animation_finished.emit(animation_name)
			return
	_update_region()
	_emit_current_markers()


func _update_region() -> void:
	if _source == null:
		return
	var frame_width := float(_source.get_width()) / float(frame_count)
	_atlas.region = Rect2(frame_width * frame_index, 0.0, frame_width, float(_source.get_height()))
	if frame_index < _frame_bounds.size():
		interaction_bounds = _frame_bounds[frame_index]
	texture = _atlas


func _emit_current_markers() -> void:
	if not _event_markers.has(frame_index) or _emitted_frames.has(frame_index):
		return
	_emitted_frames[frame_index] = true
	for event_name in _event_markers[frame_index]:
		if not str(event_name).is_empty():
			animation_marker.emit(animation_name, str(event_name), frame_index)


func _rebuild_frame_bounds() -> void:
	_frame_bounds.clear()
	var image := _source.get_image()
	if image == null or image.is_empty():
		return
	var frame_width := image.get_width() / frame_count
	for index in frame_count:
		var frame := image.get_region(Rect2i(index * frame_width, 0, frame_width, image.get_height()))
		var used := frame.get_used_rect()
		if used.size == Vector2i.ZERO:
			_frame_bounds.append(interaction_bounds)
			continue
		used = used.grow(4)
		used.position.x = clampi(used.position.x, 0, FRAME_LIMIT - 1)
		used.position.y = clampi(used.position.y, 0, FRAME_LIMIT - 1)
		used.size.x = mini(used.size.x, FRAME_LIMIT - used.position.x)
		used.size.y = mini(used.size.y, FRAME_LIMIT - used.position.y)
		_frame_bounds.append(Rect2(Vector2(used.position), Vector2(used.size)))


func _update_processing() -> void:
	var should_process := _playback_enabled and frame_count > 1 and (not reduced_motion or not frame_loop)
	set_process(should_process)
