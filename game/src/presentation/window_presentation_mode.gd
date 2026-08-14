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
	Value.SMALL: Vector2i(720, 480),
	Value.EXPANDED: Vector2i(1160, 760),
}

## Logical bounds for the genuinely resizable player windows. The minimum keeps
## the habitat, the four primary meters, one full action row and unclipped
## German labels visible; the maximum stops Expanded from claiming the desktop.
const MIN_SIZES := {
	Value.MINIMAL: Vector2i(240, 160),
	Value.SMALL: Vector2i(600, 380),
	Value.EXPANDED: Vector2i(900, 620),
}

const MAX_SIZES := {
	Value.MINIMAL: Vector2i(560, 480),
	Value.SMALL: Vector2i(1280, 860),
	Value.EXPANDED: Vector2i(2200, 1400),
}


static func label(mode: int) -> String:
	return LABELS.get(mode, "UNKNOWN")


static func is_user_resizable(mode: int) -> bool:
	return mode in [Value.SMALL, Value.EXPANDED]


static func min_size(mode: int) -> Vector2i:
	return MIN_SIZES.get(mode, MIN_SIZES[Value.SMALL])


static func max_size(mode: int) -> Vector2i:
	return MAX_SIZES.get(mode, MAX_SIZES[Value.SMALL])


## Clamps a remembered logical size into the supported range for the mode.
static func clamp_size(mode: int, requested: Vector2i) -> Vector2i:
	if not is_user_resizable(mode):
		return default_size(mode)
	var minimum := min_size(mode)
	var maximum := max_size(mode)
	if requested.x <= 0 or requested.y <= 0:
		return default_size(mode)
	return Vector2i(clampi(requested.x, minimum.x, maximum.x), clampi(requested.y, minimum.y, maximum.y))


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
	# Width must track the full text request in both modes: Small still has to
	# fit four meter names, three action labels and five window controls on one
	# row each, and at half growth a 150% text scale pushed the window controls
	# off the right edge entirely. Height grows more slowly in Small because the
	# habitat absorbs the difference.
	var text_request := maxf(0.0, text_scale - 1.0)
	var height_factor := 1.0 if mode == Value.EXPANDED else 0.5
	var width_growth := 1.0 + text_request
	var height_growth := 1.0 + text_request * height_factor
	return Vector2i(roundi(base.x * ui_scale * width_growth), roundi(base.y * ui_scale * height_growth))


## The physical bounds for a mode at a given UI and text scale. The minimum has
## to follow the text request as well, otherwise the player can drag the window
## below the size where its own labels fit.
static func scaled_bounds(mode: int, ui_scale: float, text_scale: float) -> Dictionary:
	var reference := scaled_size(mode, ui_scale, text_scale)
	var base := default_size(mode)
	var width_ratio := float(reference.x) / maxf(1.0, float(base.x))
	var height_ratio := float(reference.y) / maxf(1.0, float(base.y))
	var minimum := min_size(mode)
	var maximum := max_size(mode)
	return {
		"minimum": Vector2i(roundi(minimum.x * width_ratio), roundi(minimum.y * height_ratio)),
		"maximum": Vector2i(roundi(maximum.x * width_ratio), roundi(maximum.y * height_ratio)),
		"reference": reference,
	}
