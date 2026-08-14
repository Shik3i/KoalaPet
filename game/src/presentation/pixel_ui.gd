class_name PixelUi
extends RefCounted

## Shared player-facing pixel components.
##
## Icon names now resolve to a dedicated icon. The rejected build aliased
## `close` to the injury plaster, `minimize` to the Minimal-mode glyph and
## `discipline` to the training log, which is why the header read as a row of
## unrelated symbols. Anything still without dedicated art resolves to a
## deliberate, documented stand-in rather than the settings cog.

const ICON_ROOT := "res://assets_generated/ui/icons/"

## Only genuine synonyms remain. Every alias points at art that depicts the
## same subject, so no control shows a symbol for a different concept.
const ICON_ALIASES := {
	"attack": "battle",
	"shield": "defensive",
	"map": "dungeon",
	"pet": "health",
	"language": "settings",
	"motion": "settings",
	"xp": "level",
	"experience": "level",
	"satiety_bps": "satiety",
	"mood_bps": "mood",
	"energy_bps": "energy",
	"hygiene_bps": "hygiene",
	"health_bps": "health",
	"discipline_bps": "discipline",
}

static var tooltips_enabled := true
static var title_scale := 1.0
static var comfortable_density := true
static var _missing_icons: Dictionary = {}


static func configure_preferences(enable_tooltips: bool, text_scale := 1.0, density := "comfortable") -> void:
	tooltips_enabled = enable_tooltips
	title_scale = clampf(text_scale, 1.0, 1.75)
	comfortable_density = density == "comfortable"
	UiMetrics.configure(density, text_scale)


static func icon_name_for(name: String) -> String:
	return str(ICON_ALIASES.get(name, name))


static func icon_exists(name: String) -> bool:
	return ResourceLoader.exists(ICON_ROOT + icon_name_for(name) + ".png")


static func missing_icon_names() -> Array:
	return _missing_icons.keys()


## `scale_step` selects the pre-exported nearest-neighbour twin. Godot would
## otherwise resample a Button icon with the viewport filter and soften the
## pixel art, so large controls load exact 2x source art instead.
static func icon(name: String, scale_step := 1) -> Texture2D:
	var resolved := icon_name_for(name)
	var directory := ICON_ROOT + ("x2/" if scale_step >= 2 else "")
	var path := directory + resolved + ".png"
	if not ResourceLoader.exists(path):
		path = ICON_ROOT + resolved + ".png"
	if not ResourceLoader.exists(path):
		_missing_icons[name] = true
		push_warning("KoalaPet UI icon missing: %s" % name)
		path = ICON_ROOT + "settings.png"
	return load(path) as Texture2D


## A pixel icon at an exact integer multiple of the 24 px source art.
static func icon_rect(name: String, display_size: int) -> TextureRect:
	var value := TextureRect.new()
	value.texture = icon(name)
	value.custom_minimum_size = Vector2(display_size, display_size)
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.set_meta("component", "icon")
	value.set_meta("icon_name", icon_name_for(name))
	return value


static func panel(compact := false) -> PanelContainer:
	var value := PanelContainer.new()
	var margin := UiMetrics.space(UiMetrics.SPACE_COMPACT if compact else UiMetrics.SPACE_CONTROL)
	value.add_theme_constant_override("margin_left", margin)
	value.add_theme_constant_override("margin_right", margin)
	value.add_theme_constant_override("margin_top", margin)
	value.add_theme_constant_override("margin_bottom", margin)
	value.set_meta("component", "compact_panel" if compact else "panel")
	return value


static func title(text: String, size := UiMetrics.TEXT_PANEL_TITLE) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", UiMetrics.font_size(size))
	value.add_theme_color_override("font_color", PixelTheme.PARCHMENT)
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.set_meta("component", "title_bar")
	return value


## Captions never wrap by default: inside a narrow grid column an autowrapping
## label collapses to one character per line instead of shrinking the column.
static func caption(text: String, wrap := false) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	value.add_theme_color_override("font_color", PixelTheme.SILVER)
	if wrap:
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.set_meta("component", "caption")
	return value


static func body(text: String) -> Label:
	var value := Label.new()
	value.text = text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.set_meta("component", "body_text")
	return value


