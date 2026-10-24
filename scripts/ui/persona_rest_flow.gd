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
	&"read_opening": ["识隙", "命中猎痕目标，使其失衡 0.65 秒；同一目标冷却 2 秒。"],
	&"gaze": ["凝视", "战斗中建立新猎痕时，AI 自动瞄准并发动一次 100% 武器伤害攻击；不生热且忽略冷却。"],
	&"blood_step": ["踏血", "击杀猎痕目标后突进立即就绪，并在 2 秒内提高 20% 移动与突进速度。"],
	&"borrowed_step": ["借步", "猎痕目标进入 40 像素时，AI 寻路至安全侧后方并以手刀造成 1 伤害与 0.65 秒失衡；每个目标一次。"],
	&"shared_hunt_resonance": ["风林山火", "连续击杀 3 个猎痕目标，获得 6 秒全属性强化；强化期间免疫地形伤害。"],
	&"ceaseless_hunt": ["无间狩猎", "击杀猎痕目标后立即选择下一目标；路径可达时以最多 3 段免费突进追至 40 像素内。"],
	&"calibrated_window": ["校正窗口", "面对已解析攻击时，完美格挡窗口延长 0.2 秒；手动格挡成功后立即恢复格挡。"],
	&"proxy_stance": ["代拟架势", "已解析攻击即将命中且玩家未行动时，AI 自动面向威胁并执行普通格挡。"],
	&"refutation_reward": ["反证收益", "手动完美格挡已解析攻击后清除武器冷却；2 秒内下一击不生热且伤害 +1。"],
	&"proxy_counter": ["代行一招", "每名敌人第一次使用已解析攻击时，AI 自动执行完美格挡；每名敌人整场一次。"],
	&"open_model": ["开放模型", "显示已解析攻击的完整轨迹、命中范围与预计命中时间；每 2 次手动完美格挡恢复 1 耐久。"],
	&"master_loop": ["宗师气场", "完成一种攻击的解析时，使 220 像素内敌人失衡 1 秒，并进入 4 秒极意状态。"],
	&"steady_beat": ["稳定拍点", "命中后暂停战斗反馈衰减 1.5 秒；所有攻击热量降低 25%。"],
	&"distortion_gain": ["破音增益", "战斗反馈达到 60%：攻击速度 +30%，每个独立目标伤害 +1，热量产生 +30%。"],
	&"seamless_switch": ["无缝换台", "攻击后 1.2 秒内切换到另一武器，其第一次攻击不生热，发射反馈翻倍。"],
	&"overload_scream": ["过载嘶鸣", "攻击结算后热量达到 85% 且未过热时，AI 以当前武器发动 200% 伤害范围终止攻击，随后立即过热。"],
	&"dual_channel_performance": ["双通道演奏", "主副武器独立冷却；1.2 秒内交替攻击使双方剩余冷却 -30%，并暂停反馈衰减 1.5 秒。"],
	&"encore_autopilot": ["核武器", "战斗反馈满时进入 2 秒狂热：移除攻击间隔，可在过热时攻击，热量积累翻倍并可溢出至 200%。"],
}

