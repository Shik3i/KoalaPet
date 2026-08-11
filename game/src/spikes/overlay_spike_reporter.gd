class_name OverlaySpikeReporter
extends RefCounted

const DIAGNOSTICS_PATH := "user://windows_overlay_spike/last_diagnostics.json"


static func write_diagnostics(adapter: DesktopWindowAdapter) -> OverlayApplyResult:
	return OverlayPlacementStore.write_json_atomic(DIAGNOSTICS_PATH, WindowsOverlayDiagnostics.capture(adapter))
