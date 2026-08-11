class_name MacOSDesktopWindowAdapter
extends GodotNativeWindowAdapter

var _restore_borderless_after_minimize := false


func _init(window: Window = null) -> void:
	super(window, "macOS")


func minimize_window() -> OverlayApplyResult:
	var guard := _guard("minimize_window")
	if guard != null:
		return guard
	_restore_borderless_after_minimize = target_window.borderless
	if _restore_borderless_after_minimize:
		target_window.borderless = false
	target_window.mode = Window.MODE_MINIMIZED
	return OverlayApplyResult.limited(
		"macOS borderless window requested minimize after temporarily restoring native decoration",
		["minimize"]
	)


func restore_window() -> OverlayApplyResult:
	var result := super.restore_window()
	if result.success and _restore_borderless_after_minimize:
		target_window.borderless = true
		_restore_borderless_after_minimize = false
	return result
