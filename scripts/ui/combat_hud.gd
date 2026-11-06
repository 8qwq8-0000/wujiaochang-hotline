extends CanvasLayer

const CIRCUIT_PANEL := preload("res://scripts/ui/cyberware_circuit_panel.gd")
const CIRCUIT_CARD := preload("res://scripts/ui/cyberware_circuit_card.gd")
const CIRCUIT_DROP_ZONE := preload("res://scripts/ui/cyberware_circuit_drop_zone.gd")
const DURABILITY_BASE := preload("res://assets/art/ui/os_hud/durability_base_v1.png")
const DURABILITY_FILLED := preload("res://assets/art/ui/os_hud/durability_gem_filled_v2.png")
const DURABILITY_EMPTY := preload("res://assets/art/ui/os_hud/durability_gem_empty_v2.png")
const HEAT_HOT := preload("res://assets/art/ui/os_hud/heat_fin_hot_v2.png")
const HEAT_COLD := preload("res://assets/art/ui/os_hud/heat_fin_cold_v2.png")
const CIRCUIT_RAIL := preload("res://assets/art/ui/os_hud/energy_bus_backbone_v1.png")
const CIRCUIT_CARD_SOURCE := preload("res://assets/art/ui/os_hud/cyberware_card_graphite_a.png")

class CyberwareIcon extends TextureRect:
	func _make_custom_tooltip(for_text: String) -> Object:
		var panel := TerminalPanel.new()
		panel.title = "CYBERWARE / 义体效果"
		panel.theme = CyberUITheme.create_theme()
		panel.panel_color = CyberUITheme.BACKGROUND
		panel.custom_minimum_size.x = 232.0
		var label := Label.new()
		label.text = for_text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 212.0
		label.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
		panel.add_child(label)
		return panel


const CYBERWARE_ICONS := {
	&"active_neural_switch": preload("res://assets/art/items/equipment_v1/active_neural_switch_64.png"),
	&"combat_synapse_sensor": preload("res://assets/art/items/equipment_v1/combat_synapse_sensor_64.png"),
	&"rhythm_pulser": preload("res://assets/art/items/equipment_v1/rhythm_pulser_64.png"),
	&"smart_fire": preload("res://assets/art/items/equipment_v1/smart_fire_64.png"),
	&"explosive_magazine": preload("res://assets/art/items/equipment_v1/explosive_magazine_64.png"),
	&"tactical_coprocessor": preload("res://assets/art/items/equipment_v1/tactical_coprocessor_64.png"),
	&"optical_intruder": preload("res://assets/art/items/equipment_v1/optical_intruder_64.png"),
	&"kill_energy_sink": preload("res://assets/art/items/equipment_v1/kill_heat_sink_64.png"),
	&"shock_pulser": preload("res://assets/art/items/equipment_v1/heat_threshold_pulser_64.png"),
	&"momentum_recovery_tendon": preload("res://assets/art/items/equipment_v1/momentum_recovery_tendon_64.png"),
	&"trajectory_echo_processor": preload("res://assets/art/items/equipment_v1/trajectory_echo_processor_64.png"),
	&"ballistic_takeover_protocol": preload("res://assets/art/items/equipment_v1/ballistic_takeover_protocol_64.png"),
	&"arc_ballistic_cortex": preload("res://assets/art/items/equipment_v1/arc_ballistic_cortex_64.png"),
	&"inertial_inversion_vertebra": preload("res://assets/art/items/equipment_v1/inertial_inversion_vertebra_64.png"),
	&"axon_recycler": preload("res://assets/art/items/equipment_v1/axon_recycler_64.png"),
	&"micro_rotor_reflex_bundle": preload("res://assets/art/items/equipment_v1/micro_rotor_reflex_bundle_64.png"),
	&"predatory_vestibular_ring": preload("res://assets/art/items/equipment_v1/predatory_vestibular_ring_64.png"),
	&"guard_coprocessor": preload("res://assets/art/items/equipment_v1/guard_coprocessor_64.png"),
	&"instruction_mirror_synapse": preload("res://assets/art/items/equipment_v1/instruction_mirror_synapse_64.png"),
	&"omnidirectional_reflection_matrix": preload("res://assets/art/items/equipment_v1/guard_coprocessor_64.png"),
	&"calamity_flame": preload("res://assets/art/items/equipment_v1/calamity_flame_64.png"),
	&"relay_starter": preload("res://assets/art/items/equipment_v1/relay_starter_64.png"),
	&"world": preload("res://assets/art/items/equipment_v1/world_64.png"),
	&"ballistic_splicer": preload("res://assets/art/items/equipment_v1/ballistic_splicer_64.png"),
	&"fission_core": preload("res://assets/art/items/equipment_v1/fission_core_64.png"),
	&"penetration_booster": preload("res://assets/art/items/equipment_v1/penetration_booster_64.png"),
}
const EQUIPMENT_TINT := Color(0.8, 0.95, 1.0, 0.65)
const EQUIPMENT_COOLDOWN_TINT := Color(0.18, 0.22, 0.32, 0.55)
const CYBERWARE_ICON_SIZE := 36.0
const CYBERWARE_ICON_GAP := 4.0
const CIRCUIT_SLOT_WIDTH := 52.0
const CIRCUIT_SLOT_STRIDE := 52.0
const CIRCUIT_HUD_WIDTH := 32.0 + CIRCUIT_SLOT_STRIDE * CyberwareCircuitState.SLOT_COUNT
const CIRCUIT_HUD_HEIGHT := 78.0
const CONNECT_SOUND := preload("res://assets/audio/ui/hotline_connect.wav")
const PORTRAIT_JOHNNY := preload("res://assets/art/ui/start_menu/persona_johnny_ghost.png")
const PORTRAIT_NARAKU := preload("res://assets/art/ui/start_menu/persona_naraku_ghost.png")
const PORTRAIT_XIANGSHAN := preload("res://assets/art/ui/start_menu/persona_xiangshan_ghost.png")

