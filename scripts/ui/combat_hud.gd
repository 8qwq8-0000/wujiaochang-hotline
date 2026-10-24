extends CanvasLayer

const CONNECT_SOUND := preload("res://assets/audio/ui/hotline_connect.wav")
const PORTRAIT_JOHNNY := preload("res://assets/art/ui/start_menu/persona_johnny_ghost.png")
const PORTRAIT_NARAKU := preload("res://assets/art/ui/start_menu/persona_naraku_ghost.png")
const PORTRAIT_XIANGSHAN := preload("res://assets/art/ui/start_menu/persona_xiangshan_ghost.png")

const PERSONA_PRESENTATION := {
	TalentCoreController.DEEP_NINJA: {"name": "奈落 / NARAKU", "color": Color("ff4b55"), "portrait": PORTRAIT_NARAKU},
	TalentCoreController.LEGENDARY_MASTER: {"name": "相山 / XIANGSHAN", "color": Color("55d9ff"), "portrait": PORTRAIT_XIANGSHAN},
	TalentCoreController.ROCK_VIGILANTE: {"name": "强尼 / JOHNNY", "color": Color("ffe34a"), "portrait": PORTRAIT_JOHNNY},
}

@onready var overlay: Control = $Overlay
@onready var notice_queue: CombatNoticeQueue = $Overlay/NoticeQueue

var _player: PlayerController
var _top_left: Control
var _health_meter: SegmentMeter
var _armor_meter: SegmentMeter
var _heat_meter: SegmentMeter
var _overflow_heat_meter: SegmentMeter
var _heat_warning: Label
var _weapon_name: Label
var _weapon_preview: TextureRect
var _persona_root: Control
var _operator_panel: HoloCommsPanel
var _persona_status: PersonaStatusPanel
var _operator_audio: AudioStreamPlayer
var _comms: CombatCommsController
var _circuit_value: Label
var _circuit_protection_active := false
var _health_pulse_time := 0.0
var _heat_flash_tween: Tween
var _weapon_name_tween: Tween
var _health_meter_tween: Tween
var _damage_feedback: PlayerDamageFeedbackLayer
var _last_health_damage_usec := -1_000_000
var _scene_transition_active := false


func _ready() -> void:
	add_to_group(&"combat_hud")
	_build_minimal_hud()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.combat_message_requested.connect(show_message)
		events.combat_notice_requested.connect(_on_notice_requested)
		events.operator_communication_requested.connect(_show_operator_communication)
		events.combat_area_progress.connect(_on_area_progress)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.mandatory_enemy_count_changed.connect(_on_enemy_count_changed)
	var scene_flow := get_node_or_null("../SceneFlow") as SceneContainerManager
	if scene_flow != null:
		_scene_transition_active = not scene_flow.initial_scene.is_empty()
		scene_flow.load_started.connect(_on_scene_load_started)
		scene_flow.scene_swapped.connect(_on_scene_swapped)
		scene_flow.load_failed.connect(_on_scene_load_failed)
	overlay.hide()
	set_process(true)


