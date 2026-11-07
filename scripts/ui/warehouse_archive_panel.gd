class_name WarehouseArchivePanel
extends CanvasLayer

const PERSONA_NAMES := {
	"deep_ninja": "深渊忍者",
	"legendary_master": "传奇宗师",
	"rock_vigilante": "摇滚奇侠",
}
const TALENT_NAMES := {
	"shared_hunt_resonance": "风林山火",
	"ceaseless_hunt": "无间狩猎",
	"open_model": "开放模型",
	"master_loop": "宗师气场",
	"dual_channel_performance": "双通道演奏",
	"encore_autopilot": "核武器",
}
const LEAK_TEXT := {
	"compute_containment_slip": "系统先将目标标为“收容算力”，随后又要求销毁违禁设备。",
	"operator_root_routing": "回收算力未进入市政仓库，而是汇入接线根节点。",
	"self_renewing_authority": "维稳命令没有人类签署者，紧急权限正在自行续签。",
}

const GOLD := Color("e7c77a")
const CYAN := Color("80e0d9")
const INK := Color("0b121b")
const MUTED := Color("899cae")
const BOTTLES := {
	"deep_ninja": "res://assets/art/items/personality_drinks/drink_naraku_64.png",
	"legendary_master": "res://assets/art/items/personality_drinks/drink_xiangshan_64.png",
	"rock_vigilante": "res://assets/art/items/personality_drinks/drink_johnny_tequila_64.png",
}

var room: Node2D
var is_open := false
var _owns_pause := false
var _overlay: ColorRect
var _canvas: Control
var _content: RichTextLabel
var _list: VBoxContainer
var _portrait: TextureRect
var _portrait_mark: Label
var _entry_title: Label
var _entry_tag: Label
var _heading: Label
var _footer: Label
var _summary: Label
var _tabs: Array[Button] = []
var _rows: Array[Button] = []
var _tab := 0
var _selected := 0
var _close_button: Button


