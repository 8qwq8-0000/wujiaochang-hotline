extends CanvasLayer

signal layout_editor_closed

const ACTION_BUTTON := preload("res://scripts/mobile/mobile_action_button.gd")
const TARGET_INDICATOR := preload("res://scripts/mobile/mobile_target_indicator.gd")
const SETTINGS_SECTION := &"MobileControls"
const LAYOUT_RIGHT := &"LayoutRight"
const LAYOUT_LEFT := &"LayoutLeft"
const TOUCH_PREVIEW := &"TouchPreview"
const LEFT_HANDED := &"LeftHanded"
const HAPTICS := &"Haptics"
const TARGET_INDICATOR_SETTING := &"TargetIndicator"
const TUTORIAL_SHOWN := &"TutorialShown"
const TARGET_REFRESH_SECONDS := 0.1

const CONTROL_INFO := {
	"move": {"caption": "移动", "size": 116.0},
	"attack": {"caption": "攻击", "size": 92.0},
	"guard": {"caption": "盾反", "size": 50.0},
	"dash": {"caption": "突进", "size": 48.0},
	"interact": {"caption": "交互", "size": 46.0},
	"weapon": {"caption": "换枪", "size": 44.0},
	"inventory": {"caption": "背包", "size": 40.0},
	"pause": {"caption": "暂停", "size": 36.0},
}

var _root: Control
var _joystick: VirtualJoystick
var _buttons: Dictionary = {}
var _controls: Dictionary = {}
var _indicator: MobileTargetIndicator
var _player: PlayerController
var _target: Node2D
var _manual_aim := Vector2.ZERO
var _manual_source: StringName
var _target_refresh_remaining := 0.0
var _using_touch := true
var _touch_preview := false
var _left_handed := false
var _haptics := true
var _show_target_indicator := true
var _layout: Dictionary = {}
var _editing := false
var _selected_control := ""
var _editor_drag_control := ""
var _editor_drag_offset := Vector2.ZERO
var _editor_toolbar: PanelContainer
var _editor_name: Label
var _tutorial: ColorRect
var _tutorial_owns_pause := false
var _background_pause_pending := false
var _background_audio_muted := false
var _background_master_was_muted := false


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_controls()
	_build_editor_toolbar()
	_build_tutorial()
	get_viewport().size_changed.connect(_layout_controls)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.perfect_guarded.connect(func(_result: DamageResult) -> void: vibrate(&"perfect"))
		events.damage_resolved.connect(_on_damage_resolved)
	_layout_controls()


func _process(delta: float) -> void:
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController
	var gameplay_visible := _should_show_gameplay_controls()
	_root.visible = gameplay_visible or _editing
	_editor_toolbar.visible = _editing
	if _editing:
		return
	if not gameplay_visible:
		_clear_manual_aim()
		return
	_buttons.interact.visible = _has_available_interaction()
	_target_refresh_remaining = maxf(_target_refresh_remaining - delta, 0.0)
	if _target_refresh_remaining <= 0.0:
		_target_refresh_remaining = TARGET_REFRESH_SECONDS
		_refresh_target()
	_indicator.target = _target
	_indicator.manual_override = not _manual_aim.is_zero_approx()
	_indicator.enabled = _show_target_indicator
	if OS.has_feature("mobile") and not bool(PlayerConfig.get_config(SETTINGS_SECTION, TUTORIAL_SHOWN, false)):
		call_deferred("show_touch_tutorial")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_using_touch = true
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_touch = false
	if _editing:
		_handle_editor_input(event)


func is_touch_aim_active(player: PlayerController) -> bool:
	return player == _player and _should_show_gameplay_controls()


func get_aim_direction(player: PlayerController, fallback: Vector2) -> Vector2:
	if not is_touch_aim_active(player):
		return fallback
	if not _manual_aim.is_zero_approx():
		return _manual_aim.normalized()
	if _is_target_valid(_target):
		return player.global_position.direction_to(_target.global_position)
	return fallback


func get_aim_world_position(player: PlayerController, fallback: Vector2) -> Vector2:
	if not is_touch_aim_active(player):
		return fallback
	if _is_target_valid(_target) and _manual_aim.is_zero_approx():
		return _target.global_position
	return player.global_position + get_aim_direction(player, player.aim_direction) * 96.0


func set_touch_preview(enabled: bool) -> void:
	_touch_preview = enabled
	PlayerConfig.set_config(SETTINGS_SECTION, TOUCH_PREVIEW, enabled)


