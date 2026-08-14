class_name UiMetrics
extends RefCounted

## One spacing, sizing and typography scale for every player-facing surface.
##
## Before this milestone the player UI positioned panels with ad-hoc numbers
## (2 px separations next to 28 px title bars, 24 px icons inside 44 px buttons).
## Everything readable now derives from these tokens, so a density or text-scale
## change moves the whole layout consistently instead of one control at a time.

## Base grid. Values are logical pixels before UI scale is applied.
const SPACE_MICRO := 4
const SPACE_COMPACT := 8
const SPACE_CONTROL := 12
const SPACE_SECTION := 16
const SPACE_MAJOR := 24

## Type ramp targets at 100% text scale.
const TEXT_BODY := 16
const TEXT_ACTION := 17
const TEXT_PANEL_TITLE := 20
const TEXT_SCREEN_TITLE := 22
const TEXT_CAPTION := 14

## Icon sizes are integer multiples of the 24 px source art so nearest-neighbour
## sampling never blurs a pixel icon.
const ICON_SOURCE := 24
const ICON_STATUS := 24
const ICON_ACTION := 48
const ICON_WINDOW := 24
const ICON_HEADER := 24

## Minimum comfortable hit targets.
const BUTTON_HEIGHT := 44
const BUTTON_HEIGHT_COMPACT := 38
const PRIMARY_ACTION_HEIGHT := 58
const PRIMARY_ACTION_HEIGHT_COMPACT := 50
const NAV_HEIGHT := 36
const NAV_HEIGHT_COMPACT := 32
const WINDOW_BUTTON := 30

static var _compact := false
static var _text_scale := 1.0


static func configure(density: String, text_scale: float) -> void:
	_compact = density == "compact"
	_text_scale = clampf(text_scale, 1.0, 1.75)


static func is_compact() -> bool:
	return _compact


static func text_scale() -> float:
	return _text_scale


static func font_size(base: int) -> int:
	return maxi(base, roundi(float(base) * _text_scale))


static func space(base: int) -> int:
	return maxi(2, base - 2) if _compact else base


## Controls must keep a usable hit target when the player enlarges text.
static func control_height(base: int) -> int:
	var resolved := base - 6 if _compact else base
	return roundi(float(resolved) * clampf(_text_scale, 1.0, 1.4))


static func button_height() -> int:
	return control_height(BUTTON_HEIGHT_COMPACT if _compact else BUTTON_HEIGHT)


static func primary_action_height() -> int:
	return control_height(PRIMARY_ACTION_HEIGHT_COMPACT if _compact else PRIMARY_ACTION_HEIGHT)


static func nav_height() -> int:
	return control_height(NAV_HEIGHT_COMPACT if _compact else NAV_HEIGHT)


static func apply_margins(target: MarginContainer, amount: int) -> void:
	var resolved := space(amount)
	target.add_theme_constant_override("margin_left", resolved)
	target.add_theme_constant_override("margin_right", resolved)
	target.add_theme_constant_override("margin_top", resolved)
	target.add_theme_constant_override("margin_bottom", resolved)


static func apply_separation(target: BoxContainer, amount: int) -> void:
	target.add_theme_constant_override("separation", space(amount))


static func apply_grid_separation(target: GridContainer, amount: int) -> void:
	target.add_theme_constant_override("h_separation", space(amount))
	target.add_theme_constant_override("v_separation", space(amount))
