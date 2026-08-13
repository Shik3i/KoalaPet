extends Control

const MODE_MINIMAL := "minimal"
const MODE_SMALL := "small"
const MODE_EXPANDED := "expanded"
const PLACEMENT_PATH := "user://presentation/placement.json"
const PREFERENCES_PATH := "user://preferences.json"

var application: PetApplication
var window_adapter: DesktopWindowAdapter
var mode_controller: WindowModeController
var mode := MODE_SMALL
var locale := "de"
var reduced_motion := false
var preferences: Dictionary = {}
var preferences_path := PREFERENCES_PATH
var resolved_ui_scale := 1.0
var show_dev_tools := false
var root_layer: Control
var notification_layer: Control
var minimal_sprite: AnimatedTextureRect
var minimal_direction := 1.0
var minimal_moving := true
var minimal_pause_remaining := 0.0
var minimal_target_x := 104.0
var minimal_hit_elapsed := 0.0
var small_page := "care"
var expanded_tab := "home"
var transient_animation := ""
var notification_revision := 0
var animation_revision := 0
var requested_save_path := ""
var diagnostics_path := ""
var placement_path := PLACEMENT_PATH
var dev_window: Window
var animation_controller := PresentationAnimationController.new()
var active_habitat: HabitatView


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	requested_save_path = _argument_value(args, "--save-path=", "user://saves/koalapet.json")
	diagnostics_path = _argument_value(args, "--diagnostics-path=", "")
	placement_path = _argument_value(args, "--placement-path=", PLACEMENT_PATH)
	preferences_path = _argument_value(args, "--preferences-path=", PREFERENCES_PATH)
	preferences = PresentationPreferences.load_file(preferences_path).get("data", PresentationPreferences.defaults())
	var interface_preferences: Dictionary = preferences.get("interface", {})
	var pet_preferences: Dictionary = preferences.get("pet_presentation", {})
	var desktop_preferences: Dictionary = preferences.get("desktop", {})
	application = PetApplication.new({"save_path": requested_save_path})
	show_dev_tools = "--dev-tools" in args
	locale = _argument_value(args, "--locale=", str(interface_preferences.get("language", "de")))
	if locale not in ["de", "en"]:
		locale = "de"
	reduced_motion = "--reduced-motion" in args or bool(pet_preferences.get("reduced_motion", false))
	var requested_mode := _argument_value(args, "--mode=", str(desktop_preferences.get("default_launch_mode", MODE_SMALL)))
	mode = requested_mode if requested_mode in [MODE_MINIMAL, MODE_SMALL, MODE_EXPANDED] else MODE_SMALL
	var result := application.initialize()
	if result.get("ok", false) and not application.has_pet() and not _has_argument(args, "--mode="):
		mode = MODE_EXPANDED
	_setup_window_adapter()
	_build_root()
	if not result.get("ok", false):
		_build_error(str(result.get("reason", result.get("stage", "unknown"))))
		return
	_apply_window_mode()
	_refresh()
	var review_actions := _argument_value(args, "--review-actions=", "")
	if not review_actions.is_empty():
		var diagnostics_delay := maxi(0, int(_argument_value(args, "--diagnostics-delay-ms=", "0")))
		call_deferred("_run_review_actions", review_actions.split(",", false), diagnostics_delay)
	else:
		call_deferred("_write_diagnostics")
	if "--animation-polish-demo" in args:
		call_deferred("_run_animation_polish_demo")


func _process(delta: float) -> void:
	if mode != MODE_MINIMAL or minimal_sprite == null or not is_instance_valid(minimal_sprite):
		return
	minimal_hit_elapsed += delta
	if minimal_hit_elapsed >= 1.0 / 30.0:
		minimal_hit_elapsed = 0.0
		_update_minimal_hit_region()
	var pet_preferences: Dictionary = preferences.get("pet_presentation", {})
	var desktop_preferences: Dictionary = preferences.get("desktop", {})
	if reduced_motion or not bool(pet_preferences.get("ambient_roaming", true)) or str(desktop_preferences.get("minimal_lane", "bottom")) == "stationary":
		return
	if minimal_pause_remaining > 0.0:
		minimal_pause_remaining -= delta
		if minimal_pause_remaining <= 0.0:
			minimal_moving = true
			var bounds := _minimal_walk_bounds()
			minimal_target_x = bounds.x if minimal_sprite.position.x > (bounds.x + bounds.y) * 0.5 else bounds.y
			minimal_direction = -1.0 if minimal_target_x < minimal_sprite.position.x else 1.0
			minimal_sprite.configure(application.get_animation_descriptor("walk"), reduced_motion, _animation_speed() * _walking_speed())
			minimal_sprite.set_facing(minimal_direction)
		return
	if not minimal_moving:
		return
	minimal_sprite.position.x = move_toward(minimal_sprite.position.x, minimal_target_x, delta * 28.0 * _walking_speed())
	if is_equal_approx(minimal_sprite.position.x, minimal_target_x):
		minimal_moving = false
		minimal_pause_remaining = 2.5 if minimal_target_x < 56.0 else 4.0
		minimal_sprite.configure(application.get_animation_descriptor("idle"), reduced_motion, _animation_speed())
		minimal_sprite.set_facing(minimal_direction)


func _exit_tree() -> void:
	_save_window_placement()


func _setup_window_adapter() -> void:
	window_adapter = DesktopWindowAdapterFactory.create_for_current_host(get_window())
	mode_controller = WindowModeController.new(window_adapter)
	var loaded := OverlayPlacementStore.load_envelope(placement_path)
	var envelope: Dictionary = loaded.get("data", {})
	mode_controller.restore_placements(envelope.get("placements", {}))


func _build_root() -> void:
	_build_root_theme()
	get_viewport().transparent_bg = true
	root_layer = Control.new()
	root_layer.name = "PlayerPresentation"
	root_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_layer)
	notification_layer = Control.new()
	notification_layer.name = "TransientNotifications"
	notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(notification_layer)


