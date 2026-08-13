class_name PixelUi
extends RefCounted

const ICON_ROOT := "res://assets_generated/ui/icons/"
static var tooltips_enabled := true
static var title_scale := 1.0
static var comfortable_density := true


static func configure_preferences(enable_tooltips: bool, text_scale := 1.0, density := "comfortable") -> void:
	tooltips_enabled = enable_tooltips
	title_scale = clampf(text_scale, 1.0, 1.75)
	comfortable_density = density == "comfortable"


static func icon(name: String) -> Texture2D:
	var mapped: String = str({
		"attack": "battle", "call": "health", "close": "injury", "discipline": "train",
		"egg": "evolution", "language": "settings", "map": "dungeon", "minimize": "minimal",
		"motion": "settings", "pet": "health", "shield": "defensive",
	}.get(name, name))
	var path := ICON_ROOT + str(mapped) + ".png"
	if not ResourceLoader.exists(path):
		path = ICON_ROOT + "settings.png"
	return load(path) as Texture2D


static func panel(compact := false) -> PanelContainer:
	var value := PanelContainer.new()
	var margin := (6 if compact else 8) if comfortable_density else 4
	value.add_theme_constant_override("margin_left", margin)
	value.add_theme_constant_override("margin_right", margin)
	value.add_theme_constant_override("margin_top", margin)
	value.add_theme_constant_override("margin_bottom", margin)
	value.set_meta("component", "compact_panel" if compact else "panel")
	return value


static func title(text: String, size := 16) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", maxi(18, roundi(size * title_scale)))
	value.add_theme_color_override("font_color", PixelTheme.PARCHMENT)
	value.set_meta("component", "title_bar")
	return value


static func button(text: String, icon_name := "", tooltip := "") -> Button:
	var value := Button.new()
	value.text = text
	value.focus_mode = Control.FOCUS_ALL
	value.custom_minimum_size = Vector2(48, 44 if comfortable_density else 40)
	value.tooltip_text = (tooltip if not tooltip.is_empty() else text) if tooltips_enabled else ""
	value.icon = icon(icon_name) if not icon_name.is_empty() else null
	value.expand_icon = false
	value.set_meta("component", "primary_button")
	return value


static func icon_button(icon_name: String, tooltip: String, text := "") -> Button:
	var value := button(text, icon_name, tooltip)
	value.custom_minimum_size = Vector2(48, 44 if comfortable_density else 40)
	value.set_meta("component", "icon_button")
	return value


static func tab(text: String, selected := false) -> Button:
	var value := button(text)
	value.toggle_mode = true
	value.button_pressed = selected
	value.set_meta("component", "tabs")
	return value


static func toggle(text: String, enabled: bool) -> CheckButton:
	var value := CheckButton.new()
	value.text = text
	value.button_pressed = enabled
	value.focus_mode = Control.FOCUS_ALL
	value.set_meta("component", "toggle")
	return value


static func status_meter(key: String, label_text: String, icon_name: String, value: int) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.set_meta("component", "status_bar")
	root.set_meta("meter_key", key)
	var row := HBoxContainer.new()
	root.add_child(row)
	var image := TextureRect.new()
	image.texture = icon(icon_name)
	image.custom_minimum_size = Vector2(24, 24)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(image)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var number := Label.new()
	number.name = "Value"
	number.text = "%d%%" % int(value / 100)
	row.add_child(number)
	var progress := ProgressBar.new()
	progress.name = "Progress"
	progress.min_value = 0
	progress.max_value = 10000
	progress.value = value
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(120, 14)
	root.add_child(progress)
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


static func call_bubble(icon_name := "health") -> PanelContainer:
	var root := panel(true)
	root.set_meta("component", "call_bubble")
	var image := TextureRect.new()
	image.texture = icon(icon_name)
	image.custom_minimum_size = Vector2(32, 32)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(image)
	return root


static func modal(title_text: String, body_text: String) -> PanelContainer:
	var root := panel()
	root.set_meta("component", "modal")
	var column := VBoxContainer.new()
	root.add_child(column)
	column.add_child(title(title_text, 15))
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	return root


static func card() -> PanelContainer:
	var root := panel()
	root.set_meta("component", "card")
	return root


static func starter_egg_card() -> PanelContainer:
	var root := card()
	root.set_meta("component", "starter_egg_card")
	return root


static func inventory_slot() -> PanelContainer:
	var root := panel(true)
	root.custom_minimum_size = Vector2(112, 64)
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
	value.set_meta("component", "evolution_silhouette")
	return value


static func battle_stance_control(text: String, icon_name: String) -> Button:
	var value := button(text, icon_name)
	value.toggle_mode = true
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
	value.set_meta("component", "event_log_entry")
	return value


static func reward_notification(text: String) -> PanelContainer:
	var root := panel(true)
	root.set_meta("component", "reward_notification")
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(label)
	return root
