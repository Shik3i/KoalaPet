class_name OverlaySpikeReporter
extends RefCounted

const DIAGNOSTICS_PATH := "user://desktop_overlay_spike/last_diagnostics.json"


static func write_diagnostics(adapter: DesktopWindowAdapter, extra := {}) -> OverlayApplyResult:
	var diagnostics := DesktopOverlayDiagnostics.capture(adapter)
	for key in extra:
		diagnostics[key] = extra[key]
	return OverlayPlacementStore.write_json_atomic(DIAGNOSTICS_PATH, diagnostics)
