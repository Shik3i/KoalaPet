class_name DesktopOverlayDiagnostics
extends RefCounted


static func capture(adapter: DesktopWindowAdapter) -> Dictionary:
	var diagnostics := adapter.capture_diagnostics()
	diagnostics["godot_version"] = Engine.get_version_info()
	diagnostics["interactive_native_host_required"] = true
	if adapter.is_host_supported():
		diagnostics["session_gate"] = "READY"
	elif DisplayServer.get_name() == "headless":
		diagnostics["session_gate"] = "BLOCKED_NON_NATIVE_DISPLAY"
	else:
		diagnostics["session_gate"] = "BLOCKED_WRONG_HOST"
	return diagnostics
