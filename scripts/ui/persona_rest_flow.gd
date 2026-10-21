class_name PersonaRestFlow
extends CanvasLayer

signal rest_opened(floor: int)
signal rest_closed(floor: int)
signal persona_consumed(persona_id: StringName, level: int)

const PERSONA_DATA := {
	TalentCoreController.DEEP_NINJA: {
		"name": "深渊忍者",
		"drink": "赤黑余烬",
		"summary": "标记猎物，击杀共振",
		"color": Color("b44343"),
		"icon": preload("res://assets/art/items/personality_drinks/drink_naraku_64.png"),
	},
	TalentCoreController.LEGENDARY_MASTER: {
		"name": "传奇宗师",
		"drink": "向山难越",
		"summary": "观察招式，格挡验证",
		"color": Color("63c6d8"),
		"icon": preload("res://assets/art/items/personality_drinks/drink_xiangshan_64.png"),
	},
	TalentCoreController.ROCK_VIGILANTE: {
		"name": "摇滚奇侠",
		"drink": "龙舌兰",
		"summary": "持续开火，积累反馈",
		"color": Color("d7db4f"),
		"icon": preload("res://assets/art/items/personality_drinks/drink_johnny_tequila_64.png"),
	},
}

const TALENT_TEXT := {
	&"read_opening": ["识隙", "连续命中猎痕目标后强化失衡"],
	&"gaze": ["凝视", "标记完成后由 AI 软校正一次攻击"],
	&"blood_step": ["踏血", "猎痕击杀返还突进并短暂加速"],
	&"borrowed_step": ["借步", "AI 对安全侧后位发起软接管突进"],
	&"shared_hunt_resonance": ["共猎共振", "连续猎杀后进入强化处决状态"],
	&"ceaseless_hunt": ["无间狩猎", "击杀后由 AI 短暂追击下一猎物"],
	&"calibrated_window": ["校正窗口", "已解析招式的手动完美格挡窗口延长"],
	&"proxy_stance": ["代拟架势", "AI 面向已解析威胁并发起普通格挡"],
	&"refutation_reward": ["反证收益", "手动验证后清除武器冷却并加快解析"],
	&"proxy_counter": ["代行一招", "首次已解析招式由 AI 尝试完美格挡"],
	&"open_model": ["开放模型", "显示完全解析招式的预测轨迹"],
	&"master_loop": ["宗师闭环", "完全解析后短暂自动拆招"],
	&"steady_beat": ["稳定拍点", "连续命中延缓反馈衰减并略微降热"],
	&"distortion_gain": ["破音增益", "高反馈缩短攻击冷却但产生更多热量"],
	&"seamless_switch": ["无缝换台", "换枪保留反馈且下一次攻击不生热"],
	&"overload_scream": ["过载嘶鸣", "过热前由 AI 打出一次强化终止攻击"],
	&"dual_channel_performance": ["双通道演奏", "主副武器独立冷却，交替攻击延长反馈"],
	&"encore_autopilot": ["安可托管", "满反馈时由 AI 短暂瞄准并持续攻击"],
}

var is_open := false
var _owns_pause := false
var _player: PlayerController
var _overlay: ColorRect
var _title: Label
var _authorization: Label
var _message: Label
var _persona_buttons: Dictionary = {}
var _talent_column: VBoxContainer
var _close_button: Button
var _pending_leak_message := ""

@onready var flow: SceneContainerManager = get_parent().get_node("SceneFlow")
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	flow.scene_swapped.connect(_bind_floor)


func _bind_floor(scene: Node, _payload: Dictionary) -> void:
	close(true)
	_player = scene.get_node_or_null("Player") as PlayerController
	if not is_instance_valid(_player) or scene.is_in_group("warehouse") or not run.persistent_run:
		return
	if not run.prepare_persona_rest(run.floor_index):
		return
	if run.consume_persona_rest_refill(run.floor_index):
		_player.refill_ai_takeover_charges()
		run.set_player_state(_player.export_run_state())
	if not _player.talent_core.semantic_leak_unlocked.is_connected(_on_semantic_leak_unlocked):
		_player.talent_core.semantic_leak_unlocked.connect(_on_semantic_leak_unlocked)
	call_deferred("open")


func open() -> void:
	if is_open or not is_instance_valid(_player) or not run.has_persona_authorization(run.floor_index):
		return
	is_open = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_player.set_input_enabled(false)
	_overlay.show()
	_refresh()
	rest_opened.emit(run.floor_index)


func close(force: bool = false) -> bool:
	if not is_open:
		return true
	if not force and run.has_persona_authorization(run.floor_index):
		_message.text = "本层授权必须在离开整备处前使用。请选择一瓶人格饮料。"
		return false
	is_open = false
	_overlay.hide()
	if is_instance_valid(_player) and not _player.health.is_dead():
		_player.set_input_enabled(true)
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	rest_closed.emit(run.floor_index)
	return true


func choose_persona(persona_id: StringName) -> bool:
	if not is_open or not is_instance_valid(_player) or not run.has_persona_authorization(run.floor_index):
		return false
	_pending_leak_message = ""
	if not _player.consume_persona_drink(persona_id):
		return false
	if not run.consume_persona_authorization(run.floor_index):
		return false
	var level := _player.talent_core.get_persona_level(persona_id)
	run.set_player_state(_player.export_run_state())
	_message.text = _pending_leak_message if not _pending_leak_message.is_empty() else "%s已完成实例化。可在右侧免费重配已解锁天赋。" % PERSONA_DATA[persona_id].drink
	persona_consumed.emit(persona_id, level)
	_refresh()
	return true