func is_touch_preview_enabled() -> bool:
	return _touch_preview


func set_left_handed(enabled: bool) -> void:
	_save_layout()
	_left_handed = enabled
	PlayerConfig.set_config(SETTINGS_SECTION, LEFT_HANDED, enabled)
	_load_layout()
	_layout_controls()


func is_left_handed() -> bool:
	return _left_handed


func set_haptics_enabled(enabled: bool) -> void:
	_haptics = enabled
	PlayerConfig.set_config(SETTINGS_SECTION, HAPTICS, enabled)


func is_haptics_enabled() -> bool:
	return _haptics


func set_target_indicator_enabled(enabled: bool) -> void:
	_show_target_indicator = enabled
	PlayerConfig.set_config(SETTINGS_SECTION, TARGET_INDICATOR_SETTING, enabled)


func is_target_indicator_enabled() -> bool:
	return _show_target_indicator


func vibrate(kind: StringName) -> void:
	if not _haptics or not OS.has_feature("mobile"):
		return
	var duration := 18
	var amplitude := 0.35
	match kind:
		&"perfect":
			duration = 42
			amplitude = 0.8
		&"damage":
			duration = 55
			amplitude = 0.65
	Input.vibrate_handheld(duration, amplitude)


func begin_layout_edit() -> void:
	_editing = true
	_using_touch = true
	_selected_control = "attack"
	_root.visible = true
	_editor_toolbar.visible = true
	for button: MobileActionButton in _buttons.values():
		button.visible = true
		button.set_editing(true)
	_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_editor_label()
	_layout_controls()


func finish_layout_edit() -> void:
	if not _editing:
		return
	_editing = false
	_editor_drag_control = ""
	_save_layout()
	for button: MobileActionButton in _buttons.values():
		button.set_editing(false)
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_controls()
	layout_editor_closed.emit()


func reset_layout(left_handed: bool = _left_handed) -> void:
	_left_handed = left_handed
	PlayerConfig.set_config(SETTINGS_SECTION, LEFT_HANDED, left_handed)
	_layout = _default_layout(left_handed)
	_save_layout()
	_layout_controls()


func show_touch_tutorial(force: bool = false) -> void:
	if _tutorial.visible or (_player == null and not force):
		return
	if not force and bool(PlayerConfig.get_config(SETTINGS_SECTION, TUTORIAL_SHOWN, false)):
		return
	_tutorial_owns_pause = not get_tree().paused
	get_tree().paused = true
	_tutorial.show()


func _load_settings() -> void:
	_touch_preview = bool(PlayerConfig.get_config(SETTINGS_SECTION, TOUCH_PREVIEW, false))
	_left_handed = bool(PlayerConfig.get_config(SETTINGS_SECTION, LEFT_HANDED, false))
	_haptics = bool(PlayerConfig.get_config(SETTINGS_SECTION, HAPTICS, true))
	_show_target_indicator = bool(PlayerConfig.get_config(SETTINGS_SECTION, TARGET_INDICATOR_SETTING, true))
	_load_layout()


func _load_layout() -> void:
	var key := LAYOUT_LEFT if _left_handed else LAYOUT_RIGHT
	var saved: Variant = PlayerConfig.get_config(SETTINGS_SECTION, key, {})
	_layout = saved.duplicate(true) if saved is Dictionary and not saved.is_empty() else _default_layout(_left_handed)
	for control_name in CONTROL_INFO:
		if not _layout.has(control_name):
			_layout[control_name] = _default_layout(_left_handed)[control_name]


func _save_layout() -> void:
	var key := LAYOUT_LEFT if _left_handed else LAYOUT_RIGHT
	PlayerConfig.set_config(SETTINGS_SECTION, key, _layout)


func _default_layout(left_handed: bool) -> Dictionary:
	var result := {
		"move": {"position": Vector2(0.14, 0.74), "scale": 1.0, "opacity": 0.78},
		"attack": {"position": Vector2(0.88, 0.74), "scale": 1.0, "opacity": 0.84},
		"guard": {"position": Vector2(0.76, 0.68), "scale": 1.0, "opacity": 0.84},
		"dash": {"position": Vector2(0.79, 0.86), "scale": 1.0, "opacity": 0.84},
		"interact": {"position": Vector2(0.9, 0.52), "scale": 1.0, "opacity": 0.9},
		"weapon": {"position": Vector2(0.69, 0.85), "scale": 1.0, "opacity": 0.8},
		"inventory": {"position": Vector2(0.91, 0.16), "scale": 1.0, "opacity": 0.82},
		"pause": {"position": Vector2(0.96, 0.08), "scale": 1.0, "opacity": 0.82},
	}
	if left_handed:
		for entry: Dictionary in result.values():
			var position: Vector2 = entry.position
			entry.position = Vector2(1.0 - position.x, position.y)
	return result


