class_name AmbientAnimationScheduler
extends RefCounted

const FREQUENCIES := ["low", "normal", "high"]
const SPECIALS := ["idle_look", "idle_playful", "idle_rest", "playful_hop", "playful_pounce"]

var _random_state := 1
var _frequency := "normal"
var _reduced_motion := false
var _events_since_special := 2
var _last_special := ""
var _prop_interactions: Array[Dictionary] = []


func configure(seed: int, frequency := "normal", reduced_motion := false, prop_interactions: Array = []) -> void:
	_random_state = maxi(1, seed & 0x7fffffff)
	_frequency = frequency if frequency in FREQUENCIES else "normal"
	_reduced_motion = reduced_motion
	_prop_interactions.clear()
	for interaction in prop_interactions:
		if interaction is Dictionary and not str(interaction.get("anchor", "")).is_empty() and str(interaction.get("animation", "")) in SPECIALS:
			_prop_interactions.append(interaction.duplicate(true))


func next_event() -> Dictionary:
	var threshold := 5 if _frequency == "low" else 3 if _frequency == "normal" else 2
	if _reduced_motion:
		threshold += 3
	_events_since_special += 1
	if _events_since_special < threshold or _roll(100) < (52 if _frequency == "low" else 38 if _frequency == "normal" else 26):
		return _walk_event()
	_events_since_special = 0
	if not _reduced_motion and not _prop_interactions.is_empty() and _roll(100) < 38:
		var interaction: Dictionary = _prop_interactions[_roll(_prop_interactions.size())]
		var interaction_key := "%s@%s" % [str(interaction.get("animation", "idle_look")), str(interaction.get("anchor", "idle_center"))]
		if _prop_interactions.size() > 1 and interaction_key == _last_special:
			interaction = _prop_interactions[(_prop_interactions.find(interaction) + 1) % _prop_interactions.size()]
			interaction_key = "%s@%s" % [str(interaction.get("animation", "idle_look")), str(interaction.get("anchor", "idle_center"))]
		_last_special = interaction_key
		return {
			"kind": "prop_interaction",
			"animation": str(interaction.get("animation", "idle_look")),
			"anchor": str(interaction.get("anchor", "idle_center")),
			"duration": clampf(float(interaction.get("duration", 1.2)), 0.6, 2.5),
			"pause": _pause_duration(),
		}
	var candidates := ["idle_look", "idle_rest"] if _reduced_motion else SPECIALS.duplicate()
	if candidates.size() > 1 and _last_special in candidates:
		candidates.erase(_last_special)
	var animation := str(candidates[_roll(candidates.size())])
	_last_special = animation
	return {
		"kind": "playful_move" if animation in ["playful_hop", "playful_pounce"] else "special_idle",
		"animation": animation,
		"distance_factor": 0.12 + float(_roll(24)) / 100.0,
		"duration": 0.9 + float(_roll(8)) / 10.0,
		"pause": _pause_duration(),
	}


func _walk_event() -> Dictionary:
	return {
		"kind": "walk",
		"animation": "walk",
		"distance_factor": 0.28 + float(_roll(55)) / 100.0,
		"duration": 0.0,
		"pause": _pause_duration(),
	}


func _pause_duration() -> float:
	var base := 5.0 if _frequency == "low" else 3.4 if _frequency == "normal" else 2.2
	if _reduced_motion:
		base += 3.0
	return base + float(_roll(25)) / 10.0


func _roll(limit: int) -> int:
	if limit <= 1:
		return 0
	_random_state = int((_random_state * 1103515245 + 12345) & 0x7fffffff)
	return _random_state % limit
