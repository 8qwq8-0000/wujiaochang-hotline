extends CanvasLayer

@onready var overlay: Control = $Overlay
@onready var health_label: Label = $Overlay/TopLeft/Health
@onready var heat_label: Label = $Overlay/TopLeft/Heat
@onready var mobility_label: Label = $Overlay/TopLeft/Mobility
@onready var weapon_label: Label = $Overlay/TopLeft/Weapon
@onready var guard_label: Label = $Overlay/TopLeft/Guard
@onready var buff_label: Label = $Overlay/TopLeft/RoomBuff
@onready var objective_label: Label = $Overlay/Objective
@onready var notice_queue: CombatNoticeQueue = $Overlay/NoticeQueue

var _player: PlayerController
var _circuit_value: Label
var _circuit_protection_active := false
var _health_meter: SegmentMeter
var _takeover_meter: SegmentMeter
var _heat_meter: SegmentMeter
var _mobility_value: Label
var _weapon_value: Label
var _guard_value: Label
var _buff_value: Label
var _objective_value: Label
var _crt_overlay: CRTOverlay
var _operator_panel: TerminalPanel
var _operator_label: Label
var _operator_scanlines: Control
var _operator_audio: AudioStreamPlayer
var _operator_tween: Tween


func _ready() -> void:
	_build_cyber_hud()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.combat_message_requested.connect(show_message)
		events.combat_notice_requested.connect(_on_notice_requested)
		events.operator_communication_requested.connect(_show_operator_communication)
		events.combat_area_progress.connect(_on_area_progress)
		events.floor_cleared.connect(func() -> void: _set_objective_text("本层已清理：前往出口"))
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.mandatory_enemy_count_changed.connect(_on_enemy_count_changed)
	set_process(true)


func _process(_delta: float) -> void:
	$Overlay.visible = get_tree().get_nodes_in_group("warehouse").is_empty()
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if is_instance_valid(_player):
			_bind_player(_player)
	if not is_instance_valid(_player):
		return
	var health_state := _player.get_health_state()
	var heat_state := _player.get_heat_state()
	health_label.text = "耐久  %d / %d" % [health_state.current, health_state.maximum]
	heat_label.text = "热量  %03d / %03d%s" % [roundi(heat_state.current), roundi(heat_state.maximum), "  过热" if heat_state.overheated else ""]
	mobility_label.text = "机动  %s" % _player.get_mobility_display_name()
	weapon_label.text = "武装 %d/2  %s [Q/滚轮]" % [_player.weapons.current_index + 1, _player.get_weapon_display_name()]
	guard_label.text = "格挡  %s" % _guard_state_name(_player.get_guard_state())
	_health_meter.segments = int(health_state.maximum)
	_health_meter.set_meter(float(health_state.current), float(health_state.maximum))
	_update_circuit_status()
	_heat_meter.meter_color = CyberUITheme.DANGER if heat_state.overheated else CyberUITheme.WARNING
	_heat_meter.set_meter(float(heat_state.current), float(heat_state.maximum))
	var mobility_hint := "SPACE"
	if _player.mobility.get_current_mode() is WheelMobilityMode:
		mobility_hint = "冲撞 %.1fs" % _player.mobility.ability_cooldown_remaining if _player.mobility.ability_cooldown_remaining > 0.0 else "冲撞 SPACE"
	_mobility_value.text = "%s  // %s\n%s" % [_player.get_mobility_display_name(), mobility_hint, _player.get_node("DefenseComponent").display_state()]
	_weapon_value.text = "> %s  %s\n  Q/滚轮 切换" % ["A" if _player.weapons.current_index == 0 else "B", _player.get_weapon_display_name()]
	_guard_value.text = "格挡协议  %s" % _guard_state_name(_player.get_guard_state())
	if is_instance_valid(_player.talent_core):
		_takeover_meter.set_meter(float(_player.talent_core.takeover_charges), float(_player.talent_core.takeover_charge_max))


func _bind_player(player: PlayerController) -> void:
	_circuit_protection_active = false
	player.circuit_breaker.circuit_breaker_triggered.connect(_on_circuit_protection_triggered)
	player.tree_exiting.connect(func() -> void:
		_player = null
		buff_label.hide()
		if is_instance_valid(_buff_value):
			_buff_value.hide()
	)
	var room_buffs := player.get_node_or_null("RoomBuffComponent") as RoomBuffComponent
	if room_buffs != null and not room_buffs.changed.is_connected(_update_room_buff):
		room_buffs.changed.connect(_update_room_buff)
	_update_room_buff()