const PERSONA_PRESENTATION := {
	TalentCoreController.DEEP_NINJA: {"name": "深渊忍者", "color": Color("ff4b55"), "portrait": PORTRAIT_NARAKU},
	TalentCoreController.LEGENDARY_MASTER: {"name": "传奇宗师", "color": Color("55d9ff"), "portrait": PORTRAIT_XIANGSHAN},
	TalentCoreController.ROCK_VIGILANTE: {"name": "摇滚奇侠", "color": Color("ffe34a"), "portrait": PORTRAIT_JOHNNY},
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
var _momentum_ready_label: Label
var _weapon_name: Label
var _equipment_preview: Control
var _cyberware_preview: HBoxContainer
var _circuit_hud: Control
var _circuit_config_hint: Label
var _circuit_slot_panels: Array[PanelContainer] = []
var _circuit_slot_cards: Array[CyberwareCircuitCard] = []
var _circuit_reflow_layer: Control
var _circuit_card_texture: Texture2D
var _circuit_reflow: Array[Dictionary] = []
var _circuit_drag_source := -1
var _circuit_drag_target := -1
var _circuit_drop_zone: Control
var _circuit_insert_marker: ColorRect
var _circuit_tooltip_panel: PanelContainer
var _circuit_tooltip_label: Label
var _circuit_last_slots := PackedStringArray()
var _circuit_pointer: Label
var _circuit_energy_label: Label
var _circuit_energy_fill: ColorRect
var _circuit_payload_icon: Label
var _circuit_queue_label: Label
var _circuit_status_label: Label
var _circuit_editor: CyberwareCircuitPanel
var _active_circuit_slot := -1
var _legacy_cyberware_modules := PackedStringArray()
var _persona_root: Control
var _operator_panel: HoloCommsPanel
var _persona_status: PersonaStatusPanel
var _operator_audio: AudioStreamPlayer
var _comms: CombatCommsController
var _dialogue: PersonaDialogueController
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
	_dialogue.bind_feedback_manager(get_node_or_null("../CombatFeedbackManager") as CombatFeedbackManager)
	_dialogue.bind_rest_flow(get_node_or_null("../PersonaRestFlow"))
	overlay.hide()
	set_process(true)


func _process(delta: float) -> void:
	_health_pulse_time += delta
	if _circuit_config_hint != null:
		_circuit_config_hint.modulate.a = 0.5 + 0.5 * sin(_health_pulse_time * 5.0)
	if _circuit_payload_icon != null and _circuit_payload_icon.visible:
		_circuit_payload_icon.modulate.a = 0.65 + 0.35 * sin(_health_pulse_time * 5.0)
	_advance_circuit_reflow(delta)
	if _circuit_drag_source >= 0 and not get_viewport().gui_is_dragging():
		_reset_circuit_drag_preview()
	elif _circuit_drag_source >= 0 and _circuit_hud != null and is_instance_valid(_player):
		var hover_index := floori((_circuit_hud.get_local_mouse_position().x - 12.0) / CIRCUIT_SLOT_STRIDE)
		if hover_index >= 0 and hover_index < _player.cyberware.circuit.slot_capacity:
			_preview_circuit_insert(_circuit_drag_source, hover_index)
	var prologue := get_tree().get_first_node_in_group("prologue")
	var tutorial_hud := prologue != null and bool(prologue.get("show_combat_hud"))
	_persona_root.visible = prologue == null
	overlay.visible = (
		not _scene_transition_active
		and is_instance_valid(_player)
		and get_tree().get_nodes_in_group("warehouse").is_empty()
		and (get_tree().get_nodes_in_group("intermission").is_empty() or tutorial_hud)
		and (prologue == null or tutorial_hud)
	)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if is_instance_valid(_player):
			_bind_player(_player)
	if not is_instance_valid(_player):
		return
	_update_circuit_runtime_hud()
	var health_state := _player.get_health_state()
	_health_meter.segments = int(health_state.maximum)
	_health_meter.set_meter(float(health_state.current), float(health_state.maximum))
	var defense := _player.get_node("DefenseComponent") as DefenseComponent
	_armor_meter.visible = defense.capacity() > 0
	if _armor_meter.visible:
		_armor_meter.position = Vector2(14.0 + float(_health_meter.segments) * 41.0, 18.0)
		_armor_meter.segments = defense.capacity()
		_armor_meter.set_meter(defense.charges(), defense.capacity())
	_update_circuit_status()
	if int(health_state.current) == 1 and not _circuit_protection_active:
		_health_meter.meter_color = CyberUITheme.DANGER
		_health_meter.modulate.a = 0.68 + sin(_health_pulse_time * 3.2) * 0.24
	else:
		_health_meter.modulate.a = 1.0
	for icon in _cyberware_preview.get_children():
		var module_id := StringName(icon.name)
		if module_id not in [CyberwareController.TRAJECTORY_ECHO_PROCESSOR, CyberwareController.BALLISTIC_TAKEOVER_PROTOCOL, CyberwareController.INERTIAL_INVERSION_VERTEBRA]:
			continue
		var readiness := _player.cyberware.get_module_readiness(module_id)
		icon.modulate = EQUIPMENT_TINT if readiness >= 1.0 else EQUIPMENT_COOLDOWN_TINT.lerp(EQUIPMENT_TINT, readiness)
	if is_instance_valid(_player.talent_core):
		_operator_panel.set_takeover_state(_player.talent_core.takeover_charges, _player.talent_core.takeover_armed)
		_persona_status.update_status(_player.talent_core, _player.persona_combat.get_runtime_snapshot(), not _player.health.is_dead())
		_persona_status.position = Vector2(-224, 78) if _operator_panel.is_expanded() or _operator_panel.size.x > HoloCommsPanel.COLLAPSED_SIZE.x + 1 else Vector2(-224, 0)


func _bind_player(player: PlayerController) -> void:
	_circuit_protection_active = false
	_circuit_last_slots = PackedStringArray()
	for entry in _circuit_reflow:
		(entry["node"] as Control).queue_free()
	_circuit_reflow.clear()
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
	_dialogue.bind_player(player)
	_on_persona_changed(player.talent_core.current_persona_id)
	_announce_weapon(player.weapons.get_current_weapon(), false)
	if not player.cyberware.cyberware_changed.is_connected(_refresh_cyberware_preview):
		player.cyberware.cyberware_changed.connect(_refresh_cyberware_preview)
	if not player.cyberware.circuit_changed.is_connected(_refresh_circuit_hud):
		player.cyberware.circuit_changed.connect(_refresh_circuit_hud)
	if not player.cyberware.circuit_queue_changed.is_connected(_refresh_circuit_queue):
		player.cyberware.circuit_queue_changed.connect(_refresh_circuit_queue)
	if not player.cyberware.circuit_step_started.is_connected(_on_circuit_step_started):
		player.cyberware.circuit_step_started.connect(_on_circuit_step_started)
	if not player.cyberware.circuit_round_finished.is_connected(_on_circuit_round_finished):
		player.cyberware.circuit_round_finished.connect(_on_circuit_round_finished)
	_refresh_cyberware_preview(player.cyberware.modules)
	_refresh_circuit_hud()
	_circuit_editor.bind_player(player)
	player.tree_exiting.connect(func() -> void: _player = null, CONNECT_ONE_SHOT)


func _on_scene_load_started(_scene_path: String) -> void:
	_scene_transition_active = true
	if _circuit_editor != null and _circuit_editor.is_open:
		_circuit_editor.set_open(false)
	_player = null
	overlay.hide()


func _on_scene_swapped(_scene: Node, _payload: Dictionary) -> void:
	_scene_transition_active = false


func _on_scene_load_failed(_scene_path: String, _error: String) -> void:
	_scene_transition_active = false


func _build_minimal_hud() -> void:
	overlay.theme = CyberUITheme.create_theme()
	overlay.theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	notice_queue.hide()
	_damage_feedback = PlayerDamageFeedbackLayer.new()
	_damage_feedback.name = "PlayerDamageFeedback"
	overlay.add_child(_damage_feedback)
	overlay.move_child(_damage_feedback, 0)
	_top_left = Control.new()
	_top_left.name = "MinimalStatus"
	_top_left.position = Vector2(8.0, 8.0)
	_top_left.size = Vector2(312.0, 126.0)
	_top_left.scale = Vector2.ONE * 0.5
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_top_left)
	var durability_line := TextureRect.new()
	durability_line.name = "DurabilityLine"
	durability_line.texture = DURABILITY_BASE
	durability_line.position = Vector2(5, 2)
	durability_line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	durability_line.stretch_mode = TextureRect.STRETCH_SCALE
	durability_line.size = Vector2(160, 68)
	durability_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left.add_child(durability_line)
	durability_line.size = Vector2(160, 68)

	_health_meter = SegmentMeter.new()
	_health_meter.name = "HealthLights"
	_health_meter.position = Vector2(14.0, 9.0)
	_health_meter.size = Vector2(162.0, 39.0)
	_health_meter.custom_minimum_size = _health_meter.size
	_health_meter.caption = "耐久"
	_health_meter.segments = 3
	_health_meter.show_caption = false
	_health_meter.show_numeric = false
	_health_meter.square_segments = true
	_health_meter.filled_texture = DURABILITY_FILLED
	_health_meter.empty_texture = DURABILITY_EMPTY
	_health_meter.texture_cell_size = Vector2(39, 39)
	_health_meter.cell_gap = 2.0
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
	_heat_meter.position = Vector2(14.0, 54.0)
	_heat_meter.size = Vector2(150.0, 26.0)
	_heat_meter.custom_minimum_size = _heat_meter.size
	_heat_meter.caption = "热量"
	_heat_meter.segments = 10
	_heat_meter.show_caption = false
	_heat_meter.show_numeric = false
	_heat_meter.empty_alpha = 0.09
	_heat_meter.filled_texture = HEAT_HOT
	_heat_meter.empty_texture = HEAT_COLD
	_heat_meter.texture_cell_size = Vector2(14, 26)
	_heat_meter.cell_gap = 1.0
	_top_left.add_child(_heat_meter)
	_heat_meter.hide()

	_overflow_heat_meter = SegmentMeter.new()
	_overflow_heat_meter.name = "OverflowHeatStrip"
	_overflow_heat_meter.position = Vector2(14.0, 83.0)
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
	_heat_warning.position = Vector2(166.0, 58.0)
	_heat_warning.size = Vector2(48.0, 18.0)
	_heat_warning.text = "过热"
	_heat_warning.add_theme_font_size_override("font_size", 11)
	_heat_warning.add_theme_color_override("font_color", CyberUITheme.DANGER)
	_heat_warning.hide()
	_top_left.add_child(_heat_warning)

	_momentum_ready_label = Label.new()
	_momentum_ready_label.name = "MomentumReady"
	_momentum_ready_label.position = Vector2(14.0, 106.0)
	_momentum_ready_label.size = Vector2(140.0, 18.0)
	_momentum_ready_label.text = "零热待发"
	_momentum_ready_label.add_theme_font_size_override("font_size", 11)
	_momentum_ready_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.95))
	_momentum_ready_label.hide()
	_top_left.add_child(_momentum_ready_label)
	_momentum_ready_label.hide()

	_weapon_name = Label.new()
	_weapon_name.position = Vector2(176.0, 58.0)
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
	_dialogue = PersonaDialogueController.new()
	_dialogue.name = "PersonaDialogueController"
	_dialogue.line_requested.connect(_on_dialogue_line_requested)
	add_child(_dialogue)

	_operator_audio = AudioStreamPlayer.new()
	_operator_audio.name = "HotlineConnectAudio"
	_operator_audio.bus = &"SFX"
	_operator_audio.volume_db = -12.0
	_operator_audio.stream = CONNECT_SOUND
	add_child(_operator_audio)
	_build_equipment_preview()
	_circuit_editor = CIRCUIT_PANEL.new()
	_circuit_editor.name = "CyberwareCircuitEditor"
	add_child(_circuit_editor)
	_circuit_value = Label.new()
	_apply_hud_scale(_saved_hud_scale())


