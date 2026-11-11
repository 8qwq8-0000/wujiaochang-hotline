extends CanvasLayer

const DRAG := preload("res://scripts/ui/synthesis_drag_button.gd")
const INK := CyberUITheme.HIGHLIGHT
const GOLD := CyberUITheme.ACCENT
var heading_text := "Codex 装备工坊"
var empty_text := "没有可合成的装备\n出击收集后再来找 Codex"
var room: Node2D
var is_open := false
var _owns_pause := false
var _overlay: PanelContainer
var _list: VBoxContainer
var _materials: Array = [null, null]
var _material_buttons: Array[Button] = []
var _synthesis_button: Button
var _event_subject: OptionButton
var _event_material: OptionButton
var _event_merge_button: Button
var _preview: RichTextLabel
var _message: Label
var _target := 0
var _filter := "all"

func _style(fill: Color, border: Color = CyberUITheme.BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
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
	_overlay.theme = CyberUITheme.create_os_theme()
	_overlay.add_theme_stylebox_override("panel", _style(CyberUITheme.PANEL))
	add_child(_overlay)
	CyberUITheme.add_os_frame(_overlay)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label(heading_text, 21, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "返回 [Esc]"
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var workshop_note := "武器与防御装备升级；义体在回路面板排列。"
	if is_instance_valid(room) and room.has_method("synthesize_event_starters"):
		workshop_note = "武器与防御装备升级；事件启动器可兼并监听。"
	column.add_child(_label(workshop_note, 11, CyberUITheme.MUTED))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var catalog := VBoxContainer.new()
	catalog.custom_minimum_size.x = 235
	body.add_child(catalog)
	catalog.add_child(_label("可用装备", 15, INK))
	var filters := HBoxContainer.new()
	catalog.add_child(filters)
	for option in [{"id": "all", "title": "全部"}, {"id": "weapon", "title": "武器"}, {"id": "defense", "title": "防御"}]:
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
	result.add_theme_stylebox_override("panel", _style(CyberUITheme.BACKGROUND, CyberUITheme.BORDER))
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forge.add_child(result)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.add_theme_font_size_override("normal_font_size", 12)
	_preview.add_theme_font_size_override("bold_font_size", 13)
	result.add_child(_preview)
	_synthesis_button = Button.new()
	_synthesis_button.text = "开始合成"
	_synthesis_button.custom_minimum_size.y = 32
	_synthesis_button.add_theme_font_size_override("font_size", 14)
	_synthesis_button.add_theme_color_override("font_color", GOLD)
	_synthesis_button.pressed.connect(_synthesize)
	forge.add_child(_synthesis_button)
	var event_row := HBoxContainer.new()
	forge.add_child(event_row)
	_event_subject = OptionButton.new()
	_event_subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(_event_subject)
	_event_material = OptionButton.new()
	_event_material.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(_event_material)
	_event_merge_button = Button.new()
	_event_merge_button.text = "兼并事件"
	_event_merge_button.pressed.connect(_merge_event_starters)
	forge.add_child(_event_merge_button)
	_message = _label("", 11, CyberUITheme.MUTED)
	_message.custom_minimum_size.y = 30
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	_overlay.hide()

func owns_item(item: InventoryItem) -> bool:
	return room.owns_synthesis_item(item)

func open() -> void:
	if is_open or room.player.inventory.is_open or room.player.health.is_dead():
		return
	var dialogue_panel := room.get("panel") as CanvasLayer
	if dialogue_panel != null and dialogue_panel.get("is_open") == true:
		return
	is_open = true
	_materials = [null, null]
	_target = 0
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)
	_overlay.show()
	show_message("点击或拖入装备。确认合成前，装备不会移动。")
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
	_message.text = ControlPrompts.adapt(text)


func _refresh_event_starters() -> void:
	if _event_subject == null or not is_instance_valid(room):
		return
	var supports_event_merge := room.has_method("synthesize_event_starters")
	_event_subject.get_parent().visible = supports_event_merge
	_event_merge_button.visible = supports_event_merge
	if not supports_event_merge:
		return
	_event_subject.clear()
	_event_material.clear()
	var cyberware: CyberwareController = room.player.cyberware
	var counts := cyberware.circuit.get_library_counts()
	for raw_id in counts:
		var module_id := StringName(raw_id)
		if int(counts[raw_id]) <= 0 or CyberwareController.event_starter_mask(module_id) == 0:
			continue
		var data := cyberware.get_circuit_module_data(module_id)
		var label := data.display_name if data != null else String(module_id)
		_event_subject.add_item(label)
		_event_subject.set_item_metadata(_event_subject.item_count - 1, String(module_id))
		if cyberware.circuit.get_available_count(module_id) > 0:
			_event_material.add_item(label)
			_event_material.set_item_metadata(_event_material.item_count - 1, String(module_id))
	_event_merge_button.disabled = _event_subject.item_count == 0 or _event_material.item_count == 0


func _merge_event_starters() -> void:
	if not is_instance_valid(room) or not room.has_method("synthesize_event_starters"):
		show_message("事件启动器请前往 Codex 通道兼并。")
		return
	if _event_subject.selected < 0 or _event_material.selected < 0:
		return
	var subject_id := StringName(_event_subject.get_item_metadata(_event_subject.selected))
	var material_id := StringName(_event_material.get_item_metadata(_event_material.selected))
	room.synthesize_event_starters(subject_id, material_id)

func refresh() -> void:
	if _list == null:
		return
	_refresh_event_starters()
	for index in 2:
		if _materials[index] != null and not owns_item(_materials[index]):
			_materials[index] = null
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var inv: ComponentInventory = room.player.inventory
	for location in ["weapon", "weapon_secondary", "defense", "blackbox", "backpack", "chest"]:
		var items: Array = []
		if location == "chest":
			items = room.chest.get_items()
		elif location == "backpack":
			items = inv.backpack.get_items()
		else:
			items = [inv.item_at(location)]
		for item in items:
			if item != null and str(item.get_property("slot", "")) != "cyberware" and ComponentRolls.synthesizable(item) and (_filter == "all" or item.get_property("slot") == _filter):
				_add_item(item, location)
	if _list.get_child_count() == 0:
		_list.add_child(_label(empty_text, 12))
	_refresh_preview()

func _add_item(item: InventoryItem, location: String) -> void:
	var button := Button.new()
	button.set_script(DRAG)
	button.panel = self
	button.item = item
	var names := {"weapon": "已装备的主武器", "weapon_secondary": "已装备的副武器", "cyberware": "已装备的义体", "defense": "已装备的防具", "blackbox": "黑匣", "backpack": "背包", "chest": "仓库"}
	var selected := "（主体）" if item == _materials[0] else ("（材料）" if item == _materials[1] else "")
	ComponentRolls.apply_quality_color(button, item)
	button.text = ComponentRolls.title(item) + "\n" + names[location] + selected
	button.icon = item.get_texture()
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 23)
	button.add_theme_font_size_override("font_size", 11)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(225, 45)
	button.add_theme_stylebox_override("normal", _style(CyberUITheme.SURFACE, GOLD if item in _materials else CyberUITheme.BORDER))
	button.tooltip_text = ComponentRolls.describe(item) + "\n点击放入当前槽位，也可以直接拖到主体或材料槽。"
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
		_material_buttons[index].text = ("主体" if index == 0 else "材料") + "\n" + (ComponentRolls.title(item) if item != null else "点击或拖入")
		ComponentRolls.apply_quality_color(_material_buttons[index], item)
		_material_buttons[index].tooltip_text = ComponentRolls.describe(item) if item != null else "从左侧选择装备"
		_material_buttons[index].add_theme_stylebox_override("normal", _style(CyberUITheme.SURFACE.lerp(GOLD, 0.1), GOLD if _target == index else CyberUITheme.BORDER))
	var a: InventoryItem = _materials[0]
	var b: InventoryItem = _materials[1]
	_synthesis_button.disabled = not ComponentRolls.compatible(a, b)
	if a == null:
		_preview.text = "[color=#f3c579][b]合成预览[/b][/color]\n\n先选择主体\n同类型、同品质的武器或防具可以升级"
		return
	if a.get_property("slot") == "cyberware":
		_preview.text = "[color=#efad8c]此处不支持普通义体合成[/color]\n\n义体请在回路面板排列。监听不同事件的启动器可以在 Codex 通道兼并。"
		return
	var tier := mini(ComponentRolls.synthesis_quality(a) + 1, 3)
	var id := a.get_prototype().get_prototype_id()
	var name: String = ComponentInventory.PROTOTYPES.data[id].name
	var heading := "[color=#%s][b]%s %s[/b][/color]" % [ComponentRolls.QUALITY_COLORS[tier].to_html(false), ComponentRolls.QUALITIES[tier], name]
	if a.get_property("slot") == "defense":
		heading += "\n护甲恢复 %.0f 秒 → %.0f 秒" % [ComponentRolls.ARMOR_RECOVERY_SECONDS[ComponentRolls.quality(a) - 1], ComponentRolls.ARMOR_RECOVERY_SECONDS[tier - 1]]
	if b == null:
		_preview.text = heading + "\n\n选择另一件同类型、同品质的材料"
		return
	if a.get_property("slot") != b.get_property("slot"):
		_preview.text = "[color=#efad8c]类型不匹配[/color]\n\n武器和防具需要分别合成\n请选择与主体同类型的材料"
		return
	if ComponentRolls.synthesis_quality(a) != ComponentRolls.synthesis_quality(b):
		_preview.text = "[color=#efad8c]品质不匹配[/color]\n\n请选择同品质材料"
		return
	var lines: Array[String] = [heading, "保留主体外形。" + ("已达最高品质，仅调整属性" if tier == ComponentRolls.synthesis_quality(a) else "品质提升一级")]
	var merged := ComponentRolls.affixes(a).duplicate(true)
	for key in ComponentRolls.affixes(b):
		merged[key] = maxf(float(merged.get(key, 0)), float(ComponentRolls.affixes(b)[key]))
	lines.append("合成后最多保留 %d 条属性：" % tier)
	for key in merged:
		if ComponentRolls.AFFIXES.has(key):
			var common := ComponentRolls.affixes(a).has(key) and ComponentRolls.affixes(b).has(key)
			lines.append("%s +%s%s%s" % [ComponentRolls.AFFIXES[key][0], merged[key], "ms" if key == "guard" else "%", "（一定保留）" if common else ""])
	if merged.is_empty():
		lines.append("没有可继承属性，将随机生成至少一条")
	elif merged.size() > tier:
		lines.append("重复属性一定保留，其余属性随机选取")
	lines.append("合成后放回主体原位，两件原装备都会消耗")
	_preview.text = "\n".join(lines)

func _synthesize() -> void:
	if room.synthesize(_materials[0], _materials[1]):
		var result: InventoryItem = room.last_synthesis_result
		_materials = [null, null]
		_target = 0
		refresh()
		_material_buttons[0].grab_focus()
		_preview.text = "[color=#f3c579][b]升级完成[/b][/color]\n" + "[color=#" + ComponentRolls.quality_color(result).to_html(false) + "]" + ComponentRolls.describe(result) + "[/color]\n\n已回到主体原位置"

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
