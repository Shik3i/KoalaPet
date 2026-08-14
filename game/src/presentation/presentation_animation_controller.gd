class_name PresentationAnimationController
extends RefCounted

const MAX_PLAYED_EVENTS := 64
const MAX_PENDING_EVENTS := 32
const PRIORITIES := {
	"evolution": 800,
	"battle": 700,
	"care": 600,
	"condition": 500,
	"sleep": 400,
	"locomotion": 300,
	"attention": 200,
	"ambient": 100,
}

var _queue: Array[Dictionary] = []
var _played_event_ids: Array[String] = []
var _event_sequence := 0


func queue_one_shot(animation_name: String, anchor_name: String, duration := 1.1, event_id := "", loop_after := "idle", from_anchor := "", event_kind := "care", payload := {}) -> bool:
	var stable_id := event_id
	if stable_id.is_empty():
		_event_sequence += 1
		stable_id = "presentation:%d" % _event_sequence
	if stable_id in _played_event_ids:
		return false
	for queued in _queue:
		if str(queued.get("event_id", "")) == stable_id:
			return false
	var queued_event := {
		"event_id": stable_id,
		"sequence": _event_sequence,
		"kind": event_kind if PRIORITIES.has(event_kind) else "care",
		"priority": int(PRIORITIES.get(event_kind, PRIORITIES["care"])),
		"animation": animation_name,
		"anchor": anchor_name,
		"duration": maxf(0.1, duration),
		"loop_after": loop_after,
		"from_anchor": from_anchor,
		"payload": payload.duplicate(true) if payload is Dictionary else {},
	}
	if _queue.size() >= MAX_PENDING_EVENTS:
		var lowest_index := 0
		for index in range(1, _queue.size()):
			if int(_queue[index].get("priority", 0)) < int(_queue[lowest_index].get("priority", 0)):
				lowest_index = index
		if int(queued_event.priority) <= int(_queue[lowest_index].get("priority", 0)):
			return false
		_queue.remove_at(lowest_index)
	_queue.append(queued_event)
	return true


func consume_one_shot() -> Dictionary:
	if _queue.is_empty():
		return {}
	var selected_index := 0
	for index in range(1, _queue.size()):
		var candidate: Dictionary = _queue[index]
		var selected: Dictionary = _queue[selected_index]
		if int(candidate.get("priority", 0)) > int(selected.get("priority", 0)):
			selected_index = index
	var event: Dictionary = _queue.pop_at(selected_index)
	var event_id := str(event.get("event_id", ""))
	if not event_id.is_empty():
		_played_event_ids.append(event_id)
		if _played_event_ids.size() > MAX_PLAYED_EVENTS:
			_played_event_ids.pop_front()
	return event


func drain_pending(limit := MAX_PENDING_EVENTS) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in mini(maxi(0, limit), _queue.size()):
		result.append(consume_one_shot())
	return result


func cancel_pending_below(priority: int) -> int:
	var kept: Array[Dictionary] = []
	var removed := 0
	for event in _queue:
		if int(event.get("priority", 0)) < priority:
			removed += 1
		else:
			kept.append(event)
	_queue = kept
	return removed


func effective_loop(model: Dictionary, moving := false) -> String:
	if not model.get("active_battle", {}).is_empty():
		return "idle"
	if not model.get("injury", {}).is_empty():
		return "injured"
	if bool(model.get("sickness", false)):
		return "sick"
	if bool(model.get("sleeping", false)):
		return "sleep_loop"
	if moving:
		return "walk"
	if not model.get("open_calls", []).is_empty():
		return "call"
	return "idle"


func pending_count() -> int:
	return _queue.size()


func played_count() -> int:
	return _played_event_ids.size()


func max_pending_events() -> int:
	return MAX_PENDING_EVENTS