func _build_equipment_preview() -> void:
	_equipment_preview = Control.new()
	_equipment_preview.name = "EquipmentPreview"
	_equipment_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_equipment_preview)
	_equipment_preview.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_equipment_preview.offset_left = -8.0
	_equipment_preview.offset_right = -8.0
	_equipment_preview.offset_top = -8.0
	_equipment_preview.offset_bottom = -8.0
	_cyberware_preview = HBoxContainer.new()
	_cyberware_preview.name = "EquippedCyberware"
	_cyberware_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cyberware_preview.add_theme_constant_override("separation", int(CYBERWARE_ICON_GAP))
	_equipment_preview.add_child(_cyberware_preview)
	_circuit_hud = Control.new()
	_circuit_hud.name = "CyberwareCircuitSequence"
	_circuit_hud.position = Vector2(-CIRCUIT_HUD_WIDTH * 0.5, -CIRCUIT_HUD_HEIGHT * 0.5 - 15.0)
	_circuit_hud.size = Vector2(CIRCUIT_HUD_WIDTH, CIRCUIT_HUD_HEIGHT)
	_circuit_hud.scale = Vector2.ONE * 0.5
	_circuit_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_preview.add_child(_circuit_hud)
	_circuit_config_hint = Label.new()
	_circuit_config_hint.name = "CircuitConfigHint"
	_circuit_config_hint.text = "[C]"
	_circuit_config_hint.position = Vector2(-CIRCUIT_HUD_WIDTH * 0.5 - 26.0, -40.0)
	_circuit_config_hint.size = Vector2(24.0, 16.0)
	_circuit_config_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_circuit_config_hint.add_theme_font_size_override("font_size", 9)
	_circuit_config_hint.add_theme_color_override("font_color", CyberUITheme.WARNING)
	_circuit_config_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_preview.add_child(_circuit_config_hint)
	var card_atlas := AtlasTexture.new()
	card_atlas.atlas = CIRCUIT_CARD_SOURCE
	card_atlas.region = Rect2(35, 35, 1184, 1184)
	_circuit_card_texture = card_atlas
	var rail := TextureRect.new()
	rail.name = "EnergyRail"
	var rail_crop := AtlasTexture.new()
	rail_crop.atlas = CIRCUIT_RAIL
	rail_crop.region = Rect2(0, 260, 2172, 160)
	rail.texture = rail_crop
	rail.position = Vector2(0, 50)
	rail.modulate = Color(1.55, 1.45, 1.25)
	rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rail.stretch_mode = TextureRect.STRETCH_SCALE
	rail.size = Vector2(CIRCUIT_HUD_WIDTH, 20)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_hud.add_child(rail)
	rail.size = Vector2(CIRCUIT_HUD_WIDTH, 20)
	_circuit_energy_label = Label.new()
	_circuit_energy_label.position = Vector2(5, 2)
	_circuit_energy_label.size = Vector2(126, 18)
	_circuit_energy_label.add_theme_font_size_override("font_size", 10)
	_circuit_energy_label.add_theme_color_override("font_color", CyberUITheme.PHOSPHOR)
	_circuit_energy_label.hide()
	_circuit_hud.add_child(_circuit_energy_label)
	var energy_track := ColorRect.new()
	energy_track.name = "EnergyTrack"
	energy_track.position = Vector2(6, 64)
	energy_track.size = Vector2(CIRCUIT_HUD_WIDTH - 14.0, 2)
	energy_track.color = Color(CyberUITheme.WARNING, 0.22)
	energy_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_hud.add_child(energy_track)
	_circuit_energy_fill = ColorRect.new()
	_circuit_energy_fill.position = energy_track.position
	_circuit_energy_fill.size = energy_track.size
	_circuit_energy_fill.color = CyberUITheme.WARNING
	_circuit_energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_hud.add_child(_circuit_energy_fill)
	_circuit_payload_icon = Label.new()
	_circuit_payload_icon.name = "WeaponPayloadReady"
	_circuit_payload_icon.text = "◆"
	_circuit_payload_icon.position = Vector2(CIRCUIT_HUD_WIDTH - 26.0, 1.0)
	_circuit_payload_icon.size = Vector2(14.0, 18.0)
	_circuit_payload_icon.add_theme_font_size_override("font_size", 14)
	_circuit_payload_icon.add_theme_color_override("font_color", CyberUITheme.WARNING)
	_circuit_payload_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_payload_icon.hide()
	_circuit_hud.add_child(_circuit_payload_icon)
	_circuit_queue_label = Label.new()
	_circuit_queue_label.position = Vector2(118, 2)
	_circuit_queue_label.size = Vector2(113, 18)
	_circuit_queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_circuit_queue_label.add_theme_font_size_override("font_size", 10)
	_circuit_queue_label.add_theme_color_override("font_color", CyberUITheme.MUTED)
	_circuit_queue_label.hide()
	_circuit_hud.add_child(_circuit_queue_label)
	_circuit_status_label = Label.new()
	_circuit_status_label.position = Vector2(120, 18)
	_circuit_status_label.size = Vector2(111, 14)
	_circuit_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_circuit_status_label.add_theme_font_size_override("font_size", 9)
	_circuit_status_label.add_theme_color_override("font_color", CyberUITheme.MUTED)
	_circuit_status_label.hide()
	_circuit_hud.add_child(_circuit_status_label)
	_circuit_pointer = Label.new()
	_circuit_pointer.text = "▰"
	_circuit_pointer.position = Vector2(13, 67)
	_circuit_pointer.size = Vector2(16, 16)
	_circuit_pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_circuit_pointer.add_theme_color_override("font_color", CyberUITheme.WARNING)
	_circuit_pointer.hide()
	_circuit_hud.add_child(_circuit_pointer)
	var row := HBoxContainer.new()
	row.name = "CircuitCardRow"
	row.position = Vector2(12, 7)
	row.size = Vector2(CIRCUIT_HUD_WIDTH - 24.0, CIRCUIT_SLOT_WIDTH)
	row.add_theme_constant_override("separation", 0)
	_circuit_hud.add_child(row)
	for index in CyberwareCircuitState.SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2.ONE * CIRCUIT_SLOT_WIDTH
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		row.add_child(panel)
		_circuit_slot_panels.append(panel)
		var card := CIRCUIT_CARD.new() as CyberwareCircuitCard
		card.name = "CircuitModuleCard%d" % (index + 1)
		card.slot_index = index
		card.circuit_owner_id = get_instance_id()
		card.drop_requested = _reorder_circuit_modules
		card.hover_requested = _preview_circuit_insert
		card.drag_started = _start_circuit_drag
		card.right_click_requested = _remove_circuit_module
		card.mouse_entered.connect(_show_circuit_tooltip.bind(index))
		card.mouse_exited.connect(_hide_circuit_tooltip)
		panel.add_child(card)
		_circuit_slot_cards.append(card)
	_circuit_insert_marker = ColorRect.new()
	_circuit_insert_marker.name = "InsertMarker"
	_circuit_insert_marker.color = CyberUITheme.WARNING
	_circuit_insert_marker.size = Vector2(2, CIRCUIT_SLOT_WIDTH - 8)
	_circuit_insert_marker.position.y = 11
	_circuit_insert_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_insert_marker.hide()
	_circuit_hud.add_child(_circuit_insert_marker)
	_circuit_reflow_layer = Control.new()
	_circuit_reflow_layer.name = "CircuitReflow"
	_circuit_reflow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_hud.add_child(_circuit_reflow_layer)
	_circuit_drop_zone = CIRCUIT_DROP_ZONE.new()
	_circuit_drop_zone.name = "CircuitDropZone"
	_circuit_drop_zone.position = row.position - Vector2(8, 6)
	_circuit_drop_zone.size = Vector2(CIRCUIT_SLOT_STRIDE * CyberwareCircuitState.INITIAL_SLOT_COUNT + 16, CIRCUIT_SLOT_WIDTH + 12)
	_circuit_drop_zone.set("circuit_owner_id", get_instance_id())
	_circuit_drop_zone.set("preview_requested", _preview_circuit_insert)
	_circuit_drop_zone.set("drop_requested", _reorder_circuit_modules)
	_circuit_drop_zone.set("cancel_requested", _reset_circuit_drag_preview)
	_circuit_hud.add_child(_circuit_drop_zone)
	_circuit_tooltip_panel = PanelContainer.new()
	_circuit_tooltip_panel.name = "CircuitEffectTooltip"
	_circuit_tooltip_panel.custom_minimum_size.x = 220
	_circuit_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_tooltip_panel.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("252b30"), Color("8f7658")))
	overlay.add_child(_circuit_tooltip_panel)
	_circuit_tooltip_label = Label.new()
	_circuit_tooltip_label.custom_minimum_size.x = 200
	_circuit_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_circuit_tooltip_label.add_theme_font_size_override("font_size", 10)
	_circuit_tooltip_label.add_theme_color_override("font_color", Color("e6e1d8"))
	_circuit_tooltip_panel.add_child(_circuit_tooltip_label)
	_circuit_tooltip_panel.hide()