const TALENT_TERMS := {
	&"read_opening": ["猎痕：优先标记低耐久、失衡、较近的敌人。", "失衡：暂时无法行动。"],
	&"gaze": ["猎痕：优先标记低耐久、失衡、较近的敌人。", "软接管：移动、攻击、格挡或突进输入会立即取消。"],
	&"blood_step": ["猎痕：优先标记低耐久、失衡、较近的敌人。"],
	&"borrowed_step": ["安全侧后方：目标背面或侧面没有墙体、陷阱，并保留撤离空间。", "软接管：移动、攻击、格挡或突进输入会立即取消。"],
	&"shared_hunt_resonance": ["连续击杀：击杀非猎痕目标不会增加计数，也不会中断已有计数。", "地形伤害：火、电、爆炸残留及炸药桶爆炸；不包括敌人的爆炸攻击。"],
	&"ceaseless_hunt": ["软接管：移动、攻击、格挡或突进输入会立即取消。"],
	&"calibrated_window": ["已解析攻击：同一敌人的同类攻击被观察两次后完全识别。", "完美格挡窗口：攻击命中前精确格挡，可反射弹丸或使近战敌人失衡。"],
	&"proxy_stance": ["普通格挡：阻止伤害，但不触发完美格挡效果。", "软接管：玩家输入可立即取消。"],
	&"refutation_reward": ["手动完美格挡：不包含 AI 自动执行的格挡。"],
	&"proxy_counter": ["第一次：按敌人分别计算；同一敌人整场战斗只能触发一次。", "软接管：玩家输入可立即取消。"],
	&"open_model": ["预计命中时间：由当前攻击前摇与弹道速度估算。"],
	&"master_loop": ["极意状态：AI 只接管已解析、可格挡、非范围攻击，并立即以当前武器 100% 伤害反击。", "软接管：攻击、格挡、移动或突进会立即结束极意状态。"],
	&"steady_beat": ["战斗反馈：发射按基础热量占有效热量上限的比例积累；每次攻击首次有效命中再积累同等数值。"],
	&"distortion_gain": ["独立目标：同次攻击对同一目标只增加一次伤害，不按弹丸数量叠加。"],
	&"seamless_switch": ["发射反馈：不包含首次有效命中的额外反馈。"],
	&"overload_scream": ["终止攻击：保留当前武器弹道、范围与命中效果；首次有效命中追加与范围攻击义体一致的爆炸，且不会重复触发自身。", "过热：暂时不能普通攻击，并使当前战斗反馈降至原值的 35%。"],
	&"dual_channel_performance": ["交替攻击：必须完成攻击；只切换武器不会触发。"],
	&"encore_autopilot": ["狂热状态：反馈不再增加，并在 2 秒内线性衰减至 0；每个物理帧最多攻击一次。"],
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
		margin.add_theme_constant_override("margin_" + side, 16)
	_overlay.add_child(margin)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 8)
	margin.add_child(root_column)
	var header := HBoxContainer.new()
	root_column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 18)
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
		button.custom_minimum_size = Vector2(240, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
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
	for tier in range(1, 4):
		var locked := tier > level
		var tier_label := Label.new()
		tier_label.text = "第 %d 级｜%s" % [tier, "需人格 Lv.%d" % tier if locked else "二选一"]
		tier_label.add_theme_color_override("font_color", CyberUITheme.MUTED if locked else CyberUITheme.HIGHLIGHT)
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
			button.custom_minimum_size.y = 72
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.clip_text = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = ("锁定 " if locked else ("✓ " if selected == talent_id else "")) + text[0] + "\n" + text[1]
			button.add_theme_font_size_override("font_size", 11)
			button.set_meta("talent_locked", locked)
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


func _build_talent_tooltip() -> void:
	_talent_tooltip = PanelContainer.new()
	_talent_tooltip.name = "TalentExplanation"
	_talent_tooltip.custom_minimum_size = Vector2(330.0, 0.0)
	_talent_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talent_tooltip.z_index = 30
	_talent_tooltip.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("061713f5"), CyberUITheme.HIGHLIGHT))
	_overlay.add_child(_talent_tooltip)
	_talent_tooltip_label = RichTextLabel.new()
	_talent_tooltip_label.fit_content = true
	_talent_tooltip_label.bbcode_enabled = true
	_talent_tooltip_label.custom_minimum_size = Vector2(310.0, 80.0)
	_talent_tooltip_label.add_theme_font_size_override("normal_font_size", 12)
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
	var body := "[font_size=16][color=#9dfbe8]%s[/color][/font_size]\n%s" % [text[0], _dynamic_talent_effect(talent_id, String(text[1]))]
	if locked:
		body += "\n[color=#9aa8a8]需要人格 Lv.%d[/color]" % tier
	var terms: Array = TALENT_TERMS.get(talent_id, [])
	if not terms.is_empty():
		body += "\n\n[color=#72c8ba]名词解释[/color]\n• " + "\n• ".join(terms)
	var available_width := _overlay.get_viewport_rect().size.x - 16.0
	_talent_tooltip.custom_minimum_size.x = minf(330.0, available_width)
	_talent_tooltip_label.custom_minimum_size.x = minf(310.0, available_width - 20.0)
	_talent_tooltip_label.text = body
	_talent_tooltip.reset_size()
	_talent_tooltip.show()
	await get_tree().process_frame
	var viewport_size := _overlay.get_viewport_rect().size
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
	var max_heat := maxf(_player.heat.effective_max(), 1.0)
	var firing_feedback := weapon.heat_per_attack / max_heat * 100.0
	match talent_id:
		&"steady_beat", &"distortion_gain", &"seamless_switch", &"dual_channel_performance", &"encore_autopilot":
			return "%s\n[color=#9aa8a8]当前武器：发射 +%.1f 反馈；首次有效命中再 +%.1f。[/color]" % [fallback, firing_feedback, firing_feedback]
		&"overload_scream":
			return "%s\n[color=#9aa8a8]当前武器：触发线 %.1f / %.1f 热量。[/color]" % [fallback, max_heat * 0.85, max_heat]
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
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_operator_communication(_pending_leak_message)


func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		# Leaving rest is an explicit confirmation, never an Esc shortcut.
		_hide_talent_tooltip()
		_message.text = "请先选择一瓶人格饮料。" if run.has_persona_authorization(run.floor_index) else "确认天赋配置后，请点击“离开整备处”。"
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
