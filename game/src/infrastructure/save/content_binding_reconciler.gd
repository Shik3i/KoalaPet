class_name ContentBindingReconciler
extends RefCounted

var clock: SimulationClock


func _init(simulation_clock: SimulationClock) -> void:
	clock = simulation_clock


func reconcile(envelope: Dictionary, registry: ContentPackRegistry) -> Dictionary:
	var result := envelope.duplicate(true)
	var active_records: Array = result.simulation_state.get("records", [])
	var existing_quarantine: Array = result.get("quarantined_records", [])
	var remaining_active: Array = []
	var quarantine: Array = []
	var quarantined_count := 0
	var restored_count := 0
	for record in active_records:
		var missing := _missing_requirements(record, registry)
		if missing.content_ids.is_empty() and missing.pack_ids.is_empty():
			remaining_active.append(record)
		else:
			quarantine.append({
				"raw_record": record.duplicate(true),
				"missing_content_ids": missing.content_ids,
				"required_pack_ids": missing.pack_ids,
				"quarantined_at_utc": clock.utc_now_text(),
			})
			quarantined_count += 1
	for entry in existing_quarantine:
		if not entry is Dictionary or not entry.get("raw_record") is Dictionary:
			quarantine.append(entry)
			continue
		var missing := _missing_requirements(entry.raw_record, registry)
		if missing.content_ids.is_empty() and missing.pack_ids.is_empty():
			remaining_active.append(entry.raw_record.duplicate(true))
			restored_count += 1
		else:
			var preserved: Dictionary = entry.duplicate(true)
			preserved["missing_content_ids"] = missing.content_ids
			preserved["required_pack_ids"] = missing.pack_ids
			quarantine.append(preserved)
	remaining_active.sort_custom(_record_less)
	quarantine.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _instance_id(left.get("raw_record", {})) < _instance_id(right.get("raw_record", {})) if left is Dictionary and right is Dictionary else false
	)
	result.simulation_state["records"] = remaining_active
	result["quarantined_records"] = quarantine
	return {"ok": true, "data": result, "quarantined_count": quarantined_count, "restored_count": restored_count, "active_count": remaining_active.size(), "quarantine_count": quarantine.size()}


func _missing_requirements(record: Dictionary, registry: ContentPackRegistry) -> Dictionary:
	var missing_content_ids: Array[String] = []
	var missing_pack_ids: Array[String] = []
	var definition_id := str(record.get("definition_id", ""))
	if not definition_id.is_empty() and not registry.explain_reference(definition_id).resolved:
		missing_content_ids.append(definition_id)
	var required_pack_id := str(record.get("required_pack_id", ""))
	if not required_pack_id.is_empty():
		var found := false
		for pack in registry.list_resolved_packs():
			if pack.pack_id == required_pack_id:
				found = true
				break
		if not found:
			missing_pack_ids.append(required_pack_id)
	return {"content_ids": missing_content_ids, "pack_ids": missing_pack_ids}


func _record_less(left: Variant, right: Variant) -> bool:
	return _instance_id(left) < _instance_id(right)


func _instance_id(record: Variant) -> String:
	return str(record.get("instance_id", "")) if record is Dictionary else ""