func _refresh_cyberware_preview(modules: PackedStringArray) -> void:
	_legacy_cyberware_modules = modules.duplicate()
	for icon in _cyberware_preview.get_children():
		_cyberware_preview.remove_child(icon)
		icon.queue_free()
	for module_id in modules:
		var id := StringName(module_id)
		var data := load(ComponentRolls.cyberware_resource_path(id)) as CyberwareData
		if data == null or not CYBERWARE_ICONS.has(id):
			continue
		var icon := CyberwareIcon.new()
		icon.name = module_id
		icon.texture = CYBERWARE_ICONS[id]
		icon.custom_minimum_size = Vector2.ONE * CYBERWARE_ICON_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = EQUIPMENT_TINT
		# Hover reveals the effect, while attack/guard clicks still reach gameplay.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = "%s\n%s" % [data.display_name, data.description]
		_cyberware_preview.add_child(icon)
	var count := _cyberware_preview.get_child_count()
	var width := count * CYBERWARE_ICON_SIZE + maxi(count - 1, 0) * CYBERWARE_ICON_GAP
	_cyberware_preview.position = Vector2(-CIRCUIT_HUD_WIDTH * 0.5 - width - 12.0, -46.0)
	_cyberware_preview.size = Vector2(width, 46.0)
	var circuit_active := is_instance_valid(_player) and _has_installed_circuit_module()
	_cyberware_preview.visible = count > 0 and not circuit_active


