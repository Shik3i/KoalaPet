extends Control

const MODE_MINIMAL := "minimal"
const MODE_SMALL := "small"
const MODE_EXPANDED := "expanded"

var application: PetApplication
var mode := MODE_SMALL
var locale := "de"
var content: VBoxContainer
var status_label: Label
var background: ColorRect
var header: VBoxContainer
var shell_margin: MarginContainer
var show_dev_tools := false
var minimal_visual: TextureRect
var last_applied_mode := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	application = PetApplication.new({"save_path": _argument_value(args, "--save-path=", "user://saves/koalapet.json")})
	show_dev_tools = "--dev-tools" in args
	var requested_mode := _argument_value(args, "--mode=", MODE_SMALL)
	mode = requested_mode if requested_mode in [MODE_MINIMAL, MODE_SMALL, MODE_EXPANDED] else MODE_SMALL
	var result := application.initialize()
	_build_shell()
	if not result.ok:
		status_label.text = "Foundation error: %s" % str(result.get("reason", result.get("stage", "unknown")))
		return
	_refresh()
	_apply_window_presentation()
	var review_actions := _argument_value(args, "--review-actions=", "")
	if not review_actions.is_empty():
		call_deferred("_run_review_actions", review_actions.split(",", false))


func _build_shell() -> void:
	background = ColorRect.new()
	background.color = Color("#111820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	shell_margin = MarginContainer.new()
	shell_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell_margin.add_theme_constant_override("margin_left", 24)
	shell_margin.add_theme_constant_override("margin_right", 24)
	shell_margin.add_theme_constant_override("margin_top", 18)
	shell_margin.add_theme_constant_override("margin_bottom", 18)
	background.add_child(shell_margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	shell_margin.add_child(root)
	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)
	var title_row := HBoxContainer.new()
	header.add_child(title_row)
	var title := Label.new()
	title.text = application.text("ui.title", "KoalaPet", locale)
	title.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#95a6b5"))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)
	var controls_row := HBoxContainer.new()
	controls_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls_row.add_theme_constant_override("separation", 6)
	header.add_child(controls_row)
	for mode_name in [MODE_MINIMAL, MODE_SMALL, MODE_EXPANDED]:
		var mode_button := Button.new()
		var mode_key := "ui.minimal" if mode_name == MODE_MINIMAL else "ui.small" if mode_name == MODE_SMALL else "ui.expanded"
		mode_button.text = application.text(mode_key, mode_name.capitalize(), locale)
		mode_button.pressed.connect(_set_mode.bind(mode_name))
		mode_button.focus_mode = Control.FOCUS_ALL
		controls_row.add_child(mode_button)
	var language_button := Button.new()
	language_button.text = "DE"
	language_button.tooltip_text = "Deutsch / English"
	language_button.focus_mode = Control.FOCUS_ALL
	language_button.pressed.connect(_toggle_locale)
	controls_row.add_child(language_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)


func _apply_window_presentation() -> void:
	var minimal := mode == MODE_MINIMAL
	get_window().transparent = minimal
	get_viewport().transparent_bg = minimal
	get_window().unfocusable = minimal
	get_window().mouse_passthrough = false
	get_window().mouse_passthrough_polygon = PackedVector2Array()
	background.color = Color.TRANSPARENT if minimal else Color("#111820")
	header.visible = not minimal
	status_label.visible = not minimal
	shell_margin.add_theme_constant_override("margin_left", 0 if minimal else 24)
	shell_margin.add_theme_constant_override("margin_right", 0 if minimal else 24)
	var compact_margin := 6 if mode == MODE_SMALL else 18
	shell_margin.add_theme_constant_override("margin_top", 0 if minimal else compact_margin)
	shell_margin.add_theme_constant_override("margin_bottom", 0 if minimal else compact_margin)
	if last_applied_mode != mode:
		get_window().size = Vector2i(320, 240) if minimal else Vector2i(960, 720) if mode == MODE_EXPANDED else Vector2i(800, 600)
		last_applied_mode = mode
	call_deferred("_update_minimal_hit_region")


func _update_minimal_hit_region() -> void:
	if mode != MODE_MINIMAL or minimal_visual == null or not is_instance_valid(minimal_visual):
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		return
	var rect := minimal_visual.get_global_rect().grow(8.0)
	get_window().mouse_passthrough_polygon = PackedVector2Array([
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])


func _refresh(status_override := "") -> void:
	for child in content.get_children():
		child.free()
	minimal_visual = null
	var model := application.get_view_model(mode, locale)
	if model.screen == "starter":
		_show_starter()
	elif model.screen == "egg":
		_show_egg(model)
	else:
		_show_pet(model)
	status_label.text = status_override if not status_override.is_empty() else _offline_status(model)
	_apply_window_presentation()


func _show_starter() -> void:
	var heading := Label.new()
	heading.text = application.text("ui.choose_egg", "Choose an egg", locale)
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var hint := Label.new()
	hint.text = application.text("ui.choose_egg_hint", "Each egg grows into a different first companion.", locale)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var cards := GridContainer.new()
	cards.columns = 3
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	content.add_child(cards)
	for egg in application.get_starter_eggs():
		var egg_id := str(egg.id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(120, 190)
		card.add_theme_constant_override("separation", 4)
		card.size_flags_horizontal = Control.SIZE_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 4)
		card.add_child(card_content)
		var asset_path := application.get_preview_asset_path(egg_id)
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(0, 110)
		preview.size_flags_horizontal = Control.SIZE_FILL
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not asset_path.is_empty():
			var preview_texture: Texture2D = load(asset_path)
			if preview_texture != null:
				preview.texture = preview_texture
		card_content.add_child(preview)
		var select_button := Button.new()
		select_button.text = application.get_display_name(egg_id, locale)
		select_button.tooltip_text = application.text("ui.select", "Select", locale)
		select_button.focus_mode = Control.FOCUS_ALL
		select_button.custom_minimum_size = Vector2(0, 48)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.pressed.connect(_choose_starter.bind(egg_id))
		card_content.add_child(select_button)
		cards.add_child(card)
	if cards.get_child_count() > 0:
		cards.get_child(0).get_child(0).get_child(1).call_deferred("grab_focus")


func _show_egg(model: Dictionary) -> void:
	var heading := Label.new()
	heading.text = application.text("ui.hatching", "Your egg is warming up", locale)
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var visual := TextureRect.new()
	visual.custom_minimum_size = Vector2(180, 150)
	visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var egg_asset := application.get_asset_path("idle", true)
	if not egg_asset.is_empty():
		var egg_texture: Texture2D = load(egg_asset)
		if egg_texture != null:
			visual.texture = egg_texture
	content.add_child(visual)
	var detail := Label.new()
	detail.text = "%s %d%%" % [application.text("ui.hatch_progress", "Hatch progress", locale), int(model.get("hatch_progress_bps", 0)) / 100]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(detail)
	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 10000
	progress.value = int(model.get("hatch_progress_bps", 0))
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(260, 18)
	progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(progress)
	if show_dev_tools:
		var hatch := Button.new()
		hatch.text = application.text("ui.hatch_now", "Hatch now (development)", locale)
		hatch.pressed.connect(_complete_hatch)
		hatch.focus_mode = Control.FOCUS_ALL
		hatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(hatch)


func _show_pet(model: Dictionary) -> void:
	if mode != MODE_MINIMAL:
		var heading := Label.new()
		heading.text = str(model.get("name", "Pet"))
		heading.add_theme_font_size_override("font_size", 22)
		content.add_child(heading)
		var stage := Label.new()
		stage.text = str(model.get("form_name", ""))
		stage.add_theme_color_override("font_color", Color("#95a6b5"))
		content.add_child(stage)
	var visual := TextureRect.new()
	visual.custom_minimum_size = Vector2(220, 180) if mode == MODE_MINIMAL else Vector2(110, 80) if mode == MODE_SMALL else Vector2(180, 150)
	visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var animation := "sleep" if bool(model.get("sleeping", false)) else "sick" if bool(model.get("sickness", false)) else "idle"
	var asset_path := application.get_asset_path(animation)
	if not asset_path.is_empty():
		var pet_texture: Texture2D = load(asset_path)
		if pet_texture != null:
			visual.texture = pet_texture
	minimal_visual = visual
	visual.mouse_filter = Control.MOUSE_FILTER_STOP if mode == MODE_MINIMAL else Control.MOUSE_FILTER_IGNORE
	if mode == MODE_MINIMAL:
		visual.gui_input.connect(_on_minimal_visual_input)
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
		"%s %d%%" % [application.text("ui.satiety", "Satiety", locale), int(care.get("satiety_bps", 0)) / 100],
		"%s %d%%" % [application.text("ui.mood", "Mood", locale), int(care.get("mood_bps", 0)) / 100],
		"%s %d%%" % [application.text("ui.energy", "Energy", locale), int(care.get("energy_bps", 0)) / 100],
		"%s %d%%" % [application.text("ui.hygiene", "Hygiene", locale), int(care.get("hygiene_bps", 0)) / 100],
	])
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stats)