static func button(text: String, icon_name := "", tooltip := "") -> Button:
	var value := Button.new()
	value.text = text
	value.focus_mode = Control.FOCUS_ALL
	value.custom_minimum_size = Vector2(UiMetrics.BUTTON_HEIGHT, UiMetrics.button_height())
	value.tooltip_text = (tooltip if not tooltip.is_empty() else text) if tooltips_enabled else ""
	value.icon = icon(icon_name) if not icon_name.is_empty() else null
	value.expand_icon = false
	value.add_theme_constant_override("icon_max_width", UiMetrics.ICON_STATUS)
	value.add_theme_constant_override("h_separation", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	value.set_meta("component", "primary_button")
	value.set_meta("accessible_label", tooltip if not tooltip.is_empty() else text)
	if not icon_name.is_empty():
		value.set_meta("icon_name", icon_name_for(icon_name))
	return value


## The three or four highlighted care/adventure actions in Small mode.
## Icon above text keeps German labels readable without shrinking either part.
static func primary_action(text: String, icon_name: String, tooltip := "") -> Button:
	var value := Button.new()
	value.text = text
	value.focus_mode = Control.FOCUS_ALL
	value.clip_text = true
	value.icon = icon(icon_name, 1 if UiMetrics.is_compact() else 2)
	value.expand_icon = false
	value.custom_minimum_size = Vector2(96, UiMetrics.primary_action_height())
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.tooltip_text = (tooltip if not tooltip.is_empty() else text) if tooltips_enabled else ""
	value.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_ACTION))
	# A primary action always shows icon *and* localized text, at an integer
	# multiple of the 24 px source so the pixel icon stays crisp.
	value.add_theme_constant_override("icon_max_width", UiMetrics.ICON_SOURCE if UiMetrics.is_compact() else UiMetrics.ICON_ACTION)
	value.add_theme_constant_override("h_separation", UiMetrics.space(UiMetrics.SPACE_CONTROL))
	value.set_meta("component", "primary_action")
	value.set_meta("accessible_label", tooltip if not tooltip.is_empty() else text)
	value.set_meta("icon_name", icon_name_for(icon_name))
	return value


## Small square control used only for window chrome and header affordances.
static func window_button(icon_name: String, tooltip: String, danger := false) -> Button:
	var value := Button.new()
	value.focus_mode = Control.FOCUS_ALL
	value.custom_minimum_size = Vector2(UiMetrics.WINDOW_BUTTON, UiMetrics.WINDOW_BUTTON)
	value.tooltip_text = tooltip
	value.icon = icon(icon_name)
	value.expand_icon = false
	value.add_theme_constant_override("icon_max_width", UiMetrics.ICON_WINDOW)
	value.set_meta("component", "window_button")
	value.set_meta("accessible_label", tooltip)
	value.set_meta("icon_name", icon_name_for(icon_name))
	if danger:
		value.add_theme_color_override("font_hover_color", PixelTheme.ALERT)
	return value


static func icon_button(icon_name: String, tooltip: String, text := "") -> Button:
	var value := button(text, icon_name, tooltip)
	value.custom_minimum_size = Vector2(UiMetrics.button_height(), UiMetrics.button_height())
	value.set_meta("component", "icon_button")
	return value


## Bottom navigation entry. Always icon plus localized text.
static func nav_button(text: String, icon_name: String, selected: bool) -> Button:
	var value := button(text, icon_name, text)
	value.toggle_mode = true
	value.button_pressed = selected
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.custom_minimum_size = Vector2(64, UiMetrics.nav_height())
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.set_meta("component", "nav_button")
	value.set_meta("selected", selected)
	return value


static func tab(text: String, selected := false) -> Button:
	var value := button(text)
	value.toggle_mode = true
	value.button_pressed = selected
	value.clip_text = true
	value.custom_minimum_size = Vector2(72, UiMetrics.button_height())
	# Tabs sit in a fixed-width row, so their label uses the caption size and a
	# tighter inset to keep long German words such as "Entwicklung" complete.
	value.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	value.add_theme_constant_override("h_separation", UiMetrics.SPACE_MICRO)
	for state in ["normal", "hover", "pressed", "disabled"]:
		value.add_theme_stylebox_override(state, PixelTheme.tab_box(state, selected))
	value.set_meta("component", "tabs")
	value.set_meta("selected", selected)
	return value


static func toggle(text: String, enabled: bool) -> CheckButton:
	var value := CheckButton.new()
	value.text = text
	value.button_pressed = enabled
	value.focus_mode = Control.FOCUS_ALL
	value.set_meta("component", "toggle")
	return value


## Labelled care meter: icon, localized name, percentage text and a bar.
## Every status therefore carries a text alternative, not colour alone.
static func stat_meter(key: String, label_text: String, icon_name: String, value_bps: int, state_text := "", narrow := false) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UiMetrics.space(UiMetrics.SPACE_MICRO))
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.set_meta("component", "status_bar")
	root.set_meta("meter_key", key)
	var percent := clampi(roundi(float(value_bps) / 100.0), 0, 100)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	root.add_child(row)
	row.add_child(icon_rect(icon_name, UiMetrics.ICON_STATUS))
	# At the narrowest supported window the four meter names cannot all fit
	# without clipping, so the name drops out and the icon plus percentage carry
	# the meaning. The full localized name stays in the tooltip.
	var label := Label.new()
	label.name = "Label"
	label.text = "" if narrow else label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	row.add_child(label)
	var number := Label.new()
	number.name = "Value"
	number.text = "%d%%" % percent
	number.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	number.add_theme_color_override("font_color", _meter_color(percent))
	row.add_child(number)
	var progress := ProgressBar.new()
	progress.name = "Progress"
	progress.min_value = 0
	progress.max_value = 10000
	progress.value = clampi(value_bps, 0, 10000)
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(72, 12)
	progress.add_theme_stylebox_override("fill", PixelTheme.meter_fill(_meter_color(percent)))
	root.add_child(progress)
	root.tooltip_text = "%s %d%%%s" % [label_text, percent, "" if state_text.is_empty() else " · " + state_text]
	root.set_meta("accessible_label", root.tooltip_text)
	return root