func _refresh_circuit_hud(_state: Dictionary = {}) -> void:
	if _circuit_slot_cards.is_empty() or not is_instance_valid(_player):
		return
	var slots := _player.cyberware.circuit.get_slots()
	_refresh_circuit_capacity()
	_spawn_circuit_reflow(_circuit_last_slots, slots)
	_circuit_last_slots = slots.duplicate()
	for index in _circuit_slot_cards.size():
		var module_id := StringName(slots[index]) if index < slots.size() else StringName()
		var data := _circuit_data(module_id)
		var card := _circuit_slot_cards[index]
		var texture: Texture2D = null if module_id.is_empty() else CYBERWARE_ICONS.get(module_id, CYBERWARE_ICONS[&"combat_synapse_sensor"])
		card.set_module(module_id, texture, data.circuit_kind if data != null else -1)
	_refresh_cyberware_preview(_legacy_cyberware_modules)
	_update_circuit_runtime_hud()


func _refresh_circuit_capacity() -> void:
	var width: float = 32.0 + CIRCUIT_SLOT_STRIDE * _player.cyberware.circuit.slot_capacity
	_circuit_hud.position.x = -width * 0.5
	_circuit_hud.size.x = width
	_circuit_config_hint.position.x = _circuit_hud.position.x - _circuit_config_hint.size.x - 2.0
	(_circuit_hud.get_node("EnergyRail") as TextureRect).size.x = width
	(_circuit_hud.get_node("EnergyTrack") as ColorRect).size.x = width - 14.0
	_circuit_payload_icon.position.x = width - 26.0
	(_circuit_hud.get_node("CircuitCardRow") as HBoxContainer).size.x = width - 24.0
	_circuit_drop_zone.size.x = CIRCUIT_SLOT_STRIDE * _player.cyberware.circuit.slot_capacity + 16.0
	_circuit_drop_zone.set("slot_count", _player.cyberware.circuit.slot_capacity)
	for index in _circuit_slot_cards.size():
		_circuit_slot_panels[index].visible = index < _player.cyberware.circuit.slot_capacity


