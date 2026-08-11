class_name FeatureGateService
extends RefCounted

var registry: ContentPackRegistry
var evaluator: FeatureGateEvaluator


func _init(content_registry: ContentPackRegistry, gate_evaluator := FeatureGateEvaluator.new()) -> void:
	registry = content_registry
	evaluator = gate_evaluator


func evaluate_gate(gate_id: String, facts: ProgressionFacts) -> Dictionary:
	var record := registry.resolve(gate_id)
	if record.is_empty():
		return {"passed": false, "error_code": "GATE_NOT_FOUND", "gate_id": gate_id, "failures": [{"path": "$", "code": "GATE_NOT_FOUND", "reason": "Gate is not resolved", "details": {}}]}
	if record.schema_name != "feature-gate.schema.json":
		return {"passed": false, "error_code": "NOT_A_FEATURE_GATE", "gate_id": gate_id, "failures": [{"path": "$", "code": "NOT_A_FEATURE_GATE", "reason": "Resolved content is not a feature gate", "details": {}}]}
	var result := evaluator.evaluate(record.data.condition, facts)
	result["error_code"] = "" if result.passed else "CONDITIONS_NOT_MET"
	result["gate_id"] = gate_id
	result["reward_ids"] = record.data.reward_ids.duplicate()
	return result


func evaluate_and_grant(gate_id: String, facts: ProgressionFacts, ledger: UnlockLedger) -> Dictionary:
	var evaluation := evaluate_gate(gate_id, facts)
	var grants: Array[Dictionary] = []
	if evaluation.passed:
		for reward_id in evaluation.reward_ids:
			grants.append(ledger.grant(reward_id, gate_id))
	return {"passed": evaluation.passed, "evaluation": evaluation, "grants": grants, "ledger": ledger.snapshot()}
