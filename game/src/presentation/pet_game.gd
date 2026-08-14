extends Control

const MODE_MINIMAL := "minimal"
const MODE_SMALL := "small"
const MODE_EXPANDED := "expanded"
const PLACEMENT_PATH := "user://presentation/placement.json"
const PREFERENCES_PATH := "user://preferences.json"
## Repeating the *same* command inside this window is treated as one intent, so
## an accidental double click cannot submit the same authoritative command
## twice. The value matches the Windows double-click threshold; a deliberate
## repeat half a second later still goes through, and a different action is
## never delayed.
const COMMAND_DEBOUNCE_MSEC := 450

## Logical width per care meter below which the localized name no longer fits
## beside its percentage; the meter then shows icon and value only.
const NARROW_METER_WIDTH := 168.0

## Localization key, German fallback and icon for every care meter.
const STATUS_KEYS := {
	"satiety_bps": ["ui.satiety", "Sättigung", "satiety"],
	"mood_bps": ["ui.mood", "Stimmung", "mood"],
	"energy_bps": ["ui.energy", "Energie", "energy"],
	"hygiene_bps": ["ui.hygiene", "Hygiene", "hygiene"],
	"health_bps": ["ui.health", "Gesundheit", "health"],
	"discipline_bps": ["ui.discipline", "Disziplin", "discipline"],
}

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
var minimal_cursor_elapsed := 0.0
var minimal_cursor_cooldown := 0.0
var minimal_action_remaining := 0.0
var minimal_action_kind := ""
var minimal_event_pause := 3.0
var minimal_authoritative_loop := "idle"
var minimal_roaming_allowed := true
var minimal_open_pending := false
var minimal_animations: Dictionary = {}
var minimal_scheduler := AmbientAnimationScheduler.new()
var small_page := "care"
var expanded_tab := "home"
var transient_animation := ""
var notification_revision := 0
var animation_revision := 0
var command_in_flight := false
var last_command_msec := 0
var last_command_key := ""
var suppressed_duplicate_commands := 0
var refresh_depth := 0
var logical_size := Vector2(720, 450)
var requested_window_size := Vector2i.ZERO
var applied_presentation_scale := 0.0
var applied_reference_size := Vector2i.ZERO
var mode_switch_requests := 0
var mode_switch_applied := 0
var last_mode_request := ""
var active_habitat_frame: HabitatFrame
var last_feedback: Dictionary = {}
var requested_save_path := ""
var diagnostics_path := ""
var capture_path := ""
var diagnostics_live := false
var diagnostics_sequence := 0
var last_feedback_record: Dictionary = {}
var placement_path := PLACEMENT_PATH
var dev_window: Window
var animation_showroom_window: Window
var animation_controller := PresentationAnimationController.new()
var active_habitat: HabitatView
var review_event_sequence := 0
var minimal_hit_region_updates := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var development_actions_enabled := OS.is_debug_build()
	requested_save_path = _argument_value(args, "--save-path=", requested_save_path if not requested_save_path.is_empty() else "user://saves/koalapet.json")
	diagnostics_path = _argument_value(args, "--diagnostics-path=", "")
	capture_path = _argument_value(args, "--capture-path=", "") if development_actions_enabled else ""
	# Development-only closed loop for the interactive action matrix: the harness
	# clicks a real control, then reads the refreshed authoritative state back.
	diagnostics_live = development_actions_enabled and "--diagnostics-live" in args
	placement_path = _argument_value(args, "--placement-path=", placement_path)
	preferences_path = _argument_value(args, "--preferences-path=", preferences_path)
	preferences = PresentationPreferences.load_file(preferences_path).get("data", PresentationPreferences.defaults())
	var interface_preferences: Dictionary = preferences.get("interface", {})
	var pet_preferences: Dictionary = preferences.get("pet_presentation", {})
	var desktop_preferences: Dictionary = preferences.get("desktop", {})
	application = PetApplication.new({"save_path": requested_save_path})
	show_dev_tools = development_actions_enabled and "--dev-tools" in args
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
	if development_actions_enabled and not review_actions.is_empty():
		var diagnostics_delay := maxi(0, int(_argument_value(args, "--diagnostics-delay-ms=", "0")))
		call_deferred("_run_review_actions", review_actions.split(",", false), diagnostics_delay)
	else:
		_write_diagnostics_after_layout()
	if development_actions_enabled and "--animation-polish-demo" in args:
		call_deferred("_run_animation_polish_demo")
	var living_demo := _argument_value(args, "--living-animation-demo=", "")
	if development_actions_enabled and not living_demo.is_empty():
		call_deferred("_run_living_animation_demo", living_demo)
	if show_dev_tools and "--animation-showroom" in args:
		call_deferred("_open_animation_showroom")


func _process(delta: float) -> void:
	if mode != MODE_MINIMAL or minimal_sprite == null or not is_instance_valid(minimal_sprite):
		return
	minimal_hit_elapsed += delta
	if minimal_hit_elapsed >= 1.0 / 20.0:
		minimal_hit_elapsed = 0.0
		_update_minimal_hit_region()
	minimal_cursor_cooldown = maxf(0.0, minimal_cursor_cooldown - delta)
	minimal_cursor_elapsed += delta
	if minimal_cursor_elapsed >= 0.2:
		minimal_cursor_elapsed = 0.0
		_update_minimal_cursor_reaction()
	var pet_preferences: Dictionary = preferences.get("pet_presentation", {})
	var desktop_preferences: Dictionary = preferences.get("desktop", {})
	var ambient_enabled := minimal_roaming_allowed and bool(pet_preferences.get("ambient_roaming", true)) and str(desktop_preferences.get("minimal_lane", "bottom")) != "stationary"
	if minimal_moving:
		var speed := 46.0 if minimal_action_kind == "playful_move" else 28.0
		minimal_sprite.position.x = move_toward(minimal_sprite.position.x, minimal_target_x, delta * speed * _walking_speed())
		if is_equal_approx(minimal_sprite.position.x, minimal_target_x):
			minimal_moving = false
			if minimal_action_kind == "walk":
				minimal_action_kind = ""
				minimal_pause_remaining = minimal_event_pause
				_minimal_set_animation(minimal_authoritative_loop)
		return
	if minimal_action_remaining > 0.0:
		minimal_action_remaining -= delta
		if minimal_action_remaining <= 0.0:
			if minimal_open_pending:
				minimal_open_pending = false
				_set_mode(MODE_SMALL)
				return
			minimal_action_kind = ""
			minimal_pause_remaining = minimal_event_pause
			_minimal_set_animation(minimal_authoritative_loop)
		return
	if reduced_motion or not ambient_enabled or minimal_authoritative_loop != "idle":
		return
	if minimal_pause_remaining > 0.0:
		minimal_pause_remaining -= delta
		if minimal_pause_remaining <= 0.0:
			_start_minimal_ambient_event(minimal_scheduler.next_event())
		return


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
	if not get_window().size_changed.is_connected(_on_window_size_changed):
		get_window().size_changed.connect(_on_window_size_changed)
	if diagnostics_live and not get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _build_error(reason: String) -> void:
	_clear(root_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_layer.add_child(center)
	var panel := PixelUi.modal("Foundation error", reason)
	panel.custom_minimum_size = Vector2(420, 140)
	center.add_child(panel)


func _refresh(status_override := "") -> void:
	# A rebuild must never be able to re-enter itself. A deferred `pressed`
	# callback that arrives while the tree is half rebuilt would otherwise free
	# the controls the outer rebuild is still populating.
	if refresh_depth > 0:
		call_deferred("_refresh", status_override)
		return
	refresh_depth += 1
	_clear(root_layer)
	minimal_sprite = null
	active_habitat = null
	active_habitat_frame = null
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
	refresh_depth -= 1
	if not status_override.is_empty():
		_show_notification(status_override)
	elif not last_feedback.is_empty():
		_show_feedback(last_feedback)
	last_feedback = {}
	call_deferred("_update_minimal_hit_region")
	if diagnostics_live:
		_write_diagnostics_after_layout()


func _build_starter() -> void:
	# The starter screen carries the same window chrome as every other screen.
	# Without it a first-time player could not close, minimise, move or
	# configure the application at all.
	var shell := _window_shell({"name": application.text("ui.title", "KoalaPet", locale), "hatched": false})
	var column := VBoxContainer.new()
	column.name = "StarterScreen"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(column, UiMetrics.SPACE_SECTION)
	shell.add_child(column)
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
	var choose := PixelUi.button(application.text("ui.select", "Wählen", locale), "egg", "%s · %s" % [application.text("ui.select", "Wählen", locale), application.get_display_name(egg_id, locale)])
	choose.name = "Starter_" + egg_id.get_slice(":", 1)
	choose.set_meta("action_id", "choose_starter")
	_connect_pressed(choose, _show_starter_confirmation.bind(egg_id))
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
	cancel.name = "StarterCancel"
	_connect_pressed(cancel, shade.queue_free)
	row.add_child(cancel)
	var confirm := PixelUi.button(application.text("ui.confirm", "Bestätigen", locale), "egg")
	confirm.name = "StarterConfirm"
	confirm.set_meta("action_id", "choose_starter")
	_connect_pressed(confirm, _choose_starter.bind(egg_id))
	row.add_child(confirm)
	_note_ui_change()


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
	var close := PixelUi.window_button("close", application.text("ui.close", "Schließen", locale))
	close.name = "SettingsClose"
	_connect_pressed(close, shade.queue_free)
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, clampf(logical_size.y - 160.0, 180.0, 560.0))
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
	_add_setting_options(grid, application.text("ui.ambient_frequency", "Umgebungsanimationen", locale), [application.text("ui.low", "Niedrig", locale), application.text("ui.normal", "Normal", locale), application.text("ui.high", "Hoch", locale)], ["low", "normal", "high"], preferences["pet_presentation"]["ambient_animation_frequency"], _set_preference.bind("pet_presentation", "ambient_animation_frequency"))
	_add_setting_options(grid, application.text("ui.effects_intensity", "Kampfeffektstärke", locale), [application.text("ui.off", "Aus", locale), application.text("ui.reduced", "Reduziert", locale), application.text("ui.normal", "Normal", locale)], ["off", "reduced", "normal"], preferences["pet_presentation"]["effects_intensity"], _set_preference.bind("pet_presentation", "effects_intensity"))
	_add_setting_options(grid, application.text("ui.default_mode", "Startmodus", locale), ["Minimal", "Small", "Expanded"], ["minimal", "small", "expanded"], preferences["desktop"]["default_launch_mode"], _set_preference.bind("desktop", "default_launch_mode"))
	_add_setting_options(grid, application.text("ui.desktop_lane", "Desktop-Spur", locale), [application.text("ui.bottom", "Unterer Rand", locale), application.text("ui.stationary", "Stationär", locale)], ["bottom", "stationary"], preferences["desktop"]["minimal_lane"], _set_preference.bind("desktop", "minimal_lane"))
	_add_setting_toggle(grid, application.text("ui.ambient_roaming", "Umherlaufen", locale), bool(preferences["pet_presentation"]["ambient_roaming"]), _set_preference.bind("pet_presentation", "ambient_roaming"))
	_add_setting_toggle(grid, application.text("ui.cursor_reaction", "Pet reagiert auf den Cursor", locale), bool(preferences["pet_presentation"]["cursor_reaction"]), _set_preference.bind("pet_presentation", "cursor_reaction"))
	_add_setting_toggle(grid, application.text("ui.hit_shake", "Treffererschütterung", locale), bool(preferences["pet_presentation"]["hit_shake"]), _set_preference.bind("pet_presentation", "hit_shake"))
	_add_setting_toggle(grid, application.text("ui.damage_flash", "Trefferaufhellung", locale), bool(preferences["pet_presentation"]["damage_flash"]), _set_preference.bind("pet_presentation", "damage_flash"))
	_add_setting_toggle(grid, application.text("ui.reduced_motion", "Weniger Bewegung", locale), reduced_motion, _set_preference.bind("pet_presentation", "reduced_motion"))
	_add_setting_toggle(grid, application.text("ui.high_contrast", "Hoher Kontrast", locale), bool(preferences["interface"]["high_contrast"]), _set_preference.bind("interface", "high_contrast"))
	_add_setting_toggle(grid, application.text("ui.tooltips", "Tooltips", locale), bool(preferences["interface"]["tooltips_enabled"]), _set_preference.bind("interface", "tooltips_enabled"))
	_add_setting_toggle(grid, application.text("ui.always_on_top", "Immer im Vordergrund", locale), bool(preferences["desktop"]["always_on_top"]), _set_preference.bind("desktop", "always_on_top"))
	_add_setting_toggle(grid, application.text("ui.click_through", "Klicks außerhalb durchlassen", locale), bool(preferences["desktop"]["minimal_click_through"]), _set_preference.bind("desktop", "minimal_click_through"))
	_add_setting_toggle(grid, application.text("ui.remember_positions", "Fensterpositionen merken", locale), bool(preferences["desktop"]["remember_window_positions"]), _set_preference.bind("desktop", "remember_window_positions"))
	var reset := PixelUi.button(application.text("ui.reset_windows", "Fenster sichtbar zurücksetzen", locale), "settings")
	reset.name = "SettingsResetWindows"
	_connect_pressed(reset, _reset_windows)
	column.add_child(reset)
	_note_ui_change()


