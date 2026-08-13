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


static func create(_ui_scale := 1.0, text_scale := 1.0, high_contrast := false) -> Theme:
	var theme := Theme.new()
	theme.default_base_scale = 1.0
	_apply_text(theme, text_scale)
	var border := Color.WHITE if high_contrast else Color("#0a1117")
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, border, 3 if high_contrast else 2, 8))
	theme.set_stylebox("panel", "TooltipPanel", _box(Color("#121d25"), GOLD, 2, 8))
	theme.set_stylebox("normal", "Button", _box(DEEP, Color("#0a1117"), 2, 6))
	theme.set_stylebox("hover", "Button", _box(PANEL_LIGHT, GOLD, 2, 6))
	theme.set_stylebox("pressed", "Button", _box(Color("#14212a"), MOSS, 2, 6, Vector2(1, 1)))
	theme.set_stylebox("disabled", "Button", _box(Color("#182026"), Color("#4f5c60"), 2, 6))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_stylebox("normal", "LineEdit", _box(Color("#111b22"), Color("#51656a"), 2, 6))
	theme.set_stylebox("focus", "LineEdit", _box(Color("#111b22"), GOLD, 2, 6))
	theme.set_stylebox("read_only", "LineEdit", _box(Color("#151d22"), Color("#465256"), 2, 6))
	theme.set_stylebox("background", "ProgressBar", _box(Color("#0e171d"), Color("#0a1117"), 1, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(MOSS, Color("#a9d06f"), 1, 0))
	theme.set_constant("outline_size", "Label", 1)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("h_separation", "GridContainer", 6)
	theme.set_constant("v_separation", "GridContainer", 6)
	theme.set_constant("icon_max_width", "Button", 28)
	return theme


static func _apply_text(theme: Theme, text_scale: float) -> void:
	var body_size := roundi(16.0 * clampf(text_scale, 1.0, 1.75))
	for type_name in ["Label", "Button", "LineEdit", "CheckButton", "ProgressBar"]:
		theme.set_font_size("font_size", type_name, body_size)
		theme.set_color("font_color", type_name, PARCHMENT)
		theme.set_color("font_outline_color", type_name, INK)
	theme.set_font_size("font_size", "TooltipLabel", maxi(15, roundi(15.0 * text_scale)))
	theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	theme.set_color("font_hover_color", "Button", Color("#fff1c9"))
	theme.set_color("font_pressed_color", "Button", Color("#dce9bb"))
	theme.set_color("font_disabled_color", "Button", Color("#6f7c7f"))
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
	var style := _box(Color.TRANSPARENT, GOLD, 2, 0)
	style.expand_margin_left = 2
	style.expand_margin_right = 2
	style.expand_margin_top = 2
	style.expand_margin_bottom = 2
	return style
