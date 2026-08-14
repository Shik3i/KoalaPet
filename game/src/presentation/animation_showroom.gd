class_name AnimationShowroom
extends Control

const VISUAL_MANIFEST := "res://assets_generated/visual-rebuild-manifest.json"
const REVIEW_DIRECTORY := "user://animation-showroom"
const SPEEDS := [0.25, 0.5, 0.75, 1.0, 1.25, 2.0]
const COMPARISONS := [
	"Single",
	"Two animations",
	"Left / right",
	"Reduced Motion / normal",
	"Alternate branch",
	"Small / Minimal scale",
	"Light / dark",
]

var application: PetApplication
var locale := "en"
var entries: Array[Dictionary] = []
var _visual_manifest: Dictionary = {}
var _entity_option: OptionButton
var _animation_option: OptionButton
var _secondary_animation_option: OptionButton
var _comparison_option: OptionButton
var _speed_option: OptionButton
var _direction_option: OptionButton
var _background_option: OptionButton
var _scale_slider: HSlider
var _effects_option: OptionButton
var _loop_toggle: CheckButton
var _reduced_motion_toggle: CheckButton
var _high_contrast_toggle: CheckButton
var _vfx_toggle: CheckButton
var _frame_toggle: CheckButton
var _ground_toggle: CheckButton
var _pivot_toggle: CheckButton
var _visual_bounds_toggle: CheckButton
var _interaction_bounds_toggle: CheckButton
var _markers_toggle: CheckButton
var _primary: AnimationShowroomStage
var _secondary: AnimationShowroomStage
var _status: Label
var _capturing := false


func setup(value: PetApplication, value_locale := "en") -> void:
	application = value
	locale = value_locale


func _ready() -> void:
	name = "AnimationShowroom"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_visual_manifest()
	entries = application.get_animation_review_entries(locale) if application != null else []
	_build_ui()
	_populate_entities()
	_refresh_animation_options()
	_refresh_stages()


func reviewed_entity_count() -> int:
	return entries.size()


func reviewed_animation_count() -> int:
	var total := 0
	for entry in entries:
		total += (entry.get("animations", {}) as Dictionary).size()
	return total


func missing_or_fallback_animations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		for animation_name in (entry.get("animations", {}) as Dictionary):
			var descriptor: Dictionary = entry.animations[animation_name]
			if str(descriptor.get("path", "")).is_empty() or str(descriptor.get("animation_name", "")) != str(animation_name):
				result.append({"content_id": entry.content_id, "animation": animation_name, "resolved": descriptor.get("animation_name", "")})
	return result