static func _meter_color(percent: int) -> Color:
	if percent <= 20:
		return PixelTheme.ALERT
	if percent <= 45:
		return PixelTheme.GOLD
	return PixelTheme.MOSS


## Contextual alert shown only while a state actually needs attention.
##
## `sizing` decides how the chip competes for width:
## `fill` expands inside a column and ellipsizes, `natural` claims exactly the
## width its text needs, and `icon` drops to the pictogram plus its tooltip when
## the surrounding row is too narrow for any label at all.
static func alert_chip(text: String, icon_name: String, severity := "notice", sizing := "fill") -> PanelContainer:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", PixelTheme.chip_box(severity))
	root.set_meta("component", "alert_chip")
	root.set_meta("severity", severity)
	root.set_meta("accessible_label", text)
	root.tooltip_text = text
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	root.add_child(row)
	row.add_child(icon_rect(icon_name, UiMetrics.ICON_STATUS))
	if sizing == "icon":
		return root
	var label := Label.new()
	label.name = "AlertLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if sizing == "natural":
		# The chip reserves exactly its text, so a header alert is never clipped
		# to an unreadable fragment such as "Hat Hu".
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	else:
		# An ellipsis overrun drops the label's minimum width to almost nothing,
		# so without an explicit expand the chip rendered as a bare icon.
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(48, 0)
	row.add_child(label)
	return root


static func segmented_status(value: int, segments := 5) -> HBoxContainer:
	var root := HBoxContainer.new()
	root.set_meta("component", "segmented_status_indicator")
	for index in range(segments):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(14, 8)
		segment.color = PixelTheme.MOSS if value > index * 10000 / segments else Color("#314047")
		root.add_child(segment)
	return root


static func call_bubble(icon_name := "call") -> PanelContainer:
	var root := panel(true)
	root.set_meta("component", "call_bubble")
	root.add_child(icon_rect(icon_name, 32))
	return root


static func modal(title_text: String, body_text: String) -> PanelContainer:
	var root := panel()
	root.set_meta("component", "modal")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiMetrics.space(UiMetrics.SPACE_CONTROL))
	root.add_child(column)
	column.add_child(title(title_text, UiMetrics.TEXT_PANEL_TITLE))
	if not body_text.is_empty():
		column.add_child(body(body_text))
	return root


static func card() -> PanelContainer:
	var root := panel()
	root.set_meta("component", "card")
	return root


static func starter_egg_card() -> PanelContainer:
	var root := card()
	root.set_meta("component", "starter_egg_card")
	return root


## Wide enough for a pictogram plus a full German item or creature name. At the
## previous 128 px "Flusskiesel" wrapped mid-word into "Flusskiese / l".
static func inventory_slot() -> PanelContainer:
	var root := panel(true)
	root.custom_minimum_size = Vector2(196, 64)
	root.set_meta("component", "inventory_slot")
	return root


static func codex_slot() -> PanelContainer:
	var root := inventory_slot()
	root.set_meta("component", "codex_slot")
	return root


static func evolution_silhouette() -> TextureRect:
	var value := TextureRect.new()
	value.modulate = Color("#17232a")
	value.custom_minimum_size = Vector2(64, 64)
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	value.set_meta("component", "evolution_silhouette")
	return value


static func battle_stance_control(text: String, icon_name: String) -> Button:
	var value := button(text, icon_name)
	value.toggle_mode = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.set_meta("component", "battle_stance_control")
	return value


static func dungeon_node(kind: String, completed: bool) -> Button:
	var icon_name := "dungeon" if kind == "boss" else "battle" if kind == "encounter" else "mood" if kind == "event" else "health"
	var value := icon_button(icon_name, kind.capitalize())
	value.disabled = completed
	value.set_meta("component", "dungeon_node")
	return value


static func event_log_entry(text: String) -> Label:
	var value := Label.new()
	value.text = text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	value.set_meta("component", "event_log_entry")
	return value


## Transient status line. Severity drives colour *and* icon, never colour alone.
static func reward_notification(text: String, severity := "success", icon_name := "call") -> PanelContainer:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", PixelTheme.chip_box(severity))
	root.set_meta("component", "reward_notification")
	root.set_meta("severity", severity)
	root.set_meta("accessible_label", text)
	# The toast must never intercept a click aimed at the interface behind it.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiMetrics.space(UiMetrics.SPACE_COMPACT))
	root.add_child(row)
	row.add_child(icon_rect(icon_name, UiMetrics.ICON_STATUS))
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", UiMetrics.font_size(UiMetrics.TEXT_CAPTION))
	row.add_child(label)
	return root
