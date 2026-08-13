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
	Value.MINIMAL: Vector2i(240, 160),
	Value.SMALL: Vector2i(640, 360),
	Value.EXPANDED: Vector2i(1120, 720),
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


static func scaled_size(mode: int, ui_scale: float, text_scale: float, minimal_pet_scale := 1.0) -> Vector2i:
	var base := default_size(mode)
	if mode == Value.MINIMAL:
		var pet_extent := roundi(112.0 * clampf(minimal_pet_scale, 0.75, 2.0))
		return Vector2i(maxi(base.x, pet_extent + 80), maxi(base.y, pet_extent + 32))
	# Text scaling needs enough physical room to reflow long localized labels.
	# Expanded keeps three dense columns, so its width must track the full text
	# request. Small has fewer controls and needs only half-growth reflow room.
	var growth_factor := 1.0 if mode == Value.EXPANDED else 0.5
	var text_growth := 1.0 + maxf(0.0, text_scale - 1.0) * growth_factor
	return Vector2i(roundi(base.x * ui_scale * text_growth), roundi(base.y * ui_scale * text_growth))