func _reorder_circuit_modules(source_index: int, target_index: int) -> bool:
	_reset_circuit_drag_preview()
	if not is_instance_valid(_player):
		return false
	var slots := _player.cyberware.circuit.get_slots()
	if source_index < 0 or source_index >= slots.size() or target_index < 0 or target_index >= slots.size():
		return false
	if source_index == target_index or StringName(slots[source_index]).is_empty():
		return false
	var ordered := Array(slots)
	var moving: String = ordered.pop_at(source_index)
	ordered.insert(target_index, moving)
	ordered = ordered.filter(func(module_id: String) -> bool: return not module_id.is_empty())
	while ordered.size() < _player.cyberware.circuit.slot_capacity:
		ordered.append("")
	var result := _player.cyberware.set_circuit_slots(PackedStringArray(ordered))
	if bool(result.get("ok", false)) and target_index >= 0 and target_index < _circuit_slot_cards.size():
		_circuit_slot_cards[target_index].settle()
	return bool(result.get("ok", false))


func _remove_circuit_module(index: int) -> void:
	if not is_instance_valid(_player):
		return
	var slots := _player.cyberware.circuit.get_slots()
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return
	slots.remove_at(index)
	slots.append("")
	_player.cyberware.set_circuit_slots(slots)


func _start_circuit_drag(source_index: int) -> void:
	_clear_circuit_reflow()
	for card in _circuit_slot_cards:
		card.reset_visual_offset()
	_circuit_drag_source = source_index
	_circuit_drag_target = source_index
	_hide_circuit_tooltip()
	if source_index >= 0 and source_index < _circuit_slot_cards.size():
		_circuit_slot_cards[source_index].set_drag_origin_hidden(true)
	_circuit_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_circuit_runtime_hud()


func _preview_circuit_insert(source_index: int, target_index: int) -> void:
	if source_index != _circuit_drag_source or target_index == _circuit_drag_target:
		return
	_circuit_drag_target = target_index
	if target_index == source_index:
		_circuit_insert_marker.hide()
		for card in _circuit_slot_cards:
			card.reset_visual_offset()
		return
	for index in _circuit_slot_cards.size():
		var shift := 0.0
		if source_index < target_index and index > source_index and index <= target_index:
			shift = -CIRCUIT_SLOT_WIDTH
		elif source_index > target_index and index >= target_index and index < source_index:
			shift = CIRCUIT_SLOT_WIDTH
		_circuit_slot_cards[index].set_visual_offset(shift)
	_circuit_insert_marker.position.x = 12.0 + target_index * CIRCUIT_SLOT_STRIDE + 1.0
	_circuit_insert_marker.show()


func _reset_circuit_drag_preview() -> void:
	if _circuit_drag_source < 0:
		return
	var source_index := _circuit_drag_source
	_circuit_drag_source = -1
	_circuit_drag_target = -1
	_circuit_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circuit_insert_marker.hide()
	for card in _circuit_slot_cards:
		card.set_visual_offset(0.0)
		card.modulate.a = 1.0 if not card.module_id.is_empty() else 0.6
	_circuit_slot_cards[source_index].restore_drag_origin_after_preview()


func _show_circuit_tooltip(slot_index: int) -> void:
	if _circuit_drag_source >= 0 or slot_index < 0 or slot_index >= _circuit_slot_cards.size():
		return
	var card := _circuit_slot_cards[slot_index]
	if card.module_id.is_empty():
		return
	_circuit_tooltip_label.text = _circuit_tooltip(card.module_id, slot_index)
	_circuit_tooltip_panel.reset_size()
	_circuit_tooltip_panel.show()
	var card_rect := card.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := _circuit_tooltip_panel.size
	_circuit_tooltip_panel.global_position = Vector2(
		clampf(card_rect.get_center().x - tooltip_size.x * 0.5, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0)),
		clampf(card_rect.position.y - tooltip_size.y - 8.0, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	)


func _hide_circuit_tooltip() -> void:
	if is_instance_valid(_circuit_tooltip_panel):
		_circuit_tooltip_panel.hide()


func _spawn_circuit_reflow(previous: PackedStringArray, current: PackedStringArray) -> void:
	_clear_circuit_reflow()
	if _circuit_drag_source >= 0:
		return
	if previous.size() != current.size():
		return
	var used_targets: Array[int] = []
	for source in previous.size():
		var module_id := StringName(previous[source])
		if module_id.is_empty() or not CYBERWARE_ICONS.has(module_id):
			continue
		for destination in current.size():
			if destination in used_targets or StringName(current[destination]) != module_id:
				continue
			used_targets.append(destination)
			if source != destination:
				var ghost := Control.new()
				ghost.size = Vector2.ONE * CIRCUIT_SLOT_WIDTH
				ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_circuit_reflow_layer.add_child(ghost)
				var ceramic := ColorRect.new()
				ceramic.color = Color("30363a")
				ceramic.size = ghost.size
				ceramic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ghost.add_child(ceramic)
				var bezel := TextureRect.new()
				bezel.texture = _circuit_card_texture
				bezel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				bezel.stretch_mode = TextureRect.STRETCH_SCALE
				bezel.size = ghost.size
				bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ghost.add_child(bezel)
				bezel.size = ghost.size
				var icon := TextureRect.new()
				icon.texture = CYBERWARE_ICONS[module_id]
				icon.position = Vector2(6, 6)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.size = Vector2(40, 40)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ghost.add_child(icon)
				icon.size = Vector2(40, 40)
				ghost.position = Vector2(12.0 + source * CIRCUIT_SLOT_STRIDE, 7.0)
				_circuit_reflow.append({"node": ghost, "x": ghost.position.x, "velocity": 0.0, "target": 12.0 + destination * CIRCUIT_SLOT_STRIDE, "slot": destination})
			break


func _clear_circuit_reflow() -> void:
	for ghost in _circuit_reflow_layer.get_children():
		ghost.hide()
		ghost.queue_free()
	_circuit_reflow.clear()


