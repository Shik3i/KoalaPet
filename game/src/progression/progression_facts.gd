class_name ProgressionFacts
extends RefCounted

var _values: Dictionary


func _init(values: Dictionary = {}) -> void:
	_values = values.duplicate(true)


func has(fact_id: String) -> bool:
	return _values.has(fact_id)


func get_value(fact_id: String, default_value: Variant = null) -> Variant:
	var value: Variant = _values.get(fact_id, default_value)
	return value.duplicate(true) if value is Dictionary or value is Array else value


func snapshot() -> Dictionary:
	return _values.duplicate(true)
