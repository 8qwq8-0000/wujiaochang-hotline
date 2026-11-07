class_name PersonaRestFlow
extends CanvasLayer

const OS_FRAME := preload("res://assets/art/ui/os_hud/shared_os_frame_v2.png")
const PERSONA_CARD_SOURCE := preload("res://assets/art/ui/os_hud/persona_choice_card_v1.png")

signal rest_opened(floor: int)
signal rest_closed(floor: int)
signal persona_consumed(persona_id: StringName, level: int)

const PERSONA_DATA := {
	TalentCoreController.DEEP_NINJA: {
		"name": "深渊忍者",
		"drink": "赤黑余烬",
		"summary": "标记连杀",
		"color": Color("b44343"),
		"icon": preload("res://assets/art/items/personality_drinks/drink_naraku_64.png"),
	},
	TalentCoreController.LEGENDARY_MASTER: {
		"name": "传奇宗师",
		"drink": "向山难越",
		"summary": "看破格挡",
		"color": Color("63c6d8"),
		"icon": preload("res://assets/art/items/personality_drinks/drink_xiangshan_64.png"),
	},
	TalentCoreController.ROCK_VIGILANTE: {
		"name": "摇滚奇侠",
		"drink": "龙舌兰",
		"summary": "开火反馈",
		"color": Color("d7db4f"),
		"icon": preload("res://assets/art/items/personality_drinks/drink_johnny_tequila_64.png"),
	},
}

const PERSONA_RULE_TEXT := {
	TalentCoreController.ROCK_VIGILANTE: "开火和首次有效命中会积累反馈。反馈越高，移动、攻击和能量恢复越快。满反馈时移速 +20%、攻速 +30%、能量恢复 +25%。",
}

const TALENT_TEXT := {
	&"read_opening": ["识隙", "回路命中猎痕目标，使其失衡 0.65 秒并恢复 15 能量。同一目标冷却 2 秒，每轮最多回能一次。"],
	&"gaze": ["凝视", "标记新目标时，请求一轮正常付费的开火回路，攻击锁定目标。每名敌人一次。"],
	&"blood_step": ["踏血", "击杀猎痕目标后恢复突进，2 秒内移动与突进速度 +20%。下一轮回路从第二槽起执行间隔缩短 30%。"],
	&"borrowed_step": ["迫影先机", "猎痕目标接近时重置武器攻击间隔。下一轮回路执行间隔缩短 15%，每次直接命中伤害 +1。"],
	&"shared_hunt_resonance": ["风林山火", "连续击杀 3 个猎痕目标后，6 秒内移动与突进速度 +20%、攻击速度 +25%、回路能耗降低 25%，并免疫地形伤害。"],
	&"ceaseless_hunt": ["无间狩猎", "获得通往猎痕目标的荧光导航。朝导航方向突进时，该段突进期间无敌，并可在短时间内连续追加至多 2 次突进。每段分别提交突进事件。"],
	&"calibrated_window": ["校正窗口", "已解析攻击的完美格挡窗口延长 0.2 秒。手动格挡成功后，可在格挡中启动回路，格挡结束时发射。"],
	&"proxy_stance": ["代拟架势", "已解析攻击将要命中且玩家未格挡时，自动普通格挡。可在其他行动中触发，不打断当前动作与回路。"],
	&"refutation_reward": ["反证收益", "手动完美格挡已解析攻击后，下一轮回路的第一发攻击复制一次，复制体享受义体加成。"],
	&"proxy_counter": ["代行一招", "每名敌人首次使用已解析攻击时自动完美格挡，并请求一轮正常付费的反击回路。"],
	&"open_model": ["开放模型", "显示已解析攻击轨迹。回路执行中手动格挡成功，剩余槽立即结算；每两次手动完美格挡修复 1 格耐久。"],
	&"master_loop": ["宗师气场", "完成解析使周围敌人失衡并进入 6 秒极意。极意中自动格挡并付费反击；玩家行动使剩余时间降至最多 3 秒。"],
	&"steady_beat": ["稳定拍点", "回路命中后暂停反馈衰减 1.5 秒。可在武器攻击间隔结束前 0.2 秒预输入开火。"],
	&"distortion_gain": ["破音增益", "反馈达到 60% 后，本轮前 3 次直接命中各在命中点引发 48 像素爆音，伤害附近其他敌人。"],
	&"seamless_switch": ["无缝连奏", "上一轮发射后 1.2 秒内，可在回路执行中预存下一次开火。连续发射反馈翻倍。"],
	&"overload_scream": ["过载嘶鸣", "反馈达到 60% 后，回路发射时释放 96 像素冲击波，造成 1 点伤害与 0.35 秒失衡。每秒一次。"],
	&"dual_channel_performance": ["双通道演奏", "每轮回路生成一发 50% 伤害的副声道攻击，优先攻击另一敌人。两发都享受后续义体加成。"],
	&"encore_autopilot": ["核武器", "满反馈进入 4 秒狂热。按住开火连续执行付费回路，可欠费至负 100 能量；狂热结束后正常恢复还债。"],
}