func _advance_circuit_reflow(delta: float) -> void:
	if _circuit_reflow.is_empty():
		return
	var dt := minf(delta, 0.05)
	for entry in _circuit_reflow:
		entry["velocity"] = (float(entry["velocity"]) + (float(entry["target"]) - float(entry["x"])) * 170.0 * dt) * exp(-12.0 * dt)
		entry["x"] = float(entry["x"]) + float(entry["velocity"]) * dt
	for index in _circuit_reflow.size():
		for other in range(index + 1, _circuit_reflow.size()):
			var left := _circuit_reflow[index]
			var right := _circuit_reflow[other]
			var distance := float(right["x"]) - float(left["x"])
			var target_distance := float(right["target"]) - float(left["target"])
			# Let cards cross when their current order opposes their destination order.
			if distance * target_distance <= 0.0:
				continue
			var overlap := CIRCUIT_SLOT_WIDTH - absf(distance)
			if overlap > 0.0:
				var direction := 1.0 if distance >= 0.0 else -1.0
				left["x"] = float(left["x"]) - direction * overlap * 0.5
				right["x"] = float(right["x"]) + direction * overlap * 0.5
				left["velocity"] = float(left["velocity"]) - direction * 16.0
				right["velocity"] = float(right["velocity"]) + direction * 16.0
	for index in range(_circuit_reflow.size() - 1, -1, -1):
		var entry := _circuit_reflow[index]
		var ghost := entry["node"] as Control
		ghost.position.x = float(entry["x"])
		ghost.scale = Vector2.ONE * (1.0 + minf(absf(float(entry["velocity"])) * 0.0007, 0.08))
		if absf(float(entry["target"]) - float(entry["x"])) < 0.6 and absf(float(entry["velocity"])) < 3.0:
			ghost.queue_free()
			_circuit_reflow.remove_at(index)


func _refresh_circuit_queue(_queues: Dictionary = {}) -> void:
	_update_circuit_runtime_hud()


func _on_circuit_step_started(slot_index: int, _module_id: StringName, _effect_id: StringName) -> void:
	_active_circuit_slot = slot_index
	_update_circuit_runtime_hud()


func _on_circuit_round_finished(_request_kind: StringName) -> void:
	_active_circuit_slot = -1
	_update_circuit_runtime_hud()


func _update_circuit_runtime_hud() -> void:
	if _circuit_hud == null or not is_instance_valid(_player):
		return
	var circuit: CyberwareCircuitState = _player.cyberware.circuit
	_circuit_energy_label.visible = circuit.current_energy < 0.0
	_circuit_energy_label.text = "−%.0f" % absf(circuit.current_energy)
	_circuit_energy_label.add_theme_color_override("font_color", CyberUITheme.DANGER)
	_circuit_energy_label.tooltip_text = "预计净耗 %.0f" % float(_player.cyberware.compile_circuit_plan().get("net_energy", 0.0))
	var energy_ratio := clampf(circuit.current_energy / maxf(circuit.maximum_energy, 1.0), 0.0, 1.0)
	var track_width := 32.0 + CIRCUIT_SLOT_STRIDE * circuit.slot_capacity - 14.0
	_circuit_energy_fill.size.x = track_width * (clampf(-circuit.current_energy / 100.0, 0.0, 1.0) if circuit.current_energy < 0.0 else energy_ratio)
	_circuit_energy_fill.position.x = 6.0 + track_width - _circuit_energy_fill.size.x if circuit.current_energy < 0.0 else 6.0
	_circuit_energy_fill.color = CyberUITheme.DANGER if circuit.current_energy < 0.0 or energy_ratio < 0.25 else CyberUITheme.WARNING
	var runtime := _player.cyberware.get_circuit_runtime_state()
	_circuit_payload_icon.visible = not (runtime.get("active", {}) as Dictionary).is_empty() and (runtime.get("round_modifiers", {}) as Dictionary).values().any(func(value: Variant) -> bool: return int(value) > 0)
	var queues: Dictionary = runtime.get("queues", {})
	var active: Dictionary = runtime.get("active", {})
	var active_kind := StringName((active.get("request", {}) as Dictionary).get("kind", ""))
	_circuit_queue_label.text = "主动%s 事件%s 定时%s" % [
		_request_mark(&"active", active_kind, queues),
		_request_mark(&"event", active_kind, queues),
		_request_mark(&"timed", active_kind, queues),
	]
	if not active.is_empty():
		_circuit_status_label.text = "执行中 · 槽 %d" % (maxi(_active_circuit_slot, 0) + 1)
		_circuit_status_label.add_theme_color_override("font_color", CyberUITheme.WARNING)
	elif int(runtime.get("abort_slot", -1)) >= 0:
		_circuit_status_label.text = "能量不足 中止"
		_circuit_status_label.add_theme_color_override("font_color", CyberUITheme.DANGER)
	elif not queues.is_empty():
		_circuit_status_label.text = "请求已排队"
		_circuit_status_label.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	else:
		_circuit_status_label.text = "待机 · 40/秒"
		_circuit_status_label.add_theme_color_override("font_color", CyberUITheme.MUTED)
	var derived_slot := _active_circuit_slot
	if derived_slot < 0 and not active.is_empty():
		var plan: Dictionary = active.get("plan", {})
		var steps: Array = plan.get("steps", [])
		var completed_index := int(active.get("step_index", 0)) - 1
		if completed_index >= 0 and completed_index < steps.size():
			derived_slot = int((steps[completed_index] as Dictionary).get("slot", -1))
	_circuit_pointer.visible = derived_slot >= 0 and derived_slot < _circuit_slot_panels.size()
	if _circuit_pointer.visible:
		_circuit_pointer.position.x = derived_slot * CIRCUIT_SLOT_STRIDE + 30.0
	for index in _circuit_slot_panels.size():
		var active_step := index == derived_slot
		var aborted_step := index == int(runtime.get("abort_slot", -1)) and active.is_empty()
		var moving := false
		for entry in _circuit_reflow:
			if int(entry["slot"]) == index:
				moving = true
				break
		_circuit_slot_cards[index].modulate = Color(1.2, 1.12, 0.78, 0.12 if moving else 1.0) if active_step else Color(1.0, 0.45, 0.32, 1.0) if aborted_step else Color(1, 1, 1, 0.12 if moving else 1.0)


