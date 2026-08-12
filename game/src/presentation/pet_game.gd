extends Control

const MODE_MINIMAL := "minimal"
const MODE_SMALL := "small"
const MODE_EXPANDED := "expanded"

var application: PetApplication
var mode := MODE_SMALL
var locale := "de"
var content: VBoxContainer
var status_label: Label


func _ready() -> void:
	application = PetApplication.new({"save_path": "user://saves/koalapet.json"})
	var result := application.initialize()
	_build_shell()
	if not result.ok:
		status_label.text = "Foundation error: %s" % str(result.get("reason", result.get("stage", "unknown")))
		return
	_refresh()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("#111820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = application.text("ui.title", "KoalaPet", locale)
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for mode_name in [MODE_MINIMAL, MODE_SMALL, MODE_EXPANDED]:
		var mode_button := Button.new()
		mode_button.text = application.text("ui.mode.%s" % mode_name, mode_name.capitalize(), locale)
		mode_button.pressed.connect(_set_mode.bind(mode_name))
		header.add_child(mode_button)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	root.add_child(content)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#95a6b5"))
	root.add_child(status_label)


func _refresh() -> void:
	for child in content.get_children():
		child.queue_free()
	var model := application.get_view_model(mode, locale)
	if model.screen == "starter":
		_show_starter()
	elif model.screen == "egg":
		_show_egg(model)
	else:
		_show_pet(model)
	status_label.text = application.text("ui.save_ready", "Local save active", locale)


func _show_starter() -> void:
	var heading := Label.new()
	heading.text = application.text("ui.starter.title", "Choose one starter egg", locale)
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var hint := Label.new()
	hint.text = application.text("ui.starter.hint", "One local pet. Three data-driven beginnings.", locale)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	content.add_child(cards)
	for egg in application.get_starter_eggs():
		var egg_id := str(egg.id)
		var card := Button.new()
		card.text = application.get_display_name(egg_id, locale)
		card.tooltip_text = application.text("ui.starter.select", "Select starter", locale)
		card.custom_minimum_size = Vector2(170, 150)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var asset_path := application.get_preview_asset_path(egg_id)
		if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
			card.icon = load(asset_path)
			card.expand_icon = true
		card.pressed.connect(_choose_starter.bind(egg_id))
		cards.add_child(card)


func _show_egg(model: Dictionary) -> void:
	var heading := Label.new()
	heading.text = application.text("ui.egg.title", "Your egg is resting", locale)
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var visual := TextureRect.new()
	visual.custom_minimum_size = Vector2(180, 150)
	visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var egg_asset := application.get_asset_path("idle", true)
	if not egg_asset.is_empty() and ResourceLoader.exists(egg_asset):
		visual.texture = load(egg_asset)
	content.add_child(visual)
	var detail := Label.new()
	detail.text = application.text("ui.egg.hatch_hint", "Hatching is deterministic and time-based.", locale)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(detail)
	var hatch := Button.new()
	hatch.text = application.text("ui.dev.hatch", "Complete hatch (dev)", locale)
	hatch.pressed.connect(_complete_hatch)
	hatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(hatch)


func _show_pet(model: Dictionary) -> void:
	var heading := Label.new()
	heading.text = str(model.get("name", "Pet"))
	heading.add_theme_font_size_override("font_size", 22)
	content.add_child(heading)
	var stage := Label.new()
	stage.text = str(model.get("form_name", ""))
	stage.add_theme_color_override("font_color", Color("#95a6b5"))
	content.add_child(stage)
	var visual := TextureRect.new()
	visual.custom_minimum_size = Vector2(180, 150)
	visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var animation := "sleep" if bool(model.get("sleeping", false)) else "sick" if bool(model.get("sickness", false)) else "idle"
	var asset_path := application.get_asset_path(animation)
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		visual.texture = load(asset_path)
	content.add_child(visual)
	var state_line := Label.new()
	state_line.text = _state_line(model)
	state_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(state_line)
	if mode != MODE_MINIMAL:
		_show_care(model)
		_show_actions(model)
		_show_nickname()
	if mode == MODE_EXPANDED:
		_show_expanded(model)


func _show_care(model: Dictionary) -> void:
	var care: Dictionary = model.get("care", {})
	var stats := Label.new()
	stats.text = "  ".join([
		"Satiety %d%%" % (int(care.get("satiety_bps", 0)) / 100),
		"Mood %d%%" % (int(care.get("mood_bps", 0)) / 100),
		"Energy %d%%" % (int(care.get("energy_bps", 0)) / 100),
		"Hygiene %d%%" % (int(care.get("hygiene_bps", 0)) / 100),
	])
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stats)


func _show_actions(model: Dictionary) -> void:
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)
	_add_action(actions, application.text("ui.action.feed", "Feed", locale), _feed)
	_add_action(actions, application.text("ui.action.treat", "Treat", locale), _treat)
	_add_action(actions, application.text("ui.action.clean", "Clean", locale), _clean)
	_add_action(actions, application.text("ui.action.train", "Train", locale), _train)
	_add_action(actions, application.text("ui.action.medicine", "Medicine", locale), _medicine)
	_add_action(actions, application.text("ui.action.sleep" if not model.sleeping else "ui.action.wake", "Sleep" if not model.sleeping else "Wake", locale), _sleep_or_wake.bind(bool(model.get("sleeping", false))))
	var calls: Array = model.get("open_calls", [])
	if not calls.is_empty():
		_add_action(actions, application.text("ui.action.answer", "Answer call", locale), _resolve_call.bind(str(calls[0].get("call_id", ""))))


