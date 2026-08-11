class_name ContentDiagnostic
extends RefCounted


static func make(code: String, message: String, source_file: String, json_path := "$", pack_id := "", severity := "error") -> Dictionary:
	return {
		"code": code,
		"message": message,
		"source_file": source_file,
		"json_path": json_path,
		"pack_id": pack_id,
		"severity": severity,
	}
