class_name CyberUIShowcase
extends Control

enum Workspace { COMBAT, SETTINGS }

var _combat_workspace: Control
var _settings_workspace: Control
var _boot_panel: TerminalPanel
var _crt_overlay: CRTOverlay
var _workspace := Workspace.COMBAT
var _crt_strength := CRTOverlay.Strength.LOW


func _ready() -> void:
	theme = CyberUITheme.create_theme()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_header()
	_combat_workspace = Control.new()
	_combat_workspace.name = "CombatWorkspace"
	_combat_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_combat_workspace)
	_build_combat_workspace()
	_settings_workspace = Control.new()
	_settings_workspace.name = "SettingsWorkspace"
	_settings_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_workspace)
	_build_settings_workspace()
	_build_footer()
	_build_boot_panel()
	_crt_overlay = CRTOverlay.new()
	_crt_overlay.name = "CRTOverlay"
	_crt_overlay.strength = _crt_strength
	add_child(_crt_overlay)
	show_workspace(Workspace.COMBAT)
	if DisplayServer.get_name() == "headless":
		skip_boot()
	else:
		_play_boot_sequence()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CyberUITheme.BACKGROUND)
	for x in range(0, int(size.x) + 1, 16):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(CyberUITheme.DIM_GREEN, 0.09), 1.0)
	for y in range(0, int(size.y) + 1, 16):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(CyberUITheme.DIM_GREEN, 0.09), 1.0)
	if _workspace == Workspace.COMBAT:
		var center := size * 0.5
		draw_arc(center, 8.0, 0.0, TAU, 16, CyberUITheme.PHOSPHOR, 1.0)
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + direction * 11.0, center + direction * 17.0, CyberUITheme.PHOSPHOR, 1.0)
		draw_line(Vector2(center.x - 42.0, center.y - 32.0), Vector2(center.x - 30.0, center.y - 32.0), Color(CyberUITheme.PHOSPHOR, 0.55), 1.0)
		draw_line(Vector2(center.x + 30.0, center.y - 32.0), Vector2(center.x + 42.0, center.y - 32.0), Color(CyberUITheme.PHOSPHOR, 0.55), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _boot_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_1: show_workspace(Workspace.COMBAT)
				KEY_2: show_workspace(Workspace.SETTINGS)
				KEY_3: cycle_crt_strength()
				KEY_G: trigger_demo_glitch()
		return
	if event.is_pressed():
		skip_boot()


func show_workspace(next_workspace: Workspace) -> void:
	_workspace = next_workspace
	if is_instance_valid(_combat_workspace):
		_combat_workspace.visible = _workspace == Workspace.COMBAT
	if is_instance_valid(_settings_workspace):
		_settings_workspace.visible = _workspace == Workspace.SETTINGS
	queue_redraw()


func get_workspace_name() -> StringName:
	return &"combat" if _workspace == Workspace.COMBAT else &"settings"


func cycle_crt_strength() -> void:
	match _crt_strength:
		CRTOverlay.Strength.OFF:
			_crt_strength = CRTOverlay.Strength.LOW
		CRTOverlay.Strength.LOW:
			_crt_strength = CRTOverlay.Strength.STANDARD
		_:
			_crt_strength = CRTOverlay.Strength.OFF
	if is_instance_valid(_crt_overlay):
		_crt_overlay.set_strength(_crt_strength)


func get_crt_strength() -> CRTOverlay.Strength:
	return _crt_strength


func trigger_demo_glitch() -> void:
	if is_instance_valid(_crt_overlay):
		_crt_overlay.trigger_event_glitch()


func skip_boot() -> void:
	if is_instance_valid(_boot_panel):
		_boot_panel.hide()


func _build_header() -> void:
	var header := _make_panel(self, "WJC COMBAT TERMINAL // 接线员链路: ONLINE", Rect2(8, 5, 624, 27))
	header.name = "SystemHeader"


func _build_footer() -> void:
	var footer := _make_panel(self, "[1] 战斗  [2] 设置  [3] CRT强度  [G] 事件故障", Rect2(126, 333, 388, 22), CyberUITheme.DIM_GREEN)
	footer.name = "CommandFooter"


func _build_combat_workspace() -> void:
	var status := _make_panel(_combat_workspace, "机体状态 / UNIT", Rect2(8, 39, 205, 91))
	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 2)
	status.add_child(status_stack)
	status_stack.add_child(_meter("耐久", 3, 4, 4, CyberUITheme.PHOSPHOR))
	status_stack.add_child(_meter("接管", 2, 3, 3, CyberUITheme.HIGHLIGHT))
	var circuit := Label.new()
	circuit.text = "断路保险  ARMED"
	status_stack.add_child(circuit)

	var objective := _make_panel(_combat_workspace, "任务 / OBJECTIVE", Rect2(427, 39, 205, 74))
	var objective_stack := VBoxContainer.new()
	objective_stack.add_theme_constant_override("separation", 2)
	objective.add_child(objective_stack)
	var objective_label := Label.new()
	objective_label.text = "必杀目标    03"
	objective_stack.add_child(objective_label)
	objective_stack.add_child(_meter("警戒", 2, 3, 3, CyberUITheme.WARNING))

	var mobility := _make_panel(_combat_workspace, "机动 / MOBILITY", Rect2(8, 258, 205, 70))
	var mobility_stack := VBoxContainer.new()
	mobility.add_child(mobility_stack)
	var mobility_name := Label.new()
	mobility_name.text = "四足套件  READY"
	mobility_stack.add_child(mobility_name)
	mobility_stack.add_child(_meter("充能", 8, 10, 10, CyberUITheme.PHOSPHOR))

	var weapons := _make_panel(_combat_workspace, "火控 / WEAPON", Rect2(427, 220, 205, 108))
	var weapon_stack := VBoxContainer.new()
	weapon_stack.add_theme_constant_override("separation", 1)
	weapons.add_child(weapon_stack)
	var slot_a := Label.new()
	slot_a.text = "> SLOT-A  制式手枪"
	weapon_stack.add_child(slot_a)
	weapon_stack.add_child(_meter("热量", 64, 100, 10, CyberUITheme.WARNING))
	var slot_b := Label.new()
	slot_b.text = "  SLOT-B  警棍"
	weapon_stack.add_child(slot_b)
	weapon_stack.add_child(_meter("热量", 18, 100, 10, CyberUITheme.PHOSPHOR))

	var notices := VBoxContainer.new()
	notices.name = "NoticeStack"
	notices.position = Vector2(218, 199)
	notices.size = Vector2(204, 129)
	notices.add_theme_constant_override("separation", 3)
	_combat_workspace.add_child(notices)
	notices.add_child(_notice("接线员", "保持移动，火控链路正常。", CyberUITheme.PHOSPHOR))
	notices.add_child(_notice("ALERT", "同房间敌人已响应。", CyberUITheme.WARNING))
	notices.add_child(_notice("GUARD", "完美格挡：反射完成。", CyberUITheme.HIGHLIGHT))