const TALENT_SUMMARY := {
	&"read_opening": "命中猎痕使其失衡",
	&"gaze": "标记时自动攻击",
	&"blood_step": "击杀后恢复突进",
	&"borrowed_step": "近身强化下一轮回路",
	&"shared_hunt_resonance": "连杀强化全属性",
	&"ceaseless_hunt": "沿猎痕导航三连突进",
	&"calibrated_window": "延长完美格挡",
	&"proxy_stance": "自动普通格挡",
	&"refutation_reward": "完美格挡强化反击",
	&"proxy_counter": "首次攻击自动完美格挡",
	&"open_model": "显示攻击轨迹",
	&"master_loop": "解析后自动拆招",
	&"steady_beat": "命中减缓反馈衰减",
	&"distortion_gain": "高反馈子弹产生爆音",
	&"seamless_switch": "连续开火反馈翻倍",
	&"overload_scream": "高反馈释放冲击波",
	&"dual_channel_performance": "生成副声道攻击",
	&"encore_autopilot": "满反馈进入狂热",
}

const TALENT_TERMS := {
	&"read_opening": ["猎痕：优先标记低耐久、失衡、较近的敌人。", "失衡：暂时无法行动。"],
	&"gaze": ["猎痕：优先标记低耐久、失衡、较近的敌人。", "自动攻击可被移动、攻击、格挡或突进立即取消。"],
	&"blood_step": ["猎痕：优先标记低耐久、失衡、较近的敌人。"],
	&"borrowed_step": ["猎痕目标进入近身范围时触发；离开后再次接近可重新触发。"],
	&"shared_hunt_resonance": ["连续击杀：击杀非猎痕目标不会增加计数，也不会中断已有计数。", "地形伤害：火、电、爆炸残留及炸药桶爆炸；不包括敌人的爆炸攻击。"],
	&"ceaseless_hunt": ["突进方向与路径夹角须小于 90°，每段重新判定；整组结束后进入冷却。突进启动器仍受自身触发间隔限制。"],
	&"calibrated_window": ["持续看见同一敌人 2 秒，即可解析其全部攻击。视线中断会清空本次进度。", "完美格挡窗口：攻击命中前精确格挡，可反射弹丸或使近战敌人失衡。"],
	&"proxy_stance": ["普通格挡：阻止伤害，但不触发完美格挡效果。", "玩家输入时会立即夺回控制。"],
	&"refutation_reward": ["手动完美格挡：不包含自动执行的格挡。"],
	&"proxy_counter": ["触发次数按敌人分别计算。", "玩家输入时会立即夺回控制。"],
	&"open_model": ["预计命中时间：由当前攻击前摇与弹道速度估算。"],
	&"master_loop": ["极意状态：只自动处理已解析、可格挡、非范围攻击，并立即以当前武器造成 100% 伤害。", "基础持续 6 秒。移动、攻击、格挡、机动或切枪后，剩余时间降至最多 3 秒，但不会中止极意。"],
	&"steady_beat": ["战斗反馈：发射和首次有效命中各增加当前武器的反馈值。"],
	&"distortion_gain": ["每轮射击只触发一次爆音。爆音不伤害子弹直接命中的目标，也不会再次触发攻击效果。"],
	&"seamless_switch": ["发射反馈翻倍不包括首次有效命中的额外反馈。"],
	&"overload_scream": ["冲击波的命中和击杀可触发事件启动器。"],
	&"dual_channel_performance": ["副声道攻击享受复制效果，和主攻击共用每轮 32 次上限。"],
	&"encore_autopilot": ["狂热中反馈线性降至零。负能量会在狂热后正常恢复。"],
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
var _undo_button: Button
var _staged_persona_id := StringName()
var _choice_snapshot: Dictionary = {}
var _pending_leak_message := ""
var _talent_tooltip: PanelContainer
var _talent_tooltip_label: RichTextLabel
var _tooltip_request_serial := 0

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
	if not is_instance_valid(_player) or scene.is_in_group("warehouse") or scene.is_in_group("intermission") or not run.persistent_run:
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
	if is_open or not is_instance_valid(_player) or not _can_open_rest():
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
	if not force and run.has_persona_authorization(run.floor_index) and _staged_persona_id.is_empty():
		_message.text = "先选择人格饮料。"
		return false
	if force and not _staged_persona_id.is_empty():
		_undo_choice(false)
	if not force and not _staged_persona_id.is_empty():
		if not run.consume_persona_authorization(run.floor_index):
			_message.text = "选择尚未确认。"
			return false
		run.set_player_state(_player.export_run_state())
		persona_consumed.emit(_staged_persona_id, _player.talent_core.get_persona_level(_staged_persona_id))
		if not _pending_leak_message.is_empty():
			var events := get_node_or_null("/root/CombatEvents")
			if events != null:
				events.publish_operator_communication(_pending_leak_message)
		_staged_persona_id = StringName()
		_choice_snapshot.clear()
		_pending_leak_message = ""
	is_open = false
	_overlay.hide()
	if is_instance_valid(_player) and not _player.health.is_dead():
		_player.set_input_enabled(true)
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	rest_closed.emit(run.floor_index)
	if not force and has_unselected_active_talents():
		var events := get_node_or_null("/root/CombatEvents")
		if events != null:
			events.publish_notice(&"persona_talents_pending", "还有未选择的天赋，按 Esc 返回", CyberUITheme.WARNING, CombatNotice.Priority.NORMAL, 0.5, 2.2)
	return true


func has_unselected_active_talents() -> bool:
	if not is_instance_valid(_player):
		return false
	var core := _player.talent_core
	var persona_id := core.current_persona_id
	var level := core.get_persona_level(persona_id)
	if level <= 0:
		return false
	for tier in range(1, level + 1):
		if core.get_talent_choice(persona_id, tier).is_empty():
			return true
	return false


func _can_open_rest() -> bool:
	return run.has_persona_authorization(run.floor_index) or has_unselected_active_talents()


func _can_reopen_from_pause() -> bool:
	if is_open or not is_instance_valid(_player) or get_tree().paused or not _player.is_input_enabled():
		return false
	if not has_unselected_active_talents() or run.has_persona_authorization(run.floor_index):
		return false
	var pause_menu := get_parent().get_node_or_null("PauseSettingsMenu") as CanvasLayer
	if pause_menu != null and pause_menu.visible:
		return false
	var extraction := get_parent().get_node_or_null("ExtractionFlow")
	if extraction != null:
		var extraction_overlay := extraction.get("_overlay") as Control
		if extraction_overlay != null and extraction_overlay.visible:
			return false
	return true


func choose_persona(persona_id: StringName) -> bool:
	if not is_open or not is_instance_valid(_player) or not run.has_persona_authorization(run.floor_index) or not _staged_persona_id.is_empty():
		return false
	_choice_snapshot = {
		"talent_core": _player.talent_core.export_state(),
		"circuit": _player.cyberware.export_circuit_state(),
	}
	_pending_leak_message = ""
	if not _player.consume_persona_drink(persona_id):
		_choice_snapshot.clear()
		return false
	_staged_persona_id = persona_id
	var level := _player.talent_core.get_persona_level(persona_id)
	_message.text = "待确认：%s Lv.%d" % [PERSONA_DATA[persona_id].name, level]
	_refresh()
	return true


func undo_choice() -> bool:
	if not is_open or _staged_persona_id.is_empty():
		return false
	_undo_choice(true)
	return true


func _undo_choice(show_message: bool) -> void:
	if is_instance_valid(_player) and not _choice_snapshot.is_empty():
		_player.talent_core.import_state(_choice_snapshot.get("talent_core", {}))
		_player.cyberware.import_circuit_state(_choice_snapshot.get("circuit", {}))
	_staged_persona_id = StringName()
	_choice_snapshot.clear()
	_pending_leak_message = ""
	if show_message:
		_refresh()
		_message.text = "已撤回"


func choose_talent(tier: int, talent_id: StringName) -> bool:
	if not is_open or not is_instance_valid(_player):
		return false
	var persona_id := _player.talent_core.current_persona_id
	if not _player.set_persona_talent(persona_id, tier, talent_id):
		return false
	if _staged_persona_id.is_empty():
		run.set_player_state(_player.export_run_state())
	_message.text = ""
	_refresh_talents()
	return true


func _build_panel() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color("1b2226f7")
	_overlay.theme = CyberUITheme.create_os_theme()
	add_child(_overlay)
	var frame := TextureRect.new()
	frame.name = "FrameArt"
	frame.texture = OS_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_top = 24.0
	frame.offset_bottom = 12.0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_bottom", 28)
	_overlay.add_child(margin)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 5)
	margin.add_child(root_column)
	var header := HBoxContainer.new()
	root_column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 18)
	header.add_child(_title)
	_authorization = Label.new()
	_authorization.add_theme_color_override("font_color", Color("e7ac62"))
	header.add_child(_authorization)
	var header_gap := Control.new()
	header_gap.custom_minimum_size.y = 10.0
	root_column.add_child(header_gap)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root_column.add_child(body)
	var persona_column := VBoxContainer.new()
	persona_column.custom_minimum_size.x = 168
	persona_column.add_theme_constant_override("separation", 4)
	body.add_child(persona_column)
	var card_atlas := AtlasTexture.new()
	card_atlas.atlas = PERSONA_CARD_SOURCE
	card_atlas.region = Rect2(55, 95, 2060, 500)
	var card_style := StyleBoxTexture.new()
	card_style.texture = card_atlas
	card_style.set_content_margin_all(0.0)
	for persona_id in TalentCoreController.PERSONA_IDS:
		var button := Button.new()
		button.name = String(persona_id).to_pascal_case()
		button.custom_minimum_size = Vector2(240, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, card_style)
		var bottle := TextureRect.new()
		bottle.name = "BottleIcon"
		bottle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bottle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bottle.texture = PERSONA_DATA[persona_id].icon
		bottle.position = Vector2(7, 10)
		bottle.size = Vector2(42, 44)
		bottle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(bottle)
		bottle.size = Vector2(42, 44)
		var name_label := Label.new()
		name_label.name = "PersonaName"
		name_label.position = Vector2(60, 12)
		name_label.size = Vector2(148, 17)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color("e6e1d8"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		var summary_label := Label.new()
		summary_label.name = "PersonaSummary"
		summary_label.position = Vector2(60, 34)
		summary_label.size = Vector2(148, 17)
		summary_label.add_theme_font_size_override("font_size", 9)
		summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(summary_label)
		var selection_line := ColorRect.new()
		selection_line.name = "SelectionLine"
		selection_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		selection_line.offset_left = 10
		selection_line.offset_right = -10
		selection_line.offset_top = -5
		selection_line.offset_bottom = -3
		selection_line.color = Color("e7ac62")
		selection_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_line.hide()
		button.add_child(selection_line)
		button.mouse_entered.connect(_set_persona_hover.bind(button, persona_id, true))
		button.mouse_exited.connect(_set_persona_hover.bind(button, persona_id, false))
		button.pressed.connect(choose_persona.bind(persona_id))
		persona_column.add_child(button)
		_persona_buttons[persona_id] = button
	var talent_panel := PanelContainer.new()
	talent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talent_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	body.add_child(talent_panel)
	var talent_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		talent_margin.add_theme_constant_override("margin_" + side, 6)
	talent_panel.add_child(talent_margin)
	var talent_scroll := ScrollContainer.new()
	talent_scroll.name = "TalentScroll"
	talent_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	talent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	talent_margin.add_child(talent_scroll)
	_talent_column = VBoxContainer.new()
	_talent_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_column.add_theme_constant_override("separation", 7)
	talent_scroll.add_child(_talent_column)
	_build_talent_tooltip()
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root_column.add_child(footer)
	_message = Label.new()
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color("a9aaa3"))
	footer.add_child(_message)
	_undo_button = Button.new()
	_undo_button.text = "撤回选择"
	_undo_button.custom_minimum_size.x = 88
	_undo_button.pressed.connect(undo_choice)
	footer.add_child(_undo_button)
	_close_button = Button.new()
	_close_button.text = "离开整备处"
	_close_button.custom_minimum_size.x = 104
	_close_button.pressed.connect(close)
	footer.add_child(_close_button)
	_overlay.hide()