## Overlays such as the settings sheet and the starter confirmation are added
## without a full rebuild, so the interactive harness is told to re-sample.
func _note_ui_change() -> void:
	if diagnostics_live:
		_write_diagnostics_after_layout()


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
	options.item_selected.connect(func(index: int) -> void: callback.call(options.get_item_metadata(index)), CONNECT_DEFERRED)
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
	toggle.toggled.connect(func(enabled: bool) -> void: callback.call(enabled), CONNECT_DEFERRED)
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


## Godot's `screen_get_scale()` reports 1.0 on Windows regardless of the display
## setting, so the previous "auto" UI scale never left 100% and the whole
## interface rendered at roughly 80% of its intended physical size on a 125%
## display. DPI is the reliable signal, with the reported scale as a fallback.
func _detected_display_scale() -> float:
	if window_adapter == null:
		return 1.0
	for monitor in window_adapter.enumerate_monitors():
		if monitor.index != get_window().current_screen:
			continue
		var from_dpi := float(monitor.dpi) / 96.0 if monitor.dpi > 0 else 1.0
		return clampf(maxf(from_dpi, monitor.scale), 1.0, 2.0)
	return 1.0


func _minimal_pet_scale() -> float:
	return float(preferences.get("pet_presentation", {}).get("minimal_pet_scale", 1.0))


func _animation_speed() -> float:
	return float(preferences.get("pet_presentation", {}).get("animation_speed", 1.0))


func _walking_speed() -> float:
	return float(preferences.get("pet_presentation", {}).get("walking_speed", 1.0))


func _build_egg(model: Dictionary) -> void:
	var egg_model := model.duplicate(true)
	egg_model["name"] = application.get_display_name(str(model.get("egg_id", "")), locale)
	var shell := _window_shell(egg_model)
	var column := VBoxContainer.new()
	column.name = "EggScreen"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(column, UiMetrics.SPACE_SECTION)
	shell.add_child(column)
	var egg_sprite := AnimatedTextureRect.new()
	egg_sprite.custom_minimum_size = Vector2(140, 140)
	column.add_child(egg_sprite)
	egg_sprite.configure(application.get_animation_descriptor("idle", "", true), reduced_motion)
	column.add_child(_hatch_progress(model))
	var ready := int(model.get("current_simulation_unix", 0)) >= int(model.get("hatch_due_unix", 1))
	var hatch := PixelUi.primary_action(
		application.text("ui.hatch_ready", "Bereit zum Schlüpfen", locale) if ready else application.text("ui.hatching", "Dein Ei wird warm", locale),
		"egg"
	)
	hatch.name = "Action_hatch"
	hatch.set_meta("action_id", "complete_hatch")
	hatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hatch.custom_minimum_size = Vector2(280, UiMetrics.primary_action_height())
	hatch.disabled = not ready
	hatch.tooltip_text = application.text("ui.hatching", "Dein Ei wird warm", locale) if not ready else application.text("ui.hatch_ready", "Bereit zum Schlüpfen", locale)
	_connect_pressed(hatch, _complete_hatch)
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
	minimal_animations = application.get_animation_descriptors("", egg)
	minimal_authoritative_loop = "world" if egg else _animation_for(model)
	minimal_roaming_allowed = not egg and model.get("active_battle", {}).is_empty() and model.get("injury", {}).is_empty() and not bool(model.get("sickness", false)) and not bool(model.get("sleeping", false))
	minimal_moving = false
	minimal_action_remaining = 0.0
	minimal_action_kind = ""
	minimal_open_pending = false
	minimal_pause_remaining = 1.4
	minimal_event_pause = 3.0
	minimal_scheduler.configure(maxi(1, str(model.get("form_id", model.get("egg_id", "pet"))).hash()), str(preferences.get("pet_presentation", {}).get("ambient_animation_frequency", "normal")), reduced_motion)
	var descriptor: Dictionary = minimal_animations.get(minimal_authoritative_loop, minimal_animations.get("idle", {}))
	minimal_sprite.configure(descriptor, reduced_motion, _animation_speed())
	minimal_sprite.set_facing(minimal_direction)
	minimal_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	minimal_sprite.gui_input.connect(_on_minimal_input)
	var call_icon := _call_icon(model)
	if not call_icon.is_empty():
		var bubble := PixelUi.call_bubble(call_icon)
		bubble.name = "TransientCallBubble"
		bubble.position = Vector2(minimal_sprite.position.x + 82.0 * scale_value, maxf(2.0, minimal_sprite.position.y - 8.0))
		root_layer.add_child(bubble)


func _start_minimal_ambient_event(event: Dictionary) -> void:
	minimal_event_pause = float(event.get("pause", 3.0))
	minimal_action_kind = str(event.get("kind", "walk"))
	if minimal_action_kind == "special_idle":
		minimal_action_remaining = float(event.get("duration", 1.2))
		_minimal_set_animation(str(event.get("animation", "idle_look")))
		return
	var bounds := _minimal_walk_bounds()
	var available := maxf(1.0, bounds.y - bounds.x)
	var distance := available * float(event.get("distance_factor", 0.5))
	var center := (bounds.x + bounds.y) * 0.5
	var direction := -1.0 if minimal_sprite.position.x > center else 1.0
	minimal_target_x = clampf(minimal_sprite.position.x + direction * distance, bounds.x, bounds.y)
	if is_equal_approx(minimal_target_x, minimal_sprite.position.x):
		minimal_target_x = bounds.x if direction < 0.0 else bounds.y
	minimal_direction = -1.0 if minimal_target_x < minimal_sprite.position.x else 1.0
	minimal_sprite.set_facing(minimal_direction)
	minimal_moving = true
	if minimal_action_kind == "playful_move":
		minimal_action_remaining = float(event.get("duration", 1.0))
		_minimal_set_animation(str(event.get("animation", "playful_hop")), 1.0)
	else:
		_minimal_set_animation("walk", _walking_speed())


func _minimal_set_animation(animation_name: String, speed_scale := 1.0) -> void:
	var descriptor: Dictionary = minimal_animations.get(animation_name, {})
	if descriptor.is_empty():
		return
	minimal_sprite.configure(descriptor, reduced_motion, _animation_speed() * speed_scale)
	minimal_sprite.restart()
	minimal_sprite.set_facing(minimal_direction)


func _update_minimal_cursor_reaction() -> void:
	if minimal_sprite == null or minimal_cursor_cooldown > 0.0 or minimal_moving or minimal_action_remaining > 0.0 or minimal_authoritative_loop != "idle":
		return
	if not bool(preferences.get("pet_presentation", {}).get("cursor_reaction", true)):
		return
	var cursor := Vector2(DisplayServer.mouse_get_position() - get_window().position)
	var center := minimal_sprite.get_global_rect().get_center()
	if cursor.distance_to(center) > 112.0:
		return
	minimal_direction = -1.0 if cursor.x < center.x else 1.0
	minimal_sprite.set_facing(minimal_direction)
	minimal_action_kind = "cursor"
	minimal_action_remaining = 0.8 if not reduced_motion else 0.35
	minimal_event_pause = 2.5
	minimal_cursor_cooldown = 4.0
	_minimal_set_animation("idle_look")


func _build_small(model: Dictionary) -> void:
	var shell := _window_shell(model)
	shell.add_child(_status_row(model, ["satiety_bps", "mood_bps", "energy_bps", "hygiene_bps"]))
	var alerts := _alert_row(model)
	if alerts != null:
		shell.add_child(alerts)
	var frame := HabitatFrame.new()
	frame.name = "SmallHabitatFrame"
	frame.attach(_habitat(model))
	active_habitat_frame = frame
	shell.add_child(frame)
	shell.add_child(_small_actions(model))
	shell.add_child(_small_navigation(model))


## Shared window shell: margin, frame, drag/close header, and a body column.
func _window_shell(model: Dictionary) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "WindowMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiMetrics.apply_margins(margin, UiMetrics.SPACE_COMPACT)
	root_layer.add_child(margin)
	var frame := PixelUi.panel(true)
	frame.name = "WindowFrame"
	margin.add_child(frame)
	var root := VBoxContainer.new()
	root.name = "WindowBody"
	UiMetrics.apply_separation(root, UiMetrics.SPACE_COMPACT)
	frame.add_child(root)
	root.add_child(_window_header(model))
	return root


