class_name WindowsOverlayDiagnostics
extends RefCounted


static func capture(adapter: DesktopWindowAdapter) -> Dictionary:
	var diagnostics := adapter.capture_diagnostics()
	diagnostics["godot_version"] = Engine.get_version_info()
	diagnostics["interactive_windows_required"] = true
	diagnostics["session_gate"] = "READY" if OS.get_name() == "Windows" else "BLOCKED_NOT_WINDOWS"
	return diagnostics