func _build_settings_workspace() -> void:
	var panel := _make_panel(_settings_workspace, "系统设置 / SYSTEM CONFIG", Rect2(95, 43, 450, 282))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var video_title := Label.new()
	video_title.text = "┤ 视频与界面"
	content.add_child(video_title)
	var resolution := OptionButton.new()
	for label in ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"]:
		resolution.add_item(label)
	resolution.select(0)
	content.add_child(resolution)
	var crt_row := HBoxContainer.new()
	crt_row.add_child(_static_label("显像管效果", 105.0))
	for definition in [["关闭", CRTOverlay.Strength.OFF], ["低", CRTOverlay.Strength.LOW], ["标准", CRTOverlay.Strength.STANDARD]]:
		var button := Button.new()
		button.text = definition[0]
		button.pressed.connect(func() -> void:
			_crt_strength = definition[1]
			_crt_overlay.set_strength(_crt_strength)
		)
		crt_row.add_child(button)
	content.add_child(crt_row)
	var audio_title := Label.new()
	audio_title.text = "┤ 音频"
	content.add_child(audio_title)
	for bus_name in ["总音量", "音乐", "音效"]:
		var row := HBoxContainer.new()
		row.add_child(_static_label(bus_name, 105.0))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.value = 75
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		row.add_child(_static_label("075%", 42.0))
		content.add_child(row)
	var difficulty_title := Label.new()
	difficulty_title.text = "┤ 难度"
	content.add_child(difficulty_title)
	var difficulty := CheckButton.new()
	difficulty.text = "[OFF] 高压难度  // 标准响应 320 px"
	content.add_child(difficulty)
	var hint := Label.new()
	hint.theme_type_variation = &"TerminalMutedLabel"
	hint.text = "[ESC] 返回    [方向键] 调整    [ENTER] 确认"
	content.add_child(hint)


func _build_boot_panel() -> void:
	_boot_panel = _make_panel(self, "WJC BOOT SEQUENCE", Rect2(155, 96, 330, 164), CyberUITheme.HIGHLIGHT)
	_boot_panel.name = "BootPanel"
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	_boot_panel.add_child(lines)
	for text in ["WJC COMBAT TERMINAL", "耐久系统 ........ ONLINE", "武器与机动接口 ... ONLINE", "接线员链路 ....... CONNECTED"]:
		var label := Label.new()
		label.text = text
		label.modulate.a = 0.0
		lines.add_child(label)


func _play_boot_sequence() -> void:
	var tween := create_tween()
	for label in _boot_panel.get_child(0).get_children():
		tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_interval(0.3)
	tween.tween_callback(skip_boot)


func _make_panel(parent: Control, title_text: String, rect: Rect2, color: Color = CyberUITheme.PHOSPHOR) -> TerminalPanel:
	var panel := TerminalPanel.new()
	panel.title = title_text
	panel.accent_color = color
	panel.position = rect.position
	panel.size = rect.size
	parent.add_child(panel)
	return panel


func _meter(caption: String, value: float, maximum: float, segments: int, color: Color) -> SegmentMeter:
	var meter := SegmentMeter.new()
	meter.caption = caption
	meter.value = value
	meter.maximum = maximum
	meter.segments = segments
	meter.meter_color = color
	return meter


func _notice(title_text: String, message: String, color: Color) -> TerminalNotice:
	var notice := TerminalNotice.new()
	notice.title = title_text
	notice.message = message
	notice.accent_color = color
	notice.custom_minimum_size.y = 41.0
	return notice


func _static_label(text: String, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = width
	return label
