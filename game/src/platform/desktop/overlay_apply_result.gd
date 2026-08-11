class_name OverlayApplyResult
extends RefCounted

var success := false
var degraded := false
var error_code := ""
var reason := ""
var applied_capabilities: Array[String] = []


static func ok(message := "Applied", capabilities: Array[String] = []) -> OverlayApplyResult:
	var result := OverlayApplyResult.new()
	result.success = true
	result.reason = message
	result.applied_capabilities = capabilities
	return result


static func limited(message: String, capabilities: Array[String] = []) -> OverlayApplyResult:
	var result := ok(message, capabilities)
	result.degraded = true
	return result


static func failure(code: String, message: String) -> OverlayApplyResult:
	var result := OverlayApplyResult.new()
	result.error_code = code
	result.reason = message
	return result


func to_dict() -> Dictionary:
	return {
		"success": success,
		"degraded": degraded,
		"error_code": error_code,
		"reason": reason,
		"applied_capabilities": applied_capabilities,
	}