func _show_nickname() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var input := LineEdit.new()
	input.name = "NicknameInput"
	input.placeholder_text = application.text("ui.nickname.placeholder", "Nickname", locale)
	input.max_length = 20
	input.custom_minimum_size = Vector2(180, 0)
	row.add_child(input)
	var save_name := Button.new()
	save_name.text = application.text("ui.nickname.save", "Save name", locale)
	save_name.pressed.connect(_save_nickname.bind(input))
	row.add_child(save_name)
	content.add_child(row)


func _show_expanded(model: Dictionary) -> void:
	var aggregate: Dictionary = model.get("aggregate", {})
	var summary := Label.new()
	summary.text = "Feedings: %d   Treats: %d   Training: %d   Waste cleaned: %d   Calls missed: %d" % [int(aggregate.get("feed_count", 0)), int(aggregate.get("treat_count", 0)), int(aggregate.get("training_count", 0)), int(aggregate.get("waste_cleaned", 0)), int(aggregate.get("care_mistakes", 0))]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var history: Array = model.get("history", [])
	var history_label := Label.new()
	history_label.text = application.text("ui.history.title", "Recent history", locale) + "\n" + _history_text(history)
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(history_label)
	var dev := HBoxContainer.new()
	dev.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_action(dev, application.text("ui.dev.advance", "Advance 1 hour", locale), _advance_hour)
	_add_action(dev, application.text("ui.dev.sick", "Force ailment", locale), _force_sickness)
	content.add_child(dev)


func _add_action(parent: Container, label_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(action)
	parent.add_child(button)


func _state_line(model: Dictionary) -> String:
	var result := []
	if bool(model.get("sleeping", false)):
		result.append(application.text("ui.state.sleeping", "Sleeping", locale))
	if bool(model.get("sickness", false)):
		result.append(application.text("ui.state.sick", "Needs medicine", locale))
	if result.is_empty():
		result.append(application.text("ui.state.ready", "Ready for care", locale))
	return " · ".join(result)


func _history_text(history: Array) -> String:
	var lines: Array[String] = []
	var start := maxi(0, history.size() - 6)
	for index in range(start, history.size()):
		var entry: Dictionary = history[index]
		lines.append("%s · %s" % [str(entry.get("timestamp_utc", "")), str(entry.get("type", ""))])
	return "\n".join(lines) if not lines.is_empty() else application.text("ui.history.empty", "No events yet", locale)


func _set_mode(value: String) -> void:
	mode = value
	_refresh()


func _choose_starter(egg_id: String) -> void:
	var result := application.choose_starter(egg_id)
	status_label.text = str(result.get("reason", application.text("ui.save_ready", "Local save active", locale)))
	_refresh()


func _complete_hatch() -> void:
	var result := application.complete_hatch()
	status_label.text = str(result.get("reason", "Hatch completed"))
	_refresh()


func _feed() -> void:
	var result := application.command({"type": "feed", "item_id": application.find_item_by_kind("meal")})
	status_label.text = _command_status(result)
	_refresh()


func _treat() -> void:
	var result := application.command({"type": "feed", "item_id": application.find_item_by_kind("treat")})
	status_label.text = _command_status(result)
	_refresh()


func _clean() -> void:
	var result := application.command({"type": "clean"})
	status_label.text = _command_status(result)
	_refresh()


func _train() -> void:
	var result := application.command({"type": "train", "activity_id": application.get_training_activity_id(), "input_bps": 5000})
	status_label.text = _command_status(result)
	_refresh()


func _medicine() -> void:
	var result := application.command({"type": "medicine", "item_id": application.find_item_by_kind("medicine")})
	status_label.text = _command_status(result)
	_refresh()


func _sleep_or_wake(sleeping: bool) -> void:
	var result := application.command({"type": "wake" if sleeping else "sleep"})
	status_label.text = _command_status(result)
	_refresh()


func _resolve_call(call_id: String) -> void:
	var result := application.command({"type": "resolve_call", "call_id": call_id})
	status_label.text = _command_status(result)
	_refresh()


func _save_nickname(input: LineEdit) -> void:
	var result := application.command({"type": "set_nickname", "nickname": input.text})
	status_label.text = _command_status(result)
	_refresh()


func _advance_hour() -> void:
	var result := application.advance_simulated(3600)
	status_label.text = _command_status(result)
	_refresh()


func _force_sickness() -> void:
	var result := application.command({"type": "force_sickness"})
	status_label.text = _command_status(result)
	_refresh()


func _command_status(result: Dictionary) -> String:
	return application.text("ui.action.done", "Saved", locale) if result.get("ok", false) else str(result.get("reason", result.get("error_code", "Action failed")))
