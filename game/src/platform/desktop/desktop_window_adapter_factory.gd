class_name DesktopWindowAdapterFactory
extends RefCounted


static func create_for_current_host(window: Window) -> DesktopWindowAdapter:
	match OS.get_name():
		"Windows":
			return WindowsDesktopWindowAdapter.new(window)
		"macOS":
			return MacOSDesktopWindowAdapter.new(window)
		_:
			return DesktopWindowAdapter.new(window)