func _process(delta: float) -> void:
	_health_pulse_time += delta
	overlay.visible = (
		not _scene_transition_active
		and is_instance_valid(_player)
		and get_tree().get_nodes_in_group("warehouse").is_empty()
		and get_tree().get_nodes_in_group("intermission").is_empty()
	)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if is_instance_valid(_player):
			_bind_player(_player)
	if not is_instance_valid(_player):
		return
	var health_state := _player.get_health_state()
	var heat_state := _player.get_heat_state()
	_health_meter.segments = int(health_state.maximum)
	_health_meter.set_meter(float(health_state.current), float(health_state.maximum))
	var defense := _player.get_node("DefenseComponent") as DefenseComponent
	_armor_meter.visible = defense.capacity() > 0
	if _armor_meter.visible:
		var block_height := minf(14.0, maxf(_health_meter.size.y - 4.0, 4.0))
		_armor_meter.position = Vector2(float(_health_meter.segments) * (block_height + 2.0), 0)
		_armor_meter.segments = defense.capacity()
		_armor_meter.set_meter(defense.charges(), defense.capacity())
	_update_circuit_status()
	if int(health_state.current) == 1 and not _circuit_protection_active:
		_health_meter.meter_color = CyberUITheme.DANGER
		_health_meter.modulate.a = 0.68 + sin(_health_pulse_time * 3.2) * 0.24
	else:
		_health_meter.modulate.a = 1.0
	var heat_ratio := float(heat_state.current) / maxf(float(heat_state.maximum), 1.0)
	_heat_meter.meter_color = CyberUITheme.DANGER if heat_state.overheated else (CyberUITheme.WARNING if heat_ratio >= 0.7 else Color("79d8bf"))
	_heat_meter.set_meter(float(heat_state.current), float(heat_state.maximum))
	_overflow_heat_meter.visible = bool(heat_state.get("overflow_visible", false))
	if _overflow_heat_meter.visible:
		_overflow_heat_meter.set_meter(float(heat_state.get("overflow", 0.0)), float(heat_state.maximum))
	_heat_warning.visible = heat_state.overheated
	if is_instance_valid(_player.talent_core):
		_operator_panel.set_takeover_state(_player.talent_core.takeover_charges, _player.talent_core.takeover_armed)
		_persona_status.update_status(_player.talent_core, _player.persona_combat.get_runtime_snapshot(), not _player.health.is_dead())
		_persona_status.position = Vector2(-224, 78) if _operator_panel.is_expanded() or _operator_panel.size.x > HoloCommsPanel.COLLAPSED_SIZE.x + 1 else Vector2(-224, 0)


func _bind_player(player: PlayerController) -> void:
	_circuit_protection_active = false
	if not player.circuit_breaker.circuit_breaker_triggered.is_connected(_on_circuit_protection_triggered):
		player.circuit_breaker.circuit_breaker_triggered.connect(_on_circuit_protection_triggered)
	if not player.cyberware_triggered.is_connected(_on_cyberware_triggered):
		player.cyberware_triggered.connect(_on_cyberware_triggered)
	if not player.talent_core.persona_changed.is_connected(_on_persona_changed):
		player.talent_core.persona_changed.connect(_on_persona_changed)
	if not player.weapons.weapon_changed.is_connected(_on_weapon_changed):
		player.weapons.weapon_changed.connect(_on_weapon_changed)
	if not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
	_on_persona_changed(player.talent_core.current_persona_id)
	_set_weapon_preview(player.weapons.get_current_weapon(), false)
	player.tree_exiting.connect(func() -> void: _player = null, CONNECT_ONE_SHOT)


func _on_scene_load_started(_scene_path: String) -> void:
	_scene_transition_active = true
	_player = null
	overlay.hide()


func _on_scene_swapped(_scene: Node, _payload: Dictionary) -> void:
	_scene_transition_active = false


func _on_scene_load_failed(_scene_path: String, _error: String) -> void:
	_scene_transition_active = false