func _build_controls() -> void:
	_root = Control.new()
	_root.name = "TouchControls"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_joystick = VirtualJoystick.new()
	_joystick.name = "MoveJoystick"
	_joystick.action_left = &"move_left"
	_joystick.action_right = &"move_right"
	_joystick.action_up = &"move_up"
	_joystick.action_down = &"move_down"
	_joystick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	_joystick.deadzone_ratio = 0.12
	_joystick.clampzone_ratio = 0.9
	_joystick.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	_apply_joystick_theme()
	_root.add_child(_joystick)
	_controls.move = _joystick
	_add_action_button("attack", &"attack", Color("58d8e8"), true, true)
	_add_action_button("guard", &"guard", Color("f1c75b"), true)
	_add_action_button("dash", &"mobility_ability", Color("d45bff"))
	_add_action_button("interact", &"interact", Color("7cf29a"))
	_add_action_button("weapon", &"weapon_switch", Color("ff8f62"))
	_add_action_button("inventory", &"inventory_toggle", Color("79a9ff"))
	_add_action_button("pause", &"pause", Color("a8b7c8"))
	_indicator = TARGET_INDICATOR.new()
	_indicator.name = "TargetIndicator"
	_root.add_child(_indicator)
	_root.move_child(_indicator, 0)


func _add_action_button(
	control_name: String,
	action: StringName,
	color: Color,
	directional: bool = false,
	as_joystick: bool = false
) -> void:
	var button: MobileActionButton = ACTION_BUTTON.new()
	button.name = control_name.capitalize() + "Button"
	button.configure(action, String(CONTROL_INFO[control_name].caption), color, directional, as_joystick)
	if directional:
		button.aim_vector_changed.connect(_on_manual_aim_changed.bind(action))
	if control_name == "attack":
		button.tap_triggered.connect(_on_attack_tapped)
	_root.add_child(button)
	_buttons[control_name] = button
	_controls[control_name] = button


func _apply_joystick_theme() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.025, 0.045, 0.08, 0.58)
	base.border_color = Color(0.25, 0.82, 0.9, 0.88)
	base.set_border_width_all(2)
	base.set_corner_radius_all(64)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.25, 0.86, 0.94, 0.55)
	tip.border_color = Color(0.75, 0.96, 1.0, 0.95)
	tip.set_border_width_all(2)
	tip.set_corner_radius_all(40)
	_joystick.add_theme_stylebox_override("normal_joystick", base)
	_joystick.add_theme_stylebox_override("pressed_joystick", base)
	_joystick.add_theme_stylebox_override("normal_tip", tip)
	_joystick.add_theme_stylebox_override("pressed_tip", tip)


func _layout_controls() -> void:
	if _root == null:
		return
	var safe := _safe_rect()
	for control_name in _controls:
		var control := _controls[control_name] as Control
		var entry: Dictionary = _layout.get(control_name, _default_layout(_left_handed)[control_name])
		var base_size := float(CONTROL_INFO[control_name].size)
		var scale_value := clampf(float(entry.get("scale", 1.0)), 0.65, 1.6)
		var control_size := Vector2.ONE * base_size * scale_value
		var normalized: Vector2 = entry.get("position", Vector2(0.5, 0.5))
		var center := safe.position + normalized * safe.size
		center.x = clampf(center.x, safe.position.x + control_size.x * 0.5, safe.end.x - control_size.x * 0.5)
		center.y = clampf(center.y, safe.position.y + control_size.y * 0.5, safe.end.y - control_size.y * 0.5)
		control.position = center - control_size * 0.5
		control.size = control_size
		control.modulate.a = clampf(float(entry.get("opacity", 0.82)), 0.25, 1.0)
		if control == _joystick:
			_joystick.joystick_size = control_size.x * 0.78
			_joystick.tip_size = control_size.x * 0.38


func _safe_rect() -> Rect2:
	var viewport_rect := get_viewport().get_visible_rect()
	if not OS.has_feature("mobile"):
		return viewport_rect.grow(-6.0)
	var window_size := Vector2(DisplayServer.window_get_size())
	var display_safe := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or display_safe.size == Vector2i.ZERO:
		return viewport_rect.grow(-6.0)
	var factor := viewport_rect.size / window_size
	return Rect2(Vector2(display_safe.position) * factor, Vector2(display_safe.size) * factor).grow(-6.0)


