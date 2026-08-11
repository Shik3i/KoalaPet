class_name OverlayCapabilities
extends RefCounted

var native_windows := false
var transparency := false
var always_on_top := false
var full_mouse_passthrough := false
var polygonal_mouse_passthrough := false
var no_focus := false
var native_drag := false
var status_indicator := false
var monitor_enumeration := false
var usable_rect := false
var dpi_query := false
var taskbar_visibility_control := false
var alt_tab_visibility_control := false


func to_dict() -> Dictionary:
	return {
		"native_windows": native_windows,
		"transparency": transparency,
		"always_on_top": always_on_top,
		"full_mouse_passthrough": full_mouse_passthrough,
		"polygonal_mouse_passthrough": polygonal_mouse_passthrough,
		"no_focus": no_focus,
		"native_drag": native_drag,
		"status_indicator": status_indicator,
		"monitor_enumeration": monitor_enumeration,
		"usable_rect": usable_rect,
		"dpi_query": dpi_query,
		"taskbar_visibility_control": taskbar_visibility_control,
		"alt_tab_visibility_control": alt_tab_visibility_control,
	}