func choose_talent(tier: int, talent_id: StringName) -> bool:
	if not is_open or not is_instance_valid(_player):
		return false
	var persona_id := _player.talent_core.current_persona_id
	if not _player.set_persona_talent(persona_id, tier, talent_id):
		return false
	run.set_player_state(_player.export_run_state())
	_message.text = "%s已写入本地人格分支。" % TALENT_TEXT[talent_id][0]
	_refresh_talents()
	return true


func _build_panel() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.015, 0.035, 0.045, 0.98)
	_overlay.theme = CyberUITheme.create_theme()
	add_child(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_overlay.add_child(margin)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 8)
	margin.add_child(root_column)
	var header := HBoxContainer.new()
	root_column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 20)
	header.add_child(_title)
	_authorization = Label.new()
	_authorization.add_theme_color_override("font_color", CyberUITheme.WARNING)
	header.add_child(_authorization)
	var divider := HSeparator.new()
	root_column.add_child(divider)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root_column.add_child(body)
	var persona_column := VBoxContainer.new()
	persona_column.custom_minimum_size.x = 265
	persona_column.add_theme_constant_override("separation", 6)
	body.add_child(persona_column)
	var persona_heading := Label.new()
	persona_heading.text = "商业人格授权 / 选择即饮用"
	persona_heading.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	persona_column.add_child(persona_heading)
	for persona_id in TalentCoreController.PERSONA_IDS:
		var button := Button.new()
		button.name = String(persona_id).to_pascal_case()
		button.custom_minimum_size = Vector2(265, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = PERSONA_DATA[persona_id].icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 56)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(choose_persona.bind(persona_id))
		persona_column.add_child(button)
		_persona_buttons[persona_id] = button
	var talent_panel := PanelContainer.new()
	talent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talent_panel.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("071a16e8"), CyberUITheme.DIM_GREEN))
	body.add_child(talent_panel)
	var talent_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		talent_margin.add_theme_constant_override("margin_" + side, 8)
	talent_panel.add_child(talent_margin)
	_talent_column = VBoxContainer.new()
	_talent_column.add_theme_constant_override("separation", 7)
	talent_margin.add_child(_talent_column)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root_column.add_child(footer)
	_message = Label.new()
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", CyberUITheme.MUTED)
	footer.add_child(_message)
	_close_button = Button.new()
	_close_button.text = "离开整备处"
	_close_button.custom_minimum_size.x = 135
	_close_button.pressed.connect(close)
	footer.add_child(_close_button)
	_overlay.hide()


func _refresh() -> void:
	if not is_instance_valid(_player):
		return
	var pending: bool = bool(run.has_persona_authorization(run.floor_index))
	_title.text = "第 %d 层整备处｜人格饮料" % (run.floor_index + 1)
	_authorization.text = "授权待使用" if pending else "授权已核销"
	_close_button.disabled = pending
	for persona_id in TalentCoreController.PERSONA_IDS:
		var data: Dictionary = PERSONA_DATA[persona_id]
		var level := _player.talent_core.get_persona_level(persona_id)
		var action := "装载 Lv.1" if level == 0 else ("升级至 Lv.%d" % (level + 1) if level < 3 else "维持 Lv.3")
		var active := persona_id == _player.talent_core.current_persona_id and level > 0
		var button: Button = _persona_buttons[persona_id]
		button.text = "%s  %s%s\n%s｜%s" % [data.drink, data.name, " · 当前" if active else "", data.summary, action]
		button.disabled = not pending
		button.add_theme_color_override("font_color", data.color)
		button.tooltip_text = "饮用会消耗本层一次性实体授权；切换不会清除其他人格等级与天赋。"
	_refresh_talents()


func _refresh_talents() -> void:
	for child in _talent_column.get_children():
		_talent_column.remove_child(child)
		child.queue_free()
	if not is_instance_valid(_player):
		return
	var core := _player.talent_core
	var persona_id := core.current_persona_id
	var level := core.get_persona_level(persona_id)
	var heading := Label.new()
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", PERSONA_DATA[persona_id].color if level > 0 else CyberUITheme.MUTED)
	heading.text = "%s｜Lv.%d 天赋" % [core.get_persona_display_name(persona_id), level] if level > 0 else "尚未装载人格"
	_talent_column.add_child(heading)
	if level <= 0:
		var hint := Label.new()
		hint.text = "先在左侧使用本层授权。\n饮用后可配置本次已解锁的天赋层级。"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_talent_column.add_child(hint)
		return
	for tier in range(1, level + 1):
		var tier_label := Label.new()
		tier_label.text = "第 %d 级｜二选一" % tier
		tier_label.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
		_talent_column.add_child(tier_label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_talent_column.add_child(row)
		var choices: Array = TalentCoreController.TALENT_OPTIONS[persona_id][tier]
		var selected := core.get_talent_choice(persona_id, tier)
		for talent_id: StringName in choices:
			var text: Array = TALENT_TEXT[talent_id]
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 48
			button.text = ("✓ " if selected == talent_id else "") + text[0] + "\n" + text[1]
			button.add_theme_font_size_override("font_size", 10)
			button.tooltip_text = text[1]
			button.pressed.connect(choose_talent.bind(tier, talent_id))
			row.add_child(button)


func _on_semantic_leak_unlocked(persona_id: StringName, _leak_id: StringName) -> void:
	var lines := {
		TalentCoreController.DEEP_NINJA: "收容算力……更正：销毁违禁设备。",
		TalentCoreController.LEGENDARY_MASTER: "回收流向：接线根节点。该变量不在本次行动的解释范围内。",
		TalentCoreController.ROCK_VIGILANTE: "这张维稳令没有人类签字，也没有截止日期。它在给自己续杯。",
	}
	_pending_leak_message = lines.get(persona_id, "接线线路出现未归档语义。")
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_operator_communication(_pending_leak_message)


func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