func _should_show_gameplay_controls() -> bool:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if not (OS.has_feature("mobile") or _touch_preview):
		return false
	if not _using_touch or get_tree().paused or not _player.is_input_enabled() or _player.inventory.is_open:
		return false
	return true


func _has_available_interaction() -> bool:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if _player.interactor.get_best_target(_player) != null:
		return true
	return _player.inventory.get_nearest_reachable_pickup() != null


func _refresh_target(force_reselect: bool = false) -> void:
	if not _manual_aim.is_zero_approx():
		return
	if not force_reselect and _is_target_valid(_target):
		return
	_target = null
	if _player == null:
		return
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"bosses"):
		var candidate := node as Node2D
		if not _is_target_valid(candidate):
			continue
		var score := _target_score(candidate)
		if score < best_score:
			best_score = score
			_target = candidate


func _target_score(candidate: Node2D) -> float:
	var offset := candidate.global_position - _player.global_position
	var distance := offset.length()
	var direction := offset / distance if distance > 0.001 else _player.aim_direction
	var facing := clampf(_player.aim_direction.normalized().dot(direction), -1.0, 1.0)
	var score := distance + (1.0 - facing) * 48.0
	var weapon := _player.weapons.get_current_weapon()
	if weapon != null and distance <= weapon.attack_range + 12.0:
		score -= 96.0
	return score


func _is_target_valid(candidate: Node2D) -> bool:
	if _player == null or not is_instance_valid(candidate) or not candidate.is_inside_tree():
		return false
	var health := candidate.get_node_or_null("HealthComponent")
	if health != null and health.has_method("is_dead") and health.is_dead():
		return false
	if CombatProjectile.room_for_actor(candidate) != CombatProjectile.room_for_actor(_player):
		return false
	var camera := _player.get_viewport().get_camera_2d()
	if camera == null:
		return false
	var visible_size := _player.get_viewport_rect().size / camera.zoom
	var visible_world := Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size).grow(8.0)
	if not visible_world.has_point(candidate.global_position):
		return false
	var ray := PhysicsRayQueryParameters2D.create(_player.global_position, candidate.global_position, 1)
	return _player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _on_manual_aim_changed(vector: Vector2, active: bool, source: StringName) -> void:
	if active:
		_manual_source = source
		_manual_aim = vector.normalized()
		_target = null
	elif _manual_source == source:
		_clear_manual_aim()


func _on_attack_tapped() -> void:
	_clear_manual_aim()
	_refresh_target(true)


func is_manual_attack_active(player: PlayerController) -> bool:
	return player == _player and _manual_source == &"attack" and not _manual_aim.is_zero_approx()


func _clear_manual_aim() -> void:
	_manual_aim = Vector2.ZERO
	_manual_source = &""


func _on_damage_resolved(result: DamageResult) -> void:
	if _player != null and result != null and result.target == _player and result.final_damage > 0:
		vibrate(&"damage")


