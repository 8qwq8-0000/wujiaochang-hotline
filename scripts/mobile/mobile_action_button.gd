class_name MobileActionButton
extends Control

signal aim_vector_changed(vector: Vector2, active: bool)
signal tap_triggered

const DIRECTION_DEADZONE := 0.18

var action_name: StringName
var caption := ""
var accent := Color("55d7e8")
var supports_direction := false
var joystick_style := false
var defer_action_until_drag := false
var editing := false

var _touch_index := -1
var _mouse_active := false
var _pressed := false
var _action_active := false
var _drag_activated := false
var _stick_vector := Vector2.ZERO
var _tap_serial := 0
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)
	_refresh_caption()
	queue_redraw()


func configure(
	next_action: StringName,
	next_caption: String,
	next_accent: Color,
	directional: bool = false,
	as_joystick: bool = false
) -> void:
	action_name = next_action
	caption = next_caption
	accent = next_accent
	supports_direction = directional
	joystick_style = as_joystick
	defer_action_until_drag = as_joystick
	_refresh_caption()
	queue_redraw()


func set_editing(value: bool) -> void:
	if editing == value:
		return
	editing = value
	if editing:
		cancel_action()
	queue_redraw()


func cancel_action() -> void:
	_tap_serial += 1
	_set_action_active(false)
	_pressed = false
	_drag_activated = false
	_stick_vector = Vector2.ZERO
	_touch_index = -1
	_mouse_active = false
	aim_vector_changed.emit(Vector2.ZERO, false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if editing:
		accept_event()
		return
	# Godot mirrors physical touch to mouse and editor mouse to touch. Handle
	# only the physical source so one gesture never presses an action twice.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0:
			_touch_index = touch.index
			_begin_press(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_end_press()
			accept_event()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		_update_direction((event as InputEventScreenDrag).position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			_mouse_active = true
			_begin_press(mouse_button.position)
		else:
			_mouse_active = false
			_end_press()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_direction((event as InputEventMouseMotion).position)
		accept_event()


func _begin_press(_local_position: Vector2) -> void:
	_tap_serial += 1
	_pressed = true
	_drag_activated = false
	_stick_vector = Vector2.ZERO
	if not defer_action_until_drag:
		_set_action_active(true)
	# The attack joystick defers its action until drag or release: a release
	# without crossing the deadzone is one auto-aim tap, while crossing it
	# starts held manual fire. Directional guard keeps its immediate behavior.
	if supports_direction:
		aim_vector_changed.emit(Vector2.ZERO, false)
	queue_redraw()


func _end_press() -> void:
	var commit_tap := _pressed and defer_action_until_drag and not _drag_activated
	_set_action_active(false)
	_pressed = false
	_touch_index = -1
	_stick_vector = Vector2.ZERO
	aim_vector_changed.emit(Vector2.ZERO, false)
	if commit_tap:
		tap_triggered.emit()
		_emit_timed_tap()
	queue_redraw()


func _update_direction(local_position: Vector2) -> void:
	if not supports_direction or not _pressed:
		return
	var radius := maxf(minf(size.x, size.y) * 0.5, 1.0)
	var vector := (local_position - size * 0.5) / radius
	if vector.length() < DIRECTION_DEADZONE:
		_stick_vector = Vector2.ZERO
		aim_vector_changed.emit(Vector2.ZERO, false)
		if defer_action_until_drag:
			_set_action_active(false)
	else:
		_drag_activated = true
		_stick_vector = vector.limit_length(1.0)
		aim_vector_changed.emit(_stick_vector, true)
		if defer_action_until_drag:
			_set_action_active(true)
	queue_redraw()


func is_action_active() -> bool:
	return _action_active


func is_manual_drag_active() -> bool:
	return _pressed and _drag_activated and not _stick_vector.is_zero_approx()


func _emit_timed_tap() -> void:
	_tap_serial += 1
	var serial := _tap_serial
	_set_action_active(true)
	_release_tap_after_physics(serial)


func _release_tap_after_physics(serial: int) -> void:
	# Keep the action down across one complete physics tick. This guarantees
	# both semi-auto and automatic weapons commit exactly one tap shot.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if serial != _tap_serial or _pressed:
		return
	_set_action_active(false)


func _set_action_active(value: bool) -> void:
	if _action_active == value:
		return
	_action_active = value
	_emit_action(value)


func _emit_action(pressed: bool) -> void:
	if action_name.is_empty():
		return
	var input := InputEventAction.new()
	input.action = action_name
	input.pressed = pressed
	input.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(input)


func _refresh_caption() -> void:
	if _label != null:
		_label.text = caption


func _draw() -> void:
	var radius := maxf(minf(size.x, size.y) * 0.5 - 2.0, 2.0)
	var center := size * 0.5
	var fill := Color(0.025, 0.045, 0.08, 0.72)
	if _pressed:
		fill = Color(accent, 0.4)
	elif editing:
		fill = Color(accent, 0.22)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, Color(accent, 0.95), 2.0)
	if joystick_style:
		var knob_radius := maxf(radius * 0.34, 6.0)
		var knob_offset := _stick_vector * radius * 0.52
		draw_circle(center + knob_offset, knob_radius, Color(accent, 0.72 if _pressed else 0.42))
		draw_arc(center + knob_offset, knob_radius, 0.0, TAU, 28, Color.WHITE, 1.25)
	if editing:
		draw_arc(center, maxf(radius - 5.0, 2.0), 0.0, TAU, 32, Color.WHITE, 1.0)


func _exit_tree() -> void:
	cancel_action()