func _build_minimal_hud() -> void:
	overlay.theme = CyberUITheme.create_theme()
	notice_queue.hide()
	_damage_feedback = PlayerDamageFeedbackLayer.new()
	_damage_feedback.name = "PlayerDamageFeedback"
	overlay.add_child(_damage_feedback)
	overlay.move_child(_damage_feedback, 0)
	_top_left = Control.new()
	_top_left.name = "MinimalStatus"
	_top_left.position = Vector2(8.0, 8.0)
	_top_left.size = Vector2(312.0, 126.0)
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_top_left)

	_health_meter = SegmentMeter.new()
	_health_meter.name = "HealthLights"
	_health_meter.position = Vector2.ZERO
	_health_meter.size = Vector2(70.0, 20.0)
	_health_meter.custom_minimum_size = _health_meter.size
	_health_meter.caption = "耐久"
	_health_meter.segments = 3
	_health_meter.show_caption = false
	_health_meter.show_numeric = false
	_health_meter.square_segments = true
	_health_meter.empty_alpha = 0.08
	_health_meter.show_loss_trail = true
	_top_left.add_child(_health_meter)

	_armor_meter = SegmentMeter.new()
	_armor_meter.name = "ArmorLights"
	_armor_meter.size = Vector2(36, 20)
	_armor_meter.custom_minimum_size = _armor_meter.size
	_armor_meter.show_caption = false
	_armor_meter.show_numeric = false
	_armor_meter.square_segments = true
	_armor_meter.meter_color = Color("70b7ff")
	_armor_meter.empty_alpha = 0.08
	_armor_meter.hide()
	_top_left.add_child(_armor_meter)

	_heat_meter = SegmentMeter.new()
	_heat_meter.name = "HeatStrip"
	_heat_meter.position = Vector2(0.0, 24.0)
	_heat_meter.size = Vector2(112.0, 14.0)
	_heat_meter.custom_minimum_size = _heat_meter.size
	_heat_meter.caption = "热量"
	_heat_meter.segments = 10
	_heat_meter.show_caption = false
	_heat_meter.show_numeric = false
	_heat_meter.empty_alpha = 0.09
	_top_left.add_child(_heat_meter)

	_overflow_heat_meter = SegmentMeter.new()
	_overflow_heat_meter.name = "OverflowHeatStrip"
	_overflow_heat_meter.position = Vector2(0.0, 40.0)
	_overflow_heat_meter.size = Vector2(112.0, 10.0)
	_overflow_heat_meter.custom_minimum_size = _overflow_heat_meter.size
	_overflow_heat_meter.caption = "溢出热量"
	_overflow_heat_meter.segments = 10
	_overflow_heat_meter.show_caption = false
	_overflow_heat_meter.show_numeric = false
	_overflow_heat_meter.empty_alpha = 0.06
	_overflow_heat_meter.meter_color = Color("8b342f")
	_overflow_heat_meter.hide()
	_top_left.add_child(_overflow_heat_meter)

	_heat_warning = Label.new()
	_heat_warning.position = Vector2(118.0, 21.0)
	_heat_warning.size = Vector2(48.0, 18.0)
	_heat_warning.text = "过热"
	_heat_warning.add_theme_font_size_override("font_size", 11)
	_heat_warning.add_theme_color_override("font_color", CyberUITheme.DANGER)
	_heat_warning.hide()
	_top_left.add_child(_heat_warning)

	_weapon_name = Label.new()
	_weapon_name.position = Vector2(118.0, 21.0)
	_weapon_name.size = Vector2(154.0, 18.0)
	_weapon_name.add_theme_font_size_override("font_size", 11)
	_weapon_name.add_theme_color_override("font_color", CyberUITheme.MUTED)
	_weapon_name.modulate.a = 0.0
	_top_left.add_child(_weapon_name)

	_persona_root = Control.new()
	_persona_root.name = "TopRightPersona"
	_persona_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_persona_root)
	_persona_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_persona_root.offset_left = -8
	_persona_root.offset_right = -8
	_persona_root.offset_top = 8
	_persona_root.offset_bottom = 8
	_operator_panel = HoloCommsPanel.new()
	_operator_panel.name = "AICommsPanel"
	_operator_panel.position = Vector2(-304, 0)
	_persona_root.add_child(_operator_panel)
	_persona_status = PersonaStatusPanel.new()
	_persona_status.name = "PersonaStatus"
	_persona_status.position = Vector2(-224, 0)
	_persona_root.add_child(_persona_status)

	_comms = CombatCommsController.new()
	_comms.name = "CombatCommsController"
	_comms.message_started.connect(_on_comms_message_started)
	_comms.collapsed.connect(_on_comms_collapsed)
	add_child(_comms)

	_operator_audio = AudioStreamPlayer.new()
	_operator_audio.name = "HotlineConnectAudio"
	_operator_audio.bus = &"SFX"
	_operator_audio.volume_db = -12.0
	_operator_audio.stream = CONNECT_SOUND
	add_child(_operator_audio)
	_build_weapon_preview()
	_circuit_value = Label.new()
	_apply_hud_scale(_saved_hud_scale())


func _build_weapon_preview() -> void:
	_weapon_preview = TextureRect.new()
	_weapon_preview.name = "CurrentWeaponPreview"
	_weapon_preview.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_preview.position = Vector2(-158.0, -54.0)
	_weapon_preview.size = Vector2(150.0, 46.0)
	_weapon_preview.pivot_offset = _weapon_preview.size
	_weapon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_preview.modulate = Color(0.8, 0.95, 1.0, 0.5)
	_weapon_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_weapon_preview)