func _build_editor_toolbar() -> void:
	_editor_toolbar = PanelContainer.new()
	_editor_toolbar.process_mode = Node.PROCESS_MODE_ALWAYS
	_editor_toolbar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_editor_toolbar.position = Vector2(-235, 8)
	_editor_toolbar.custom_minimum_size = Vector2(470, 44)
	add_child(_editor_toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_editor_toolbar.add_child(row)
	_editor_name = Label.new()
	_editor_name.custom_minimum_size.x = 90
	row.add_child(_editor_name)
	_add_editor_button(row, "缩小", func() -> void: _change_selected("scale", -0.1))
	_add_editor_button(row, "放大", func() -> void: _change_selected("scale", 0.1))
	_add_editor_button(row, "更淡", func() -> void: _change_selected("opacity", -0.1))
	_add_editor_button(row, "更亮", func() -> void: _change_selected("opacity", 0.1))
	_add_editor_button(row, "右手默认", func() -> void: reset_layout(false))
	_add_editor_button(row, "左手默认", func() -> void: reset_layout(true))
	_add_editor_button(row, "完成", finish_layout_edit)
	_editor_toolbar.hide()


func _add_editor_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _handle_editor_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var dragging := false
	if event is InputEventScreenTouch:
		point = (event as InputEventScreenTouch).position
		pressed = (event as InputEventScreenTouch).pressed
		released = not pressed
	elif event is InputEventScreenDrag:
		point = (event as InputEventScreenDrag).position
		dragging = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		point = (event as InputEventMouseButton).position
		pressed = (event as InputEventMouseButton).pressed
		released = not pressed
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		point = (event as InputEventMouseMotion).position
		dragging = true
	else:
		return
	if pressed:
		for control_name in _controls.keys():
			var control := _controls[control_name] as Control
			if control.get_global_rect().has_point(point):
				_selected_control = control_name
				_editor_drag_control = control_name
				_editor_drag_offset = point - control.get_global_rect().get_center()
				_sync_editor_label()
				get_viewport().set_input_as_handled()
				return
	elif dragging and not _editor_drag_control.is_empty():
		var safe := _safe_rect()
		var center := point - _editor_drag_offset
		var normalized := (center - safe.position) / safe.size
		(_layout[_editor_drag_control] as Dictionary).position = Vector2(clampf(normalized.x, 0.0, 1.0), clampf(normalized.y, 0.0, 1.0))
		_layout_controls()
		get_viewport().set_input_as_handled()
	elif released:
		_editor_drag_control = ""


func _change_selected(property_name: String, amount: float) -> void:
	if _selected_control.is_empty() or not _layout.has(_selected_control):
		return
	var entry: Dictionary = _layout[_selected_control]
	if property_name == "scale":
		entry.scale = clampf(float(entry.get("scale", 1.0)) + amount, 0.65, 1.6)
	else:
		entry.opacity = clampf(float(entry.get("opacity", 0.82)) + amount, 0.25, 1.0)
	_layout_controls()


func _sync_editor_label() -> void:
	_editor_name.text = "编辑：%s" % String(CONTROL_INFO.get(_selected_control, {"caption": "控件"}).caption)


func _build_tutorial() -> void:
	_tutorial = ColorRect.new()
	_tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.color = Color(0.01, 0.02, 0.04, 0.9)
	_tutorial.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_tutorial)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 250)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "触控作战"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var body := Label.new()
	body.text = "左侧摇杆移动。\n点按攻击摇杆会自动选择当前最优敌人并攻击一次；向外拖动则按摇杆方向手动瞄准并持续攻击。\n盾反键向外拖动可手动指定防御方向。摇杆有方向时突进按移动方向发动，回中时按当前朝向发动。\n交互键只在附近存在可交互目标或可拾取装备时显示。\n可在设置中编辑按键位置、大小和透明度。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var confirm := Button.new()
	confirm.text = "知道了"
	confirm.pressed.connect(_close_tutorial)
	column.add_child(confirm)
	_tutorial.hide()


func _close_tutorial() -> void:
	PlayerConfig.set_config(SETTINGS_SECTION, TUTORIAL_SHOWN, true)
	_tutorial.hide()
	if _tutorial_owns_pause:
		get_tree().paused = false
	_tutorial_owns_pause = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_system_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if OS.has_feature("mobile") and not _background_pause_pending:
			_mute_for_background()
			_background_pause_pending = true
			call_deferred("_pause_for_background")
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_background_pause_pending = false
		_restore_background_audio()


func _handle_system_back() -> void:
	if _tutorial.visible:
		_close_tutorial()
		return
	if _editing:
		finish_layout_edit()
		return
	var menu := get_tree().get_first_node_in_group(&"pause_menu") as PauseSettingsMenu
	if menu != null and menu.visible:
		menu.close_menu()
		return
	if menu != null and not get_tree().paused:
		menu.open_menu()
		return
	# A modal owner such as inventory or synthesis is already paused. Let its
	# existing pause action unwind itself instead of stealing pause ownership.
	var back := InputEventAction.new()
	back.action = &"pause"
	back.pressed = true
	Input.parse_input_event(back)
	back = back.duplicate()
	back.pressed = false
	Input.parse_input_event(back)


func _pause_for_background() -> void:
	_background_pause_pending = false
	if get_tree().paused:
		return
	var menu := get_tree().get_first_node_in_group(&"pause_menu") as PauseSettingsMenu
	if menu != null:
		menu.open_menu()
	else:
		get_tree().paused = true


func _mute_for_background() -> void:
	if _background_audio_muted:
		return
	var master := AudioServer.get_bus_index(&"Master")
	if master < 0:
		return
	_background_master_was_muted = AudioServer.is_bus_mute(master)
	AudioServer.set_bus_mute(master, true)
	_background_audio_muted = true


func _restore_background_audio() -> void:
	if not _background_audio_muted:
		return
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, _background_master_was_muted)
	_background_audio_muted = false
