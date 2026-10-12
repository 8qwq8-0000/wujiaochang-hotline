extends Node


func _ready() -> void:
	_ensure_input_map()
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null and run_manager.run_seed == 0:
		run_manager.begin_run()


func _ensure_input_map() -> void:
	_add_key_action(&"move_left", KEY_A)
	_add_key_action(&"move_right", KEY_D)
	_add_key_action(&"move_up", KEY_W)
	_add_key_action(&"move_down", KEY_S)
	_add_key_action(&"mobility_ability", KEY_SPACE)
	_add_key_action(&"mobility_1", KEY_1)
	_add_key_action(&"mobility_2", KEY_2)
	_add_key_action(&"mobility_3", KEY_3)
	_add_key_action(&"mobility_4", KEY_4)
	_add_mouse_action(&"attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action(&"guard", MOUSE_BUTTON_RIGHT)
	_add_mouse_action(&"weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse_action(&"weapon_previous", MOUSE_BUTTON_WHEEL_UP)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_get_events(action).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_get_events(action).is_empty():
		return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
