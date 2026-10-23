extends CanvasLayer

var heading_text := "仓库 / 储物箱"
var open_message := "点击装备存取 · 取出进入背包 · 自动保存"
var fixed_chest_catalog := false
var room: Node2D
var is_open := false
var _owns_pause := false
var _title: Label
var _overlay: ColorRect
var _bag_list: VBoxContainer
var _chest_list: VBoxContainer
var _count: Label
var _message: Label
var _detail: Label
var _bag_meter: Label

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color("020b09f5")
	_overlay.theme = CyberUITheme.create_theme()
	_overlay.theme.set_stylebox("scroll", "VScrollBar", _box(Color("07120c"), Color("173b27"), 0))
	_overlay.theme.set_stylebox("grabber", "VScrollBar", _box(Color("28553a"), Color("427957"), 0))
	_overlay.theme.set_stylebox("grabber_highlight", "VScrollBar", _box(Color("427957"), CyberUITheme.PHOSPHOR, 0))
	_overlay.theme.set_stylebox("grabber_pressed", "VScrollBar", _box(Color("568b60"), CyberUITheme.HIGHLIGHT, 0))
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _box(Color("10271d"), CyberUITheme.DIM_GREEN, 8))
	column.add_child(header)
	var heading := HBoxContainer.new()
	header.add_child(heading)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	_label(titles, "WJC / SAFEHOUSE     ·     STORAGE TERMINAL", 10, CyberUITheme.MUTED)
	_title = _label(titles, heading_text, 18, CyberUITheme.HIGHLIGHT)
	var close_button := Button.new()
	close_button.text = "关闭 [E / Esc]"
	close_button.custom_minimum_size = Vector2(98, 28)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	var status := HBoxContainer.new()
	column.add_child(status)
	_count = _label(status, "", 12, CyberUITheme.HIGHLIGHT)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_meter = _label(status, "", 10, CyberUITheme.PHOSPHOR)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	_bag_list = _make_list(columns, "01 / 随身装备", "点击存入  →  储物箱")
	_chest_list = _make_list(columns, "02 / 安全储存", "点击取出  →  背包")
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", _box(Color("0d2119"), CyberUITheme.DIM_GREEN, 6))
	column.add_child(detail_panel)
	_detail = _label(detail_panel, "", 11, CyberUITheme.HIGHLIGHT)
	_detail.custom_minimum_size.y = 29
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.max_lines_visible = 2
	_message = _label(column, "", 11, CyberUITheme.MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.hide()

func _box(fill: Color, border: Color, padding: int = 5) -> StyleBoxFlat:
	var style := CyberUITheme.create_box(fill, border)
	style.set_content_margin_all(padding)
	return style

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _make_list(parent: Control, title: String, hint: String) -> VBoxContainer:
	var panel := TerminalPanel.new()
	panel.title = title
	panel.accent_color = Color("427957")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_label(column, hint, 10, CyberUITheme.MUTED)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list

func _show_empty(parent: Control, title: String, hint: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 85
	panel.add_theme_stylebox_override("panel", _box(Color("0a1913"), Color("1c3b2a"), 10))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	_label(column, "[  +  ]  " + title, 12, CyberUITheme.MUTED)
	_label(column, hint, 10, Color("587b66"))

func open() -> void:
	if is_open or (room.get("upgrade_panel") != null and room.upgrade_panel.is_open) or room.player.inventory.is_open or room.player.health.is_dead():
		return
	is_open = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)
	_overlay.show()
	_title.text = heading_text
	show_message(open_message)
	refresh()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_overlay.hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	room.player.set_input_enabled(true)

func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("inventory_toggle"):
		close()
		get_viewport().set_input_as_handled()

func show_message(message: String) -> void:
	_message.text = message

func refresh() -> void:
	for list in [_bag_list, _chest_list]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	var inventory: ComponentInventory = room.player.inventory
	_count.text = "背包 %d / 6     储物箱 %d 件" % [inventory.backpack.get_item_count(), room.chest.get_item_count()]
	_bag_meter.text = "随身容量 " + "■".repeat(inventory.backpack.get_item_count()) + "□".repeat(maxi(0, 6 - inventory.backpack.get_item_count()))
	_detail.text = "物品详情 / 指向卡片查看属性\n已装备物品不占背包格 · 取出物品进入背包"
	for entry in [{"slot": inventory.weapon_slot, "name": "主武器"}, {"slot": inventory.secondary_weapon_slot, "name": "副武器"}, {"slot": inventory.cyberware_slot, "name": "义体"}, {"slot": inventory.defense_slot, "name": "防御"}, {"slot": inventory.blackbox_slot, "name": "黑匣"}]:
		var item: InventoryItem = entry.slot.get_item()
		if item != null:
			_add_item(_bag_list, item, entry.name + " · ", true)
	for item in inventory.backpack.get_items():
		_add_item(_bag_list, item, "背包 · ", true)
	for item in _chest_display_items():
		_add_item(_chest_list, item, "", false)
	if _bag_list.get_child_count() == 0:
		_show_empty(_bag_list, "随身物品为空", "从右侧取出组件，准备下一次行动")
	if room.chest.get_item_count() == 0:
		_show_empty(_chest_list, "等待战利品入库", "点击左侧卡片，将物品存入安全储物箱")

func _chest_display_items() -> Array:
	var items: Array = room.chest.get_items()
	if not fixed_chest_catalog:
		return items
	# Supply rows represent item types, so replenishment and returned copies
	# never move other types or add rows in the middle of the catalog.
	var by_id := {}
	for item in items:
		var id: String = item.get_prototype().get_prototype_id()
		if not by_id.has(id):
			by_id[id] = item
	var ordered: Array = []
	for id in ComponentInventory.PROTOTYPES.data:
		if by_id.has(id):
			ordered.append(by_id[id])
	return ordered

func _add_item(parent: Control, item: InventoryItem, prefix: String, deposit: bool) -> void:
	var button := Button.new()
	# Preserve the row's accessible name and native button input handling.
	button.text = prefix + ComponentRolls.title(item)
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	button.disabled = deposit and bool(item.get_property("bound", false))
	var quality := ComponentRolls.quality_color(item)
	button.add_theme_stylebox_override("normal", _box(Color("10251c"), Color("284e36")))
	button.add_theme_stylebox_override("hover", _box(Color("193b29"), CyberUITheme.PHOSPHOR))
	button.add_theme_stylebox_override("pressed", _box(Color("244d33"), CyberUITheme.HIGHLIGHT))
	button.add_theme_stylebox_override("disabled", _box(Color("0d1b15"), Color("203b2b")))
	parent.add_child(button)
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 5)
	button.add_child(inset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	inset.add_child(row)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(36, 36)
	icon_panel.add_theme_stylebox_override("panel", _box(Color("06100b"), Color(quality, 0.4), 4))
	row.add_child(icon_panel)
	var icon := TextureRect.new()
	icon.texture = item.get_texture()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_panel.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 3)
	row.add_child(words)
	var category := prefix.trim_suffix(" · ") if not prefix.is_empty() else "箱内组件"
	_label(words, category + (" / 已绑定" if button.disabled else ""), 10, CyberUITheme.MUTED)
	var title := _label(words, ComponentRolls.title(item), 12, quality)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var action := _label(row, "锁定" if button.disabled else ("存入 >" if deposit else "取出 >"), 10, CyberUITheme.MUTED if button.disabled else CyberUITheme.PHOSPHOR)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ignore_pointer(inset)
	var details := ComponentRolls.describe(item).replace("\n", "  ·  ")
	button.mouse_entered.connect(func() -> void: _detail.text = details)
	button.focus_entered.connect(func() -> void: _detail.text = details)
	button.pressed.connect(func() -> void: room.transfer(item, deposit))

func _ignore_pointer(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_pointer(child)

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