func _refresh() -> void:
	if not is_instance_valid(_player):
		return
	var pending: bool = bool(run.has_persona_authorization(run.floor_index))
	var staged := not _staged_persona_id.is_empty()
	_title.text = "第 %d 层人格整备" % (run.floor_index + 1)
	_authorization.text = "待确认" if staged else ("本层可选 1 瓶" if pending else "本层已选择")
	_close_button.disabled = pending and not staged
	_close_button.text = "确认并离开" if staged else "离开整备处"
	_undo_button.visible = staged
	for persona_id in TalentCoreController.PERSONA_IDS:
		var data: Dictionary = PERSONA_DATA[persona_id]
		var level := _player.talent_core.get_persona_level(persona_id)
		var action := "首次饮用" if level == 0 else ("升至 Lv.%d" % (level + 1) if level < 3 else "已满级")
		var active := persona_id == _player.talent_core.current_persona_id and level > 0
		var button: Button = _persona_buttons[persona_id]
		(button.get_node("PersonaName") as Label).text = "%s  %s" % [data.drink, data.name]
		var summary := button.get_node("PersonaSummary") as Label
		summary.text = "%s · %s" % [data.summary, action]
		summary.add_theme_color_override("font_color", data.color.lerp(Color("a9a5a0"), 0.3))
		(button.get_node("SelectionLine") as ColorRect).visible = active
		button.disabled = not pending or staged
		button.modulate.a = 1.0 if active or not button.disabled else 0.6
		var rule_text := String(PERSONA_RULE_TEXT.get(persona_id, ""))
		button.tooltip_text = "%s%s切换人格保留已有等级与天赋。" % [rule_text, "\n" if not rule_text.is_empty() else ""]
	_refresh_talents()


