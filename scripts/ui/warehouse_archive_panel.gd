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

var room: Node2D
var is_open := false
var _owns_pause := false
var _overlay: ColorRect
var _content: RichTextLabel


func _ready() -> void:
	layer = 97
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.018, 0.03, 0.045, 0.98)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "遗产酒谱"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("80e0d9"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 [Esc]"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var note := Label.new()
	note.text = "这里只保存发现和通关记录，不提供属性。行动结束后，人格等级、天赋和关系会清空。"
	note.add_theme_color_override("font_color", Color("a9bac5"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_content = RichTextLabel.new()
	_content.bbcode_enabled = true
	_content.fit_content = false
	_content.scroll_active = true
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_content)
	_overlay.hide()


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
	var lines := PackedStringArray()
	lines.append("[font_size=18][color=#e7c77a]已发现人格[/color][/font_size]")
	var personas: Array = codex.get("personas", [])
	if personas.is_empty():
		lines.append("尚未将任何商业人格带出行动。")
	else:
		for persona_id: Variant in personas:
			lines.append("• %s" % PERSONA_NAMES.get(String(persona_id), String(persona_id)))
	lines.append("")
	lines.append("[font_size=18][color=#e7c77a]语义泄漏[/color][/font_size]")
	var leaks: Array = codex.get("semantic_leaks", [])
	if leaks.is_empty():
		lines.append("没有永久收录的异常通讯。")
	else:
		for leak_id: Variant in leaks:
			lines.append("• %s" % LEAK_TEXT.get(String(leak_id), String(leak_id)))
	lines.append("")
	lines.append("[font_size=18][color=#e7c77a]遗产饮料（%d 瓶）[/color][/font_size]" % drinks.size())
	if drinks.is_empty():
		lines.append("完整通关后，本次行动会保存到遗产酒谱。")
	else:
		for index in drinks.size():
			_append_drink(lines, drinks[index], index + 1)
	_content.text = "\n".join(lines)


func _append_drink(lines: PackedStringArray, record: Dictionary, index: int) -> void:
	var date := Time.get_datetime_dict_from_unix_time(int(record.get("created_unix", 0)))
	lines.append("")
	lines.append("[font_size=16][color=#80e0d9]#%02d  %04d-%02d-%02d  %s[/color][/font_size]" % [
		index, int(date.get("year", 0)), int(date.get("month", 0)), int(date.get("day", 0)), record.get("id", "无编号")
	])
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
