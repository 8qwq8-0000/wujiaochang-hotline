extends CanvasLayer

const DRAG := preload("res://scripts/ui/synthesis_drag_button.gd")
const CYAN := Color("8de3da")
const GOLD := Color("e6bc73")
var heading_text := "GPT 的合成工坊"
var empty_text := "暂无可合成组件\n出击收集后再来找 GPT"
var room: Node2D
var is_open := false
var _owns_pause := false
var _overlay: PanelContainer
var _list: VBoxContainer
var _materials: Array = [null, null]
var _material_buttons: Array[Button] = []
var _synthesis_button: Button
var _preview: RichTextLabel
var _message: Label
var _target := 0
var _filter := "all"

func _style(fill: String, border: Color = Color("344550")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = PanelContainer.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_theme_stylebox_override("panel", _style("101b25"))
	add_child(_overlay)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label(heading_text, 21, CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "返回 [E / Esc]"
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	column.add_child(_label("武装/防御同品质升级；义体最多四种模块，重复模块不可合成。", 11, Color("a6b9c4")))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var catalog := VBoxContainer.new()
	catalog.custom_minimum_size.x = 235
	body.add_child(catalog)
	catalog.add_child(_label("可用组件", 15, CYAN))
	var filters := HBoxContainer.new()
	catalog.add_child(filters)
	for option in [{"id": "all", "title": "全部"}, {"id": "weapon", "title": "武器"}, {"id": "cyberware", "title": "义体"}, {"id": "defense", "title": "防御"}]:
		var button := Button.new()
		button.text = option.title
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(func() -> void:
			_filter = option.id
			refresh())
		filters.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var forge := VBoxContainer.new()
	forge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge.add_theme_constant_override("separation", 6)
	body.add_child(forge)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	forge.add_child(slots)
	for index in 2:
		var column_slot := VBoxContainer.new()
		column_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(column_slot)
		var button := Button.new()
		button.set_script(DRAG)
		button.panel = self
		button.target_index = index
		button.custom_minimum_size = Vector2(160, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(func() -> void:
			_target = index
			_refresh_preview())
		column_slot.add_child(button)
		_material_buttons.append(button)
		var clear_button := Button.new()
		clear_button.text = "清空主体" if index == 0 else "清空材料"
		clear_button.add_theme_font_size_override("font_size", 10)
		clear_button.pressed.connect(func() -> void: select_material(index, null))
		column_slot.add_child(clear_button)
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", _style("172833", Color("52706c")))
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forge.add_child(result)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.add_theme_font_size_override("normal_font_size", 12)
	_preview.add_theme_font_size_override("bold_font_size", 13)
	result.add_child(_preview)
	_synthesis_button = Button.new()
	_synthesis_button.text = "确认合成升级"
	_synthesis_button.custom_minimum_size.y = 32
	_synthesis_button.add_theme_font_size_override("font_size", 14)
	_synthesis_button.add_theme_color_override("font_color", GOLD)
	_synthesis_button.pressed.connect(_synthesize)
	forge.add_child(_synthesis_button)
	_message = _label("", 11, Color("a6b9c4"))
	_message.custom_minimum_size.y = 30
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	_overlay.hide()

func owns_item(item: InventoryItem) -> bool:
	return room.owns_synthesis_item(item)

func open() -> void:
	if is_open or room.panel.is_open or room.player.inventory.is_open or room.player.health.is_dead():
		return
	is_open = true
	_materials = [null, null]
	_target = 0
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)
	_overlay.show()
	show_message("拖入组件，或先点主体 / 材料槽，再点击左侧组件。选取不会移动物品。")
	refresh()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_materials = [null, null]
	_overlay.hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	room.player.set_input_enabled(true)

func _input(event: InputEvent) -> void:
	if is_open and not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("inventory_toggle")):
		close()
		get_viewport().set_input_as_handled()

func show_message(text: String) -> void:
	_message.text = text

func refresh() -> void:
	if _list == null:
		return
	for index in 2:
		if _materials[index] != null and not owns_item(_materials[index]):
			_materials[index] = null
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var inv: ComponentInventory = room.player.inventory
	for location in ["weapon", "weapon_secondary", "cyberware", "defense", "blackbox", "backpack", "chest"]:
		var items: Array = []
		if location == "chest":
			items = room.chest.get_items()
		elif location == "backpack":
			items = inv.backpack.get_items()
		else:
			items = [inv.item_at(location)]
		for item in items:
			if ComponentRolls.synthesizable(item) and (_filter == "all" or item.get_property("slot") == _filter):
				_add_item(item, location)
	if _list.get_child_count() == 0:
		_list.add_child(_label(empty_text, 12))
	_refresh_preview()

func _add_item(item: InventoryItem, location: String) -> void:
	var button := Button.new()
	button.set_script(DRAG)
	button.panel = self
	button.item = item
	var names := {"weapon": "主武器 · 正在装备", "weapon_secondary": "副武器 · 正在装备", "cyberware": "义体 · 正在装备", "defense": "防御 · 正在装备", "blackbox": "黑匣", "backpack": "背包", "chest": "仓库"}
	var selected := " · 已选主体" if item == _materials[0] else (" · 已选材料" if item == _materials[1] else "")
	ComponentRolls.apply_quality_color(button, item)
	button.text = ComponentRolls.title(item) + "\n" + names[location] + selected
	button.icon = item.get_texture()
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 23)
	button.add_theme_font_size_override("font_size", 11)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(225, 45)
	button.add_theme_stylebox_override("normal", _style("1c303e", CYAN if item in _materials else Color("344550")))
	button.tooltip_text = ComponentRolls.describe(item) + "\n拖到主体或材料槽；点击放入当前选中槽"
	button.pressed.connect(func() -> void: select_material(_target, item))
	_list.add_child(button)