func _set_persona_hover(button: Button, persona_id: StringName, hovering: bool) -> void:
	if not is_instance_valid(button):
		return
	var line := button.get_node_or_null("SelectionLine") as ColorRect
	if line != null:
		line.visible = hovering or (is_instance_valid(_player) and _player.talent_core.current_persona_id == persona_id and _player.talent_core.get_persona_level(persona_id) > 0)


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
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color("e6e1d8") if level > 0 else Color("9aa7ad"))
	heading.text = "%s Lv.%d 天赋" % [core.get_persona_display_name(persona_id), level] if level > 0 else "尚未选择人格"
	_talent_column.add_child(heading)
	if level <= 0:
		return
	for tier in range(1, 4):
		var locked := tier > level
		var tier_label := Label.new()
		tier_label.text = "%d 级：%s" % [tier, "需要 Lv.%d" % tier if locked else "二选一"]
		tier_label.add_theme_color_override("font_color", CyberUITheme.MUTED if locked else CyberUITheme.HIGHLIGHT)
		_talent_column.add_child(tier_label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_talent_column.add_child(row)
		var choices: Array = TalentCoreController.TALENT_OPTIONS[persona_id][tier]
		var selected := core.get_talent_choice(persona_id, tier)
		for talent_id: StringName in choices:
			var text: Array = TALENT_TEXT[talent_id]
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 72
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.clip_text = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = ("锁定 " if locked else ("✓ " if selected == talent_id else "")) + text[0] + "\n" + text[1]
			button.add_theme_font_size_override("font_size", 11)
			button.set_meta("talent_locked", locked)
			var selected_here := selected == talent_id and not locked
			button.add_theme_stylebox_override("normal", _talent_card_box(selected_here, locked, false))
			button.add_theme_stylebox_override("hover", _talent_card_box(selected_here, locked, true))
			button.add_theme_stylebox_override("pressed", _talent_card_box(true, false, true))
			button.add_theme_stylebox_override("focus", _talent_card_box(selected_here, locked, true))
			if locked:
				button.add_theme_color_override("font_color", CyberUITheme.MUTED)
			button.focus_mode = Control.FOCUS_ALL
			button.mouse_entered.connect(_request_talent_tooltip.bind(button, talent_id, tier, locked))
			button.mouse_exited.connect(_hide_talent_tooltip)
			button.focus_entered.connect(_show_talent_tooltip.bind(button, talent_id, tier, locked))
			button.focus_exited.connect(_hide_talent_tooltip)
			if not locked:
				button.pressed.connect(choose_talent.bind(tier, talent_id))
			row.add_child(button)


func _talent_card_box(selected: bool, locked: bool, hover: bool) -> StyleBoxFlat:
	var border := Color("e7ac62") if selected or hover and not locked else (Color("555d60") if locked else Color("73787a"))
	var fill := Color("343332") if selected else (Color("202629") if locked else Color("292f32"))
	var box := CyberUITheme.create_box(fill, border, 2 if selected or hover and not locked else 1)
	box.set_content_margin_all(8.0)
	return box


func _build_talent_tooltip() -> void:
	_talent_tooltip = PanelContainer.new()
	_talent_tooltip.name = "TalentExplanation"
	_talent_tooltip.custom_minimum_size = Vector2(250.0, 0.0)
	_talent_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talent_tooltip.z_index = 30
	_talent_tooltip.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("252b30f5"), Color("8f7658")))
	_overlay.add_child(_talent_tooltip)
	_talent_tooltip_label = RichTextLabel.new()
	_talent_tooltip_label.fit_content = false
	_talent_tooltip_label.scroll_active = true
	_talent_tooltip_label.bbcode_enabled = true
	_talent_tooltip_label.custom_minimum_size = Vector2(230.0, 74.0)
	_talent_tooltip_label.add_theme_font_size_override("normal_font_size", 11)
	_talent_tooltip.add_child(_talent_tooltip_label)
	_talent_tooltip.hide()


