class_name SimulationClock
extends RefCounted


func utc_now_unix_seconds() -> int:
	return 0


func utc_now_text() -> String:
	return Time.get_datetime_string_from_unix_time(utc_now_unix_seconds(), false) + "Z"


func monotonic_seconds() -> float:
	return 0.0
