class_name SystemSimulationClock
extends SimulationClock


func utc_now_unix_seconds() -> int:
	return int(Time.get_unix_time_from_system())


func monotonic_seconds() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