func _build_ui() -> void:
	var base := ColorRect.new()
	base.color = Color("#172126")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.add_theme_constant_override("margin_left", 8)
	root.add_theme_constant_override("margin_right", 8)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	add_child(root)
	var title := Label.new()
	title.text = "Animation Showroom — runtime profiles"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)
	var selectors := GridContainer.new()
	selectors.columns = 8
	selectors.add_theme_constant_override("h_separation", 6)
	selectors.add_theme_constant_override("v_separation", 4)
	root.add_child(selectors)
	_entity_option = _labeled_option(selectors, "Entity")
	_animation_option = _labeled_option(selectors, "Animation")
	_secondary_animation_option = _labeled_option(selectors, "Compare animation")
	_comparison_option = _labeled_option(selectors, "Comparison")
	for label in COMPARISONS:
		_comparison_option.add_item(label)
	_speed_option = _labeled_option(selectors, "Speed")
	for speed in SPEEDS:
		_speed_option.add_item("%d%%" % int(speed * 100.0))
	_speed_option.select(3)
	_direction_option = _labeled_option(selectors, "Facing")
	_direction_option.add_item("Right")
	_direction_option.add_item("Left")
	_background_option = _labeled_option(selectors, "Background")
	_background_option.add_item("Dark")
	_background_option.add_item("Light")
	_effects_option = _labeled_option(selectors, "Effects")
	_effects_option.add_item("Full")
	_effects_option.add_item("Reduced")
	_effects_option.add_item("Off")
	var scale_label := Label.new()
	scale_label.text = "Pet scale"
	selectors.add_child(scale_label)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 2.0
	_scale_slider.step = 0.05
	_scale_slider.value = 1.0
	_scale_slider.custom_minimum_size.x = 140
	_scale_slider.tooltip_text = "Preview pet scale from 50% to 200%"
	selectors.add_child(_scale_slider)
	var toggles := HFlowContainer.new()
	root.add_child(toggles)
	_loop_toggle = _toggle(toggles, "Loop", true)
	_reduced_motion_toggle = _toggle(toggles, "Reduced Motion", false)
	_high_contrast_toggle = _toggle(toggles, "High contrast", false)
	_vfx_toggle = _toggle(toggles, "VFX", true)
	_frame_toggle = _toggle(toggles, "Frame number", true)
	_ground_toggle = _toggle(toggles, "Ground anchor", false)
	_pivot_toggle = _toggle(toggles, "Pivot", false)
	_visual_bounds_toggle = _toggle(toggles, "Visual bounds", false)
	_interaction_bounds_toggle = _toggle(toggles, "Interaction bounds", false)
	_markers_toggle = _toggle(toggles, "Markers", true)
	var actions := HFlowContainer.new()
	root.add_child(actions)
	_add_action(actions, "Play", _play)
	_add_action(actions, "Pause", _pause)
	_add_action(actions, "Restart", _restart)
	_add_action(actions, "Previous frame", _step.bind(-1))
	_add_action(actions, "Next frame", _step.bind(1))
	_add_action(actions, "Cycle entity animations", _cycle_entity_animations)
	_add_action(actions, "Cycle forms for animation", _cycle_forms_for_animation)
	_add_action(actions, "Capture standardized pair", _capture_standardized_pair)
	_add_action(actions, "Record GIF source", _record_gif_source)
	_add_action(actions, "Write review manifest", _write_review_manifest)
	var stages := HBoxContainer.new()
	stages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stages.add_theme_constant_override("separation", 8)
	root.add_child(stages)
	_primary = AnimationShowroomStage.new()
	_primary.name = "PrimaryStage"
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stages.add_child(_primary)
	_secondary = AnimationShowroomStage.new()
	_secondary.name = "ComparisonStage"
	_secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secondary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stages.add_child(_secondary)
	_status = Label.new()
	_status.text = "%d runtime entities · %d sequences" % [reviewed_entity_count(), reviewed_animation_count()]
	_status.tooltip_text = "Batch output: " + ProjectSettings.globalize_path(REVIEW_DIRECTORY)
	root.add_child(_status)
	_entity_option.item_selected.connect(_on_entity_selected)
	for control in [_animation_option, _secondary_animation_option, _comparison_option, _speed_option, _direction_option, _background_option, _effects_option]:
		control.item_selected.connect(func(_index: int) -> void: _refresh_stages())
	for control in [_loop_toggle, _reduced_motion_toggle, _high_contrast_toggle, _vfx_toggle, _frame_toggle, _ground_toggle, _pivot_toggle, _visual_bounds_toggle, _interaction_bounds_toggle, _markers_toggle]:
		control.toggled.connect(func(_enabled: bool) -> void: _refresh_stages())
	_scale_slider.value_changed.connect(func(_value: float) -> void: _refresh_stages())


