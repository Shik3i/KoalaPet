class_name OverlayUnderlayProbe
extends Control

const RESULT_PATH := "user://desktop_overlay_spike/underlay_probe.json"

var click_count := 0
var last_click := Vector2.ZERO
var status_label: Label


func _ready() -> void:
	get_window().title = "KoalaPet Neutral Underlay Probe"
	get_window().size = Vector2i(900, 650)
	get_window().position = Vector2i(180, 120)
	get_window().close_requested.connect(_quit)
	_apply_user_arguments()
	_build_interface()
	_write_result("ready")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		click_count += 1
		last_click = event.position
		_update_label()
		_write_result("click")
		print("UNDERLAY_CLICK count=%d position=%s button=%d" % [click_count, event.position, event.button_index])


func _build_interface() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("31547a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var target := ColorRect.new()
	target.position = Vector2(80, 100)
	target.size = Vector2(740, 450)
	target.color = Color("d9edf2")
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(target)

	status_label = Label.new()
	status_label.position = Vector2(110, 140)
	status_label.size = Vector2(680, 360)
	status_label.add_theme_color_override("font_color", Color("162c3b"))
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	_update_label()


func _update_label() -> void:
	status_label.text = "NEUTRAL UNDERLAY PROBE\n\nClick count: %d\nLast local position: %s\n\nUsed only for native passthrough evidence" % [click_count, last_click]


func _apply_user_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--position="):
			var components := argument.trim_prefix("--position=").split(",")
			if components.size() == 2:
				get_window().position = Vector2i(int(components[0]), int(components[1]))


func _write_result(event_label: String) -> void:
	OverlayPlacementStore.write_json_atomic(RESULT_PATH, {
		"schema_version": 1,
		"captured_at_utc": Time.get_datetime_string_from_system(true),
		"event": event_label,
		"click_count": click_count,
		"last_click": [last_click.x, last_click.y],
		"window_position": [get_window().position.x, get_window().position.y],
		"window_size": [get_window().size.x, get_window().size.y],
		"window_focused": get_window().has_focus(),
	})


func _quit() -> void:
	_write_result("quit")
	get_tree().quit()
