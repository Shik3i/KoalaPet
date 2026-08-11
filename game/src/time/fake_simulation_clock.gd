class_name FakeSimulationClock
extends SimulationClock

var _utc_seconds: int
var _monotonic_seconds: float


func _init(initial_utc_seconds := 0, initial_monotonic_seconds := 0.0) -> void:
	_utc_seconds = initial_utc_seconds
	_monotonic_seconds = initial_monotonic_seconds


func utc_now_unix_seconds() -> int:
	return _utc_seconds


func monotonic_seconds() -> float:
	return _monotonic_seconds


func advance(seconds: float) -> void:
	_utc_seconds += int(seconds)
	_monotonic_seconds += seconds


func set_utc_seconds(value: int) -> void:
	_utc_seconds = value


func set_monotonic_seconds(value: float) -> void:
	_monotonic_seconds = value
