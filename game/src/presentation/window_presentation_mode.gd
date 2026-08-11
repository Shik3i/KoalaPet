class_name WindowPresentationMode
extends RefCounted

enum Value {
	MINIMAL,
	SMALL,
	EXPANDED,
}

const LABELS := {
	Value.MINIMAL: "MINIMAL",
	Value.SMALL: "SMALL",
	Value.EXPANDED: "EXPANDED",
}

const DEFAULT_SIZES := {
	Value.MINIMAL: Vector2i(240, 180),
	Value.SMALL: Vector2i(480, 240),
	Value.EXPANDED: Vector2i(960, 540),
}


static func label(mode: int) -> String:
	return LABELS.get(mode, "UNKNOWN")


static func from_label(value: String, fallback: int = Value.SMALL) -> int:
	var normalized := value.strip_edges().to_upper()
	for mode in LABELS:
		if LABELS[mode] == normalized:
			return mode
	return fallback


static func default_size(mode: int) -> Vector2i:
	return DEFAULT_SIZES.get(mode, DEFAULT_SIZES[Value.SMALL])