func _update_room_buff(_id: StringName = &"") -> void:
	if not is_instance_valid(_player):
		buff_label.hide()
		if is_instance_valid(_buff_value):
			_buff_value.hide()
		return
	var buffs := _player.get_node_or_null("RoomBuffComponent") as RoomBuffComponent
	var has_buff := buffs != null and not buffs.active_buff.is_empty()
	var buff_text := "增益  %s" % RoomBuffComponent.TITLES.get(buffs.active_buff, "") if has_buff else ""
	buff_label.visible = has_buff
	buff_label.text = buff_text
	if is_instance_valid(_buff_value):
		_buff_value.visible = has_buff
		_buff_value.text = "房间%s" % buff_text



func _on_enemy_count_changed(remaining: int) -> void:
	_set_objective_text("必杀目标剩余：%d" % remaining if remaining > 0 else "区域清理完成")


func show_message(text: String, color: Color = Color.WHITE) -> void:
	notice_queue.push_legacy(text, color)


func _on_notice_requested(notice: CombatNotice) -> void:
	notice_queue.push_notice(notice)


func _guard_state_name(state: GuardComponent.State) -> String:
	match state:
		GuardComponent.State.STARTUP:
			return "起手"
		GuardComponent.State.PERFECT:
			return "完美窗口"
		GuardComponent.State.NORMAL:
			return "普通窗口"
		GuardComponent.State.RECOVERY:
			return "后摇"
		_:
			return "就绪"


func _build_cyber_hud() -> void:
	overlay.theme = CyberUITheme.create_theme()
	health_label.get_parent().hide()
	objective_label.hide()

	var status := _make_panel("机体状态 / UNIT", Rect2(8, 31, 175, 100))
	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 2)
	status.add_child(status_stack)
	_health_meter = _make_meter("耐久", 3.0, 3.0, 3, CyberUITheme.PHOSPHOR)
	_takeover_meter = _make_meter("接管", 1.0, 1.0, 3, CyberUITheme.HIGHLIGHT)
	status_stack.add_child(_health_meter)
	status_stack.add_child(_takeover_meter)
	_circuit_value = Label.new()
	_circuit_value.text = "断路保险  就绪"
	status_stack.add_child(_circuit_value)
	_buff_value = Label.new()
	_buff_value.hide()
	status_stack.add_child(_buff_value)

	var objective := _make_panel("任务 / OBJECTIVE", Rect2(457, 31, 175, 66))
	_objective_value = Label.new()
	_objective_value.text = objective_label.text
	_objective_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(_objective_value)

	var mobility := _make_panel("机动 / 防御", Rect2(8, 274, 175, 78))
	_mobility_value = Label.new()
	_mobility_value.text = "步行（无套件）"
	_mobility_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mobility.add_child(_mobility_value)

	var weapons := _make_panel("火控 / WEAPON", Rect2(457, 256, 175, 96))
	var weapon_stack := VBoxContainer.new()
	weapon_stack.add_theme_constant_override("separation", 2)
	weapons.add_child(weapon_stack)
	_weapon_value = Label.new()
	_weapon_value.text = "> SLOT-A  武装链路"
	_weapon_value.custom_minimum_size.y = 28.0
	_weapon_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	_weapon_value.clip_text = true
	_weapon_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weapon_stack.add_child(_weapon_value)
	_heat_meter = _make_meter("热量", 0.0, 100.0, 10, CyberUITheme.WARNING)
	weapon_stack.add_child(_heat_meter)
	_guard_value = Label.new()
	_guard_value.text = "格挡协议  就绪"
	weapon_stack.add_child(_guard_value)

	notice_queue.position = Vector2(225, 244)
	notice_queue.size = Vector2(190, 108)
	notice_queue.add_theme_constant_override("separation", 3)

	_crt_overlay = CRTOverlay.new()
	_crt_overlay.name = "CRTOverlay"
	_crt_overlay.strength = _saved_crt_strength()
	overlay.add_child(_crt_overlay)
	_build_operator_overlay()