func select_material(index: int, item: InventoryItem) -> void:
	if index not in [0, 1] or (item != null and (not owns_item(item) or not ComponentRolls.synthesizable(item))):
		return
	_materials[index] = item
	if item != null and _materials[1 - index] == item:
		_materials[1 - index] = null
	_target = 1 if index == 0 and item != null else index
	show_message("")
	refresh()

func _refresh_preview() -> void:
	for index in 2:
		var item: InventoryItem = _materials[index]
		_material_buttons[index].text = ("01  主体" if index == 0 else "02  消耗材料") + "\n" + (ComponentRolls.title(item) if item != null else "拖入 / 点击选择")
		ComponentRolls.apply_quality_color(_material_buttons[index], item)
		_material_buttons[index].tooltip_text = ComponentRolls.describe(item) if item != null else "从左侧选择组件"
		_material_buttons[index].add_theme_stylebox_override("normal", _style("223744", CYAN if _target == index else Color("52706c")))
	var a: InventoryItem = _materials[0]
	var b: InventoryItem = _materials[1]
	_synthesis_button.disabled = not ComponentRolls.compatible(a, b)
	if a == null:
		_preview.text = "[color=#e6bc73][b]合成结果预览[/b][/color]\n\n先选一件主体组件\n武装 / 防御升级；义体模块取并集"
		return
	if a.get_property("slot") == "cyberware":
		var modules := ComponentRolls.cyberware_modules(a)
		if b == null:
			_preview.text = "[color=#8de3da][b]%s[/b][/color]\n\n选择一件包含不同模块的义体" % ComponentRolls.cyberware_title(modules)
			return
		if b.get_property("slot") != "cyberware":
			_preview.text = "[color=#efad8c]槽位不匹配[/color]\n\n义体只能与义体敲合"
			return
		var overlap_error := ComponentRolls.cyberware_overlap_error(a, b)
		if not overlap_error.is_empty():
			_preview.text = "[color=#efad8c][b]义体模块重复[/b][/color]\n\n" + overlap_error
			show_message(overlap_error)
			return
		for module_id in ComponentRolls.cyberware_modules(b):
			if module_id not in modules:
				modules.append(module_id)
		modules.sort()
		_preview.text = "[color=#8de3da][b]%s[/b][/color]\n\n%s\n\n模块一经敲合不可拆分；成品仍可整体装卸。" % [ComponentRolls.cyberware_title(modules), "\n".join(modules)]
		return
	var tier := mini(ComponentRolls.synthesis_quality(a) + 1, 3)
	var id := a.get_prototype().get_prototype_id()
	var name: String = ComponentInventory.PROTOTYPES.data[id].name
	var heading := "[color=#%s][b]%s · %s[/b][/color]" % [ComponentRolls.QUALITY_COLORS[tier].to_html(false), ComponentRolls.QUALITIES[tier], name]
	if a.get_property("slot") == "defense":
		heading += "\n护甲恢复 %.0f 秒 → %.0f 秒" % [ComponentRolls.ARMOR_RECOVERY_SECONDS[ComponentRolls.quality(a) - 1], ComponentRolls.ARMOR_RECOVERY_SECONDS[tier - 1]]
	if b == null:
		_preview.text = heading + "\n\n选择另一件同槽位、同品质组件"
		return
	if a.get_property("slot") != b.get_property("slot"):
		_preview.text = "[color=#efad8c]槽位不匹配[/color]\n\n武装、防御分别合成\n请选择与主体同槽位的材料"
		return
	if ComponentRolls.synthesis_quality(a) != ComponentRolls.synthesis_quality(b):
		_preview.text = "[color=#efad8c]品质不匹配[/color]\n\n请选择同品质材料"
		return
	var lines: Array[String] = [heading, "保留主体形态 · " + ("原型封顶，调整词条" if tier == ComponentRolls.synthesis_quality(a) else "品质提升一阶")]
	var merged := ComponentRolls.affixes(a).duplicate(true)
	for key in ComponentRolls.affixes(b):
		merged[key] = maxf(float(merged.get(key, 0)), float(ComponentRolls.affixes(b)[key]))
	lines.append("词条合并池（最多保留 %d 条）：" % tier)
	for key in merged:
		if ComponentRolls.AFFIXES.has(key):
			var common := ComponentRolls.affixes(a).has(key) and ComponentRolls.affixes(b).has(key)
			lines.append("%s +%s%s%s" % [ComponentRolls.AFFIXES[key][0], merged[key], "ms" if key == "guard" else "%", " · 必继承" if common else ""])
	if merged.is_empty():
		lines.append("无可继承词条，生成至少一条新词条")
	elif merged.size() > tier:
		lines.append("共有词条必保留，其余从合并池随机选取")
	lines.append("结果回到主体原位置；两件原组件均消耗")
	_preview.text = "\n".join(lines)

func _synthesize() -> void:
	if room.synthesize(_materials[0], _materials[1]):
		var result: InventoryItem = room.last_synthesis_result
		_materials = [null, null]
		_target = 0
		refresh()
		_material_buttons[0].grab_focus()
		_preview.text = "[color=#8de3da][b]升级完成[/b][/color]\n" + "[color=#" + ComponentRolls.quality_color(result).to_html(false) + "]" + ComponentRolls.describe(result) + "[/color]\n\n已回到主体原位置"

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
