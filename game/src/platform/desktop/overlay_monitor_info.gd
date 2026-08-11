class_name OverlayMonitorInfo
extends RefCounted

var index := 0
var position := Vector2i.ZERO
var full_rect := Rect2i()
var usable_rect := Rect2i()
var scale := 1.0
var dpi := 96
var primary := false


static func from_display(screen_index: int) -> OverlayMonitorInfo:
	var info := OverlayMonitorInfo.new()
	info.index = screen_index
	info.position = DisplayServer.screen_get_position(screen_index)
	info.full_rect = Rect2i(info.position, DisplayServer.screen_get_size(screen_index))
	info.usable_rect = DisplayServer.screen_get_usable_rect(screen_index)
	info.scale = DisplayServer.screen_get_scale(screen_index)
	info.dpi = DisplayServer.screen_get_dpi(screen_index)
	info.primary = screen_index == DisplayServer.get_primary_screen()
	return info


static func synthetic(screen_index: int, full: Rect2i, usable: Rect2i, display_scale := 1.0, display_dpi := 96, is_primary := false) -> OverlayMonitorInfo:
	var info := OverlayMonitorInfo.new()
	info.index = screen_index
	info.position = full.position
	info.full_rect = full
	info.usable_rect = usable
	info.scale = display_scale
	info.dpi = display_dpi
	info.primary = is_primary
	return info


func to_dict() -> Dictionary:
	return {
		"index": index,
		"position": [position.x, position.y],
		"full_rect": [full_rect.position.x, full_rect.position.y, full_rect.size.x, full_rect.size.y],
		"usable_rect": [usable_rect.position.x, usable_rect.position.y, usable_rect.size.x, usable_rect.size.y],
		"scale": scale,
		"dpi": dpi,
		"primary": primary,
	}