func _show_actions(model: Dictionary) -> void:
	var actions := GridContainer.new()
	actions.columns = 4
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	content.add_child(actions)
	_add_action(actions, application.text("ui.feed", "Feed", locale), _feed)
	_add_action(actions, application.text("ui.treat", "Treat", locale), _treat)
	_add_action(actions, application.text("ui.clean", "Clean", locale), _clean)
	_add_action(actions, application.text("ui.train", "Train", locale), _train)
	_add_action(actions, application.text("ui.medicine", "Medicine", locale), _medicine)
	_add_action(actions, application.text("ui.sleep" if not model.sleeping else "ui.wake", "Sleep" if not model.sleeping else "Wake", locale), _sleep_or_wake.bind(bool(model.get("sleeping", false))))
	var calls: Array = model.get("open_calls", [])
	if not calls.is_empty():
		_add_action(actions, application.text("ui.resolve", "Resolve", locale), _resolve_call.bind(str(calls[0].get("call_id", ""))))


func _show_nickname() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var input := LineEdit.new()
	input.name = "NicknameInput"
	input.placeholder_text = application.text("ui.nickname_hint", "Optional nickname", locale)
	input.max_length = 20
	input.custom_minimum_size = Vector2(180, 0)
	row.add_child(input)
	var save_name := Button.new()
	save_name.text = application.text("ui.save", "Save", locale)
	save_name.pressed.connect(_save_nickname.bind(input))
	row.add_child(save_name)
	content.add_child(row)


