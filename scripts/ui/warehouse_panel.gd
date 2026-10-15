extends CanvasLayer

var room: Node2D
var is_open := false
var _owns_pause := false
var _overlay: ColorRect
var _bag_list: VBoxContainer
var _chest_list: VBoxContainer
var _count: Label
var _message: Label

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.04, 0.06, 0.97)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "仓库 / 储物箱"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 [E / Esc]"
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 13)
	column.add_child(_count)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	_bag_list = _make_list(columns, "随身装备 → 存入")
	_chest_list = _make_list(columns, "储物箱 → 取出")
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 12)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	_overlay.hide()

func _make_list(parent: Control, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	column.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list

func open() -> void:
	if is_open or room.player.inventory.is_open or room.player.health.is_dead():
		return
	is_open = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)
	_overlay.show()
	show_message("点击装备存取 · 取出进入背包 · 自动保存")
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
	_count.text = "背包 %d / 6    储物箱 %d 件    已装备物品不占背包格" % [inventory.backpack.get_item_count(), room.chest.get_item_count()]
	for entry in [{"slot": inventory.weapon_slot, "name": "主武器"}, {"slot": inventory.secondary_weapon_slot, "name": "副武器"}, {"slot": inventory.mobility_slot, "name": "机动"}]:
		var item: InventoryItem = entry.slot.get_item()
		if item != null:
			_add_item(_bag_list, item, entry.name + " · ", true)
	for item in inventory.backpack.get_items():
		_add_item(_bag_list, item, "背包 · ", true)
	for item in room.chest.get_items():
		_add_item(_chest_list, item, "", false)
	if room.chest.get_item_count() == 0:
		var empty := Label.new()
		empty.text = "箱子是空的\n从左侧存入战利品"
		empty.add_theme_font_size_override("font_size", 14)
		_chest_list.add_child(empty)

func _add_item(parent: Control, item: InventoryItem, prefix: String, deposit: bool) -> void:
	var button := Button.new()
	button.text = prefix + item.get_title()
	button.icon = item.get_texture()
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = Vector2(270, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.disabled = deposit and bool(item.get_property("bound", false))
	button.tooltip_text = "绑定初始装备不能存入" if button.disabled else ("点击存入箱子" if deposit else "点击取出到背包")
	button.pressed.connect(func() -> void: room.transfer(item, deposit))
	parent.add_child(button)

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