## Header shows identity plus window controls only. Care, adventure and view
## actions live in their own regions so the header stops being an icon dump.
func _window_header(model: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PlayerTitleBar"
	row.custom_minimum_size = Vector2(0, UiMetrics.control_height(36))
	UiMetrics.apply_separation(row, UiMetrics.SPACE_COMPACT)
	row.gui_input.connect(_on_title_bar_input)
	var portrait_id := str(model.get("form_id", model.get("egg_id", "")))
	var portrait := _portrait(portrait_id, 32)
	if portrait != null:
		row.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.name = "HeaderIdentity"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 0)
	row.add_child(identity)
	var name_label := PixelUi.title(str(model.get("name", application.text("ui.title", "KoalaPet", locale))), UiMetrics.TEXT_SCREEN_TITLE if mode == MODE_EXPANDED else 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(name_label)
	if bool(model.get("hatched", false)):
		identity.add_child(PixelUi.caption(_stage_line(model)))
	var urgent := _primary_alert(model)
	if not urgent.is_empty():
		# Below this width the name, the alert and five window controls cannot
		# share one row, so the alert keeps only its pictogram and its tooltip.
		var sizing := "natural" if logical_size.x >= 660.0 else "icon"
		var chip := PixelUi.alert_chip(str(urgent["text"]), str(urgent["icon"]), str(urgent["severity"]), sizing)
		chip.name = "HeaderUrgentAlert"
		chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(chip)
	var settings_button := PixelUi.window_button("settings", application.text("ui.settings", "Einstellungen", locale))
	settings_button.name = "HeaderSettings"
	_connect_pressed(settings_button, _open_settings)
	row.add_child(settings_button)
	if show_dev_tools:
		var dev := PixelUi.window_button("codex", application.text("ui.dev", "Entwicklungswerkzeuge", locale))
		dev.name = "HeaderDevTools"
		_connect_pressed(dev, _open_dev_window)
		row.add_child(dev)
	var expanding := mode == MODE_SMALL
	var switch_mode := PixelUi.window_button(
		"expand" if expanding else "collapse",
		application.text("ui.expanded", "Erweitert", locale) if expanding else application.text("ui.small", "Klein", locale)
	)
	switch_mode.name = "HeaderModeSwitch"
	_connect_pressed(switch_mode, _set_mode.bind(MODE_EXPANDED if expanding else MODE_SMALL))
	row.add_child(switch_mode)
	# Minimal is pet-only. Offering it before there is a pet would drop the
	# starter choice into a 240x160 window with no way to complete it.
	if application.has_pet():
		var minimal_button := PixelUi.window_button("minimal", application.text("ui.minimal", "Minimal", locale))
		minimal_button.name = "HeaderMinimalMode"
		_connect_pressed(minimal_button, _set_mode.bind(MODE_MINIMAL))
		row.add_child(minimal_button)
	var minimize := PixelUi.window_button("minimize", application.text("ui.minimize", "Minimieren", locale))
	minimize.name = "HeaderMinimize"
	_connect_pressed(minimize, _minimize)
	row.add_child(minimize)
	var close := PixelUi.window_button("close", application.text("ui.close", "Schließen", locale), true)
	close.name = "HeaderClose"
	_connect_pressed(close, _quit_game)
	row.add_child(close)
	return row


func _portrait(content_id: String, extent: int) -> TextureRect:
	if content_id.is_empty():
		return null
	var path := application.get_preview_asset_path(content_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var value := TextureRect.new()
	value.name = "HeaderPortrait"
	value.texture = load(path) as Texture2D
	value.custom_minimum_size = Vector2(extent, extent)
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value


func _stage_line(model: Dictionary) -> String:
	return "%s · %s %d" % [
		application.text("stage." + str(model.get("stage", "hatchling")), str(model.get("stage", "hatchling")).capitalize(), locale),
		application.text("ui.level", "Stufe", locale),
		int(model.get("level", 1)),
	]


## The four states the player needs at a glance. Health, sickness, injury,
## sleep and calls are contextual alerts instead of permanent equal-weight bars.
func _status_row(model: Dictionary, keys: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PrimaryStatusRow"
	UiMetrics.apply_separation(row, UiMetrics.SPACE_CONTROL)
	var care: Dictionary = model.get("care", {})
	# Below this width four names plus four percentages cannot share one row
	# without clipping, so the meters switch to their icon-and-value form.
	var narrow := logical_size.x / maxf(1.0, float(keys.size())) < NARROW_METER_WIDTH
	for key in keys:
		var meta: Array = STATUS_KEYS.get(str(key), [])
		if meta.is_empty():
			continue
		var value_bps := int(care.get(str(key), 0))
		row.add_child(PixelUi.stat_meter(
			str(key),
			application.text(str(meta[0]), str(meta[1]), locale),
			str(meta[2]),
			value_bps,
			_status_word(value_bps),
			narrow
		))
	return row


func _status_word(value_bps: int) -> String:
	if value_bps <= 2000:
		return application.text("ui.status.critical", "Dringend", locale)
	if value_bps <= 4500:
		return application.text("ui.status.low", "Niedrig", locale)
	if value_bps >= 9000:
		return application.text("ui.status.full", "Voll", locale)
	return application.text("ui.status.ok", "In Ordnung", locale)


## Every contextual state carries readable text, never colour or an icon alone.
func _alerts(model: Dictionary) -> Array:
	var result: Array = []
	if not model.get("injury", {}).is_empty():
		result.append({
			"id": "injury",
			"icon": "injury",
			"severity": "failure",
			"text": application.text("ui.alert.injury", "Verletzt · Behandlung nötig", locale),
		})
	if bool(model.get("sickness", false)):
		result.append({
			"id": "sickness",
			"icon": "sickness",
			"severity": "failure",
			"text": application.text("ui.alert.sick", "Krank · Medizin geben", locale),
		})
	var care: Dictionary = model.get("care", {})
	if int(care.get("health_bps", 10000)) <= 3500:
		result.append({
			"id": "health",
			"icon": "health",
			"severity": "failure",
			"text": application.text("ui.alert.health", "Gesundheit niedrig", locale),
		})
	if bool(model.get("sleeping", false)):
		result.append({
			"id": "sleeping",
			"icon": "sleep",
			"severity": "info",
			"text": application.text("ui.alert.sleeping", "Schläft · Energie erholt sich", locale),
		})
	for call in model.get("open_calls", []):
		result.append({
			"id": "call",
			"icon": "call",
			"severity": "notice",
			"text": application.text("call." + str(call.get("reason", "")), application.text("ui.alert.call", "Braucht Aufmerksamkeit", locale), locale),
		})
	if not model.get("active_battle", {}).is_empty():
		result.append({
			"id": "battle",
			"icon": "battle",
			"severity": "notice",
			"text": application.text("ui.alert.battle", "Kampf läuft", locale),
		})
	if not model.get("active_dungeon_run", {}).is_empty():
		result.append({
			"id": "dungeon",
			"icon": "dungeon",
			"severity": "notice",
			"text": application.text("ui.alert.dungeon", "Dungeon läuft", locale),
		})
	if not model.get("pending_evolution", {}).is_empty():
		result.append({
			"id": "evolution",
			"icon": "evolution",
			"severity": "success",
			"text": application.text("ui.pending_evolution", "Entwicklung wartet auf einen sicheren Moment", locale),
		})
	# Progressive onboarding rather than a tutorial modal: a brand new companion
	# gets one hint, and it disappears for good after the first care action.
	if result.is_empty() and bool(model.get("hatched", false)) and _is_first_session(model):
		result.append({
			"id": "first_care",
			"icon": "call",
			"severity": "info",
			"text": application.text("ui.hint.first_action", "Wähle unten eine Pflegeaktion", locale),
		})
	return result


func _is_first_session(model: Dictionary) -> bool:
	var aggregate: Dictionary = model.get("aggregate", {})
	for key in ["feed_count", "treat_count", "clean_count", "training_count", "treatment_count"]:
		if int(aggregate.get(key, 0)) > 0:
			return false
	return true


func _primary_alert(model: Dictionary) -> Dictionary:
	var alerts := _alerts(model)
	return alerts[0] if not alerts.is_empty() else {}


func _alert_row(model: Dictionary) -> HBoxContainer:
	var alerts := _alerts(model)
	if alerts.size() < 2:
		return null
	var row := HBoxContainer.new()
	row.name = "ContextualAlerts"
	UiMetrics.apply_separation(row, UiMetrics.SPACE_COMPACT)
	for index in range(1, mini(alerts.size(), 4)):
		var alert: Dictionary = alerts[index]
		row.add_child(PixelUi.alert_chip(str(alert["text"]), str(alert["icon"]), str(alert["severity"])))
	return row


## Three or four current primary actions. Contextual replacements (Wake,
## Medicine, Treatment) take the place of the action they supersede instead of
## being added as extra permanent buttons.
func _small_actions(model: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "QuickActions"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(row, UiMetrics.SPACE_CONTROL)
	for entry in _action_page(model):
		_add_primary_action(row, model, entry)
	return row


func _action_page(model: Dictionary) -> Array:
	var sleeping := bool(model.get("sleeping", false))
	match small_page:
		"adventure":
			var adventure: Array = []
			var in_battle: bool = not model.get("active_battle", {}).is_empty()
			var in_dungeon: bool = not model.get("active_dungeon_run", {}).is_empty()
			if bool(model.get("battle_unlocked", false)):
				# Advancing a running battle is a different intent from starting
				# one, so it keeps its own action id and stays enabled.
				adventure.append({
					"id": "battle_round" if in_battle else "battle",
					"icon": "attack" if in_battle else "battle",
					"text": application.text("ui.next_round", "Runde", locale) if in_battle else application.text("ui.battle", "Kampf", locale),
					"action": _battle_action,
				})
			if bool(model.get("dungeon_unlocked", false)):
				adventure.append({
					"id": "dungeon_next" if in_dungeon else "dungeon",
					"icon": "map" if in_dungeon else "dungeon",
					"text": application.text("ui.next_node", "Etappe", locale) if in_dungeon else application.text("ui.dungeon", "Dungeon", locale),
					"action": _dungeon_action,
				})
			adventure.append({
				"id": "expand",
				"icon": "expand",
				"text": application.text("ui.expanded", "Erweitert", locale),
				"action": _set_mode.bind(MODE_EXPANDED),
			})
			return adventure
		"more":
			var more: Array = [
				{"id": "treat", "icon": "treat", "text": application.text("ui.treat", "Leckerli", locale), "action": _treat},
				{
					"id": "wake" if sleeping else "sleep",
					"icon": "wake" if sleeping else "sleep",
					"text": application.text("ui.wake", "Aufwecken", locale) if sleeping else application.text("ui.sleep", "Schlafen", locale),
					"action": _sleep_or_wake.bind(sleeping),
				},
				{"id": "inventory", "icon": "inventory", "text": application.text("ui.inventory", "Inventar", locale), "action": _open_expanded_tab.bind("inventory")},
				{"id": "codex", "icon": "codex", "text": application.text("ui.codex", "Kodex", locale), "action": _open_expanded_tab.bind("codex")},
			]
			return more
		_:
			var care: Array = [{"id": "feed", "icon": "feed", "text": application.text("ui.feed", "Füttern", locale), "action": _feed}]
			if not model.get("injury", {}).is_empty():
				care.append({"id": "treat_injury", "icon": "treatment", "text": application.text("ui.treat_injury", "Behandeln", locale), "action": _treat_injury})
			elif bool(model.get("sickness", false)):
				care.append({"id": "medicine", "icon": "medicine", "text": application.text("ui.medicine", "Medizin", locale), "action": _medicine})
			else:
				care.append({"id": "clean", "icon": "clean", "text": application.text("ui.clean", "Reinigen", locale), "action": _clean})
			if sleeping:
				care.append({"id": "wake", "icon": "wake", "text": application.text("ui.wake", "Aufwecken", locale), "action": _sleep_or_wake.bind(true)})
			else:
				care.append({"id": "train", "icon": "train", "text": application.text("ui.train", "Trainieren", locale), "action": _train})
			return care


func _add_primary_action(parent: Container, model: Dictionary, entry: Dictionary) -> void:
	var action_id := str(entry.get("id", ""))
	var value := PixelUi.primary_action(str(entry.get("text", "")), str(entry.get("icon", "call")), str(entry.get("text", "")))
	value.name = "Action_" + action_id
	value.set_meta("action_id", action_id)
	var hint := ActionFeedback.unavailable_hint(action_id, model)
	if not hint.is_empty():
		value.disabled = true
		value.tooltip_text = application.text(str(hint["key"]), str(hint["fallback"]), locale)
		value.set_meta("accessible_label", value.tooltip_text)
	elif command_in_flight:
		value.disabled = true
	_connect_pressed(value, entry.get("action", Callable()))
	parent.add_child(value)


## Footer navigation. Never icon-only, and adventure stays hidden until a gate
## actually unlocks it.
func _small_navigation(model: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SmallNavigation"
	UiMetrics.apply_separation(row, UiMetrics.SPACE_COMPACT)
	var pages: Array = [["care", "ui.care", "Pflege", "health"]]
	if bool(model.get("battle_unlocked", false)) or bool(model.get("dungeon_unlocked", false)):
		pages.append(["adventure", "ui.adventure", "Abenteuer", "battle"])
	pages.append(["more", "ui.more", "Mehr", "inventory"])
	for page in pages:
		var button := PixelUi.nav_button(application.text(str(page[1]), str(page[2]), locale), str(page[3]), small_page == str(page[0]))
		button.name = "Nav_" + str(page[0])
		_connect_pressed(button, _set_small_page.bind(str(page[0])))
		row.add_child(button)
	return row


func _build_expanded(model: Dictionary) -> void:
	var shell := _window_shell(model)
	var body := HBoxContainer.new()
	body.name = "ExpandedBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(body, UiMetrics.SPACE_CONTROL)
	shell.add_child(body)
	body.add_child(_expanded_status(model))
	body.add_child(_expanded_center(model))
	body.add_child(_expanded_context(model))


func _expanded_status(model: Dictionary) -> PanelContainer:
	var panel := PixelUi.panel(true)
	panel.name = "ExpandedStatus"
	panel.custom_minimum_size = Vector2(268, 0)
	var column := VBoxContainer.new()
	UiMetrics.apply_separation(column, UiMetrics.SPACE_CONTROL)
	panel.add_child(column)
	column.add_child(PixelUi.title(application.text("ui.stats", "Pflegeprotokoll", locale), UiMetrics.TEXT_PANEL_TITLE))
	var care: Dictionary = model.get("care", {})
	for key in ["satiety_bps", "mood_bps", "energy_bps", "hygiene_bps", "health_bps", "discipline_bps"]:
		var meta: Array = STATUS_KEYS[key]
		var value_bps := int(care.get(key, 0))
		column.add_child(PixelUi.stat_meter(key, application.text(str(meta[0]), str(meta[1]), locale), str(meta[2]), value_bps, _status_word(value_bps)))
	column.add_child(HSeparator.new())
	var facts := GridContainer.new()
	facts.name = "ExpandedFacts"
	facts.columns = 2
	UiMetrics.apply_grid_separation(facts, UiMetrics.SPACE_COMPACT)
	column.add_child(facts)
	for fact in [
		[application.text("ui.experience", "Erfahrung", locale), "%d / %d" % [int(model.get("experience", 0)), int(model.get("experience_next", 0))]],
		[application.text("ui.weight", "Gewicht", locale), "%.2f kg" % (float(care.get("weight_grams", 0)) / 1000.0)],
		[application.text("ui.waste", "Abfall", locale), str(int(care.get("waste_count", 0)))],
		[application.text("ui.care_mistakes", "Pflegefehler", locale), str(int(model.get("aggregate", {}).get("care_mistakes", 0)))],
	]:
		var fact_label := PixelUi.caption(str(fact[0]))
		fact_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		facts.add_child(fact_label)
		# An ellipsis overrun makes a Label's minimum width collapse, so the
		# value column needs an explicit reservation to stay visible.
		var value_label := PixelUi.caption(str(fact[1]))
		value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		value_label.custom_minimum_size = Vector2(88, 0)
		value_label.add_theme_color_override("font_color", PixelTheme.PARCHMENT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		facts.add_child(value_label)
	var alerts := _alerts(model)
	if not alerts.is_empty():
		column.add_child(HSeparator.new())
		for alert in alerts.slice(0, 4):
			column.add_child(PixelUi.alert_chip(str(alert["text"]), str(alert["icon"]), str(alert["severity"])))
	return panel


func _expanded_center(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "ExpandedCenter"
	column.custom_minimum_size = Vector2(420, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(column, UiMetrics.SPACE_CONTROL)
	var frame := HabitatFrame.new()
	frame.name = "ExpandedHabitatFrame"
	frame.set_expand_vertical(false)
	frame.attach(_habitat(model))
	active_habitat_frame = frame
	column.add_child(frame)
	var tabs := HBoxContainer.new()
	tabs.name = "ExpandedTabs"
	UiMetrics.apply_separation(tabs, UiMetrics.SPACE_MICRO)
	for entry in _expanded_tabs(model):
		var tab := PixelUi.tab(application.text(str(entry[1]), str(entry[2]), locale), expanded_tab == str(entry[0]))
		tab.name = "Tab_" + str(entry[0])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_connect_pressed(tab, _set_expanded_tab.bind(str(entry[0])))
		tabs.add_child(tab)
	column.add_child(tabs)
	var detail := PixelUi.panel(true)
	detail.name = "ExpandedDetail"
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 0.9
	column.add_child(detail)
	match _resolved_expanded_tab(model):
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


## Battle and Dungeon stay absent until their data-driven gate opens.
func _expanded_tabs(model: Dictionary) -> Array:
	var entries: Array = [["home", "ui.home", "Übersicht"]]
	if bool(model.get("battle_unlocked", false)):
		entries.append(["battle", "ui.battle", "Kampf"])
	if bool(model.get("dungeon_unlocked", false)):
		entries.append(["dungeon", "ui.dungeon", "Dungeon"])
	entries.append(["inventory", "ui.inventory", "Inventar"])
	entries.append(["codex", "ui.codex", "Kodex"])
	entries.append(["evolution", "ui.evolution", "Entwicklung"])
	return entries


func _resolved_expanded_tab(model: Dictionary) -> String:
	for entry in _expanded_tabs(model):
		if str(entry[0]) == expanded_tab:
			return expanded_tab
	return "home"


## The right column follows the selected tab. It never shows every panel at
## once, and it never leaves a large empty area behind.
func _expanded_context(model: Dictionary) -> PanelContainer:
	var panel := PixelUi.panel(true)
	panel.name = "ExpandedActions"
	panel.custom_minimum_size = Vector2(268, 0)
	var column := VBoxContainer.new()
	UiMetrics.apply_separation(column, UiMetrics.SPACE_CONTROL)
	panel.add_child(column)
	var tab := _resolved_expanded_tab(model)
	column.add_child(PixelUi.title(_context_title(tab), UiMetrics.TEXT_PANEL_TITLE))
	var actions := _context_actions(tab, model)
	for entry in actions:
		_add_context_action(column, model, entry)
	# A tab without its own actions still owes the player an explanation and a
	# progress read, otherwise the column is a heading above empty space.
	var summary := _context_summary(tab, model)
	if not summary.is_empty():
		column.add_child(PixelUi.body(summary))
	column.add_child(HSeparator.new())
	column.add_child(PixelUi.title(_context_detail_title(tab), UiMetrics.TEXT_CAPTION))
	column.add_child(_context_detail(tab, model))
	return panel


## Short progress read for the tabs that carry no direct action of their own.
func _context_summary(tab: String, model: Dictionary) -> String:
	match tab:
		"inventory":
			var inventory: Dictionary = model.get("inventory", {})
			var total := 0
			for item_id in inventory:
				total += int(inventory[item_id])
			if inventory.is_empty():
				return application.text("ui.inventory_empty", "Noch keine Gegenstände gesammelt.", locale)
			return application.text("ui.inventory_summary", "{kinds} Arten · {total} Stück", locale).replace("{kinds}", str(inventory.size())).replace("{total}", str(total))
		"codex":
			var codex: Dictionary = model.get("codex", {})
			return application.text("ui.codex_summary", "{forms} Formen · {encounters} Gegner entdeckt", locale) 				.replace("{forms}", str(codex.get("forms", []).size())) 				.replace("{encounters}", str(codex.get("encounters", []).size()))
		"evolution":
			if not model.get("pending_evolution", {}).is_empty():
				return application.text("ui.pending_evolution", "Entwicklung wartet auf einen sicheren Moment", locale)
			var candidates: Array = model.get("evolution", {}).get("candidates", [])
			if candidates.is_empty():
				return application.text("ui.evolution_hint", "Pflege und Training bestimmen den nächsten Weg.", locale)
			return application.text("ui.evolution_candidates", "{count} mögliche Wege", locale).replace("{count}", str(candidates.size()))
		_:
			return ""


func _context_title(tab: String) -> String:
	match tab:
		"battle":
			return application.text("ui.battle", "Kampf", locale)
		"dungeon":
			return application.text("ui.dungeon", "Dungeon", locale)
		"inventory":
			return application.text("ui.inventory", "Inventar", locale)
		"codex":
			return application.text("ui.codex", "Kodex", locale)
		"evolution":
			return application.text("ui.evolution", "Entwicklung", locale)
		_:
			return application.text("ui.actions", "Aktionen", locale)


func _context_detail_title(tab: String) -> String:
	if tab in ["battle", "dungeon"]:
		return application.text("ui.objective", "Aktuelles Ziel", locale)
	return application.text("ui.history", "Letzte Ereignisse", locale)


func _context_actions(tab: String, model: Dictionary) -> Array:
	var sleeping := bool(model.get("sleeping", false))
	match tab:
		"battle":
			var battle: Array = []
			if model.get("active_battle", {}).is_empty():
				battle.append({"id": "battle", "icon": "battle", "text": application.text("ui.start_battle", "Kampf beginnen", locale), "action": _start_battle})
			else:
				battle.append({"id": "battle_round", "icon": "attack", "text": application.text("ui.next_round", "Runde ausführen", locale), "action": _battle_round})
			if not model.get("injury", {}).is_empty():
				battle.append({"id": "treat_injury", "icon": "treatment", "text": application.text("ui.treat_injury", "Behandeln", locale), "action": _treat_injury})
			return battle
		"dungeon":
			if model.get("active_dungeon_run", {}).is_empty():
				return [{"id": "dungeon", "icon": "dungeon", "text": application.text("ui.start_dungeon", "Dungeon beginnen", locale), "action": _start_dungeon}]
			if not model.get("active_battle", {}).is_empty():
				return [{"id": "battle_round", "icon": "attack", "text": application.text("ui.next_round", "Runde ausführen", locale), "action": _battle_round}]
			if _dungeon_awaits_choice(model):
				return []
			return [{"id": "dungeon_next", "icon": "map", "text": application.text("ui.next_node", "Nächste Etappe", locale), "action": _dungeon_next}]
		"evolution":
			return []
		"inventory", "codex":
			return []
		_:
			var care: Array = [
				{"id": "feed", "icon": "feed", "text": application.text("ui.feed", "Füttern", locale), "action": _feed},
				{"id": "treat", "icon": "treat", "text": application.text("ui.treat", "Leckerli", locale), "action": _treat},
				{"id": "clean", "icon": "clean", "text": application.text("ui.clean", "Reinigen", locale), "action": _clean},
				{"id": "train", "icon": "train", "text": application.text("ui.train", "Trainieren", locale), "action": _train},
				{
					"id": "wake" if sleeping else "sleep",
					"icon": "wake" if sleeping else "sleep",
					"text": application.text("ui.wake", "Aufwecken", locale) if sleeping else application.text("ui.sleep", "Schlafen", locale),
					"action": _sleep_or_wake.bind(sleeping),
				},
			]
			if bool(model.get("sickness", false)):
				care.append({"id": "medicine", "icon": "medicine", "text": application.text("ui.medicine", "Medizin", locale), "action": _medicine})
			if not model.get("injury", {}).is_empty():
				care.append({"id": "treat_injury", "icon": "treatment", "text": application.text("ui.treat_injury", "Behandeln", locale), "action": _treat_injury})
			if not model.get("open_calls", []).is_empty():
				care.append({"id": "resolve_call", "icon": "call", "text": application.text("ui.resolve", "Erledigen", locale), "action": _resolve_first_call})
			return care


func _add_context_action(parent: Container, model: Dictionary, entry: Dictionary) -> void:
	var action_id := str(entry.get("id", ""))
	var value := PixelUi.button(str(entry.get("text", "")), str(entry.get("icon", "call")), str(entry.get("text", "")))
	value.name = "Context_" + action_id
	value.set_meta("action_id", action_id)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := ActionFeedback.unavailable_hint(action_id, model)
	if not hint.is_empty():
		value.disabled = true
		value.tooltip_text = application.text(str(hint["key"]), str(hint["fallback"]), locale)
		value.set_meta("accessible_label", value.tooltip_text)
	elif command_in_flight:
		value.disabled = true
	_connect_pressed(value, entry.get("action", Callable()))
	parent.add_child(value)


func _context_detail(tab: String, model: Dictionary) -> Control:
	if tab == "battle":
		return PixelUi.body(_battle_objective(model))
	if tab == "dungeon":
		return PixelUi.body(_dungeon_objective(model))
	var scroll := ScrollContainer.new()
	scroll.name = "ExpandedEventHistory"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(column, UiMetrics.SPACE_MICRO)
	scroll.add_child(column)
	var history: Array = model.get("history", [])
	if history.is_empty():
		column.add_child(PixelUi.event_log_entry(application.text("ui.history.empty", "Noch keine Ereignisse", locale)))
		return scroll
	for index in range(history.size() - 1, maxi(-1, history.size() - 13), -1):
		var entry: Dictionary = history[index]
		column.add_child(PixelUi.event_log_entry(_event_label(str(entry.get("type", "")))))
	return scroll


func _battle_objective(model: Dictionary) -> String:
	var battle: Dictionary = model.get("active_battle", {})
	if battle.is_empty():
		if not bool(model.get("battle_unlocked", false)):
			return application.text("feedback.locked", "Das ist noch nicht freigeschaltet.", locale)
		return application.text("ui.battle_objective_idle", "Wähle eine Haltung und beginne einen kurzen Kampf.", locale)
	var encounter := application.get_encounter_presentation(str(battle.get("encounter_id", "")), locale)
	return "%s · %s %d\n%s %d\n%s  %d/%d\n%s  %d/%d" % [
		str(encounter.get("name", "")),
		application.text("ui.level", "Stufe", locale),
		int(encounter.get("level", 1)),
		application.text("ui.round", "Runde", locale),
		int(battle.get("current_round", 0)) + 1,
		str(model.get("name", "")),
		int(battle.get("pet_transient_hp", 0)),
		int(battle.get("pet_transient_max_hp", 0)),
		str(encounter.get("name", "")),
		int(battle.get("opponent_transient_hp", 0)),
		int(battle.get("opponent_transient_max_hp", 0)),
	]


## True while the player is standing on a branch node and must pick a route.
func _dungeon_awaits_choice(model: Dictionary) -> bool:
	var run: Dictionary = model.get("active_dungeon_run", {})
	if run.is_empty():
		return false
	var dungeon := application.get_dungeon_presentation(str(run.get("dungeon_id", "")), locale)
	var nodes: Array = dungeon.get("nodes", [])
	var current := int(run.get("current_node", -1))
	return current >= 0 and current < nodes.size() and str(nodes[current].get("kind", "")) == "event"


func _dungeon_objective(model: Dictionary) -> String:
	var run: Dictionary = model.get("active_dungeon_run", {})
	if run.is_empty():
		if not bool(model.get("dungeon_unlocked", false)):
			return application.text("feedback.locked", "Das ist noch nicht freigeschaltet.", locale)
		return application.text("ui.dungeon_objective_idle", "Ein Dungeon ist eine kurze Folge aus Kämpfen, Ereignissen und einem Boss.", locale)
	return "%s %d\n%s" % [
		application.text("ui.next_node", "Nächste Etappe", locale),
		int(run.get("current_node", 0)) + 1,
		application.text("ui.dungeon", "Dungeon", locale),
	]


func _home_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "HomePanel"
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(column, UiMetrics.SPACE_CONTROL)
	column.add_child(PixelUi.title(_state_line(model), UiMetrics.TEXT_PANEL_TITLE))
	column.add_child(PixelUi.body(_contextual_hint(model)))
	column.add_child(HSeparator.new())
	var aggregate: Dictionary = model.get("aggregate", {})
	var grid := GridContainer.new()
	grid.name = "HomeSummary"
	grid.columns = 3
	UiMetrics.apply_grid_separation(grid, UiMetrics.SPACE_CONTROL)
	column.add_child(grid)
	for entry in [
		["ui.feed", "Füttern", "feed", int(aggregate.get("feed_count", 0))],
		["ui.treat", "Leckerli", "treat", int(aggregate.get("treat_count", 0))],
		["ui.train", "Trainieren", "train", int(aggregate.get("training_count", 0))],
		["ui.clean", "Reinigen", "clean", int(aggregate.get("clean_count", 0))],
		["ui.medicine", "Medizin", "medicine", int(aggregate.get("treatment_count", 0))],
		["ui.calls", "Aufmerksamkeitsrufe", "call", int(aggregate.get("resolved_calls", 0))],
		["ui.care_mistakes", "Pflegefehler", "injury", int(aggregate.get("care_mistakes", 0))],
		["ui.battle", "Kampf", "battle", int(model.get("battle_history", {}).get("battle_count", 0))],
	]:
		grid.add_child(_summary_tile(application.text(str(entry[0]), str(entry[1]), locale), str(entry[2]), int(entry[3])))
	column.add_child(HSeparator.new())
	column.add_child(PixelUi.caption(application.text("ui.discovered_route", "Entdeckte Route", locale)))
	var route := HBoxContainer.new()
	route.name = "DiscoveredRoute"
	UiMetrics.apply_separation(route, UiMetrics.SPACE_COMPACT)
	column.add_child(route)
	for form_id in model.get("discovered_forms", []):
		var chip := PixelUi.panel(true)
		var chip_row := HBoxContainer.new()
		chip.add_child(chip_row)
		var chip_portrait := _portrait(str(form_id), 32)
		if chip_portrait != null:
			chip_row.add_child(chip_portrait)
		chip_row.add_child(PixelUi.caption(application.get_display_name(str(form_id), locale)))
		route.add_child(chip)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	return column


func _summary_tile(label_text: String, icon_name: String, value: int) -> PanelContainer:
	var tile := PixelUi.panel(true)
	tile.set_meta("component", "summary_tile")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	UiMetrics.apply_separation(row, UiMetrics.SPACE_COMPACT)
	tile.add_child(row)
	row.add_child(PixelUi.icon_rect(icon_name, UiMetrics.ICON_STATUS))
	var text := PixelUi.caption(label_text)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(text)
	var number := PixelUi.caption(str(value))
	number.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	number.add_theme_color_override("font_color", PixelTheme.PARCHMENT)
	row.add_child(number)
	tile.tooltip_text = "%s: %d" % [label_text, value]
	return tile


## One short contextual hint instead of a tutorial modal sequence. It follows
## the pet's current need, so a new player always has a next step on screen.
func _contextual_hint(model: Dictionary) -> String:
	if not model.get("injury", {}).is_empty():
		return application.text("feedback.state.injured", "Erst die Verletzung behandeln.", locale)
	if bool(model.get("sickness", false)):
		return application.text("feedback.state.sick", "Zu krank dafür. Erst Medizin geben.", locale)
	var care: Dictionary = model.get("care", {})
	for key in ["satiety_bps", "mood_bps", "energy_bps", "hygiene_bps"]:
		if int(care.get(key, 10000)) <= 3500:
			var meta: Array = STATUS_KEYS[key]
			return "%s: %s" % [application.text(str(meta[0]), str(meta[1]), locale), application.text("ui.status.low", "Niedrig", locale)]
	if bool(model.get("battle_unlocked", false)) and int(model.get("battle_history", {}).get("battle_count", 0)) == 0:
		return application.text("ui.hint.adventure_unlocked", "Abenteuer ist freigeschaltet.", locale)
	return application.text("ui.hint.first_care", "Halte Sättigung, Stimmung, Energie und Hygiene im grünen Bereich.", locale)


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
		column.add_child(PixelUi.caption(application.text("ui.battle_hint", "Der Kampf startet über die Aktionsspalte.", locale), true))
		return column
	var encounter := application.get_encounter_presentation(str(battle.get("encounter_id", "")), locale)
	column.add_child(PixelUi.title("%s · %s %d" % [str(encounter.get("name", "")), application.text("ui.level", "Stufe", locale), int(encounter.get("level", 1))], 15))
	var hp := Label.new()
	hp.text = "%s HP %d/%d  ·  %s HP %d/%d  ·  R%d" % [model.get("name", "Pet"), int(battle.get("pet_transient_hp", 0)), int(battle.get("pet_transient_max_hp", 0)), encounter.get("name", "Opponent"), int(battle.get("opponent_transient_hp", 0)), int(battle.get("opponent_transient_max_hp", 0)), int(battle.get("current_round", 0)) + 1]
	column.add_child(hp)
	var stances := HBoxContainer.new()
	stances.name = "BattleStances"
	UiMetrics.apply_separation(stances, UiMetrics.SPACE_COMPACT)
	column.add_child(stances)
	for stance in ["aggressive", "balanced", "defensive"]:
		var stance_button := PixelUi.battle_stance_control(application.text("ui." + stance, stance.capitalize(), locale), "attack" if stance == "aggressive" else "shield" if stance == "defensive" else "health")
		stance_button.name = "Stance_" + stance
		stance_button.button_pressed = str(battle.get("selected_stance", "balanced")) == stance
		_connect_pressed(stance_button, _set_battle_stance.bind(stance))
		stances.add_child(stance_button)
	column.add_child(_battle_log(model, battle))
	return column


## What actually happened in the last rounds. Without it a resolved round only
## moves two numbers, and the player cannot tell a miss from a weak hit.
func _battle_log(model: Dictionary, battle: Dictionary) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "BattleLog"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiMetrics.apply_separation(column, UiMetrics.SPACE_MICRO)
	scroll.add_child(column)
	var log: Array = battle.get("turn_event_log", []) if battle.get("turn_event_log", []) is Array else []
	if log.is_empty():
		column.add_child(PixelUi.caption(application.text("ui.battle_log_empty", "Noch keine Runde ausgeführt.", locale), true))
		return scroll
	var encounter := application.get_encounter_presentation(str(battle.get("encounter_id", "")), locale)
	var pet_name := str(model.get("name", ""))
	var enemy_name := str(encounter.get("name", ""))
	for index in range(log.size() - 1, maxi(-1, log.size() - 9), -1):
		var event: Variant = log[index]
		if not event is Dictionary:
			continue
		var entry: Dictionary = event
		var actor := pet_name if str(entry.get("actor", "pet")) == "pet" else enemy_name
		var line := ""
		if str(entry.get("result", "")) == "hit":
			line = application.text("ui.battle_hit", "R{round} · {actor} trifft für {amount}", locale) 				.replace("{round}", str(int(entry.get("round", 0)))) 				.replace("{actor}", actor) 				.replace("{amount}", str(int(entry.get("amount", 0))))
		else:
			line = application.text("ui.battle_miss", "R{round} · {actor} verfehlt", locale) 				.replace("{round}", str(int(entry.get("round", 0)))) 				.replace("{actor}", actor)
		column.add_child(PixelUi.event_log_entry(line))
	return scroll


func _dungeon_panel(model: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	var dungeons := application.get_dungeons()
	if dungeons.is_empty():
		column.add_child(PixelUi.caption(application.text("ui.dungeon_none", "Noch kein Dungeon verfügbar.", locale), true))
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
	# Starting the run and advancing it live in the contextual action column.
	# Only the branch choices are unique to this panel, because each one is a
	# different command rather than a repeat of the column's action.
	if run.is_empty():
		column.add_child(PixelUi.caption(application.text("ui.dungeon_hint", "Der Aufbruch startet über die Aktionsspalte.", locale), true))
		return column
	if not model.get("active_battle", {}).is_empty():
		column.add_child(PixelUi.body(application.text("ui.dungeon_battle_active", "Diese Etappe wird im Kampf entschieden.", locale)))
		return column
	var nodes: Array = dungeon.get("nodes", [])
	if current >= 0 and current < nodes.size() and str(nodes[current].get("kind", "")) == "event":
		column.add_child(PixelUi.caption(application.text("ui.choose_route", "Route wählen", locale)))
		for choice in nodes[current].get("choices", []):
			var choice_button := PixelUi.button(str(choice.get("name", choice.get("id", ""))), "mood")
			choice_button.name = "DungeonChoice_" + str(choice.get("id", ""))
			choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_connect_pressed(choice_button, _dungeon_choice.bind(str(choice.get("id", ""))))
			column.add_child(choice_button)
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
	var events := animation_controller.drain_pending()
	var animations := application.get_animation_descriptors()
	habitat.configure_pet(animations, animation_controller.effective_loop(model), {
		"reduced_motion": reduced_motion,
		"ambient_roaming": bool(preferences.get("pet_presentation", {}).get("ambient_roaming", true)),
		"ambient_frequency": str(preferences.get("pet_presentation", {}).get("ambient_animation_frequency", "normal")),
		"pet_scale": float(preferences.get("pet_presentation", {}).get("standard_pet_scale", 1.0)),
		"animation_speed": _animation_speed(),
		"walking_speed": _walking_speed(),
		"effects_intensity": str(preferences.get("pet_presentation", {}).get("effects_intensity", "normal")),
		"hit_shake": bool(preferences.get("pet_presentation", {}).get("hit_shake", true)),
		"damage_flash": bool(preferences.get("pet_presentation", {}).get("damage_flash", true)),
		"family_id": str(model.get("family_id", "")),
		"ambient_seed": maxi(1, str(model.get("form_id", "pet")).hash()),
	})
	var battle: Dictionary = model.get("active_battle", {})
	if not battle.is_empty():
		var encounter_id := str(battle.get("encounter_id", ""))
		habitat.set_opponent_animations(application.get_animation_descriptors(encounter_id), encounter_id)
	else:
		for event in events:
			var encounter_id := str(event.get("payload", {}).get("encounter_id", ""))
			if not encounter_id.is_empty():
				habitat.set_opponent_animations(application.get_animation_descriptors(encounter_id), encounter_id)
				break
	if not events.is_empty():
		habitat.start_sequence(events)
	habitat.show_call(_call_icon(model))
	habitat.set_trophy_visible("koalapet.base:boss_memory_gate" in model.get("unlock_ids", []))


func _animation_for(model: Dictionary) -> String:
	if not transient_animation.is_empty():
		return transient_animation
	if not model.get("active_battle", {}).is_empty():
		return "idle"
	if not model.get("injury", {}).is_empty():
		return "injured"
	if bool(model.get("sickness", false)):
		return "sick"
	if bool(model.get("sleeping", false)):
		return "sleep_loop"
	if not model.get("open_calls", []).is_empty():
		return "call"
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
	mode_switch_requests += 1
	last_mode_request = value
	if value not in [MODE_MINIMAL, MODE_SMALL, MODE_EXPANDED] or value == mode:
		return
	if value == MODE_MINIMAL and not application.has_pet():
		# Refused with a readable reason rather than silently ignored.
		last_feedback = {
			"key": "feedback.minimal_needs_pet",
			"fallback": "Minimal zeigt nur deinen Gefährten. Wähle zuerst ein Ei.",
			"severity": ActionFeedback.SEVERITY_BLOCKED,
			"icon": "minimal",
		}
		_refresh()
		return
	mode_switch_applied += 1
	_save_window_placement()
	mode = value
	_apply_window_mode()
	_refresh()


func _apply_window_mode() -> void:
	get_viewport().transparent_bg = true
	var mode_value := _mode_value(mode)
	var text_scale := float(preferences.get("interface", {}).get("text_scale", 1.0))
	var presentation_scale := resolved_ui_scale if mode != MODE_MINIMAL else 1.0
	var rendered_size := _target_window_size(mode_value, text_scale, presentation_scale)
	if window_adapter.is_host_supported():
		mode_controller.transition_to(mode_value)
		var native_bounds := WindowPresentationMode.scaled_bounds(mode_value, presentation_scale, text_scale)
		window_adapter.set_size_bounds(native_bounds["minimum"], native_bounds["maximum"])
		window_adapter.set_size(rendered_size)
		window_adapter.set_transparency(true)
		window_adapter.set_always_on_top(bool(preferences.get("desktop", {}).get("always_on_top", true)))
		if mode == MODE_MINIMAL:
			window_adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NO_FOCUS)
			window_adapter.set_input_policy(DesktopWindowAdapter.INPUT_HIT_REGION if bool(preferences.get("desktop", {}).get("minimal_click_through", true)) else DesktopWindowAdapter.INPUT_INTERACTIVE)
		else:
			window_adapter.set_focus_policy(DesktopWindowAdapter.FOCUS_NORMAL)
			window_adapter.set_input_policy(DesktopWindowAdapter.INPUT_INTERACTIVE)
	requested_window_size = rendered_size
	applied_presentation_scale = presentation_scale
	applied_reference_size = WindowPresentationMode.scaled_size(mode_value, presentation_scale, text_scale, _minimal_pet_scale())
	_apply_presentation_extent(rendered_size, presentation_scale)
	root_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE if mode == MODE_MINIMAL else Control.MOUSE_FILTER_PASS
	# The main window can still be resized by the engine boot sequence after the
	# scene's `_ready`, so the requested extent is confirmed on the next frame.
	call_deferred("_confirm_window_size")


func _confirm_window_size() -> void:
	if window_adapter == null or not window_adapter.is_host_supported():
		return
	if requested_window_size.x <= 0 or requested_window_size.y <= 0:
		return
	if get_window().size == requested_window_size:
		return
	window_adapter.set_size(requested_window_size)
	_apply_presentation_extent(get_window().size, resolved_ui_scale if mode != MODE_MINIMAL else 1.0)


## Resolves the physical window size for the mode: the remembered resizable size
## when there is one, otherwise the scaled mode default.
func _target_window_size(mode_value: int, text_scale: float, presentation_scale: float) -> Vector2i:
	if not WindowPresentationMode.is_user_resizable(mode_value):
		return WindowPresentationMode.scaled_size(mode_value, presentation_scale, text_scale, _minimal_pet_scale())
	var bounds := WindowPresentationMode.scaled_bounds(mode_value, presentation_scale, text_scale)
	var reference: Vector2i = bounds["reference"]
	var remembered := mode_controller.remembered_size(mode_value) if mode_controller != null else Vector2i.ZERO
	if remembered.x <= 0 or remembered.y <= 0:
		remembered = reference
	elif applied_reference_size.x > 0 and applied_reference_size.y > 0 and applied_reference_size != reference:
		# Raising the UI or text scale must enlarge the window rather than
		# squeeze the same content into it. At half growth a 150% text scale
		# pushed the window controls past the right edge, so the remembered size
		# follows the full reference change on both axes.
		remembered = Vector2i(
			roundi(float(remembered.x) * float(reference.x) / maxf(1.0, float(applied_reference_size.x))),
			roundi(float(remembered.y) * float(reference.y) / maxf(1.0, float(applied_reference_size.y)))
		)
	var minimum: Vector2i = bounds["minimum"]
	var maximum: Vector2i = bounds["maximum"]
	return Vector2i(
		clampi(remembered.x, minimum.x, maxi(minimum.x, maximum.x)),
		clampi(remembered.y, minimum.y, maxi(minimum.y, maximum.y))
	)


## Keeps the render viewport, the presentation layers and the native client area
## on one pixel grid. Without this a live scale or resize change enlarges only
## the native window and leaves the previous Control viewport clipped.
func _apply_presentation_extent(rendered_size: Vector2i, presentation_scale: float) -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# `content_scale_size` must stay unset. A non-zero override pins the root
	# viewport, which in turn pinned the native window: the client area kept the
	# project's boot size and a user drag on the border snapped straight back.
	get_window().content_scale_size = Vector2i.ZERO
	logical_size = (Vector2(rendered_size) / maxf(0.01, presentation_scale)).floor()
	for layer in [root_layer, notification_layer]:
		layer.anchor_right = 0.0
		layer.anchor_bottom = 0.0
		layer.position = Vector2.ZERO
		layer.scale = Vector2.ONE * presentation_scale
		layer.size = logical_size


func _on_window_size_changed() -> void:
	if window_adapter == null or not window_adapter.is_host_supported():
		return
	if mode == MODE_MINIMAL:
		return
	var presentation_scale := resolved_ui_scale
	var rendered_size := get_window().size
	if Vector2(rendered_size) / maxf(0.01, presentation_scale) == logical_size:
		return
	var previous_narrow := _status_row_is_narrow()
	_apply_presentation_extent(rendered_size, presentation_scale)
	# Godot containers reflow on their own, so a drag normally needs no rebuild
	# and therefore never restarts an animation. The one exception is crossing
	# the width where the status row has to drop its labels.
	if _status_row_is_narrow() != previous_narrow:
		_refresh()
	_save_window_placement()


func _status_row_is_narrow() -> bool:
	return logical_size.x / 4.0 < NARROW_METER_WIDTH


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
	minimal_hit_region_updates += 1


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


## Small mode reaches management surfaces by switching to Expanded on that tab
## instead of duplicating the whole panel inside the compact window.
func _open_expanded_tab(value: String) -> void:
	expanded_tab = value
	_set_mode(MODE_EXPANDED)


func _quit_game() -> void:
	_save_window_placement()
	get_tree().quit()


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
		if bool(preferences.get("pet_presentation", {}).get("cursor_reaction", true)) and minimal_animations.has("attention"):
			minimal_moving = false
			minimal_open_pending = true
			minimal_action_kind = "click"
			minimal_action_remaining = 0.18 if reduced_motion else 0.55
			_minimal_set_animation("attention")
		else:
			_set_mode(MODE_SMALL)


func _minimize() -> void:
	if window_adapter.is_host_supported():
		window_adapter.minimize_window()


func _show_notification(text_value: String, severity := ActionFeedback.SEVERITY_SUCCESS, icon_name := "call") -> void:
	_clear(notification_layer)
	notification_revision += 1
	var revision := notification_revision
	var notice := PixelUi.reward_notification(text_value, severity, icon_name)
	notice.name = "StatusToast"
	var width := clampf(logical_size.x - 48.0, 200.0, 380.0)
	notice.size = Vector2(width, 0)
	# Placed over the upper habitat, which is the one region both modes keep free
	# of controls: clear of the header, the status row, the tab row and the
	# action/footer rows. It is fully click-through, so it can never swallow the
	# next action even while it is fading.
	var text_scale := clampf(float(preferences.get("interface", {}).get("text_scale", 1.0)), 1.0, 1.75)
	var band := (130.0 if mode == MODE_SMALL else 92.0) * text_scale
	notice.position = Vector2(
		floorf((logical_size.x - width) * 0.5),
		clampf(band, 72.0, maxf(72.0, logical_size.y - 200.0))
	)
	notification_layer.add_child(notice)
	_remove_notification_later(revision)


func _show_feedback(feedback: Dictionary) -> void:
	if feedback.is_empty():
		return
	_show_notification(
		application.text(str(feedback.get("key", "")), str(feedback.get("fallback", "")), locale),
		str(feedback.get("severity", ActionFeedback.SEVERITY_SUCCESS)),
		str(feedback.get("icon", "call"))
	)


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
	if command_in_flight:
		suppressed_duplicate_commands += 1
		return
	command_in_flight = true
	var result := application.choose_starter(egg_id)
	command_in_flight = false
	if result.get("ok", false):
		mode = MODE_SMALL
		_apply_window_mode()
	last_feedback = ActionFeedback.describe("choose_starter", result)
	if result.get("ok", false):
		last_feedback = {
			"key": "feedback.starter.ok",
			"fallback": "Dein Ei wird warm. Gleich schlüpft es.",
			"severity": ActionFeedback.SEVERITY_SUCCESS,
			"icon": "egg",
		}
	_refresh()


func _complete_hatch() -> void:
	_command({"type": "complete_hatch"}, "happy", "idle_center", "idle", "", "care")


func _feed() -> void:
	_command({"type": "feed", "item_id": application.find_item_by_kind("meal")}, "eat", "feeding_bowl")


func _treat() -> void:
	_command({"type": "feed", "item_id": application.find_item_by_kind("treat")}, "treat", "treat_position")


func _clean() -> void:
	_command({"type": "clean"}, "clean", "bath")


func _train() -> void:
	_command({"type": "train", "activity_id": application.get_training_activity_id(), "input_bps": 5000}, "training", "training")


func _medicine() -> void:
	_command({"type": "medicine", "item_id": application.find_item_by_kind("medicine")}, "medicine", "medicine")


func _treat_injury() -> void:
	_command({"type": "treat_injury", "item_id": application.find_item_by_kind("injury_treatment")}, "treatment", "medicine")


func _sleep_or_wake(sleeping: bool) -> void:
	_command({"type": "wake" if sleeping else "sleep"}, "wake" if sleeping else "sleep_enter", "bed", "idle" if sleeping else "sleep_loop", "bed" if sleeping else "idle_center", "sleep")


func _resolve_first_call() -> void:
	var calls: Array = application.get_view_model(MODE_SMALL, locale).get("open_calls", [])
	if not calls.is_empty():
		_command({"type": "resolve_call", "call_id": str(calls[0].get("call_id", ""))}, "attention", "idle_center", "idle", "", "attention")


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
	_command({"type": "start_battle", "encounter_id": _default_encounter_id(), "stance": "balanced"}, "idle_look", "departure", "idle", "", "locomotion")


func _set_battle_stance(stance: String) -> void:
	_command({"type": "battle_stance", "stance": stance}, "")


func _battle_round() -> void:
	_command({"type": "battle_round"}, "attack")


func _battle_resolve(outcome: String) -> void:
	_command({"type": "battle_resolve", "outcome": outcome}, "")


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


func _command(payload: Dictionary, animation_name: String, anchor_name := "idle_center", loop_after := "idle", from_anchor := "", event_kind := "care") -> void:
	var command_type := str(payload.get("type", "action"))
	# Input safety: one authoritative command at a time, plus a short debounce so
	# a double click or a repeated key press cannot submit the same intent twice.
	if command_in_flight:
		suppressed_duplicate_commands += 1
		return
	var now_msec := Time.get_ticks_msec()
	if command_type == last_command_key and now_msec - last_command_msec < COMMAND_DEBOUNCE_MSEC:
		suppressed_duplicate_commands += 1
		return
	last_command_msec = now_msec
	last_command_key = command_type
	command_in_flight = true
	var result: Dictionary = {}
	if application == null:
		result = {"ok": false, "error_code": "APP_NOT_READY"}
	else:
		result = application.command(payload)
	if result.get("ok", false):
		if command_type in ["battle_round", "battle_resolve"]:
			_queue_battle_presentation(result)
		elif not animation_name.is_empty():
			animation_controller.queue_one_shot(animation_name, anchor_name, 1.1, "command:%d:%s" % [int(application.get_view_model(MODE_SMALL, locale).get("state_revision", 0)), command_type], loop_after, from_anchor, event_kind)
	command_in_flight = false
	last_feedback = ActionFeedback.describe(command_type, result)
	last_feedback_record = last_feedback.duplicate(true)
	last_feedback_record["command"] = command_type
	last_feedback_record["ok"] = bool(result.get("ok", false))
	_refresh()


func _queue_battle_presentation(result: Dictionary) -> void:
	var summary: Dictionary = result.get("summary", {})
	var revision := int(application.get_view_model(MODE_SMALL, locale).get("state_revision", 0))
	var battle: Dictionary = application.get_view_model(MODE_SMALL, locale).get("active_battle", {})
	var outcome: Dictionary = summary.get("result", {})
	var encounter_id := str(battle.get("encounter_id", outcome.get("encounter_id", "")))
	var status := str(outcome.get("status", ""))
	var terminal_slots := 2 if status in ["win", "draw"] else 1 if status == "loss" else 0
	var maximum_exchanges := maxi(0, (PresentationAnimationController.MAX_PENDING_EVENTS - terminal_slots) / 2)
	var source_events: Array = summary.get("events", []) if summary.get("events", []) is Array else []
	var first_event := maxi(0, source_events.size() - maximum_exchanges) if terminal_slots > 0 else 0
	var sequence := 0
	for event_index in range(first_event, mini(source_events.size(), first_event + maximum_exchanges)):
		var source_event: Variant = source_events[event_index]
		if not source_event is Dictionary:
			continue
		var battle_event: Dictionary = source_event
		var actor := "enemy" if str(battle_event.get("actor", "pet")) == "enemy" else "pet"
		var target := "enemy" if actor == "pet" else "pet"
		var move_id := str(battle_event.get("move_id", ""))
		var move_presentation := application.get_move_presentation(move_id)
		animation_controller.queue_one_shot("attack", "idle_center", 0.9, "battle:%d:%d:attack" % [revision, sequence], "idle", "", "battle", {"actor": actor, "encounter_id": encounter_id, "move_id": move_id, "move_tags": move_presentation.get("tags", [])})
		sequence += 1
		var reaction := "dodge" if str(battle_event.get("result", "miss")) == "miss" else "hit"
		animation_controller.queue_one_shot(reaction, "idle_center", 0.75, "battle:%d:%d:%s" % [revision, sequence, reaction], "idle", "", "battle", {"actor": target, "encounter_id": encounter_id, "move_id": move_id})
		sequence += 1
	if status == "win":
		animation_controller.queue_one_shot("victory", "idle_center", 0.9, "battle:%d:result:pet" % revision, "idle", "", "battle", {"actor": "pet", "encounter_id": encounter_id, "terminal": true})
		animation_controller.queue_one_shot("defeat", "idle_center", 1.0, "battle:%d:result:enemy" % revision, "idle", "", "battle", {"actor": "enemy", "encounter_id": encounter_id, "terminal": true})
	elif status == "loss":
		animation_controller.queue_one_shot("defeat", "idle_center", 1.0, "battle:%d:result:pet" % revision, "injured", "", "battle", {"actor": "pet", "encounter_id": encounter_id, "terminal": true})
	elif status == "draw":
		animation_controller.queue_one_shot("defeat", "idle_center", 1.0, "battle:%d:result:pet" % revision, "idle", "", "battle", {"actor": "pet", "encounter_id": encounter_id, "terminal": true})
		animation_controller.queue_one_shot("defeat", "idle_center", 1.0, "battle:%d:result:enemy" % revision, "idle", "", "battle", {"actor": "enemy", "encounter_id": encounter_id, "terminal": true})


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
	_connect_pressed(save, _save_nickname.bind(input))
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
	dev_window.size = Vector2i(360, 270)
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
	for entry in [[application.text("ui.dev_advance_hour", "1 Stunde vor", locale), _advance_hour], [application.text("ui.dev_force_sick", "Krankheit erzwingen", locale), _force_sickness], ["Animation Showroom", _open_animation_showroom]]:
		var button := PixelUi.button(str(entry[0]))
		_connect_pressed(button, entry[1])
		column.add_child(button)
	dev_window.close_requested.connect(dev_window.hide, CONNECT_DEFERRED)
	dev_window.show()


func _open_animation_showroom() -> void:
	if not show_dev_tools:
		return
	if animation_showroom_window != null and is_instance_valid(animation_showroom_window):
		animation_showroom_window.show()
		animation_showroom_window.grab_focus()
		return
	animation_showroom_window = Window.new()
	animation_showroom_window.title = "KoalaPet Animation Showroom"
	animation_showroom_window.size = Vector2i(1360, 860)
	animation_showroom_window.min_size = Vector2i(960, 680)
	animation_showroom_window.transient = false
	animation_showroom_window.exclusive = false
	var showroom := AnimationShowroom.new()
	showroom.setup(application, locale)
	animation_showroom_window.add_child(showroom)
	add_child(animation_showroom_window)
	animation_showroom_window.close_requested.connect(animation_showroom_window.hide, CONNECT_DEFERRED)
	animation_showroom_window.show()


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


## Always a localized sentence. Raw `error_code` / `reason` values are internal
## diagnostics and must never reach the player-facing status area.
func _command_status(result: Dictionary, action_id := "") -> String:
	var feedback := ActionFeedback.describe(action_id, result)
	return application.text(str(feedback.get("key", "")), str(feedback.get("fallback", "")), locale)


func _set_margins(value: MarginContainer, amount: int) -> void:
	value.add_theme_constant_override("margin_left", amount)
	value.add_theme_constant_override("margin_right", amount)
	value.add_theme_constant_override("margin_top", amount)
	value.add_theme_constant_override("margin_bottom", amount)


func _connect_pressed(button: BaseButton, callback: Callable) -> void:
	button.pressed.connect(callback, CONNECT_DEFERRED)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


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


## Development-only scripted driver. Each entry is one deliberate player intent,
## so the duplicate-input guard is cleared between steps instead of treating the
## scripted sequence as an accidental double click.
func _reset_input_guard() -> void:
	command_in_flight = false
	last_command_key = ""
	last_command_msec = -COMMAND_DEBOUNCE_MSEC


func _run_review_steps(steps: Array) -> void:
	for step in steps:
		if step is Callable:
			_reset_input_guard()
			step.call()


func _run_review_actions(actions: PackedStringArray, diagnostics_delay_ms := 0) -> void:
	for action in actions:
		await get_tree().process_frame
		_reset_input_guard()
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
			"page:care": _set_small_page("care")
			"page:adventure": _set_small_page("adventure")
			"page:more": _set_small_page("more")
			"tab:battle": _set_expanded_tab("battle")
			"tab:dungeon": _set_expanded_tab("dungeon")
			"tab:inventory": _set_expanded_tab("inventory")
			"tab:codex": _set_expanded_tab("codex")
			"tab:evolution": _set_expanded_tab("evolution")
			"dungeon_unlock":
				_run_review_steps([_start_battle, _battle_resolve.bind("win")])
				application.command({"type": "start_battle", "encounter_id": "koalapet.base:thornlet_encounter", "stance": "aggressive"})
				application.command({"type": "battle_resolve", "outcome": "win"})
				_refresh()
			"dungeon_run":
				_run_review_steps([_start_dungeon, _dungeon_next, _battle_resolve.bind("win")])
			"dungeon_boss":
				_run_review_steps([
					_start_dungeon, _dungeon_next, _battle_resolve.bind("win"),
					_dungeon_choice.bind("quiet_pool"), _dungeon_next, _battle_resolve.bind("win"),
					_dungeon_next, _dungeon_next,
				])
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
			"text:125": _set_preference(1.25, "interface", "text_scale")
			"text:150": _set_preference(1.5, "interface", "text_scale")
			"text:175": _set_preference(1.75, "interface", "text_scale")
			"density:compact": _set_preference("compact", "interface", "layout_density")
			"contrast:on": _set_preference(true, "interface", "high_contrast")
			"pet:75": _set_preference(0.75, "pet_presentation", "standard_pet_scale")
			"pet:150": _set_preference(1.5, "pet_presentation", "standard_pet_scale")
			"minimal_pet:75": _set_preference(0.75, "pet_presentation", "minimal_pet_scale")
			"minimal_pet:150": _set_preference(1.5, "pet_presentation", "minimal_pet_scale")
			"roaming:off": _set_preference(false, "pet_presentation", "ambient_roaming")
			"reduced:on": _set_preference(true, "pet_presentation", "reduced_motion")
			"effects:reduced": _set_preference("reduced", "pet_presentation", "effects_intensity")
			"effects:off": _set_preference("off", "pet_presentation", "effects_intensity")
			"ambient:low": _set_preference("low", "pet_presentation", "ambient_animation_frequency")
			"ambient:high": _set_preference("high", "pet_presentation", "ambient_animation_frequency")
			"demo:idle": _review_idle_sequence()
			"demo:care": _review_care_sequence()
			"demo:sleep": _review_sleep_sequence()
			"demo:combat": _review_combat_sequence("koalapet.base:creekling_encounter")
			"demo:boss": _review_combat_sequence("koalapet.base:canopy_guardian")
			"minimal:playful":
				if mode == MODE_MINIMAL and minimal_sprite != null:
					_start_minimal_ambient_event({"kind": "playful_move", "animation": "playful_pounce", "distance_factor": 0.25, "duration": 1.2, "pause": 4.0})
			_:
				if str(action).begins_with("anim:"):
					_review_one_shot(str(action).trim_prefix("anim:"))
				elif str(action).begins_with("size:"):
					# Review-only resize down the same path a border drag takes:
					# the native window is resized and the presentation reflows
					# without rebuilding the scene or restarting an animation.
					var extent := str(action).trim_prefix("size:").split("x", false)
					if extent.size() == 2 and window_adapter.is_host_supported():
						window_adapter.set_size(Vector2i(int(extent[0]), int(extent[1])))
						await get_tree().process_frame
						_on_window_size_changed()
	await get_tree().process_frame
	await get_tree().process_frame
	if diagnostics_delay_ms > 0:
		await get_tree().create_timer(float(diagnostics_delay_ms) / 1000.0).timeout
		await get_tree().process_frame
		await get_tree().process_frame
	_write_diagnostics()
	await _write_capture()


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


func _run_living_animation_demo(scenario: String) -> void:
	if not application.has_pet():
		application.choose_starter("koalapet.base:moss_egg")
		application.advance_simulated(61)
		application.complete_hatch()
	_set_mode(MODE_SMALL)
	await get_tree().create_timer(1.0).timeout
	match scenario:
		"care-sleep":
			_review_idle_sequence()
			await get_tree().create_timer(4.2).timeout
			_review_care_sequence()
			await get_tree().create_timer(17.0).timeout
			_review_sleep_sequence()
		"combat":
			_review_combat_sequence("koalapet.base:creekling_encounter")
			await get_tree().create_timer(12.0).timeout
			_review_combat_sequence("koalapet.base:canopy_guardian")
		"minimal":
			_set_mode(MODE_MINIMAL)
			await get_tree().create_timer(1.5).timeout
			_start_minimal_ambient_event({"kind": "special_idle", "animation": "idle_playful", "duration": 1.4, "pause": 2.0})
			await get_tree().create_timer(3.0).timeout
			_start_minimal_ambient_event({"kind": "playful_move", "animation": "playful_pounce", "distance_factor": 0.28, "duration": 1.2, "pause": 3.0})
		"reduced-motion":
			_set_preference(true, "pet_presentation", "reduced_motion")
			_set_preference("reduced", "pet_presentation", "effects_intensity")
			await get_tree().create_timer(1.8).timeout
			_review_combat_sequence("koalapet.base:creekling_encounter")
		"ambient":
			_set_preference("high", "pet_presentation", "ambient_animation_frequency")
			_review_idle_sequence()
			await get_tree().create_timer(4.0).timeout
			_review_sequence([
				{"animation": "attention", "anchor": "idle_center", "kind": "attention"},
				{"animation": "playful_hop", "anchor": "idle_center", "kind": "ambient"},
			])
		"sleep-habitat":
			_sleep_or_wake(false)
		"sleep-minimal":
			_sleep_or_wake(false)
			await get_tree().create_timer(1.4).timeout
			_set_mode(MODE_MINIMAL)
		_:
			_review_idle_sequence()


func _review_one_shot(animation_name: String, anchor := "idle_center", loop_after := "idle", kind := "care", payload := {}) -> void:
	_review_sequence([{"animation": animation_name, "anchor": anchor, "loop_after": loop_after, "kind": kind, "payload": payload}])


func _review_idle_sequence() -> void:
	_review_sequence([
		{"animation": "idle_look", "kind": "ambient"},
		{"animation": "idle_playful", "kind": "ambient"},
		{"animation": "idle_rest", "kind": "ambient"},
	])


func _review_care_sequence() -> void:
	_review_sequence([
		{"animation": "eat", "anchor": "feeding_bowl", "kind": "care"},
		{"animation": "clean", "anchor": "bath", "kind": "care"},
		{"animation": "training", "anchor": "training", "kind": "care"},
		{"animation": "medicine", "anchor": "medicine", "kind": "care"},
	])


func _review_sleep_sequence() -> void:
	_review_sequence([
		{"animation": "sleep_enter", "anchor": "bed", "loop_after": "sleep_loop", "kind": "sleep"},
		{"animation": "wake", "anchor": "bed", "loop_after": "idle", "kind": "sleep"},
	])


func _review_combat_sequence(encounter_id: String) -> void:
	_review_sequence([
		{"animation": "attack", "kind": "battle", "payload": {"actor": "pet", "encounter_id": encounter_id}},
		{"animation": "hit", "kind": "battle", "payload": {"actor": "enemy", "encounter_id": encounter_id}},
		{"animation": "attack", "kind": "battle", "payload": {"actor": "enemy", "encounter_id": encounter_id}},
		{"animation": "dodge", "kind": "battle", "payload": {"actor": "pet", "encounter_id": encounter_id}},
		{"animation": "victory", "kind": "battle", "payload": {"actor": "pet", "encounter_id": encounter_id, "terminal": true}},
		{"animation": "defeat", "kind": "battle", "payload": {"actor": "enemy", "encounter_id": encounter_id, "terminal": true}},
	])


func _review_sequence(specs: Array) -> void:
	for raw_spec in specs:
		if not raw_spec is Dictionary:
			continue
		var spec: Dictionary = raw_spec
		review_event_sequence += 1
		animation_controller.queue_one_shot(
			str(spec.get("animation", "idle")),
			str(spec.get("anchor", "idle_center")),
			float(spec.get("duration", 0.9)),
			"review:%d" % review_event_sequence,
			str(spec.get("loop_after", "idle")),
			str(spec.get("from_anchor", "")),
			str(spec.get("kind", "care")),
			spec.get("payload", {}),
		)
	_refresh()


## Container layout only settles on the frame after the rebuild, so diagnostics
## must never be sampled inside the same frame or every rect is pre-layout noise.
func _write_diagnostics_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_write_diagnostics()
	_write_capture()


## Development-only privacy-safe capture. It reads back this application's own
## rendered viewport, so evidence can never contain unrelated desktop content
## and is unaffected by compositor or DPI-virtualisation artefacts.
func _write_capture() -> void:
	if capture_path.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	image.save_png(absolute)


func _write_diagnostics() -> void:
	if diagnostics_path.is_empty():
		return
	var persistent_backgrounds := 0
	for child in root_layer.get_children():
		if child is ColorRect:
			persistent_backgrounds += 1
	diagnostics_sequence += 1
	var view_model := application.get_view_model(mode, locale)
	var payload := {
		"schema_version": 2,
		"diagnostics_sequence": diagnostics_sequence,
		"mode": mode,
		"locale": locale,
		"last_feedback": last_feedback_record,
		"pet": {
			"screen": str(view_model.get("screen", "")),
			"name": str(view_model.get("name", "")),
			"stage": str(view_model.get("stage", "")),
			"level": int(view_model.get("level", 0)),
			"sleeping": bool(view_model.get("sleeping", false)),
			"sickness": bool(view_model.get("sickness", false)),
			"injured": not view_model.get("injury", {}).is_empty(),
			"battle_active": not view_model.get("active_battle", {}).is_empty(),
			"dungeon_active": not view_model.get("active_dungeon_run", {}).is_empty(),
			"battle_unlocked": bool(view_model.get("battle_unlocked", false)),
			"dungeon_unlocked": bool(view_model.get("dungeon_unlocked", false)),
			"open_calls": view_model.get("open_calls", []).size(),
			"care": view_model.get("care", {}),
		},
		"state_revision": int(view_model.get("state_revision", 0)),
		"persistent_root_color_rects": persistent_backgrounds,
		"presentation_rect": _rect_array(get_rect()),
		"viewport_visible_rect": _rect_array(get_viewport_rect()),
		"content_scale_size": [get_window().content_scale_size.x, get_window().content_scale_size.y],
		"layout_rects": _diagnostic_layout_rects(),
		"controls": _diagnostic_controls(),
		"focused_control": _focused_control_name(),
		"logical_size": [logical_size.x, logical_size.y],
		"requested_window_size": [requested_window_size.x, requested_window_size.y],
		"mode_switch_requests": mode_switch_requests,
		"mode_switch_applied": mode_switch_applied,
		"last_mode_request": last_mode_request,
		"window_min_size": [get_window().min_size.x, get_window().min_size.y],
		"window_max_size": [get_window().max_size.x, get_window().max_size.y],
		"window_resizable": not get_window().unresizable,
		"habitat_frame_scale": active_habitat_frame.current_scale() if active_habitat_frame != null and is_instance_valid(active_habitat_frame) else 0.0,
		"suppressed_duplicate_commands": suppressed_duplicate_commands,
		"missing_icon_names": PixelUi.missing_icon_names(),
		"small_page": small_page,
		"expanded_tab": expanded_tab,
		"minimal_pet_rect": _rect_array(minimal_sprite.get_global_rect()) if minimal_sprite != null and is_instance_valid(minimal_sprite) else [],
		"resolved_ui_scale": resolved_ui_scale,
		"text_scale": float(preferences.get("interface", {}).get("text_scale", 1.0)),
		"standard_pet_scale": float(preferences.get("pet_presentation", {}).get("standard_pet_scale", 1.0)),
		"minimal_pet_scale": _minimal_pet_scale(),
		"theme_base_scale": theme.default_base_scale if theme != null else 0.0,
		"reduced_motion": reduced_motion,
		"ambient_roaming": bool(preferences.get("pet_presentation", {}).get("ambient_roaming", true)),
		"ambient_animation_frequency": str(preferences.get("pet_presentation", {}).get("ambient_animation_frequency", "normal")),
		"effects_intensity": str(preferences.get("pet_presentation", {}).get("effects_intensity", "normal")),
		"habitat_visual_state": active_habitat.current_visual_state() if active_habitat != null and is_instance_valid(active_habitat) else "",
		"habitat_anchor": [active_habitat.current_anchor_position().x, active_habitat.current_anchor_position().y] if active_habitat != null and is_instance_valid(active_habitat) else [],
		"habitat_moving": active_habitat.is_moving() if active_habitat != null and is_instance_valid(active_habitat) else false,
		"habitat_highlighted_station": active_habitat.highlighted_station() if active_habitat != null and is_instance_valid(active_habitat) else "",
		"habitat_pending_events": active_habitat.pending_event_count() if active_habitat != null and is_instance_valid(active_habitat) else 0,
		"active_animation_processors": active_habitat.active_animation_processor_count() if active_habitat != null and is_instance_valid(active_habitat) else (1 if minimal_sprite != null and minimal_sprite.is_processing() else 0),
		"minimal_hit_region_updates": minimal_hit_region_updates,
		"observed_fps": Engine.get_frames_per_second(),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"preference_schema_version": int(preferences.get("version", 0)),
		"native_window": window_adapter.capture_diagnostics() if window_adapter != null else {},
	}
	var absolute := ProjectSettings.globalize_path(diagnostics_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	# Written through a temporary file and renamed, so a live reader can never
	# observe a half-serialized document.
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.flush()
	file.close()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	DirAccess.rename_absolute(temporary, absolute)


func _rect_array(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _minimal_walk_bounds(sprite_extent := Vector2.ZERO, window_extent := Vector2i.ZERO) -> Vector2:
	var resolved_sprite := sprite_extent if sprite_extent != Vector2.ZERO else (minimal_sprite.size if minimal_sprite != null else Vector2(128, 128))
	var resolved_window := Vector2(window_extent) if window_extent != Vector2i.ZERO else size
	return Vector2(8.0, maxf(8.0, resolved_window.x - resolved_sprite.x - 8.0))


func _diagnostic_layout_rects() -> Dictionary:
	var result := {}
	for node_name in [
		"WindowFrame", "PlayerTitleBar", "PrimaryStatusRow", "ContextualAlerts",
		"SmallHabitatFrame", "QuickActions", "SmallNavigation",
		"ExpandedBody", "ExpandedStatus", "ExpandedCenter", "ExpandedActions",
		"ExpandedHabitatFrame", "ExpandedTabs", "ExpandedDetail",
	]:
		var node := root_layer.find_child(node_name, true, false) as Control
		if node != null:
			result[node_name] = _rect_array(node.get_global_rect())
	return result


func _on_focus_changed(_control: Control) -> void:
	_write_diagnostics()


func _focused_control_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return str(focused.name) if focused != null else ""


## Every player-facing control with its resolved label, icon and enabled state.
## The interactive matrix is generated from this instead of from source reading.
func _diagnostic_controls() -> Array:
	var result: Array = []
	for node in root_layer.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or not button.is_visible_in_tree():
			continue
		result.append({
			"name": button.name,
			"component": str(button.get_meta("component", "")),
			"action_id": str(button.get_meta("action_id", "")),
			"icon": str(button.get_meta("icon_name", "")),
			"label": button.text if button is Button else "",
			"accessible_label": str(button.get_meta("accessible_label", button.tooltip_text)),
			"tooltip": button.tooltip_text,
			"disabled": button.disabled,
			"focusable": button.focus_mode == Control.FOCUS_ALL,
			"rect": _rect_array(button.get_global_rect()),
			"pressed_connections": button.pressed.get_connections().size(),
		})
	return result