func _show_expanded(model: Dictionary) -> void:
	var aggregate: Dictionary = model.get("aggregate", {})
	var summary := Label.new()
	summary.text = "%s: %d   %s: %d   %s: %d   %s: %d   %s: %d" % [application.text("ui.feed", "Feed", locale), int(aggregate.get("feed_count", 0)), application.text("ui.treat", "Treat", locale), int(aggregate.get("treat_count", 0)), application.text("ui.train", "Train", locale), int(aggregate.get("training_count", 0)), application.text("ui.waste", "Waste cleaned", locale), int(aggregate.get("waste_cleaned", 0)), application.text("ui.care_mistakes", "Care mistakes", locale), int(aggregate.get("care_mistakes", 0))]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var history: Array = model.get("history", [])
	var history_label := Label.new()
	history_label.text = application.text("ui.history", "Recent history", locale) + "\n" + _history_text(history)
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(history_label)
	if show_dev_tools:
		var dev := HBoxContainer.new()
		dev.alignment = BoxContainer.ALIGNMENT_CENTER
		_add_action(dev, application.text("ui.dev_advance_hour", "Advance 1 hour", locale), _advance_hour)
		_add_action(dev, application.text("ui.dev_force_sick", "Force sickness", locale), _force_sickness)
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


func _toggle_locale() -> void:
	locale = "en" if locale == "de" else "de"
	_refresh()


func _choose_starter(egg_id: String) -> void:
	var result := application.choose_starter(egg_id)
	_refresh(application.text("ui.selected", "Selected", locale) if result.get("ok", false) else str(result.get("reason", "Selection failed")))


func _complete_hatch() -> void:
	var result := application.complete_hatch()
	_refresh(application.text("ui.hatched", "Hatched", locale) if result.get("ok", false) else str(result.get("reason", "Hatch failed")))


func _feed() -> void:
	var result := application.command({"type": "feed", "item_id": application.find_item_by_kind("meal")})
	_refresh(_command_status(result))


func _treat() -> void:
	var result := application.command({"type": "feed", "item_id": application.find_item_by_kind("treat")})
	_refresh(_command_status(result))


func _clean() -> void:
	var result := application.command({"type": "clean"})
	_refresh(_command_status(result))


func _train() -> void:
	var result := application.command({"type": "train", "activity_id": application.get_training_activity_id(), "input_bps": 5000})
	_refresh(_command_status(result))


