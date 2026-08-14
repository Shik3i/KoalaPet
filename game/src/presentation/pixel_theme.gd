class_name PixelTheme
extends RefCounted

const INK := Color("#101820")
const DEEP := Color("#182631")
const PANEL := Color("#20323b")
const PANEL_LIGHT := Color("#2b414a")
const PARCHMENT := Color("#f3e2b8")
const SILVER := Color("#9eb0b3")
const GOLD := Color("#e6bd67")
const MOSS := Color("#72a85d")
const ALERT := Color("#e36b58")
const SKY := Color("#7ab2cc")

const SEVERITY_COLORS := {
	"success": MOSS,
	"notice": GOLD,
	"blocked": GOLD,
	"failure": ALERT,
	"urgent": ALERT,
	"info": SKY,
}


static func create(_ui_scale := 1.0, text_scale := 1.0, high_contrast := false) -> Theme:
	var theme := Theme.new()
	theme.default_base_scale = 1.0
	_apply_text(theme, text_scale)
	var border := Color.WHITE if high_contrast else Color("#0a1117")
	var content := UiMetrics.space(UiMetrics.SPACE_CONTROL)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, border, 3 if high_contrast else 2, content))
	theme.set_stylebox("panel", "TooltipPanel", _box(Color("#121d25"), GOLD, 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("normal", "Button", _box(DEEP, Color("#0a1117"), 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("hover", "Button", _box(PANEL_LIGHT, GOLD, 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("pressed", "Button", _box(Color("#14212a"), MOSS, 2, UiMetrics.SPACE_COMPACT, Vector2(1, 1)))
	theme.set_stylebox("disabled", "Button", _box(Color("#182026"), Color("#42504f"), 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_stylebox("normal", "LineEdit", _box(Color("#111b22"), Color("#51656a"), 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("focus", "LineEdit", _box(Color("#111b22"), GOLD, 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("read_only", "LineEdit", _box(Color("#151d22"), Color("#465256"), 2, UiMetrics.SPACE_COMPACT))
	theme.set_stylebox("background", "ProgressBar", _box(Color("#0e171d"), Color("#0a1117"), 1, 0))
	theme.set_stylebox("fill", "ProgressBar", meter_fill(MOSS))
	theme.set_constant("outline_size", "Label", 1)
	theme.set_constant("separation", "HBoxContainer", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	theme.set_constant("separation", "VBoxContainer", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	theme.set_constant("h_separation", "GridContainer", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	theme.set_constant("v_separation", "GridContainer", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	theme.set_constant("icon_max_width", "Button", UiMetrics.ICON_STATUS)
	return theme


static func meter_fill(color: Color) -> StyleBoxFlat:
	var style := _box(color, color.lightened(0.22), 1, 0)
	style.shadow_size = 0
	return style


## Tabs use a tighter horizontal inset than a general button so a long localized
## label still fits inside an equally divided tab row.
static func tab_box(state: String, selected: bool) -> StyleBoxFlat:
	var background := PANEL_LIGHT if selected else DEEP
	if state == "hover":
		background = PANEL_LIGHT
	elif state == "pressed":
		background = Color("#14212a")
	elif state == "disabled":
		background = Color("#182026")
	var border := MOSS if selected else Color("#0a1117")
	if state == "hover" and not selected:
		border = GOLD
	var style := _box(background, border, 2, UiMetrics.SPACE_MICRO)
	style.content_margin_top = UiMetrics.SPACE_COMPACT
	style.content_margin_bottom = UiMetrics.SPACE_COMPACT
	return style


static func chip_box(severity: String) -> StyleBoxFlat:
	var accent: Color = SEVERITY_COLORS.get(severity, GOLD)
	var style := _box(Color("#16232b"), accent, 2, UiMetrics.space(UiMetrics.SPACE_COMPACT))
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.16).blend(Color("#16232bee"))
	return style


static func _apply_text(theme: Theme, text_scale: float) -> void:
	var scale := clampf(text_scale, 1.0, 1.75)
	var body_size := maxi(UiMetrics.TEXT_BODY, roundi(float(UiMetrics.TEXT_BODY) * scale))
	for type_name in ["Label", "Button", "LineEdit", "CheckButton", "ProgressBar", "OptionButton"]:
		theme.set_font_size("font_size", type_name, body_size)
		theme.set_color("font_color", type_name, PARCHMENT)
		theme.set_color("font_outline_color", type_name, INK)
	theme.set_font_size("font_size", "TooltipLabel", maxi(15, roundi(15.0 * scale)))
	theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	theme.set_color("font_hover_color", "Button", Color("#fff1c9"))
	theme.set_color("font_pressed_color", "Button", Color("#dce9bb"))
	theme.set_color("font_disabled_color", "Button", Color("#7b878a"))
	theme.set_color("font_focus_color", "Button", PARCHMENT)


static func _box(background: Color, border: Color, width: int, content: int, offset := Vector2.ZERO) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = content
	style.content_margin_right = content
	style.content_margin_top = content
	style.content_margin_bottom = content
	style.shadow_color = Color("#00000066")
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 2) + offset
	style.anti_aliasing = false
	return style


static func _focus_box() -> StyleBoxFlat:
	var style := _box(Color.TRANSPARENT, GOLD, 3, 0)
	style.expand_margin_left = 2
	style.expand_margin_right = 2
	style.expand_margin_top = 2
	style.expand_margin_bottom = 2
	style.shadow_size = 0
	return style
