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
			if not child is Dictionary:
				failures.append(_failure("%s.all[%d]" % [path, index], "INVALID_CONDITION", "all contains a non-object condition"))
				passed = false
				continue
			if not _evaluate_node(child, facts, "%s.all[%d]" % [path, index], failures):
				passed = false
		return passed
	if condition.has("any"):
		if not condition.any is Array or condition.any.is_empty():
			failures.append(_failure(path + ".any", "INVALID_ANY", "any requires at least one condition"))
			return false
		var branch_failures: Array[Dictionary] = []
		var branch_passed := false
		var invalid_branch := false
		for index in condition.any.size():
			var local_failures: Array[Dictionary] = []
			var child: Variant = condition.any[index]
			if not child is Dictionary:
				local_failures.append(_failure("%s.any[%d]" % [path, index], "INVALID_CONDITION", "any contains a non-object condition"))
			else:
				branch_passed = _evaluate_node(child, facts, "%s.any[%d]" % [path, index], local_failures) or branch_passed
			if _has_invalid_failure(local_failures):
				invalid_branch = true
			branch_failures.append_array(local_failures)
		if invalid_branch:
			failures.append(_failure(path + ".any", "INVALID_ANY_BRANCH", "any contains an invalid condition", {"branch_failures": branch_failures}))
			return false
		if branch_passed:
			return true
		failures.append(_failure(path + ".any", "NO_ANY_BRANCH_PASSED", "No any branch passed", {"branch_failures": branch_failures}))
		return false
	if condition.has("not"):
		if not condition.not is Dictionary:
			failures.append(_failure(path + ".not", "INVALID_NOT", "not requires one condition"))
			return false
		var nested_failures: Array[Dictionary] = []
		var nested_passed := _evaluate_node(condition.not, facts, path + ".not", nested_failures)
		if _has_invalid_failure(nested_failures):
			failures.append(_failure(path + ".not", "INVALID_NOT_OPERAND", "Negated condition is invalid"))
			return false
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


func _has_invalid_failure(failures: Array[Dictionary]) -> bool:
	for failure in failures:
		var code := str(failure.get("code", ""))
		if code.begins_with("INVALID_") or code == "UNKNOWN_OPERATOR":
			return true
		var details: Variant = failure.get("details", {})
		if details is Dictionary:
			var nested: Variant = details.get("branch_failures", [])
			if nested is Array:
				for item in nested:
					if item is Dictionary:
						var nested_failures: Array[Dictionary] = [item]
						if _has_invalid_failure(nested_failures):
							return true
	return false


func _failure(path: String, code: String, reason: String, details: Dictionary = {}) -> Dictionary:
	return {"path": path, "code": code, "reason": reason, "details": details}