func get_circuit_hud_snapshot() -> Dictionary:
	var module_ids := PackedStringArray()
	var icon_count := 0
	for card in _circuit_slot_cards:
		module_ids.append(String(card.module_id))
		if card.module_texture != null:
			icon_count += 1
	return {
		"rect": _circuit_hud.get_global_rect() if _circuit_hud != null else Rect2(),
		"slots": module_ids,
		"slot_icon_count": icon_count,
		"pointer_visible": _circuit_pointer.visible if _circuit_pointer != null else false,
		"pointer_slot": _active_circuit_slot,
		"energy": _circuit_energy_label.text if _circuit_energy_label != null else "",
		"queues": _circuit_queue_label.text if _circuit_queue_label != null else "",
		"status": _circuit_status_label.text if _circuit_status_label != null else "",
		"energy_ratio": _circuit_energy_fill.size.x / maxf(_circuit_hud.size.x - 14.0, 1.0) if _circuit_energy_fill != null else 0.0,
	}


func get_circuit_editor() -> CyberwareCircuitPanel:
	return _circuit_editor


func _request_mark(kind: StringName, active_kind: StringName, queues: Dictionary) -> String:
	if kind == active_kind:
		return "▶"
	if kind == &"event":
		for key in queues:
			if String(key).begins_with("event_"):
				return "●"
	return "●" if queues.has(kind) else "·"


func _circuit_kind_color(data: CyberwareData) -> Color:
	if data == null:
		return CyberUITheme.MUTED
	match data.circuit_kind:
		CyberwareData.CircuitKind.STARTER:
			return Color("78f5d2")
		CyberwareData.CircuitKind.MODIFIER:
			return Color("ffd36a")
		CyberwareData.CircuitKind.RESTRUCTURER:
			return Color("cf99ff")
		_:
			return Color("70b7ff")


func _circuit_data(module_id: StringName) -> CyberwareData:
	if module_id.is_empty():
		return null
	var path := ComponentRolls.cyberware_resource_path(module_id)
	if not path.is_empty():
		return load(path) as CyberwareData
	return _player.cyberware.get_circuit_module_data(module_id) if is_instance_valid(_player) else null


func _has_installed_circuit_module() -> bool:
	for raw_id in _player.cyberware.circuit.get_slots():
		if not StringName(raw_id).is_empty():
			return true
	return false


func _circuit_tooltip(module_id: StringName, slot_index: int = -1) -> String:
	if module_id.is_empty():
		return ""
	var path := ComponentRolls.cyberware_resource_path(module_id)
	var data := load(path) as CyberwareData if not path.is_empty() else null
	if data == null:
		return String(module_id)
	var kind_names := ["启动器", "修正器", "效果器", "规则器"]
	var detail := data.description
	if module_id == &"world" and is_instance_valid(_player):
		detail += "\n本层剩余 %d/10 次" % _player.cyberware.world_uses_remaining()
	var plan := _player.cyberware.compile_circuit_plan() if is_instance_valid(_player) else {}
	for raw_step in plan.get("steps", []):
		var step: Dictionary = raw_step
		if int(step.get("slot", -1)) == slot_index and StringName(step.get("effect_id", module_id)) != module_id:
			var effect_id := StringName(step.get("effect_id", module_id))
			var effect_data := _circuit_data(effect_id)
			if effect_data != null:
				detail = "当前复制：%s\n%s" % [effect_data.display_name, effect_data.description]
			break
	return "%s · %s\n耗能 %.0f\n%s" % [
		data.display_name,
		kind_names[clampi(data.circuit_kind, 0, kind_names.size() - 1)],
		data.circuit_energy_cost,
		detail,
	]


func _on_pause_pressed() -> void:
	var menu := get_node_or_null("../PauseSettingsMenu") as PauseSettingsMenu
	if menu != null:
		menu.open_menu()


func _on_weapon_changed(_index: int, data: WeaponComponentData) -> void:
	_announce_weapon(data, true)


func _announce_weapon(data: WeaponComponentData, announce: bool) -> void:
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
		_:
			pass


func _show_operator_communication(text: String) -> void:
	_push_ai_message(text, CombatCommsController.Priority.NORMAL)


func _push_ai_message(
	text: String,
	priority: CombatCommsController.Priority,
	seconds: float = -1.0,
	persona_id: StringName = &"",
	queue_policy: CombatCommsController.QueuePolicy = CombatCommsController.QueuePolicy.LATEST
) -> void:
	var speaker_id := persona_id if not persona_id.is_empty() else (_player.talent_core.current_persona_id if is_instance_valid(_player) else TalentCoreController.LEGENDARY_MASTER)
	var presentation: Dictionary = PERSONA_PRESENTATION.get(speaker_id, PERSONA_PRESENTATION[TalentCoreController.LEGENDARY_MASTER])
	_comms.push_message(text, priority, speaker_id, String(presentation.name), seconds, queue_policy)


func _on_dialogue_line_requested(text: String, priority: int, persona_id: StringName, queue_policy: int) -> void:
	_push_ai_message(
		text,
		priority,
		-1.0,
		persona_id,
		queue_policy
	)


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
	_top_left.scale = Vector2.ONE * value * 0.5
	_persona_root.scale = Vector2.ONE * value * 0.85
	_equipment_preview.scale = Vector2.ONE * value


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
	pass


func _update_circuit_status() -> void:
	var circuit := _player.circuit_breaker
	if _circuit_protection_active and not _player.hurt_box.is_invulnerable():
		_circuit_protection_active = false
	_health_meter.caption = "耐久"
	if _circuit_protection_active:
		_health_meter.caption = "保护中"
		_health_meter.meter_color = CyberUITheme.WARNING
		_circuit_value.text = "断路保险正在保护"
	elif not circuit.equipped:
		_health_meter.meter_color = CyberUITheme.PHOSPHOR
		_circuit_value.text = "未装备断路保险"
	elif circuit.circuit_breaker_used:
		_health_meter.meter_color = CyberUITheme.WARNING
		_circuit_value.text = "断路保险已使用"
	else:
		_health_meter.meter_color = CyberUITheme.PHOSPHOR
		_circuit_value.text = "断路保险就绪"