func _on_pause_pressed() -> void:
	var menu := get_node_or_null("../PauseSettingsMenu") as PauseSettingsMenu
	if menu != null:
		menu.open_menu()


func _on_weapon_changed(_index: int, data: WeaponComponentData) -> void:
	_set_weapon_preview(data, true)


func _set_weapon_preview(data: WeaponComponentData, announce: bool) -> void:
	_weapon_preview.texture = _extract_weapon_texture(data)
	_weapon_preview.visible = _weapon_preview.texture != null
	if not announce or data == null:
		return
	_weapon_name.text = data.display_name
	_weapon_name.show()
	_weapon_name.modulate.a = 1.0
	if _weapon_name_tween != null and _weapon_name_tween.is_valid():
		_weapon_name_tween.kill()
	_weapon_name_tween = create_tween()
	_weapon_name_tween.tween_interval(0.75)
	_weapon_name_tween.tween_property(_weapon_name, "modulate:a", 0.0, 0.25)


func _extract_weapon_texture(data: WeaponComponentData) -> Texture2D:
	if data == null or data.view_scene == null:
		return null
	var instance := data.view_scene.instantiate()
	var result: Texture2D
	for node in instance.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite != null and sprite.texture != null and sprite.visible:
			result = sprite.texture
			break
	instance.free()
	return result


func show_message(_text: String, _color: Color = Color.WHITE) -> void:
	pass


func _on_notice_requested(notice: CombatNotice) -> void:
	match notice.id:
		&"persona_takeover", &"player_defeated":
			_push_ai_message(notice.text, CombatCommsController.Priority.CRITICAL, notice.display_seconds)
		&"shared_hunt", &"attack_analyzed":
			_push_ai_message(notice.text, CombatCommsController.Priority.HIGH, notice.display_seconds)
		&"boss_phase_one", &"boss_phase_two", &"boss_shield_down":
			_push_ai_message(_boss_line(notice.id), CombatCommsController.Priority.HIGH, notice.display_seconds)
		&"weapon_overheated":
			_heat_warning.show()
		_:
			pass


func _show_operator_communication(text: String) -> void:
	_push_ai_message(text, CombatCommsController.Priority.NORMAL)


func _push_ai_message(text: String, priority: CombatCommsController.Priority, seconds: float = -1.0) -> void:
	var persona_id := _player.talent_core.current_persona_id if is_instance_valid(_player) else TalentCoreController.LEGENDARY_MASTER
	var presentation: Dictionary = PERSONA_PRESENTATION.get(persona_id, PERSONA_PRESENTATION[TalentCoreController.LEGENDARY_MASTER])
	_comms.push_message(text, priority, persona_id, String(presentation.name), seconds)


func _on_comms_message_started(entry: Dictionary, connection_started: bool) -> void:
	var persona_id := StringName(entry.get("persona_id", TalentCoreController.LEGENDARY_MASTER))
	var presentation: Dictionary = PERSONA_PRESENTATION.get(persona_id, PERSONA_PRESENTATION[TalentCoreController.LEGENDARY_MASTER])
	_operator_panel.set_persona(presentation.portrait, String(presentation.name), presentation.color)
	_operator_panel.set_message(String(entry.text))
	_operator_panel.set_expanded(true)
	if connection_started:
		_operator_audio.play()


func _on_comms_collapsed() -> void:
	_operator_panel.set_expanded(false)


func _on_persona_changed(persona_id: StringName) -> void:
	var presentation: Dictionary = PERSONA_PRESENTATION.get(persona_id, PERSONA_PRESENTATION[TalentCoreController.LEGENDARY_MASTER])
	_operator_panel.set_persona(presentation.portrait, String(presentation.name), presentation.color)