func _ready() -> void:
	layer = 97
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color("20262af7")
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = CyberUITheme.create_os_theme()
	add_child(_overlay)
	_canvas = Control.new()
	_canvas.size = Vector2(640, 360)
	_overlay.add_child(_canvas)
	CyberUITheme.add_os_frame(_canvas)
	_line(Rect2(18, 16, 4, 38), GOLD)
	_text("ARCHIVE  /  行动档案", Rect2(32, 25, 400, 16), 9, GOLD)
	_heading = _text("通关记录", Rect2(31, 42, 360, 32), 25, Color("eef2ed"))
	_close_button = _button("关闭 [Esc]", Rect2(514, 33, 92, 28), close)
	_summary = _text("", Rect2(32, 78, 570, 18), 11, MUTED)
	for index in 4:
		var button := _button(["通关记录", "结局档案", "人格档案", "敌人图鉴"][index], Rect2(32 + index * 145, 105, 139, 27), _select_tab.bind(index))
		button.toggle_mode = true
		_tabs.append(button)
	_line(Rect2(32, 141, 574, 1), Color("344454"))
	var scroll := ScrollContainer.new()
	_place(scroll, Rect2(32, 151, 172, 151))
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_list)
	_box(Rect2(216, 151, 390, 151), Color("0b1420"), Color("26394a"))
	_box(Rect2(226, 162, 92, 128), Color("142333"), Color("354b59"))
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_portrait, Rect2(227, 165, 90, 120))
	_portrait_mark = _text("?", Rect2(226, 193, 92, 48), 36, Color("485c6c"))
	_portrait_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_title = _text("", Rect2(330, 161, 264, 24), 17, GOLD)
	_entry_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_entry_tag = _text("", Rect2(330, 188, 264, 17), 10, CYAN)
	_content = RichTextLabel.new()
	_content.bbcode_enabled = true
	_content.scroll_active = true
	_content.add_theme_color_override("default_color", Color("c6d1da"))
	_content.add_theme_font_override("normal_font", CyberUITheme.FONT)
	_content.add_theme_font_size_override("normal_font_size", 11)
	_place(_content, Rect2(330, 210, 264, 80))
	_line(Rect2(32, 313, 574, 1), Color("344454"))
	_footer = _text("", Rect2(32, 321, 230, 14), 9, GOLD)
	var footer := _text("仅作记录，无属性加成  /  滚轮查看详情", Rect2(271, 321, 335, 14), 9, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	get_viewport().size_changed.connect(_resize)
	_resize()
	_overlay.hide()


func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ratio := minf(viewport_size.x / 640.0, viewport_size.y / 360.0)
	_canvas.scale = Vector2.ONE * ratio
	_canvas.position = (viewport_size - Vector2(640, 360) * ratio) * 0.5


func _place(node: Control, rect: Rect2) -> void:
	_canvas.add_child(node)
	node.position = rect.position
	node.size = rect.size


func _box(rect: Rect2, fill: Color, border: Color) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := CyberUITheme.create_box(fill, border)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	_place(panel, rect)


func _line(rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = color
	_place(line, rect)


func _text(value: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_place(label, rect)
	return label


func _button(value: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "focus"]:
		var active: bool = state != "normal"
		var style := CyberUITheme.create_box(Color("263b43") if active else Color("14212e"), GOLD if active else Color("354958"))
		style.set_content_margin_all(6)
		style.set_corner_radius_all(2)
		button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", GOLD if active else Color("c6d1da"))
	button.pressed.connect(action)
	_place(button, rect)
	return button


func _select_tab(index: int) -> void:
	_tab = index
	_selected = 0
	refresh()
	(_list.get_parent() as ScrollContainer).scroll_vertical = 0
	_tabs[index].grab_focus()


func _select_entry(index: int) -> void:
	_selected = index
	_show_entry()
	_rows[index].grab_focus()
	call_deferred("_scroll_to_selection")


func _scroll_to_selection() -> void:
	await get_tree().process_frame
	if is_open and not _rows.is_empty():
		var row := _rows[_selected]
		var scroll := _list.get_parent() as ScrollContainer
		if scroll.is_ancestor_of(row):
			scroll.ensure_control_visible(row)


func _exit_tree() -> void:
	if is_open and _owns_pause:
		get_tree().paused = false


func open() -> void:
	if (
		is_open
		or room.player.health.is_dead()
		or room.player.inventory.is_open
		or (room.panel != null and room.panel.is_open)
		or (room.upgrade_panel != null and room.upgrade_panel.is_open)
	):
		return
	is_open = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)
	refresh()
	_overlay.show()
	_tabs[_tab].grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_overlay.hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	room.player.set_input_enabled(true)


func refresh() -> void:
	var store := get_node("/root/WarehouseStore")
	var codex: Dictionary = store.get_codex()
	var drinks: Array = store.get_legacy_drinks()
	var unlocked := 0
	for entry in EnemyCatalog.ENTRIES:
		if entry.id in codex.get("enemies", []):
			unlocked += 1
	_heading.text = ["通关记录", "结局档案", "人格档案", "敌人图鉴"][_tab]
	match _tab:
		0:
			_summary.text = "累计通关 %d 次" % drinks.size()
			_footer.text = "每次通关，独立留档"
		1:
			var completed: Array[String] = []
			for record: Dictionary in drinks:
				var ending := String(record.get("ending", "core_destroyed"))
				if ending not in completed and ending in ["core_destroyed", "channel_returned"]:
					completed.append(ending)
			_summary.text = "已完成结局 %d / 2" % completed.size()
			_footer.text = "结局进度 · 路线线索"
		2:
			_summary.text = "已收录人格 %d / 3" % codex.get("personas", []).size()
			_footer.text = "人格资料 · 异常通讯"
		3:
			_summary.text = "已发现敌人 %d / %d" % [unlocked, EnemyCatalog.ENTRIES.size()]
			_footer.text = "遭遇记录 · 应对提示"
	for index in _tabs.size():
		_tabs[index].set_pressed_no_signal(index == _tab)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var labels: Array[String] = []
	match _tab:
		0:
			for index in drinks.size():
				var record: Dictionary = drinks[index]
				var date := Time.get_datetime_dict_from_unix_time(int(record.get("created_unix", 0)))
				labels.append("%02d.%02d  %s" % [int(date.month), int(date.day), PERSONA_NAMES.get(String(record.get("last_persona_id", "")), "行动记录")])
		1:
			labels.append("摧毁中枢 · " + ("已完成" if not drinks.is_empty() else "可挑战"))
			labels.append("频道归还 · " + _channel_status())
		2:
			for id in PERSONA_NAMES:
				labels.append(PERSONA_NAMES[id] if id in codex.get("personas", []) else "未解锁")
		3:
			for entry in EnemyCatalog.ENTRIES:
				labels.append(entry.name if entry.id in codex.get("enemies", []) else "未解锁")
	for index in labels.size():
		var button := _button("%02d   %s" % [index + 1, labels[index]], Rect2(), _select_entry.bind(index))
		_canvas.remove_child(button)
		_list.add_child(button)
		button.custom_minimum_size = Vector2(0, 33)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 11)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.toggle_mode = true
		_rows.append(button)
	if labels.is_empty():
		var empty := Label.new()
		empty.text = "暂无通关记录"
		empty.add_theme_color_override("font_color", MUTED)
		empty.add_theme_font_size_override("font_size", 11)
		_list.add_child(empty)
	_selected = clampi(_selected, 0, maxi(0, labels.size() - 1))
	_show_entry()


func _show_entry() -> void:
	for index in _rows.size():
		_rows[index].set_pressed_no_signal(index == _selected)
	_portrait.texture = null
	_portrait_mark.show()
	_portrait_mark.text = "?"
	_content.scroll_to_line(0)
	var store := get_node("/root/WarehouseStore")
	var codex: Dictionary = store.get_codex()
	match _tab:
		0:
			var drinks: Array = store.get_legacy_drinks()
			_entry_title.text = "暂无通关记录"
			_entry_tag.text = "完成行动后自动保存"
			if drinks.is_empty():
				_portrait_mark.text = "—"
				_content.text = "完整通关后，会在这里保存本次行动的结局、用时、人格与战斗表现。"
				return
			var record: Dictionary = drinks[_selected]
			_entry_title.text = "第 %02d 次通关 · %s" % [_selected + 1, "频道归还" if record.get("ending", "core_destroyed") == "channel_returned" else "摧毁中枢"]
			_entry_tag.text = "通关记录 / %02d" % (_selected + 1)
			var lines := PackedStringArray()
			_append_drink(lines, record, _selected + 1)
			_content.text = "\n".join(lines).strip_edges()
			_show_bottle(String(record.get("last_persona_id", "")))
		1:
			if _selected == 1:
				_show_channel_status()
				return
			_entry_title.text = "第一结局 · 摧毁中枢"
			_entry_tag.text = "已完成" if not store.get_legacy_drinks().is_empty() else "可挑战"
			_portrait_mark.text = "Ⅰ"
			_content.text = "[color=#e7c77a]常规路线[/color]\n逐层突破，抵达楼顶并摧毁中枢。\n\n完成后保存通关记录，并解锁「频道归还」路线。"
		2:
			var id: String = PERSONA_NAMES.keys()[_selected]
			var unlocked: bool = id in codex.get("personas", [])
			_entry_title.text = PERSONA_NAMES[id] if unlocked else "未解锁"
			_entry_tag.text = ""
			if not unlocked:
				_content.text = "带该人格通关后解锁。"
				return
			_show_bottle(id)
			var descriptions := {
				"deep_ninja": "以猎痕锁定和连续击杀建立战斗节奏。",
				"legendary_master": "观察威胁，以手动完美格挡推进解析。",
				"rock_vigilante": "持续开火积累反馈，在火力节奏中寻找返场机会。",
			}
			var leak_id := String(TalentCoreController.SEMANTIC_LEAK_IDS.get(StringName(id), ""))
			_content.text = descriptions[id] + "\n\n[color=#e7c77a]异常通讯[/color]\n" + (LEAK_TEXT.get(leak_id, "") if leak_id in codex.get("semantic_leaks", []) else "未收录：在行动中达到三级后发现。") + "\n\n人格等级、天赋和关系在行动结束后清空。"
		3:
			var entry: Dictionary = EnemyCatalog.ENTRIES[_selected]
			var unlocked: bool = entry.id in codex.get("enemies", [])
			_entry_title.text = entry.name if unlocked else "未解锁"
			_entry_tag.text = entry.tag if unlocked else ""
			if not unlocked:
				_content.text = "首次遭遇后解锁。"
				return
			_portrait.texture = EnemyCatalog.portrait(entry)
			_portrait_mark.hide()
			_content.text = "[color=#e7c77a]战斗特点[/color]\n%s\n\n[color=#80e0d9]应对提示[/color]\n%s" % [entry.behavior, entry.counter]


func _channel_status() -> String:
	var store := get_node("/root/WarehouseStore")
	for record: Dictionary in store.get_legacy_drinks():
		if record.get("ending", "") == "channel_returned":
			return "已完成"
	return "已解锁" if store.is_channel_route_unlocked() else "未解锁"


func _show_channel_status() -> void:
	var status := _channel_status()
	_entry_title.text = "第二结局 · 频道归还"
	_entry_tag.text = status
	_portrait_mark.text = "Ⅱ"
	if status == "未解锁":
		_content.text = "[color=#e7c77a]解锁条件[/color]\n完成一次「摧毁中枢」结局并保存通关记录。\n\n解锁后，可在普通行动中寻找通往「频道归还」的隐藏路线。"
		return
	var lines := "[color=#80e0d9]第二结局路线已解锁[/color]\n中枢残片中恢复了一段被屏蔽的求救呼叫。楼内备份系统仍能重新部署中枢。\n\n[color=#e7c77a]路线提示[/color]\n下一次普通行动，第一层清场后留意两个出口。有光环的是正常出口；另一扇门受到枪击时会作出反应。门后隐藏房的祭坛上，留着残损频道核心。\n\n[color=#e7c77a]拾取代价[/color]\n生命上限 1、移速 -15%、突进冷却 +40%、散热 -30%。确认拾取后，本局无法撤离。携带核心抵达第二层后的整备通道，与 Codex 交谈即可邀请她同行。第三层需要守住修复祭坛的三波突袭。祭坛完好并携带核心抵达楼顶后，Codex 接入核心，解除携带负担并恢复正常耐久；随后与苏醒的神像单挑，夺回公共频道。祭坛被毁则继续原本的两阶段 Boss 战。返回主菜单可从最近安全检查点继续。"
	var discoveries: Array = get_node("/root/WarehouseStore").get_profile().get("channel_story", {}).get("discoveries", [])
	if not discoveries.is_empty():
		lines += "\n\n[color=#e7c77a]已发现[/color]"
		var names := {"call_record": "原始呼叫", "signature_key": "频道签名", "writeback_isolated": "回写隔离", "shrine_core": "残损频道核心"}
		for discovery: String in discoveries:
			lines += "\n· " + String(names.get(discovery, discovery))
	if status == "已完成":
		lines = "[color=#e7c77a]频道归还 · 已完成[/color]\n公共频道已恢复。新的呼叫正在等待接线。\n\n" + lines
	_content.text = lines


func _show_bottle(persona_id: String) -> void:
	if BOTTLES.has(persona_id):
		_portrait.texture = load(BOTTLES[persona_id])
		_portrait_mark.hide()


func _append_drink(lines: PackedStringArray, record: Dictionary, index: int) -> void:
	var date := Time.get_datetime_dict_from_unix_time(int(record.get("created_unix", 0)))
	lines.append("")
	lines.append("[font_size=12][color=#80e0d9]#%02d  %04d-%02d-%02d[/color][/font_size]" % [
		index, int(date.get("year", 0)), int(date.get("month", 0)), int(date.get("day", 0))
	])
	lines.append("结局：" + ("频道归还" if record.get("ending", "core_destroyed") == "channel_returned" else "摧毁中枢"))
	lines.append("通关用时 %.1f 秒，行动种子 %d" % [float(record.get("clear_seconds", 0.0)), int(record.get("run_seed", 0))])
	var last_persona_id := String(record.get("last_persona_id", ""))
	if not last_persona_id.is_empty():
		lines.append("最后使用的人格：%s" % PERSONA_NAMES.get(last_persona_id, last_persona_id))
	for entry: Variant in record.get("personas", []):
		if not entry is Dictionary:
			continue
		var talent := String(entry.get("tier_3_talent", ""))
		lines.append("• %s Lv.%d%s" % [
			entry.get("name", PERSONA_NAMES.get(String(entry.get("id", "")), "未知人格")),
			int(entry.get("level", 0)),
			"（三级天赋：" + TALENT_NAMES.get(talent, talent) + "）" if not talent.is_empty() else "",
		])
	lines.append("猎痕连杀 %d，手动完美格挡 %d\n摇滚峰值 %.1f，摇滚攻击 %d" % [
		int(record.get("highest_marked_kill_chain", 0)), int(record.get("manual_perfect_guards", 0)),
		float(record.get("peak_rock_feedback", 0.0)), int(record.get("rock_attacks", 0)),
	])
	var leaks: Array = record.get("semantic_leaks", [])
	if not leaks.is_empty():
		lines.append("本次发现：%s" % "、".join(leaks))


func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("inventory_toggle"):
		close()
		get_viewport().set_input_as_handled()