func _build_operator_overlay() -> void:
	_operator_panel = _make_panel("接线员 / PERSONAL AI", Rect2(170, 112, 300, 76))
	_operator_panel.hide()
	_operator_label = Label.new()
	_operator_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_operator_label.modulate = Color("b9f8d2")
	_operator_panel.add_child(_operator_label)
	_operator_scanlines = Control.new()
	_operator_scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_operator_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_operator_scanlines.hide()
	_operator_panel.add_child(_operator_scanlines)
	for y in range(4, 72, 6):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(300, 1)
		line.color = Color(0.25, 1.0, 0.62, 0.14)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_operator_scanlines.add_child(line)
	_operator_audio = AudioStreamPlayer.new()
	_operator_audio.bus = &"SFX"
	_operator_audio.volume_db = -18.0
	_operator_audio.stream = _make_radio_static()
	add_child(_operator_audio)


func _show_operator_communication(text: String) -> void:
	if _operator_tween != null and _operator_tween.is_valid():
		_operator_tween.kill()
	_operator_label.text = text
	_operator_panel.modulate = Color.WHITE
	_operator_panel.show()
	_operator_scanlines.show()
	_operator_audio.play()
	_operator_tween = create_tween()
	_operator_tween.tween_interval(0.25)
	_operator_tween.tween_callback(_operator_scanlines.hide)
	_operator_tween.tween_interval(1.55)
	_operator_tween.tween_property(_operator_panel, "modulate:a", 0.0, 0.2)
	_operator_tween.tween_callback(_operator_panel.hide)


func _make_radio_static() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 12000
	stream.stereo = false
	var samples := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0DE51
	for index in 1800:
		var envelope := 1.0 - float(index) / 1800.0
		samples.append(clampi(128 + roundi(float(rng.randi_range(-48, 48)) * envelope), 0, 255))
	stream.data = samples
	return stream


func _make_panel(title_text: String, rect: Rect2) -> TerminalPanel:
	var panel := TerminalPanel.new()
	panel.title = title_text
	panel.panel_color = Color(CyberUITheme.PANEL, 0.68)
	panel.position = rect.position
	panel.size = rect.size
	overlay.add_child(panel)
	return panel


func _make_meter(caption: String, value: float, maximum: float, segments: int, color: Color) -> SegmentMeter:
	var meter := SegmentMeter.new()
	meter.custom_minimum_size = Vector2(145.0, 16.0)
	meter.caption = caption
	meter.value = value
	meter.maximum = maximum
	meter.segments = segments
	meter.meter_color = color
	return meter


func _set_objective_text(text: String) -> void:
	objective_label.text = text
	if is_instance_valid(_objective_value):
		_objective_value.text = text


func _saved_crt_strength() -> CRTOverlay.Strength:
	var saved := int(PlayerConfig.get_config(&"UISettings", &"CRTStrength", CRTOverlay.Strength.LOW))
	return clampi(saved, CRTOverlay.Strength.OFF, CRTOverlay.Strength.STANDARD) as CRTOverlay.Strength


func _on_area_progress(index: int, total: int, remaining: int, cleared: bool) -> void:
	if cleared and index < total:
		_set_objective_text("区域 %d/%d 已清场\n前往下一区 →" % [index, total])
	else:
		_set_objective_text("区域 %d/%d\n必杀目标剩余：%d" % [index, total, remaining])


func _on_circuit_protection_triggered() -> void:
	_circuit_protection_active = true


func _update_circuit_status() -> void:
	var circuit := _player.circuit_breaker
	if _circuit_protection_active and not _player.hurt_box.is_invulnerable():
		_circuit_protection_active = false
	var tint := CyberUITheme.PHOSPHOR
	_health_meter.caption = "耐久"
	if _circuit_protection_active:
		_health_meter.caption = "保护中"
		tint = CyberUITheme.WARNING
		_circuit_value.text = "断路保险触发 · 保护中"
	elif not circuit.equipped:
		_circuit_value.text = "断路保险  未装备"
		tint = CyberUITheme.MUTED
	elif circuit.circuit_breaker_used:
		_circuit_value.text = "断路保险  已消耗"
		tint = CyberUITheme.MUTED
	else:
		_circuit_value.text = "断路保险  就绪"
	_circuit_value.add_theme_color_override("font_color", tint)
	_health_meter.meter_color = CyberUITheme.WARNING if _circuit_protection_active or circuit.circuit_breaker_used else CyberUITheme.PHOSPHOR