func _labeled_option(parent: GridContainer, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 150
	option.tooltip_text = label_text
	parent.add_child(option)
	return option


func _toggle(parent: Container, label_text: String, enabled: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = enabled
	toggle.tooltip_text = label_text
	parent.add_child(toggle)
	return toggle


func _add_action(parent: Container, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.tooltip_text = label_text
	button.pressed.connect(callback)
	parent.add_child(button)


func _populate_entities() -> void:
	_entity_option.clear()
	for entry in entries:
		_entity_option.add_item("%s · %s" % [str(entry.get("kind", "")), str(entry.get("display_name", entry.get("content_id", "")))])


func _on_entity_selected(_index: int) -> void:
	_refresh_animation_options()
	_refresh_stages()


func _refresh_animation_options() -> void:
	_animation_option.clear()
	_secondary_animation_option.clear()
	var entry := _selected_entry()
	var names: Array = (entry.get("animations", {}) as Dictionary).keys()
	names.sort()
	for animation_name in names:
		_animation_option.add_item(str(animation_name))
		_secondary_animation_option.add_item(str(animation_name))
	if _secondary_animation_option.item_count > 1:
		_secondary_animation_option.select(1)


func _selected_entry() -> Dictionary:
	if entries.is_empty() or _entity_option == null:
		return {}
	return entries[clampi(_entity_option.selected, 0, entries.size() - 1)]


func _selected_descriptor(option: OptionButton, entry := {}) -> Dictionary:
	var source: Dictionary = _selected_entry() if entry.is_empty() else entry
	if source.is_empty() or option.item_count == 0:
		return {}
	return (source.get("animations", {}) as Dictionary).get(option.get_item_text(option.selected), {})


func _refresh_stages() -> void:
	if _primary == null or _animation_option.item_count == 0:
		return
	var entry := _selected_entry()
	var primary_descriptor := _selected_descriptor(_animation_option, entry)
	var secondary_entry := entry
	var secondary_descriptor := primary_descriptor
	var primary_direction := -1.0 if _direction_option.selected == 1 else 1.0
	var secondary_direction := primary_direction
	var primary_reduced := _reduced_motion_toggle.button_pressed
	var secondary_reduced := primary_reduced
	var primary_scale := float(_scale_slider.value)
	var secondary_scale := primary_scale
	var primary_background := _background_option.get_item_text(_background_option.selected).to_lower()
	var secondary_background := primary_background
	var comparison := _comparison_option.get_item_text(_comparison_option.selected)
	_secondary.visible = comparison != "Single"
	match comparison:
		"Two animations":
			secondary_descriptor = _selected_descriptor(_secondary_animation_option, entry)
		"Left / right":
			primary_direction = 1.0
			secondary_direction = -1.0
		"Reduced Motion / normal":
			primary_reduced = false
			secondary_reduced = true
		"Alternate branch":
			secondary_entry = _alternate_branch(entry)
			secondary_descriptor = _matching_descriptor(secondary_entry, _animation_option.get_item_text(_animation_option.selected))
		"Small / Minimal scale":
			primary_scale = 0.75
			secondary_scale = 0.5
		"Light / dark":
			primary_background = "light"
			secondary_background = "dark"
	var speed := float(SPEEDS[_speed_option.selected])
	_configure_stage(_primary, entry, primary_descriptor, primary_direction, primary_reduced, primary_scale, primary_background, speed)
	if _secondary.visible:
		_configure_stage(_secondary, secondary_entry, secondary_descriptor, secondary_direction, secondary_reduced, secondary_scale, secondary_background, speed)
	var fallback_count := missing_or_fallback_animations().size()
	_status.text = "%s · %s · %d entities · %d sequences · %d missing/fallback" % [str(entry.get("display_name", "")), _animation_option.get_item_text(_animation_option.selected), reviewed_entity_count(), reviewed_animation_count(), fallback_count]


func _configure_stage(stage: AnimationShowroomStage, entry: Dictionary, descriptor: Dictionary, facing: float, reduce_motion: bool, scale_value: float, background: String, speed: float) -> void:
	stage.background_name = background
	stage.show_vfx = _vfx_toggle.button_pressed
	stage.show_frame_number = _frame_toggle.button_pressed
	stage.show_ground_anchor = _ground_toggle.button_pressed
	stage.show_pivot = _pivot_toggle.button_pressed
	stage.show_visual_bounds = _visual_bounds_toggle.button_pressed
	stage.show_interaction_bounds = _interaction_bounds_toggle.button_pressed
	stage.show_markers = _markers_toggle.button_pressed
	stage.modulate = Color.WHITE if not _high_contrast_toggle.button_pressed else Color(1.18, 1.18, 1.18)
	stage.set_direction(facing)
	stage.set_pet_scale(scale_value)
	stage.configure_animation(descriptor, reduce_motion, speed, _loop_toggle.button_pressed)
	var intensity := _effects_option.get_item_text(_effects_option.selected).to_lower()
	stage.configure_effect(_effect_descriptor(entry, str(descriptor.get("animation_name", ""))), reduce_motion, speed, intensity)
	stage.queue_redraw()


func _alternate_branch(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "")) != "form":
		return entry
	var family_id := str(entry.get("family_id", ""))
	for candidate in entries:
		if str(candidate.get("kind", "")) == "form" and str(candidate.get("family_id", "")) == family_id and str(candidate.get("content_id", "")) != str(entry.get("content_id", "")):
			return candidate
	return entry


func _matching_descriptor(entry: Dictionary, animation_name: String) -> Dictionary:
	var animations: Dictionary = entry.get("animations", {})
	return animations.get(animation_name, animations.get("idle", {}))


func _effect_descriptor(entry: Dictionary, animation_name: String) -> Dictionary:
	var family_id := str(entry.get("family_id", ""))
	var family_key := family_id.trim_prefix("koalapet.base:").trim_suffix("_family")
	var effect_name := "impact" if animation_name in ["hit", "defeat"] else "attack"
	var profiles: Dictionary = _visual_manifest.get("living_animation", {}).get("family_profiles", {})
	var profile: Dictionary = profiles.get(family_id, {})
	if str(entry.get("kind", "")) == "enemy":
		var encounter_profiles: Dictionary = _visual_manifest.get("living_animation", {}).get("encounter_profiles", {})
		profile = encounter_profiles.get(str(entry.get("content_id", "")), {})
		family_key = str(profile.get("effect_set", "moss"))
	var requested := str(profile.get("impact_effect" if effect_name == "impact" else "attack_effect", ""))
	var families: Dictionary = _visual_manifest.get("living_animation", {}).get("family_effects", {})
	var effect: Dictionary = families.get(str(profile.get("effect_set", family_key)), {}).get(requested, {})
	if effect.is_empty():
		return {}
	var result := effect.duplicate(true)
	result["path"] = "res://" + str(result.get("path", "")).trim_prefix("game/")
	result["animation_name"] = requested
	return result


func _load_visual_manifest() -> void:
	if not FileAccess.file_exists(VISUAL_MANIFEST):
		return
	var value = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_MANIFEST))
	if value is Dictionary:
		_visual_manifest = value


