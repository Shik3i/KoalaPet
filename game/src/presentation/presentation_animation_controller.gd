class_name PresentationAnimationController
extends RefCounted

const MAX_PLAYED_EVENTS := 64

var _queue: Array[Dictionary] = []
var _played_event_ids: Array[String] = []
var _event_sequence := 0


func queue_one_shot(animation_name: String, anchor_name: String, duration := 1.1, event_id := "", loop_after := "idle", from_anchor := "") -> bool:
	var stable_id := event_id
	if stable_id.is_empty():
		_event_sequence += 1
		stable_id = "presentation:%d" % _event_sequence
	if stable_id in _played_event_ids:
		return false
	for queued in _queue:
		if str(queued.get("event_id", "")) == stable_id:
			return false
	_queue.append({
		"event_id": stable_id,
		"animation": animation_name,
		"anchor": anchor_name,
		"duration": maxf(0.1, duration),
		"loop_after": loop_after,
		"from_anchor": from_anchor,
	})
	return true


func consume_one_shot() -> Dictionary:
	if _queue.is_empty():
		return {}
	var event: Dictionary = _queue.pop_front()
	var event_id := str(event.get("event_id", ""))
	if not event_id.is_empty():
		_played_event_ids.append(event_id)
		if _played_event_ids.size() > MAX_PLAYED_EVENTS:
			_played_event_ids.pop_front()
	return event


func effective_loop(model: Dictionary, moving := false) -> String:
	if bool(model.get("sleeping", false)):
		return "sleep"
	if bool(model.get("sickness", false)):
		return "sick"
	if not model.get("injury", {}).is_empty():
		return "injured"
	if not model.get("active_battle", {}).is_empty():
		return "attack"
	if moving:
		return "walk"
	if not model.get("open_calls", []).is_empty():
		return "call"
	return "idle"


func pending_count() -> int:
	return _queue.size()


func played_count() -> int:
	return _played_event_ids.size()