func _boss_line(id: StringName) -> String:
	var persona_id := _player.talent_core.current_persona_id if is_instance_valid(_player) else TalentCoreController.LEGENDARY_MASTER
	var lines := {
		TalentCoreController.DEEP_NINJA: {&"boss_phase_one": "守卫是锁。先割断他们。", &"boss_phase_two": "链路还在。别打本体。", &"boss_shield_down": "链路断了。现在动手。"},
		TalentCoreController.LEGENDARY_MASTER: {&"boss_phase_one": "先处理护卫链路。", &"boss_phase_two": "现在打本体没有意义。", &"boss_shield_down": "链路解除，可以攻击本体。"},
		TalentCoreController.ROCK_VIGILANTE: {&"boss_phase_one": "先砸掉护卫，主唱最后登场。", &"boss_phase_two": "护卫还连着，别浪费火力。", &"boss_shield_down": "伴奏停了，轮到本体。"},
	}
	return String((lines.get(persona_id, lines[TalentCoreController.LEGENDARY_MASTER]) as Dictionary).get(id, ""))


func _on_enemy_count_changed(_remaining: int) -> void:
	pass


func _on_area_progress(_index: int, _total: int, _remaining: int, _cleared: bool) -> void:
	pass


func get_communication_history() -> Array[Dictionary]:
	return _comms.get_history()


func set_hud_scale(value: float) -> void:
	_apply_hud_scale(clampf(value, 1.0, 1.5))


func preview_combat_feedback() -> void:
	if _damage_feedback != null:
		_damage_feedback.preview_feedback()


func _apply_hud_scale(value: float) -> void:
	_top_left.scale = Vector2.ONE * value
	_persona_root.scale = Vector2.ONE * value * 0.85
	_weapon_preview.scale = Vector2.ONE * value


func _saved_hud_scale() -> float:
	return clampf(float(PlayerConfig.get_config(&"UISettings", &"HUDScale", 1.0)), 1.0, 1.5)


func _on_circuit_protection_triggered() -> void:
	_circuit_protection_active = true


func _on_player_health_changed(_current: int, _maximum: int, delta: int) -> void:
	if delta > 0:
		if Time.get_ticks_usec() - _last_health_damage_usec <= 120_000:
			return
		_health_meter.modulate = Color(0.55, 1.25, 0.72, 1.0)
		var heal_tween := create_tween().set_ignore_time_scale(true)
		heal_tween.tween_property(_health_meter, "modulate", Color.WHITE, 0.22)
		return
	if delta >= 0:
		return
	_last_health_damage_usec = Time.get_ticks_usec()
	if absi(delta) < 2:
		return
	if _health_meter_tween != null and _health_meter_tween.is_valid():
		_health_meter_tween.kill()
	_health_meter.position = Vector2(2.0, -1.0)
	_health_meter_tween = create_tween().set_ignore_time_scale(true)
	_health_meter_tween.tween_property(_health_meter, "position", Vector2(-2.0, 1.0), 0.035)
	_health_meter_tween.tween_property(_health_meter, "position", Vector2.ZERO, 0.055)


func _on_cyberware_triggered(module_id: StringName) -> void:
	if module_id != CyberwareController.KILL_HEAT_SINK:
		return
	if _heat_flash_tween != null and _heat_flash_tween.is_valid():
		_heat_flash_tween.kill()
	_heat_meter.modulate = Color(0.35, 1.35, 1.2)
	_heat_flash_tween = create_tween()
	_heat_flash_tween.tween_property(_heat_meter, "modulate", Color.WHITE, 0.28)


func _update_circuit_status() -> void:
	var circuit := _player.circuit_breaker
	if _circuit_protection_active and not _player.hurt_box.is_invulnerable():
		_circuit_protection_active = false
	_health_meter.caption = "耐久"
	if _circuit_protection_active:
		_health_meter.caption = "保护中"
		_health_meter.meter_color = CyberUITheme.WARNING
		_circuit_value.text = "断路保险触发 · 保护中"
	elif not circuit.equipped:
		_health_meter.meter_color = CyberUITheme.PHOSPHOR
		_circuit_value.text = "断路保险  未装备"
	elif circuit.circuit_breaker_used:
		_health_meter.meter_color = CyberUITheme.WARNING
		_circuit_value.text = "断路保险  已消耗"
	else:
		_health_meter.meter_color = CyberUITheme.PHOSPHOR
		_circuit_value.text = "断路保险  就绪"