func _medicine() -> void:
	var result := application.command({"type": "medicine", "item_id": application.find_item_by_kind("medicine")})
	_refresh(_command_status(result))


func _sleep_or_wake(sleeping: bool) -> void:
	var result := application.command({"type": "wake" if sleeping else "sleep"})
	_refresh(_command_status(result))


func _resolve_call(call_id: String) -> void:
	var result := application.command({"type": "resolve_call", "call_id": call_id})
	_refresh(_command_status(result))


func _save_nickname(input: LineEdit) -> void:
	var result := application.command({"type": "set_nickname", "nickname": input.text})
	_refresh(_command_status(result))


func _advance_hour() -> void:
	var result := application.advance_simulated(3600)
	_refresh(_command_status(result))


func _force_sickness() -> void:
	var result := application.command({"type": "force_sickness"})
	_refresh(_command_status(result))


func _command_status(result: Dictionary) -> String:
	return application.text("ui.saved", "Saved", locale) if result.get("ok", false) else str(result.get("reason", result.get("error_code", "Action failed")))


func _offline_status(model: Dictionary) -> String:
	var offline: Dictionary = model.get("offline", {})
	var accepted := int(offline.get("accepted_simulation_seconds", 0))
	if accepted <= 0:
		return application.text("ui.local_save_active", "Local save active", locale)
	return "%s: %s" % [application.text("ui.offline", "While you were away", locale), _format_duration(accepted)]


func _format_duration(seconds: int) -> String:
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	return "%dh %02dm" % [hours, minutes]


func _on_minimal_visual_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_mode(MODE_SMALL)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			_set_mode(MODE_MINIMAL)
		KEY_F2:
			_set_mode(MODE_SMALL)
		KEY_F3:
			_set_mode(MODE_EXPANDED)
		KEY_1, KEY_2, KEY_3:
			if show_dev_tools and not application.has_pet():
				var starters := application.get_starter_eggs()
				var index := int(event.keycode - KEY_1)
				if index >= 0 and index < starters.size():
					_choose_starter(str(starters[index].get("id", "")))
		KEY_F4:
			if show_dev_tools and application.is_hatched():
				_feed()
		KEY_F5:
			if show_dev_tools and application.is_hatched():
				_treat()
		KEY_F6:
			if show_dev_tools and application.is_hatched():
				_clean()
		KEY_F7:
			if show_dev_tools and application.is_hatched():
				_train()
		KEY_F8:
			if show_dev_tools and application.is_hatched():
				var current := application.get_view_model(MODE_SMALL, locale)
				_sleep_or_wake(bool(current.get("sleeping", false)))
		KEY_F9:
			if show_dev_tools and application.has_pet():
				_advance_hour()
		KEY_F10:
			if show_dev_tools and application.is_hatched():
				_force_sickness()
		KEY_F11:
			if show_dev_tools and application.is_hatched():
				_medicine()
		KEY_F12:
			if show_dev_tools and not application.is_hatched() and application.has_pet():
				_complete_hatch()


func _argument_value(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for argument in args:
		var value := str(argument)
		if value.begins_with(prefix):
			return value.substr(prefix.length())
	return fallback


func _run_review_actions(actions: PackedStringArray) -> void:
	for action in actions:
		await get_tree().process_frame
		match str(action):
			"choose:moss":
				_choose_starter("koalapet.base:moss_egg")
			"choose:ember":
				_choose_starter("koalapet.base:ember_egg")
			"choose:tide":
				_choose_starter("koalapet.base:tide_egg")
			"hatch":
				_complete_hatch()
			"feed":
				_feed()
			"treat":
				_treat()
			"clean":
				_clean()
			"train":
				_train()
			"sleep":
				_sleep_or_wake(false)
			"wake":
				_sleep_or_wake(true)
			"sick":
				_force_sickness()
			"medicine":
				_medicine()
			"hour":
				_advance_hour()
			"resolve":
				var calls: Array = application.get_view_model(MODE_SMALL, locale).get("open_calls", [])
				if not calls.is_empty():
					_resolve_call(str(calls[0].get("call_id", "")))
			"mode:minimal":
				_set_mode(MODE_MINIMAL)
			"mode:small":
				_set_mode(MODE_SMALL)
			"mode:expanded":
				_set_mode(MODE_EXPANDED)
			"locale:en":
				locale = "en"
				_refresh()