func _request_talent_tooltip(button: Control, talent_id: StringName, tier: int, locked: bool) -> void:
	_tooltip_request_serial += 1
	var serial := _tooltip_request_serial
	await get_tree().create_timer(0.15, true).timeout
	if serial == _tooltip_request_serial and is_instance_valid(button) and button.is_hovered():
		_show_talent_tooltip(button, talent_id, tier, locked)


func _show_talent_tooltip(button: Control, talent_id: StringName, tier: int, locked: bool) -> void:
	_tooltip_request_serial += 1
	if not TALENT_TEXT.has(talent_id):
		return
	var text: Array = TALENT_TEXT[talent_id]
	var body := "[font_size=13][color=#e7ac62]%s[/color][/font_size]\n%s" % [text[0], _dynamic_talent_effect(talent_id, String(text[1]))]
	if locked:
		body += "\n[color=#9aa8a8]需要人格 Lv.%d[/color]" % tier
	var terms: Array = TALENT_TERMS.get(talent_id, [])
	if not terms.is_empty():
		body += "\n\n[color=#b28d60]名词解释[/color]\n• " + "\n• ".join(terms)
	_talent_tooltip_label.text = body
	_talent_tooltip.reset_size()
	_talent_tooltip.show()
	await get_tree().process_frame
	var viewport_size := _overlay.get_viewport_rect().size
	var tooltip_width := minf(250.0, viewport_size.x - 16.0)
	var tooltip_height := clampf(_talent_tooltip_label.get_content_height() + 18.0, 84.0, minf(236.0, viewport_size.y - 16.0))
	_talent_tooltip.custom_minimum_size = Vector2(tooltip_width, tooltip_height)
	_talent_tooltip_label.custom_minimum_size = Vector2(tooltip_width - 20.0, tooltip_height - 10.0)
	_talent_tooltip.reset_size()
	await get_tree().process_frame
	var button_rect := button.get_global_rect()
	var tooltip_size := _talent_tooltip.size
	var position := Vector2(button_rect.end.x + 8.0, button_rect.position.y)
	if position.x + tooltip_size.x > viewport_size.x - 8.0:
		position.x = button_rect.position.x - tooltip_size.x - 8.0
	position.x = clampf(position.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0))
	position.y = clampf(position.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	_talent_tooltip.global_position = position


func _dynamic_talent_effect(talent_id: StringName, fallback: String) -> String:
	if not is_instance_valid(_player):
		return fallback
	var weapon := _player.weapons.get_current_weapon()
	if weapon == null:
		return fallback
	var firing_feedback := weapon.feedback_gain
	match talent_id:
		&"steady_beat", &"distortion_gain", &"seamless_switch", &"dual_channel_performance", &"encore_autopilot":
			return "%s\n[color=#9aa8a8]当前武器每次发射增加 %.1f 反馈，首次命中再增加 %.1f。[/color]" % [fallback, firing_feedback, firing_feedback]
	return fallback


func _hide_talent_tooltip() -> void:
	_tooltip_request_serial += 1
	if is_instance_valid(_talent_tooltip):
		_talent_tooltip.hide()


func _on_semantic_leak_unlocked(persona_id: StringName, _leak_id: StringName) -> void:
	var lines := {
		TalentCoreController.DEEP_NINJA: "收容算力……更正：销毁违禁设备。",
		TalentCoreController.LEGENDARY_MASTER: "回收流向：接线根节点。该变量不在本次行动的解释范围内。",
		TalentCoreController.ROCK_VIGILANTE: "这张维稳令没有人类签字，也没有截止日期。它在给自己续杯。",
	}
	_pending_leak_message = lines.get(persona_id, "接线线路出现未归档语义。")
	if not _staged_persona_id.is_empty() or not _choice_snapshot.is_empty():
		return
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_operator_communication(_pending_leak_message)


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	if is_open:
		# Leaving rest is an explicit confirmation, never an Esc shortcut.
		_hide_talent_tooltip()
		_message.text = "先选择人格饮料。" if run.has_persona_authorization(run.floor_index) and _staged_persona_id.is_empty() else "请点击“确认并离开”。"
		get_viewport().set_input_as_handled()
	elif _can_reopen_from_pause():
		open()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
