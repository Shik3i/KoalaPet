class_name FeatureGateEvaluator
extends RefCounted


func evaluate(condition: Dictionary, facts: ProgressionFacts) -> Dictionary:
	var failures: Array[Dictionary] = []
	var passed := _evaluate_node(condition, facts, "$", failures)
	return {"passed": passed, "failures": failures}


func _evaluate_node(condition: Dictionary, facts: ProgressionFacts, path: String, failures: Array[Dictionary]) -> bool:
	if condition.has("all"):
		if not condition.all is Array or condition.all.is_empty():
			failures.append(_failure(path + ".all", "INVALID_ALL", "all requires at least one condition"))
			return false
		var passed := true
		for index in condition.all.size():
			var child: Variant = condition.all[index]
			if not child is Dictionary or not _evaluate_node(child, facts, "%s.all[%d]" % [path, index], failures):
				passed = false
		return passed
	if condition.has("any"):
		if not condition.any is Array or condition.any.is_empty():
			failures.append(_failure(path + ".any", "INVALID_ANY", "any requires at least one condition"))
			return false
		var branch_failures: Array[Dictionary] = []
		for index in condition.any.size():
			var local_failures: Array[Dictionary] = []
			var child: Variant = condition.any[index]
			if child is Dictionary and _evaluate_node(child, facts, "%s.any[%d]" % [path, index], local_failures):
				return true
			branch_failures.append_array(local_failures)
		failures.append(_failure(path + ".any", "NO_ANY_BRANCH_PASSED", "No any branch passed", {"branch_failures": branch_failures}))
		return false
	if condition.has("not"):
		if not condition.not is Dictionary:
			failures.append(_failure(path + ".not", "INVALID_NOT", "not requires one condition"))
			return false
		var nested_failures: Array[Dictionary] = []
		var nested_passed := _evaluate_node(condition.not, facts, path + ".not", nested_failures)
		if nested_passed:
			failures.append(_failure(path + ".not", "NOT_CONDITION_PASSED", "Negated condition passed"))
			return false
		return true
	return _evaluate_leaf(condition, facts, path, failures)


func _evaluate_leaf(condition: Dictionary, facts: ProgressionFacts, path: String, failures: Array[Dictionary]) -> bool:
	var fact_id := str(condition.get("fact", ""))
	var operation := str(condition.get("operator", ""))
	var expected: Variant = condition.get("value")
	if fact_id.is_empty() or operation.is_empty():
		failures.append(_failure(path, "INVALID_CONDITION", "Leaf condition requires fact and operator"))
		return false
	var exists := facts.has(fact_id)
	var actual: Variant = facts.get_value(fact_id)
	var passed := false
	match operation:
		"eq":
			passed = exists and actual == expected
		"neq":
			passed = exists and actual != expected
		"gte":
			passed = exists and _is_number(actual) and _is_number(expected) and float(actual) >= float(expected)
		"lte":
			passed = exists and _is_number(actual) and _is_number(expected) and float(actual) <= float(expected)
		"gt":
			passed = exists and _is_number(actual) and _is_number(expected) and float(actual) > float(expected)
		"lt":
			passed = exists and _is_number(actual) and _is_number(expected) and float(actual) < float(expected)
		"contains":
			passed = exists and _contains(actual, expected)
		"has":
			passed = exists == bool(expected)
		_:
			failures.append(_failure(path + ".operator", "UNKNOWN_OPERATOR", "Unknown operator: %s" % operation))
			return false
	if not passed:
		failures.append(_failure(path, "CONDITION_FAILED", "Fact %s did not satisfy %s" % [fact_id, operation], {"fact": fact_id, "operator": operation, "expected": expected, "actual": actual, "fact_exists": exists}))
	return passed


func _contains(container: Variant, expected: Variant) -> bool:
	if container is Array or container is PackedStringArray:
		return expected in container
	if container is Dictionary:
		return container.has(expected)
	if container is String and expected is String:
		return container.contains(expected)
	return false


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _failure(path: String, code: String, reason: String, details: Dictionary = {}) -> Dictionary:
	return {"path": path, "code": code, "reason": reason, "details": details}