func _build_error(reason: String) -> void:
	_clear(root_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_layer.add_child(center)
	var panel := PixelUi.modal("Foundation error", reason)
	panel.custom_minimum_size = Vector2(420, 140)
	center.add_child(panel)


func _refresh(status_override := "") -> void:
	_clear(root_layer)
	minimal_sprite = null
	active_habitat = null
	var model := application.get_view_model(mode, locale)
	match str(model.get("screen", "starter")):
		"starter":
			_build_starter()
		"egg":
			if mode == MODE_MINIMAL:
				_build_minimal(model, true)
			else:
				_build_egg(model)
		_:
			match mode:
				MODE_MINIMAL:
					_build_minimal(model, false)
				MODE_EXPANDED:
					_build_expanded(model)
				_:
					_build_small(model)
	if not status_override.is_empty():
		_show_notification(status_override)
	call_deferred("_update_minimal_hit_region")


func _build_starter() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#0d1820f2")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_layer.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_margins(margin, 28)
	root_layer.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var heading := PixelUi.title(application.text("ui.choose_egg", "Wähle ein Ei", locale), 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var hint := Label.new()
	hint.text = application.text("ui.choose_egg_hint", "Jedes Ei wird zu einem anderen ersten Gefährten.", locale)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	column.add_child(cards)
	for egg in application.get_starter_eggs():
		cards.add_child(_starter_card(egg))
	var footer := Label.new()
	footer.text = application.text("ui.local_save_active", "Lokaler Speicher aktiv", locale)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", PixelTheme.SILVER)
	column.add_child(footer)


func _starter_card(egg: Dictionary) -> PanelContainer:
	var egg_id := str(egg.get("id", ""))
	var card := PixelUi.starter_egg_card()
	card.custom_minimum_size = Vector2(250, 290)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	var preview := TextureRect.new()
	preview.texture = load(application.get_preview_asset_path(egg_id)) as Texture2D
	preview.custom_minimum_size = Vector2(160, 160)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(preview)
	var name_label := PixelUi.title(application.get_display_name(egg_id, locale), 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var affinity := Label.new()
	affinity.text = _starter_affinity(egg_id)
	affinity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	affinity.add_theme_color_override("font_color", PixelTheme.SILVER)
	column.add_child(affinity)
	var choose := PixelUi.button(application.text("ui.select", "Wählen", locale), "egg", application.text("ui.select", "Wählen", locale))
	choose.pressed.connect(_show_starter_confirmation.bind(egg_id))
	column.add_child(choose)
	return card


func _show_starter_confirmation(egg_id: String) -> void:
	var shade := ColorRect.new()
	shade.name = "StarterConfirmation"
	shade.color = Color("#081015cc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var modal := PixelUi.modal(application.text("ui.confirm_companion", "Gefährten bestätigen", locale), application.get_display_name(egg_id, locale))
	modal.custom_minimum_size = Vector2(360, 190)
	center.add_child(modal)
	var column := modal.get_child(0) as VBoxContainer
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	var cancel := PixelUi.button(application.text("ui.cancel", "Abbrechen", locale))
	cancel.pressed.connect(shade.queue_free)
	row.add_child(cancel)
	var confirm := PixelUi.button(application.text("ui.confirm", "Bestätigen", locale), "egg")
	confirm.pressed.connect(_choose_starter.bind(egg_id))
	row.add_child(confirm)


func _open_settings() -> void:
	var shade := ColorRect.new()
	shade.name = "PresentationSettings"
	shade.color = Color("#081015dd")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PixelUi.panel()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := PixelUi.title(application.text("ui.settings", "Einstellungen", locale), 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := PixelUi.icon_button("close", application.text("ui.close", "Schließen", locale))
	close.pressed.connect(shade.queue_free)
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, clampf(root_layer.size.y - 140.0, 180.0, 520.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var grid := GridContainer.new()
	# One logical column keeps every localized label immediately above its control.
	# It also avoids cross-pairing when larger text forces a narrow modal reflow.
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_add_setting_options(grid, application.text("ui.ui_scale", "UI-Skalierung", locale), ["Auto", "100%", "125%", "150%", "175%", "200%"], ["auto", 1.0, 1.25, 1.5, 1.75, 2.0], preferences["interface"]["ui_scale"], _set_preference.bind("interface", "ui_scale"))
	_add_setting_options(grid, application.text("ui.text_scale", "Textskalierung", locale), ["100%", "125%", "150%", "175%"], [1.0, 1.25, 1.5, 1.75], preferences["interface"]["text_scale"], _set_preference.bind("interface", "text_scale"))
	_add_setting_options(grid, application.text("ui.layout_density", "Layoutdichte", locale), [application.text("ui.compact", "Kompakt", locale), application.text("ui.comfortable", "Komfortabel", locale)], ["compact", "comfortable"], preferences["interface"]["layout_density"], _set_preference.bind("interface", "layout_density"))
	_add_setting_options(grid, application.text("ui.language", "Sprache", locale), ["Deutsch", "English"], ["de", "en"], preferences["interface"]["language"], _set_preference.bind("interface", "language"))
	_add_setting_options(grid, application.text("ui.pet_scale", "Pet-Skalierung", locale), ["75%", "100%", "125%", "150%", "200%"], [0.75, 1.0, 1.25, 1.5, 2.0], preferences["pet_presentation"]["standard_pet_scale"], _set_preference.bind("pet_presentation", "standard_pet_scale"))
	_add_setting_options(grid, application.text("ui.minimal_pet_scale", "Minimal-Pet", locale), ["75%", "100%", "125%", "150%", "200%"], [0.75, 1.0, 1.25, 1.5, 2.0], preferences["pet_presentation"]["minimal_pet_scale"], _set_preference.bind("pet_presentation", "minimal_pet_scale"))
	_add_setting_options(grid, application.text("ui.animation_speed", "Animationsgeschwindigkeit", locale), ["75%", "100%", "125%"], [0.75, 1.0, 1.25], preferences["pet_presentation"]["animation_speed"], _set_preference.bind("pet_presentation", "animation_speed"))
	_add_setting_options(grid, application.text("ui.walking_speed", "Laufgeschwindigkeit", locale), ["75%", "100%", "125%", "150%"], [0.75, 1.0, 1.25, 1.5], preferences["pet_presentation"]["walking_speed"], _set_preference.bind("pet_presentation", "walking_speed"))
	_add_setting_options(grid, application.text("ui.effects_intensity", "Effektstärke", locale), [application.text("ui.reduced", "Reduziert", locale), application.text("ui.normal", "Normal", locale)], ["reduced", "normal"], preferences["pet_presentation"]["effects_intensity"], _set_preference.bind("pet_presentation", "effects_intensity"))
	_add_setting_options(grid, application.text("ui.default_mode", "Startmodus", locale), ["Minimal", "Small", "Expanded"], ["minimal", "small", "expanded"], preferences["desktop"]["default_launch_mode"], _set_preference.bind("desktop", "default_launch_mode"))
	_add_setting_options(grid, application.text("ui.desktop_lane", "Desktop-Spur", locale), [application.text("ui.bottom", "Unterer Rand", locale), application.text("ui.stationary", "Stationär", locale)], ["bottom", "stationary"], preferences["desktop"]["minimal_lane"], _set_preference.bind("desktop", "minimal_lane"))
	_add_setting_toggle(grid, application.text("ui.ambient_roaming", "Umherlaufen", locale), bool(preferences["pet_presentation"]["ambient_roaming"]), _set_preference.bind("pet_presentation", "ambient_roaming"))
	_add_setting_toggle(grid, application.text("ui.reduced_motion", "Weniger Bewegung", locale), reduced_motion, _set_preference.bind("pet_presentation", "reduced_motion"))
	_add_setting_toggle(grid, application.text("ui.high_contrast", "Hoher Kontrast", locale), bool(preferences["interface"]["high_contrast"]), _set_preference.bind("interface", "high_contrast"))
	_add_setting_toggle(grid, application.text("ui.tooltips", "Tooltips", locale), bool(preferences["interface"]["tooltips_enabled"]), _set_preference.bind("interface", "tooltips_enabled"))
	_add_setting_toggle(grid, application.text("ui.always_on_top", "Immer im Vordergrund", locale), bool(preferences["desktop"]["always_on_top"]), _set_preference.bind("desktop", "always_on_top"))
	_add_setting_toggle(grid, application.text("ui.click_through", "Klicks außerhalb durchlassen", locale), bool(preferences["desktop"]["minimal_click_through"]), _set_preference.bind("desktop", "minimal_click_through"))
	_add_setting_toggle(grid, application.text("ui.remember_positions", "Fensterpositionen merken", locale), bool(preferences["desktop"]["remember_window_positions"]), _set_preference.bind("desktop", "remember_window_positions"))
	var reset := PixelUi.button(application.text("ui.reset_windows", "Fenster sichtbar zurücksetzen", locale), "settings")
	reset.pressed.connect(_reset_windows)
	column.add_child(reset)


func _add_setting_options(parent: GridContainer, label_text: String, labels: Array, values: Array, current: Variant, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var options := OptionButton.new()
	options.focus_mode = Control.FOCUS_ALL
	options.custom_minimum_size = Vector2(220, 44)
	for index in labels.size():
		options.add_item(str(labels[index]))
		options.set_item_metadata(index, values[index])
		var comparable_number := typeof(values[index]) in [TYPE_FLOAT, TYPE_INT] and typeof(current) in [TYPE_FLOAT, TYPE_INT]
		if (typeof(values[index]) == typeof(current) and values[index] == current) or (comparable_number and is_equal_approx(float(values[index]), float(current))):
			options.select(index)
	options.item_selected.connect(func(index: int) -> void: callback.call(options.get_item_metadata(index)))
	row.add_child(options)


func _add_setting_toggle(parent: GridContainer, label_text: String, current: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var toggle := PixelUi.toggle(application.text("ui.on", "An", locale) if current else application.text("ui.off", "Aus", locale), current)
	toggle.toggled.connect(func(enabled: bool) -> void: callback.call(enabled))
	row.add_child(toggle)


func _set_preference(value: Variant, section: String, key: String) -> void:
	preferences[section][key] = value
	preferences = PresentationPreferences.sanitize(preferences)
	reduced_motion = bool(preferences["pet_presentation"]["reduced_motion"])
	locale = str(preferences["interface"]["language"])
	_save_preferences()
	_save_window_placement()
	_build_root_theme()
	_apply_window_mode()
	_refresh(application.text("ui.settings_applied", "Einstellungen angewendet", locale))


func _reset_windows() -> void:
	if window_adapter.is_host_supported():
		window_adapter.reset_to_safe_default(_mode_value(mode))
	_refresh(application.text("ui.windows_reset", "Fensterpositionen zurückgesetzt", locale))


func _save_preferences() -> void:
	PresentationPreferences.save_file(preferences, preferences_path)


func _build_root_theme() -> void:
	var interface_preferences: Dictionary = preferences.get("interface", {})
	resolved_ui_scale = PresentationPreferences.resolved_ui_scale(interface_preferences.get("ui_scale", "auto"), _detected_display_scale())
	theme = PixelTheme.create(1.0, float(interface_preferences.get("text_scale", 1.0)), bool(interface_preferences.get("high_contrast", false)))
	PixelUi.configure_preferences(bool(interface_preferences.get("tooltips_enabled", true)), float(interface_preferences.get("text_scale", 1.0)), str(interface_preferences.get("layout_density", "comfortable")))


func _detected_display_scale() -> float:
	if window_adapter != null:
		for monitor in window_adapter.enumerate_monitors():
			if monitor.index == get_window().current_screen:
				return maxf(1.0, monitor.scale)
	return 1.0


func _minimal_pet_scale() -> float:
	return float(preferences.get("pet_presentation", {}).get("minimal_pet_scale", 1.0))


func _animation_speed() -> float:
	return float(preferences.get("pet_presentation", {}).get("animation_speed", 1.0))


func _walking_speed() -> float:
	return float(preferences.get("pet_presentation", {}).get("walking_speed", 1.0))


func _build_egg(model: Dictionary) -> void:
	var shell := _window_shell(application.get_display_name(str(model.get("egg_id", "")), locale), "egg")
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	shell.add_child(column)
	var egg_sprite := AnimatedTextureRect.new()
	egg_sprite.custom_minimum_size = Vector2(140, 140)
	column.add_child(egg_sprite)
	egg_sprite.configure(application.get_animation_descriptor("idle", "", true), reduced_motion)
	column.add_child(_hatch_progress(model))
	var ready := int(model.get("current_simulation_unix", 0)) >= int(model.get("hatch_due_unix", 1))
	var hatch := PixelUi.button(application.text("ui.hatch_ready", "Bereit zum Schlüpfen", locale) if ready else application.text("ui.hatching", "Dein Ei wird warm", locale), "egg")
	hatch.disabled = not ready
	hatch.tooltip_text = application.text("ui.hatching", "Dein Ei wird warm", locale) if not ready else application.text("ui.hatch_ready", "Bereit zum Schlüpfen", locale)
	hatch.pressed.connect(_complete_hatch)
	column.add_child(hatch)


func _hatch_progress(model: Dictionary) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(320, 40)
	var label := Label.new()
	label.text = "%s · %d%%" % [application.text("ui.hatch_progress", "Schlüpffortschritt", locale), int(model.get("hatch_progress_bps", 0)) / 100]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)
	var progress := ProgressBar.new()
	progress.max_value = 10000
	progress.value = int(model.get("hatch_progress_bps", 0))
	progress.show_percentage = false
	root.add_child(progress)
	return root


func _build_minimal(model: Dictionary, egg := false) -> void:
	root_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimal_sprite = AnimatedTextureRect.new()
	minimal_sprite.name = "MinimalPet"
	var scale_value := _minimal_pet_scale()
	var target_size := WindowPresentationMode.scaled_size(WindowPresentationMode.Value.MINIMAL, 1.0, float(preferences.get("interface", {}).get("text_scale", 1.0)), scale_value)
	var sprite_extent := Vector2(128, 128) * scale_value
	minimal_sprite.position = Vector2((float(target_size.x) - sprite_extent.x) * 0.5, maxf(4.0, float(target_size.y) - sprite_extent.y - 8.0))
	minimal_sprite.size = sprite_extent
	var walk_bounds := _minimal_walk_bounds(sprite_extent, target_size)
	minimal_target_x = walk_bounds.y
	minimal_sprite.position.x = clampf(minimal_sprite.position.x, walk_bounds.x, walk_bounds.y)
	root_layer.add_child(minimal_sprite)
	var animation_name := "world" if egg else ("idle" if reduced_motion else "walk" if minimal_moving else _animation_for(model))
	var descriptor := application.get_animation_descriptor(animation_name, "", egg)
	minimal_sprite.configure(descriptor, reduced_motion, _animation_speed() * (_walking_speed() if animation_name == "walk" else 1.0))
	minimal_sprite.set_facing(minimal_direction)
	minimal_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	minimal_sprite.gui_input.connect(_on_minimal_input)
	var call_icon := _call_icon(model)
	if not call_icon.is_empty():
		var bubble := PixelUi.call_bubble(call_icon)
		bubble.name = "TransientCallBubble"
		bubble.position = Vector2(minimal_sprite.position.x + 82.0 * scale_value, maxf(2.0, minimal_sprite.position.y - 8.0))
		root_layer.add_child(bubble)


func _build_small(model: Dictionary) -> void:
	var shell := _window_shell(str(model.get("name", "KoalaPet")), "pet")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	shell.add_child(column)
	column.add_child(_small_status_strip(model))
	var habitat_center := CenterContainer.new()
	column.add_child(habitat_center)
	var habitat := _habitat(model)
	habitat_center.add_child(habitat)
	column.add_child(_small_actions(model))


func _window_shell(title_text: String, icon_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_margins(margin, 4)
	root_layer.add_child(margin)
	var frame := PixelUi.panel(true)
	margin.add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	frame.add_child(root)
	root.add_child(_title_bar(title_text, icon_name))
	return root


func _title_bar(title_text: String, icon_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PlayerTitleBar"
	row.custom_minimum_size = Vector2(0, 28)
	row.gui_input.connect(_on_title_bar_input)
	var icon_rect := TextureRect.new()
	icon_rect.texture = PixelUi.icon(icon_name)
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon_rect)
	var title_label := PixelUi.title(title_text, 14)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title_label)
	if mode == MODE_SMALL and application.is_hatched():
		var care_tab := PixelUi.icon_button("health", application.text("ui.care", "Pflege", locale))
		care_tab.button_pressed = small_page == "care"
		care_tab.pressed.connect(_set_small_page.bind("care"))
		row.add_child(care_tab)
		var adventure_tab := PixelUi.icon_button("battle", application.text("ui.adventure", "Abenteuer", locale))
		adventure_tab.button_pressed = small_page == "adventure"
		adventure_tab.pressed.connect(_set_small_page.bind("adventure"))
		row.add_child(adventure_tab)
		var more_tab := PixelUi.icon_button("settings", application.text("ui.more", "Mehr", locale))
		more_tab.button_pressed = small_page == "more"
		more_tab.pressed.connect(_set_small_page.bind("more"))
		row.add_child(more_tab)
	var settings_button := PixelUi.icon_button("settings", application.text("ui.settings", "Einstellungen", locale))
	settings_button.pressed.connect(_open_settings)
	row.add_child(settings_button)
	if show_dev_tools:
		var dev := PixelUi.icon_button("settings", application.text("ui.dev", "Entwicklungswerkzeuge", locale))
		dev.pressed.connect(_open_dev_window)
		row.add_child(dev)
	var switch_mode := PixelUi.icon_button("expand", application.text("ui.expanded", "Erweitert", locale) if mode == MODE_SMALL else application.text("ui.small", "Klein", locale))
	switch_mode.pressed.connect(_set_mode.bind(MODE_EXPANDED if mode == MODE_SMALL else MODE_SMALL))
	row.add_child(switch_mode)
	var minimize := PixelUi.icon_button("minimize", application.text("ui.minimize", "Minimieren", locale))
	minimize.pressed.connect(_minimize)
	row.add_child(minimize)
	var close := PixelUi.icon_button("close", application.text("ui.close", "Schließen", locale))
	close.pressed.connect(get_tree().quit)
	row.add_child(close)
	return row


func _small_status_strip(model: Dictionary) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.name = "CompactStatusStrip"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	var care: Dictionary = model.get("care", {})
	for entry in [
		["satiety_bps", "feed"], ["mood_bps", "mood"], ["energy_bps", "energy"],
		["hygiene_bps", "clean"], ["health_bps", "health"], ["discipline_bps", "discipline"],
	]:
		var item := HBoxContainer.new()
		var image := TextureRect.new()
		image.texture = PixelUi.icon(str(entry[1]))
		image.custom_minimum_size = Vector2(24, 24)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item.add_child(image)
		var meter := PixelUi.segmented_status(int(care.get(str(entry[0]), 0)), 3)
		meter.tooltip_text = "%d%%" % int(care.get(str(entry[0]), 0) / 100)
		item.add_child(meter)
		strip.add_child(item)
	return strip


func _small_actions(model: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "QuickActions"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match small_page:
		"adventure":
			_add_small_action(row, application.text("ui.next_round", "Runde", locale) if not model.get("active_battle", {}).is_empty() else application.text("ui.battle", "Kampf", locale), "battle", _battle_action, not bool(model.get("battle_unlocked", false)))
			_add_small_action(row, application.text("ui.next_node", "Etappe", locale) if not model.get("active_dungeon_run", {}).is_empty() else application.text("ui.dungeon", "Dungeon", locale), "dungeon", _dungeon_action, not bool(model.get("dungeon_unlocked", false)))
			_add_small_action(row, application.text("ui.expanded", "Erweitert", locale), "expand", _set_mode.bind(MODE_EXPANDED))
		"more":
			_add_small_action(row, application.text("ui.treat", "Leckerli", locale), "treat", _treat)
			_add_small_action(row, application.text("ui.train", "Training", locale), "train", _train)
			_add_small_action(row, application.text("ui.minimal", "Minimal", locale), "minimize", _set_mode.bind(MODE_MINIMAL))
		_:
			_add_small_action(row, application.text("ui.feed", "Füttern", locale), "feed", _feed)
			_add_small_action(row, application.text("ui.clean", "Reinigen", locale), "clean", _clean)
			_add_small_action(row, application.text("ui.wake", "Aufwecken", locale) if model.get("sleeping", false) else application.text("ui.sleep", "Schlafen", locale), "sleep", _sleep_or_wake.bind(bool(model.get("sleeping", false))))
	return row


func _add_small_action(parent: Container, text_value: String, icon_name: String, action: Callable, disabled := false, icon_only := false) -> void:
	var value := PixelUi.button("" if icon_only else text_value, icon_name, text_value)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.disabled = disabled
	value.pressed.connect(action)
	parent.add_child(value)


func _build_expanded(model: Dictionary) -> void:
	var shell := _window_shell(str(model.get("name", "KoalaPet")), "pet")
	var body := HBoxContainer.new()
	body.name = "ExpandedBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	shell.add_child(body)
	body.add_child(_expanded_status(model))
	body.add_child(_expanded_center(model))
	body.add_child(_expanded_actions(model))


func _expanded_status(model: Dictionary) -> PanelContainer:
	var panel := PixelUi.panel(true)
	panel.name = "ExpandedStatus"
	panel.custom_minimum_size = Vector2(252, 0)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(PixelUi.title(application.text("ui.stats", "Pflegeprotokoll", locale), 20))
	var care: Dictionary = model.get("care", {})
	for entry in [
		["satiety_bps", "ui.satiety", "Sättigung", "feed"],
		["mood_bps", "ui.mood", "Stimmung", "mood"],
		["energy_bps", "ui.energy", "Energie", "energy"],
		["hygiene_bps", "ui.hygiene", "Hygiene", "clean"],
		["health_bps", "ui.health", "Gesundheit", "health"],
		["discipline_bps", "ui.discipline", "Disziplin", "discipline"],
	]:
		column.add_child(PixelUi.status_meter(str(entry[0]), application.text(str(entry[1]), str(entry[2]), locale), str(entry[3]), int(care.get(str(entry[0]), 0))))
	var facts := Label.new()
	facts.text = "%s %d · XP %d/%d\n%s %.2f kg · %s %d" % [application.text("ui.level", "Stufe", locale), int(model.get("level", 1)), int(model.get("experience", 0)), int(model.get("experience_next", 0)), application.text("ui.weight", "Gewicht", locale), float(care.get("weight_grams", 0)) / 1000.0, application.text("ui.waste", "Abfall", locale), int(care.get("waste_count", 0))]
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(facts)
	return panel


func _expanded_center(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "ExpandedCenter"
	column.custom_minimum_size = Vector2(576, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var habitat_center := CenterContainer.new()
	habitat_center.add_child(_habitat(model))
	column.add_child(habitat_center)
	var tabs := HBoxContainer.new()
	for entry in [["home", "ui.home", "Übersicht"], ["battle", "ui.battle", "Kampf"], ["dungeon", "ui.dungeon", "Dungeon"], ["inventory", "ui.inventory", "Inventar"], ["codex", "ui.codex", "Kodex"], ["evolution", "ui.evolution", "Entwicklung"]]:
		var tab := PixelUi.tab(application.text(str(entry[1]), str(entry[2]), locale), expanded_tab == str(entry[0]))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_set_expanded_tab.bind(str(entry[0])))
		tabs.add_child(tab)
	column.add_child(tabs)
	var detail := PixelUi.panel(true)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	match expanded_tab:
		"battle":
			detail.add_child(_battle_panel(model))
		"dungeon":
			detail.add_child(_dungeon_panel(model))
		"inventory":
			detail.add_child(_inventory_panel(model))
		"codex":
			detail.add_child(_codex_panel(model))
		"evolution":
			detail.add_child(_evolution_panel(model))
		_:
			detail.add_child(_home_panel(model))
	return column


func _expanded_actions(model: Dictionary) -> PanelContainer:
	var panel := PixelUi.panel(true)
	panel.name = "ExpandedActions"
	panel.custom_minimum_size = Vector2(252, 0)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(PixelUi.title(application.text("ui.actions", "Aktionen", locale), 20))
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for entry in [
		["ui.feed", "Füttern", "feed", _feed], ["ui.treat", "Leckerli", "treat", _treat],
		["ui.clean", "Reinigen", "clean", _clean], ["ui.train", "Trainieren", "train", _train],
		["ui.sleep", "Schlafen", "sleep", _sleep_or_wake.bind(bool(model.get("sleeping", false)))],
		["ui.medicine", "Medizin", "medicine", _medicine],
	]:
		var action := PixelUi.button(application.text(str(entry[0]), str(entry[1]), locale), str(entry[2]))
		action.pressed.connect(entry[3])
		grid.add_child(action)
	if not model.get("injury", {}).is_empty():
		var injury := PixelUi.button(application.text("ui.treat_injury", "Bandagieren", locale), "medicine")
		injury.pressed.connect(_treat_injury)
		column.add_child(injury)
	var calls: Array = model.get("open_calls", [])
	if not calls.is_empty():
		var resolve := PixelUi.button(application.text("ui.resolve", "Erledigen", locale), "call")
		resolve.pressed.connect(_resolve_first_call)
		column.add_child(resolve)
	column.add_child(HSeparator.new())
	column.add_child(PixelUi.title(application.text("ui.history", "Letzte Ereignisse", locale), 14))
	var history: Array = model.get("history", [])
	var start := maxi(0, history.size() - 7)
	for index in range(start, history.size()):
		var entry: Dictionary = history[index]
		column.add_child(PixelUi.event_log_entry(_event_label(str(entry.get("type", "")))))
	if history.is_empty():
		column.add_child(PixelUi.event_log_entry(application.text("ui.history.empty", "Noch keine Ereignisse", locale)))
	return panel


func _home_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_child(PixelUi.title(_state_line(model), 14))
	var summary := Label.new()
	var aggregate: Dictionary = model.get("aggregate", {})
	summary.text = "%s %d · %s %d · %s %d · %s %d" % [application.text("ui.feed", "Füttern", locale), int(aggregate.get("feed_count", 0)), application.text("ui.treat", "Leckerli", locale), int(aggregate.get("treat_count", 0)), application.text("ui.train", "Trainieren", locale), int(aggregate.get("training_count", 0)), application.text("ui.care_mistakes", "Pflegefehler", locale), int(aggregate.get("care_mistakes", 0))]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	var route := Label.new()
	var names: Array[String] = []
	for form_id in model.get("discovered_forms", []):
		names.append(application.get_display_name(str(form_id), locale))
	route.text = application.text("ui.discovered_route", "Entdeckte Route", locale) + ": " + ", ".join(names)
	route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(route)
	return column


func _battle_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	var battle: Dictionary = model.get("active_battle", {})
	if battle.is_empty():
		column.add_child(PixelUi.title(application.text("ui.battle", "Kampf", locale), 15))
		var encounter_id := _default_encounter_id()
		var encounter := application.get_encounter_presentation(encounter_id, locale)
		var row := HBoxContainer.new()
		column.add_child(row)
		var portrait := AnimatedTextureRect.new()
		portrait.custom_minimum_size = Vector2(96, 96)
		row.add_child(portrait)
		portrait.configure(encounter.get("animation", {}), reduced_motion)
		var copy := Label.new()
		copy.text = "%s · %s %d\n%s" % [str(encounter.get("name", "")), application.text("ui.level", "Stufe", locale), int(encounter.get("level", 1)), str(encounter.get("description", ""))]
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var start := PixelUi.button(application.text("ui.start_battle", "Kampf beginnen", locale), "battle")
		start.disabled = not bool(model.get("battle_unlocked", false))
		start.pressed.connect(_start_battle)
		column.add_child(start)
		return column
	var encounter := application.get_encounter_presentation(str(battle.get("encounter_id", "")), locale)
	column.add_child(PixelUi.title("%s · %s %d" % [str(encounter.get("name", "")), application.text("ui.level", "Stufe", locale), int(encounter.get("level", 1))], 15))
	var hp := Label.new()
	hp.text = "%s HP %d/%d  ·  %s HP %d/%d  ·  R%d" % [model.get("name", "Pet"), int(battle.get("pet_transient_hp", 0)), int(battle.get("pet_transient_max_hp", 0)), encounter.get("name", "Opponent"), int(battle.get("opponent_transient_hp", 0)), int(battle.get("opponent_transient_max_hp", 0)), int(battle.get("current_round", 0)) + 1]
	column.add_child(hp)
	var stances := HBoxContainer.new()
	column.add_child(stances)
	for stance in ["aggressive", "balanced", "defensive"]:
		var stance_button := PixelUi.battle_stance_control(application.text("ui." + stance, stance.capitalize(), locale), "attack" if stance == "aggressive" else "shield" if stance == "defensive" else "health")
		stance_button.button_pressed = str(battle.get("selected_stance", "balanced")) == stance
		stance_button.pressed.connect(_set_battle_stance.bind(stance))
		stances.add_child(stance_button)
	var round_button := PixelUi.button(application.text("ui.next_round", "Runde ausführen", locale), "attack")
	round_button.pressed.connect(_battle_round)
	column.add_child(round_button)
	return column


func _dungeon_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	var dungeons := application.get_dungeons()
	if dungeons.is_empty():
		column.add_child(Label.new())
		return column
	var dungeon_id := str(dungeons[0].get("id", ""))
	var run: Dictionary = model.get("active_dungeon_run", {})
	if not run.is_empty():
		dungeon_id = str(run.get("dungeon_id", dungeon_id))
	var dungeon := application.get_dungeon_presentation(dungeon_id, locale)
	column.add_child(PixelUi.title(str(dungeon.get("name", application.text("ui.dungeon", "Dungeon", locale))), 15))
	var route := HBoxContainer.new()
	column.add_child(route)
	var current := int(run.get("current_node", -1))
	var completed: Array = run.get("completed_nodes", [])
	for index in range(dungeon.get("nodes", []).size()):
		var node: Dictionary = dungeon.nodes[index]
		var node_button := PixelUi.dungeon_node(str(node.get("kind", "encounter")), index in completed)
		node_button.button_pressed = index == current
		node_button.tooltip_text = "%d · %s" % [index + 1, str(node.get("kind", ""))]
		route.add_child(node_button)
	if run.is_empty():
		var start := PixelUi.button(application.text("ui.start_dungeon", "Dungeon beginnen", locale), "dungeon")
		start.disabled = not bool(model.get("dungeon_unlocked", false))
		start.pressed.connect(_start_dungeon)
		column.add_child(start)
		return column
	if not model.get("active_battle", {}).is_empty():
		var battle_notice := Label.new()
		battle_notice.text = application.text("ui.dungeon_battle_active", "Diese Etappe wird im Kampf entschieden.", locale)
		column.add_child(battle_notice)
		var round_button := PixelUi.button(application.text("ui.next_round", "Runde ausführen", locale), "attack")
		round_button.pressed.connect(_battle_round)
		column.add_child(round_button)
		return column
	var nodes: Array = dungeon.get("nodes", [])
	if current >= 0 and current < nodes.size() and str(nodes[current].get("kind", "")) == "event":
		for choice in nodes[current].get("choices", []):
			var choice_button := PixelUi.button(str(choice.get("name", choice.get("id", ""))), "mood")
			choice_button.pressed.connect(_dungeon_choice.bind(str(choice.get("id", ""))))
			column.add_child(choice_button)
	else:
		var next := PixelUi.button(application.text("ui.next_node", "Nächste Etappe", locale), "map")
		next.pressed.connect(_dungeon_next)
		column.add_child(next)
	return column


func _inventory_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_child(PixelUi.title(application.text("ui.inventory", "Inventar", locale), 15))
	var grid := GridContainer.new()
	grid.columns = 6
	column.add_child(grid)
	var inventory: Dictionary = model.get("inventory", {})
	for item_id in inventory:
		var slot := PixelUi.inventory_slot()
		var label := Label.new()
		label.text = "%s\nx%d" % [application.get_display_name(str(item_id), locale), int(inventory[item_id])]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(label)
		grid.add_child(slot)
	if inventory.is_empty():
		column.add_child(Label.new())
	return column


func _codex_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_child(PixelUi.title(application.text("ui.codex", "Kodex", locale), 15))
	var grid := GridContainer.new()
	grid.columns = 6
	column.add_child(grid)
	var codex: Dictionary = model.get("codex", {})
	var ids: Array = []
	ids.append_array(codex.get("forms", []))
	ids.append_array(codex.get("encounters", []))
	for content_id in ids:
		var slot := PixelUi.codex_slot()
		var label := Label.new()
		label.text = application.get_display_name(str(content_id), locale)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(label)
		grid.add_child(slot)
	return column


func _evolution_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_child(PixelUi.title(application.text("ui.evolution", "Entwicklung", locale), 15))
	var row := HBoxContainer.new()
	column.add_child(row)
	var current := TextureRect.new()
	current.texture = load(application.get_preview_asset_path(str(model.get("form_id", "")))) as Texture2D
	current.custom_minimum_size = Vector2(80, 80)
	current.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	current.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	current.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(current)
	var evaluation: Dictionary = model.get("evolution", {})
	for candidate in evaluation.get("candidates", []):
		var target := PixelUi.evolution_silhouette()
		target.texture = load(application.get_preview_asset_path(str(candidate.get("to_form_id", "")))) as Texture2D
		target.tooltip_text = application.get_display_name(str(candidate.get("to_form_id", "")), locale)
		row.add_child(target)
	var hint := Label.new()
	hint.text = application.text("ui.pending_evolution", "Entwicklung wartet auf einen sicheren Moment", locale) if not model.get("pending_evolution", {}).is_empty() else application.text("ui.evolution_hint", "Pflege und Training bestimmen den nächsten Weg.", locale)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	return column


func _habitat(model: Dictionary) -> HabitatView:
	var habitat := HabitatView.new()
	active_habitat = habitat
	habitat.ready.connect(_configure_habitat.bind(habitat, model))
	return habitat


func _configure_habitat(habitat: HabitatView, model: Dictionary) -> void:
	var event := animation_controller.consume_one_shot()
	var animations := {}
	for animation_name in ["idle", "walk", "eat", "happy", "sleep", "sick", "injured", "training", "attack", "hit", "victory", "call"]:
		animations[animation_name] = application.get_animation_descriptor(animation_name)
	habitat.configure_pet(animations, "idle" if not event.is_empty() else animation_controller.effective_loop(model), {
		"reduced_motion": reduced_motion,
		"ambient_roaming": bool(preferences.get("pet_presentation", {}).get("ambient_roaming", true)),
		"pet_scale": float(preferences.get("pet_presentation", {}).get("standard_pet_scale", 1.0)),
		"animation_speed": _animation_speed(),
		"walking_speed": _walking_speed(),
		"effects_intensity": str(preferences.get("pet_presentation", {}).get("effects_intensity", "normal")),
	})
	if not event.is_empty():
		var from_anchor := str(event.get("from_anchor", ""))
		if not from_anchor.is_empty():
			habitat.set_world_anchor(from_anchor)
		habitat.start_action(str(event.get("anchor", "idle_center")), str(event.get("animation", "happy")), float(event.get("duration", 1.1)), str(event.get("loop_after", "idle")))
	var battle: Dictionary = model.get("active_battle", {})
	if not battle.is_empty():
		habitat.set_opponent(application.get_animation_descriptor("idle", str(battle.get("encounter_id", ""))))
	habitat.show_call(_call_icon(model))
	habitat.set_trophy_visible("koalapet.base:boss_memory_gate" in model.get("unlock_ids", []))


func _animation_for(model: Dictionary) -> String:
	if not transient_animation.is_empty():
		return transient_animation
	if not model.get("active_battle", {}).is_empty():
		return "attack"
	if not model.get("injury", {}).is_empty():
		return "injured"
	if bool(model.get("sickness", false)):
		return "sick"
	if bool(model.get("sleeping", false)):
		return "sleep"
	if not model.get("open_calls", []).is_empty():
		return "call"
	var last: Dictionary = model.get("last_battle_result", {})
	if str(last.get("status", "")) == "win":
		return "victory"
	return "idle"


func _call_icon(model: Dictionary) -> String:
	if not model.get("injury", {}).is_empty() or bool(model.get("sickness", false)):
		return "health"
	var calls: Array = model.get("open_calls", [])
	if calls.is_empty():
		return ""
	var kind := str(calls[0].get("kind", calls[0].get("type", "")))
	return "feed" if "hunger" in kind else "sleep" if "bed" in kind or "sleep" in kind else "clean" if "dirty" in kind else "call"


func _set_mode(value: String) -> void:
	if value not in [MODE_MINIMAL, MODE_SMALL, MODE_EXPANDED] or value == mode:
		return
	_save_window_placement()
	mode = value
	_apply_window_mode()
	_refresh()


func _apply_window_mode() -> void:
	get_viewport().transparent_bg = true
	var mode_value := _mode_value(mode)
	var text_scale := float(preferences.get("interface", {}).get("text_scale", 1.0))
	var logical_size := WindowPresentationMode.scaled_size(mode_value, 1.0, text_scale, _minimal_pet_scale())
	var rendered_size := WindowPresentationMode.scaled_size(mode_value, resolved_ui_scale, text_scale, _minimal_pet_scale())
	# Keep the render viewport and the native client area on the same pixel grid.
	# Without this, a live scale change can enlarge only the Win32 window and
	# leave the previous Control viewport clipped inside a transparent border.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = rendered_size
	var presentation_scale := resolved_ui_scale if mode != MODE_MINIMAL else 1.0
	for layer in [root_layer, notification_layer]:
		layer.anchor_right = 0.0
		layer.anchor_bottom = 0.0
		layer.position = Vector2.ZERO
		layer.scale = Vector2.ONE * presentation_scale
		layer.size = Vector2(logical_size)
	if window_adapter.is_host_supported():
		mode_controller.transition_to(mode_value)
		window_adapter.set_size(rendered_size)
		window_adapter.set_transparency(true)
		window_adapter.set_always_on_top(bool(preferences.get("desktop", {}).get("always_on_top", true)))
		if mode == MODE_MINIMAL:
			window_adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NO_FOCUS)
			window_adapter.set_input_policy(DesktopWindowAdapter.INPUT_HIT_REGION if bool(preferences.get("desktop", {}).get("minimal_click_through", true)) else DesktopWindowAdapter.INPUT_INTERACTIVE)
		else:
			window_adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NORMAL)
			window_adapter.set_input_policy(DesktopWindowAdapter.INPUT_INTERACTIVE)
	root_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE if mode == MODE_MINIMAL else Control.MOUSE_FILTER_PASS


func _update_minimal_hit_region() -> void:
	if not window_adapter.is_host_supported():
		return
	if mode != MODE_MINIMAL or minimal_sprite == null or not is_instance_valid(minimal_sprite):
		window_adapter.set_input_policy(DesktopWindowAdapter.INPUT_INTERACTIVE)
		return
	if not bool(preferences.get("desktop", {}).get("minimal_click_through", true)):
		window_adapter.set_input_policy(DesktopWindowAdapter.INPUT_INTERACTIVE)
		return
	var polygon := minimal_sprite.interaction_polygon()
	window_adapter.set_hit_regions([OverlayHitRegion.single(polygon, 4, "minimal_pet")])


func _save_window_placement() -> void:
	if mode_controller == null or not window_adapter.is_host_supported() or not bool(preferences.get("desktop", {}).get("remember_window_positions", true)):
		return
	mode_controller.remember_placement(window_adapter.get_current_placement(_mode_value(mode)))
	OverlayPlacementStore.save_envelope({
		"version": OverlayPlacementStore.VERSION,
		"last_mode": mode.to_upper(),
		"always_on_top": bool(preferences.get("desktop", {}).get("always_on_top", true)),
		"placements": mode_controller.serialize_placements(),
	}, placement_path)


func _mode_value(value: String) -> int:
	return WindowPresentationMode.from_label(value, WindowPresentationMode.Value.SMALL)


func _set_small_page(value: String) -> void:
	small_page = value
	_refresh()


func _set_expanded_tab(value: String) -> void:
	expanded_tab = value
	_refresh()


func _toggle_locale() -> void:
	locale = "en" if locale == "de" else "de"
	preferences["interface"]["language"] = locale
	_save_preferences()
	_refresh()


func _toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	preferences["pet_presentation"]["reduced_motion"] = reduced_motion
	_save_preferences()
	_refresh(application.text("ui.reduced_motion_on", "Bewegungsreduktion aktiv", locale) if reduced_motion else application.text("ui.reduced_motion_off", "Bewegungsreduktion aus", locale))


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and window_adapter.is_host_supported():
		window_adapter.begin_native_drag()


func _on_minimal_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_mode(MODE_SMALL)


func _minimize() -> void:
	if window_adapter.is_host_supported():
		window_adapter.minimize_window()


func _show_notification(text_value: String) -> void:
	_clear(notification_layer)
	notification_revision += 1
	var revision := notification_revision
	var notice := PixelUi.reward_notification(text_value)
	notice.position = Vector2(maxf(8.0, root_layer.size.x - 300.0), 44.0)
	notice.size = Vector2(280, 50)
	notification_layer.add_child(notice)
	_remove_notification_later(revision)


func _remove_notification_later(revision: int) -> void:
	await get_tree().create_timer(2.2).timeout
	if revision == notification_revision:
		_clear(notification_layer)


func _play_action(animation_name: String) -> void:
	transient_animation = animation_name
	animation_revision += 1
	var revision := animation_revision
	_refresh()
	_reset_animation_later(revision)


func _reset_animation_later(revision: int) -> void:
	await get_tree().create_timer(1.1).timeout
	if revision == animation_revision:
		transient_animation = ""
		_refresh()


func _choose_starter(egg_id: String) -> void:
	var result := application.choose_starter(egg_id)
	if result.get("ok", false):
		mode = MODE_SMALL
		_apply_window_mode()
	_refresh(_command_status(result))


func _complete_hatch() -> void:
	var result := application.complete_hatch()
	_refresh(application.text("ui.hatched", "Willkommen, {name}!", locale).replace("{name}", application.get_view_model(MODE_SMALL, locale).get("name", "")) if result.get("ok", false) else _command_status(result))


func _feed() -> void:
	_command({"type": "feed", "item_id": application.find_item_by_kind("meal")}, "eat", "feeding_bowl")


func _treat() -> void:
	_command({"type": "feed", "item_id": application.find_item_by_kind("treat")}, "happy", "treat_position")


func _clean() -> void:
	_command({"type": "clean"}, "happy", "bath")


func _train() -> void:
	_command({"type": "train", "activity_id": application.get_training_activity_id(), "input_bps": 5000}, "training", "training")


func _medicine() -> void:
	_command({"type": "medicine", "item_id": application.find_item_by_kind("medicine")}, "happy", "medicine")


func _treat_injury() -> void:
	_command({"type": "treat_injury", "item_id": application.find_item_by_kind("injury_treatment")}, "happy", "medicine")


func _sleep_or_wake(sleeping: bool) -> void:
	_command({"type": "wake" if sleeping else "sleep"}, "idle" if sleeping else "sleep", "idle_center" if sleeping else "bed", "idle" if sleeping else "sleep", "bed" if sleeping else "idle_center")


func _resolve_first_call() -> void:
	var calls: Array = application.get_view_model(MODE_SMALL, locale).get("open_calls", [])
	if not calls.is_empty():
		_command({"type": "resolve_call", "call_id": str(calls[0].get("call_id", ""))}, "happy")


func _battle_action() -> void:
	var model := application.get_view_model(MODE_SMALL, locale)
	if model.get("active_battle", {}).is_empty():
		_start_battle()
	else:
		_battle_round()


func _dungeon_action() -> void:
	var model := application.get_view_model(MODE_SMALL, locale)
	if model.get("active_dungeon_run", {}).is_empty():
		_start_dungeon()
	else:
		_dungeon_next()


func _start_battle() -> void:
	_command({"type": "start_battle", "encounter_id": _default_encounter_id(), "stance": "balanced"}, "attack", "departure")


func _set_battle_stance(stance: String) -> void:
	_command({"type": "battle_stance", "stance": stance}, "idle")


func _battle_round() -> void:
	_command({"type": "battle_round"}, "attack")


func _battle_resolve(outcome: String) -> void:
	_command({"type": "battle_resolve", "outcome": outcome}, "victory" if outcome == "win" else "injured")


func _start_dungeon() -> void:
	var dungeons := application.get_dungeons()
	if not dungeons.is_empty():
		_command({"type": "start_dungeon", "dungeon_id": str(dungeons[0].get("id", ""))}, "walk", "departure")


func _dungeon_next() -> void:
	var model := application.get_view_model(MODE_SMALL, locale)
	if not model.get("active_battle", {}).is_empty():
		_battle_round()
	else:
		_command({"type": "dungeon_next"}, "walk")


func _dungeon_choice(choice_id: String) -> void:
	_command({"type": "dungeon_choice", "choice_id": choice_id}, "happy")


func _command(payload: Dictionary, animation_name: String, anchor_name := "idle_center", loop_after := "idle", from_anchor := "") -> void:
	var result := application.command(payload)
	if result.get("ok", false):
		animation_controller.queue_one_shot(animation_name, anchor_name, 1.1, "command:%d:%s" % [int(application.get_view_model(MODE_SMALL, locale).get("state_revision", 0)), str(payload.get("type", "action"))], loop_after, from_anchor)
	_refresh(_command_status(result))


func _default_encounter_id() -> String:
	for encounter in application.get_encounters():
		var id := str(encounter.get("id", ""))
		if id == "koalapet.base:creekling_encounter":
			return id
	for encounter in application.get_encounters():
		if str(encounter.get("id", "")) != "koalapet.base:canopy_guardian":
			return str(encounter.get("id", ""))
	return ""


func _open_nickname_modal() -> void:
	var shade := ColorRect.new()
	shade.name = "NicknameModal"
	shade.color = Color("#081015cc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var modal := PixelUi.modal(application.text("ui.nickname", "Spitzname", locale), application.text("ui.nickname_hint", "Optionaler Spitzname", locale))
	modal.custom_minimum_size = Vector2(340, 180)
	center.add_child(modal)
	var column := modal.get_child(0) as VBoxContainer
	var input := LineEdit.new()
	input.max_length = 20
	input.placeholder_text = application.text("ui.nickname_hint", "Optionaler Spitzname", locale)
	column.add_child(input)
	var save := PixelUi.button(application.text("ui.save", "Speichern", locale))
	save.pressed.connect(_save_nickname.bind(input))
	column.add_child(save)


func _save_nickname(input: LineEdit) -> void:
	_command({"type": "set_nickname", "nickname": input.text}, "happy")


func _open_dev_window() -> void:
	if not show_dev_tools:
		return
	if dev_window != null and is_instance_valid(dev_window):
		dev_window.show()
		return
	dev_window = Window.new()
	dev_window.title = "KoalaPet Development Tools"
	dev_window.size = Vector2i(360, 220)
	dev_window.transient = true
	dev_window.exclusive = false
	add_child(dev_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_margins(margin, 12)
	dev_window.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	column.add_child(PixelUi.title(application.text("ui.dev", "Entwicklungswerkzeuge", locale), 16))
	for entry in [[application.text("ui.dev_advance_hour", "1 Stunde vor", locale), _advance_hour], [application.text("ui.dev_force_sick", "Krankheit erzwingen", locale), _force_sickness]]:
		var button := PixelUi.button(str(entry[0]))
		button.pressed.connect(entry[1])
		column.add_child(button)
	dev_window.close_requested.connect(dev_window.hide)
	dev_window.show()


func _advance_hour() -> void:
	var result := application.advance_simulated(3600)
	_refresh(_command_status(result))


func _force_sickness() -> void:
	_command({"type": "force_sickness"}, "sick")


func _run_poor_route_review() -> void:
	for cycle in range(2):
		application.command({"type": "force_sickness"})
		application.advance_simulated(1)
		application.advance_simulated(7200)
		application.command({"type": "medicine", "item_id": application.find_item_by_kind("medicine")})
	_refresh(_command_status(application.advance_simulated(60)))


func _state_line(model: Dictionary) -> String:
	if bool(model.get("sleeping", false)):
		return application.text("ui.state.sleeping", "Schläft", locale)
	if bool(model.get("sickness", false)):
		return application.text("ui.state.sick", "Braucht Medizin", locale)
	if not model.get("injury", {}).is_empty():
		return application.text("ui.injury", "Verletzung: {name}", locale).replace("{name}", application.get_display_name(str(model.injury.get("injury_id", "")), locale))
	if not model.get("active_battle", {}).is_empty():
		return application.text("ui.battle", "Kampf", locale)
	if not model.get("active_dungeon_run", {}).is_empty():
		return application.text("ui.dungeon", "Dungeon", locale)
	return application.text("ui.state.ready", "Bereit für Pflege", locale)


func _event_label(event_type: String) -> String:
	return application.text("event." + event_type, event_type.replace("_", " ").capitalize(), locale)


func _starter_affinity(egg_id: String) -> String:
	if "moss" in egg_id:
		return application.text("ui.affinity.moss", "Ruhig · Blätter · Schutz", locale)
	if "ember" in egg_id:
		return application.text("ui.affinity.ember", "Mutig · Glut · Tempo", locale)
	return application.text("ui.affinity.tide", "Neugierig · Wasser · Fokus", locale)


func _command_status(result: Dictionary) -> String:
	return application.text("ui.saved", "Gespeichert", locale) if result.get("ok", false) else str(result.get("reason", result.get("error_code", "Action failed")))


func _set_margins(value: MarginContainer, amount: int) -> void:
	value.add_theme_constant_override("margin_left", amount)
	value.add_theme_constant_override("margin_right", amount)
	value.add_theme_constant_override("margin_top", amount)
	value.add_theme_constant_override("margin_bottom", amount)


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.free()


func _argument_value(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for argument in args:
		var value := str(argument)
		if value.begins_with(prefix):
			return value.substr(prefix.length())
	return fallback


func _has_argument(args: PackedStringArray, prefix: String) -> bool:
	for argument in args:
		if str(argument).begins_with(prefix):
			return true
	return false


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
		KEY_F9:
			if show_dev_tools:
				_advance_hour()
		KEY_F10:
			if show_dev_tools:
				_force_sickness()


func _run_review_actions(actions: PackedStringArray, diagnostics_delay_ms := 0) -> void:
	for action in actions:
		await get_tree().process_frame
		match str(action):
			"choose:moss": _choose_starter("koalapet.base:moss_egg")
			"choose:ember": _choose_starter("koalapet.base:ember_egg")
			"choose:tide": _choose_starter("koalapet.base:tide_egg")
			"hatch": _complete_hatch()
			"feed": _feed()
			"treat": _treat()
			"clean": _clean()
			"train": _train()
			"sleep": _sleep_or_wake(false)
			"wake": _sleep_or_wake(true)
			"sick": _force_sickness()
			"medicine": _medicine()
			"injury_treatment": _treat_injury()
			"hour": _advance_hour()
			"battle": _start_battle()
			"round": _battle_round()
			"win": _battle_resolve("win")
			"loss": _battle_resolve("loss")
			"dungeon": _start_dungeon()
			"dungeon_event": _dungeon_choice("quiet_pool")
			"poor:tide": _run_poor_route_review()
			"good":
				_train()
				application.advance_simulated(60)
				_refresh(application.text("ui.evolution", "Entwicklung", locale))
			"node": _dungeon_next()
			"resolve": _resolve_first_call()
			"mode:minimal": _set_mode(MODE_MINIMAL)
			"mode:small": _set_mode(MODE_SMALL)
			"mode:expanded": _set_mode(MODE_EXPANDED)
			"tab:battle": _set_expanded_tab("battle")
			"tab:dungeon": _set_expanded_tab("dungeon")
			"tab:inventory": _set_expanded_tab("inventory")
			"tab:codex": _set_expanded_tab("codex")
			"tab:evolution": _set_expanded_tab("evolution")
			"dungeon_unlock":
				_start_battle()
				_battle_resolve("win")
				application.command({"type": "start_battle", "encounter_id": "koalapet.base:thornlet_encounter", "stance": "aggressive"})
				application.command({"type": "battle_resolve", "outcome": "win"})
				_refresh()
			"dungeon_run":
				_start_dungeon()
				_dungeon_next()
				_battle_resolve("win")
			"dungeon_boss":
				_start_dungeon()
				_dungeon_next()
				_battle_resolve("win")
				_dungeon_choice("quiet_pool")
				_dungeon_next()
				_battle_resolve("win")
				_dungeon_next()
				_dungeon_next()
				_set_expanded_tab("dungeon")
			"digest":
				application.advance_simulated(901)
				_refresh()
			"locale:en":
				locale = "en"
				_refresh()
			"settings": _open_settings()
			"ui:100": _set_preference(1.0, "interface", "ui_scale")
			"ui:150": _set_preference(1.5, "interface", "ui_scale")
			"ui:200": _set_preference(2.0, "interface", "ui_scale")
			"text:100": _set_preference(1.0, "interface", "text_scale")
			"text:150": _set_preference(1.5, "interface", "text_scale")
			"pet:75": _set_preference(0.75, "pet_presentation", "standard_pet_scale")
			"pet:150": _set_preference(1.5, "pet_presentation", "standard_pet_scale")
			"minimal_pet:75": _set_preference(0.75, "pet_presentation", "minimal_pet_scale")
			"minimal_pet:150": _set_preference(1.5, "pet_presentation", "minimal_pet_scale")
			"roaming:off": _set_preference(false, "pet_presentation", "ambient_roaming")
			"reduced:on": _set_preference(true, "pet_presentation", "reduced_motion")
	await get_tree().process_frame
	await get_tree().process_frame
	if diagnostics_delay_ms > 0:
		await get_tree().create_timer(float(diagnostics_delay_ms) / 1000.0).timeout
		await get_tree().process_frame
		await get_tree().process_frame
	_write_diagnostics()


func _run_animation_polish_demo() -> void:
	# Review-only deterministic product-polish sequence. It exercises the same
	# commands, state controller, preferences and mode transitions as player UI.
	await get_tree().create_timer(3.5).timeout
	_feed()
	await get_tree().create_timer(2.5).timeout
	_train()
	await get_tree().create_timer(4.6).timeout
	_sleep_or_wake(false)
	await get_tree().create_timer(5.0).timeout
	_set_mode(MODE_EXPANDED)
	await get_tree().create_timer(2.0).timeout
	_set_preference(1.25, "interface", "ui_scale")
	await get_tree().create_timer(2.0).timeout
	_set_preference(1.0, "interface", "ui_scale")
	_set_mode(MODE_MINIMAL)


func _write_diagnostics() -> void:
	if diagnostics_path.is_empty():
		return
	var persistent_backgrounds := 0
	for child in root_layer.get_children():
		if child is ColorRect:
			persistent_backgrounds += 1
	var payload := {
		"schema_version": 1,
		"mode": mode,
		"locale": locale,
		"state_revision": int(application.get_view_model(mode, locale).get("state_revision", 0)),
		"persistent_root_color_rects": persistent_backgrounds,
		"presentation_rect": _rect_array(get_rect()),
		"viewport_visible_rect": _rect_array(get_viewport_rect()),
		"content_scale_size": [get_window().content_scale_size.x, get_window().content_scale_size.y],
		"layout_rects": _diagnostic_layout_rects(),
		"minimal_pet_rect": _rect_array(minimal_sprite.get_global_rect()) if minimal_sprite != null and is_instance_valid(minimal_sprite) else [],
		"resolved_ui_scale": resolved_ui_scale,
		"text_scale": float(preferences.get("interface", {}).get("text_scale", 1.0)),
		"standard_pet_scale": float(preferences.get("pet_presentation", {}).get("standard_pet_scale", 1.0)),
		"minimal_pet_scale": _minimal_pet_scale(),
		"theme_base_scale": theme.default_base_scale if theme != null else 0.0,
		"reduced_motion": reduced_motion,
		"ambient_roaming": bool(preferences.get("pet_presentation", {}).get("ambient_roaming", true)),
		"habitat_visual_state": active_habitat.current_visual_state() if active_habitat != null and is_instance_valid(active_habitat) else "",
		"habitat_anchor": [active_habitat.current_anchor_position().x, active_habitat.current_anchor_position().y] if active_habitat != null and is_instance_valid(active_habitat) else [],
		"habitat_moving": active_habitat.is_moving() if active_habitat != null and is_instance_valid(active_habitat) else false,
		"preference_schema_version": int(preferences.get("version", 0)),
		"native_window": window_adapter.capture_diagnostics() if window_adapter != null else {},
	}
	var absolute := ProjectSettings.globalize_path(diagnostics_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t") + "\n")
		file.close()


func _rect_array(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _minimal_walk_bounds(sprite_extent := Vector2.ZERO, window_extent := Vector2i.ZERO) -> Vector2:
	var resolved_sprite := sprite_extent if sprite_extent != Vector2.ZERO else (minimal_sprite.size if minimal_sprite != null else Vector2(128, 128))
	var resolved_window := Vector2(window_extent) if window_extent != Vector2i.ZERO else size
	return Vector2(8.0, maxf(8.0, resolved_window.x - resolved_sprite.x - 8.0))


func _diagnostic_layout_rects() -> Dictionary:
	var result := {}
	for node_name in ["ExpandedBody", "ExpandedStatus", "ExpandedCenter", "ExpandedActions"]:
		var node := root_layer.find_child(node_name, true, false) as Control
		if node != null:
			result[node_name] = _rect_array(node.get_global_rect())
	return result