func _play() -> void:
	_primary.play()
	if _secondary.visible:
		_secondary.play()


func _pause() -> void:
	_primary.pause()
	if _secondary.visible:
		_secondary.pause()


func _restart() -> void:
	_primary.restart()
	if _secondary.visible:
		_secondary.restart()


func _step(offset: int) -> void:
	_primary.step_frame(offset)
	if _secondary.visible:
		_secondary.step_frame(offset)


func _cycle_entity_animations() -> void:
	await _batch_capture(false)


func _cycle_forms_for_animation() -> void:
	await _batch_capture(true)


func _capture_standardized_pair() -> void:
	await _capture_viewport("standardized-pair")


func _record_gif_source() -> void:
	if _capturing:
		return
	_capturing = true
	var original_frame := _primary.current_frame()
	_pause()
	var descriptor := _selected_descriptor(_animation_option)
	for frame in range(maxi(1, int(descriptor.get("frames", 1)))):
		_primary.sprite.set_frame(frame)
		if _secondary.visible:
			_secondary.sprite.set_frame(mini(frame, _secondary.sprite.frame_count - 1))
		await _capture_viewport("gif-source-%02d" % frame)
	_primary.sprite.set_frame(original_frame)
	_capturing = false
	_status.text = "GIF source frames written to " + ProjectSettings.globalize_path(REVIEW_DIRECTORY)


func _batch_capture(forms_for_animation: bool) -> void:
	if _capturing:
		return
	_capturing = true
	var original_entity := _entity_option.selected
	var original_animation := _animation_option.selected
	if forms_for_animation:
		var animation_name := _animation_option.get_item_text(_animation_option.selected)
		for entity_index in entries.size():
			if not (entries[entity_index].get("animations", {}) as Dictionary).has(animation_name):
				continue
			_entity_option.select(entity_index)
			_refresh_animation_options()
			_select_text(_animation_option, animation_name)
			_refresh_stages()
			await _capture_viewport("form-%02d-%s" % [entity_index, animation_name])
	else:
		for animation_index in _animation_option.item_count:
			_animation_option.select(animation_index)
			_refresh_stages()
			await _capture_viewport("entity-%02d-%s" % [original_entity, _animation_option.get_item_text(animation_index)])
	_entity_option.select(original_entity)
	_refresh_animation_options()
	_animation_option.select(mini(original_animation, _animation_option.item_count - 1))
	_refresh_stages()
	_capturing = false
	_write_review_manifest()


func _select_text(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == value:
			option.select(index)
			return


func _capture_viewport(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIRECTORY))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var safe_label := label.validate_filename().to_lower()
	var error := image.save_png("%s/%s.png" % [REVIEW_DIRECTORY, safe_label])
	_status.text = "Captured %s (%s)" % [safe_label, error_string(error)]


func _write_review_manifest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIRECTORY))
	var entity_manifest: Array[Dictionary] = []
	for entry in entries:
		entity_manifest.append({"content_id": entry.get("content_id", ""), "kind": entry.get("kind", ""), "animations": (entry.get("animations", {}) as Dictionary).keys()})
	var manifest := {
		"schema_version": 1,
		"runtime_controller": "AnimatedTextureRect",
		"entity_count": reviewed_entity_count(),
		"sequence_count": reviewed_animation_count(),
		"missing_or_fallback": missing_or_fallback_animations(),
		"entities": entity_manifest,
	}
	var file := FileAccess.open(REVIEW_DIRECTORY + "/review-manifest.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "  ") + "\n")
	_status.text = "Review manifest written to " + ProjectSettings.globalize_path(REVIEW_DIRECTORY)
