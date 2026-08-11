class_name OfflineProgressPolicy
extends RefCounted

const REASON_NONE := "NONE"
const REASON_MISSING_TIMESTAMP := "MISSING_TIMESTAMP"
const REASON_INVALID_TIMESTAMP := "INVALID_TIMESTAMP"
const REASON_SMALL_NEGATIVE_DRIFT := "SMALL_NEGATIVE_DRIFT"
const REASON_CLOCK_ROLLBACK := "CLOCK_ROLLBACK"
const REASON_FORWARD_JUMP := "FORWARD_JUMP"
const REASON_OFFLINE_CAP := "OFFLINE_CAP"

var offline_cap_seconds: int
var small_negative_tolerance_seconds: int
var forward_jump_threshold_seconds: int


func _init(cap_seconds := 7 * 24 * 60 * 60, negative_tolerance_seconds := 5, forward_jump_seconds := 24 * 60 * 60) -> void:
	offline_cap_seconds = maxi(0, cap_seconds)
	small_negative_tolerance_seconds = maxi(0, negative_tolerance_seconds)
	forward_jump_threshold_seconds = maxi(0, forward_jump_seconds)


func evaluate(persisted_utc: Variant, current_utc: Variant) -> Dictionary:
	var persisted := _parse_utc(persisted_utc)
	if not persisted.ok:
		return _result(null, 0, REASON_MISSING_TIMESTAMP if persisted.missing else REASON_INVALID_TIMESTAMP, false)
	var current := _parse_utc(current_utc)
	if not current.ok:
		return _result(null, 0, REASON_MISSING_TIMESTAMP if current.missing else REASON_INVALID_TIMESTAMP, false)
	var raw_seconds: int = current.seconds - persisted.seconds
	if raw_seconds < -small_negative_tolerance_seconds:
		return _result(raw_seconds, 0, REASON_CLOCK_ROLLBACK, true)
	if raw_seconds < 0:
		return _result(raw_seconds, 0, REASON_SMALL_NEGATIVE_DRIFT, true)
	if raw_seconds > offline_cap_seconds:
		return _result(raw_seconds, offline_cap_seconds, REASON_OFFLINE_CAP, true)
	if raw_seconds > forward_jump_threshold_seconds:
		return _result(raw_seconds, raw_seconds, REASON_FORWARD_JUMP, true)
	return _result(raw_seconds, raw_seconds, REASON_NONE, false)


func _parse_utc(value: Variant) -> Dictionary:
	if value == null or (value is String and value.strip_edges().is_empty()):
		return {"ok": false, "missing": true}
	if value is int or value is float:
		return {"ok": true, "seconds": int(value), "missing": false}
	if not value is String or not value.ends_with("Z"):
		return {"ok": false, "missing": false}
	var utc_pattern := RegEx.new()
	utc_pattern.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
	if utc_pattern.search(value) == null:
		return {"ok": false, "missing": false}
	var unix_seconds := Time.get_unix_time_from_datetime_string(value)
	if unix_seconds < 0:
		return {"ok": false, "missing": false}
	return {"ok": true, "seconds": int(unix_seconds), "missing": false}


func _result(raw_seconds: Variant, accepted_seconds: int, reason: String, anomalous: bool) -> Dictionary:
	return {
		"raw_observed_seconds": raw_seconds,
		"accepted_simulation_seconds": accepted_seconds,
		"reason": reason,
		"anomalous": anomalous,
		"capped": reason == REASON_OFFLINE_CAP,
	}
