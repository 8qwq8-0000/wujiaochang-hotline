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
var _materials: Array = [null, null]
var _material_buttons: Array[Button] = []
var _synthesis_button: Button
const SYNTHESIS_DRAG := preload("res://scripts/ui/synthesis_drag_button.gd")

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
	_title = title
	title.text = heading_text
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
	if room.has_method("synthesize"):
		var row := HBoxContainer.new()
		column.add_child(row)
		for index in 2:
			var slot := Button.new()
			slot.set_script(SYNTHESIS_DRAG)
			slot.panel = self
			slot.target_index = index
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.add_theme_font_size_override("font_size", 12)
			slot.pressed.connect(func() -> void: select_material(index, null))
			row.add_child(slot)
			_material_buttons.append(slot)
		_synthesis_button = Button.new()
		_synthesis_button.text = "合成并保存"
		_synthesis_button.pressed.connect(_synthesize)
		row.add_child(_synthesis_button)
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

func open(upgrading: bool = false) -> void:
	if is_open or room.player.inventory.is_open or room.player.health.is_dead():
		return
	is_open = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)
	_overlay.show()
	_title.text = "合成师 · 武器升级" if upgrading else heading_text
	show_message("先将随身材料存入右侧，再拖入主体 / 材料升级；初始警棍按制式计算" if upgrading else open_message)
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
	_refresh_materials()
	for list in [_bag_list, _chest_list]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	var inventory: ComponentInventory = room.player.inventory
	_count.text = "背包 %d / 6    储物箱 %d 件    已装备物品不占背包格" % [inventory.backpack.get_item_count(), room.chest.get_item_count()]
	for entry in [{"slot": inventory.weapon_slot, "name": "主武器"}, {"slot": inventory.secondary_weapon_slot, "name": "副武器"}, {"slot": inventory.mobility_slot, "name": "机动"}, {"slot": inventory.blackbox_slot, "name": "黑匣"}]:
		var item: InventoryItem = entry.slot.get_item()
		if item != null:
			_add_item(_bag_list, item, entry.name + " · ", true)
	for item in inventory.backpack.get_items():
		_add_item(_bag_list, item, "背包 · ", true)
	for item in _chest_display_items():
		_add_item(_chest_list, item, "", false)
	if room.chest.get_item_count() == 0:
		var empty := Label.new()
		empty.text = "箱子是空的\n从左侧存入战利品"
		empty.add_theme_font_size_override("font_size", 14)
		_chest_list.add_child(empty)

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
	if room.has_method("synthesize") and not deposit:
		button.set_script(SYNTHESIS_DRAG)
		button.panel = self
		button.item = item
	button.text = prefix + ComponentRolls.title(item)
	button.icon = item.get_texture()
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = Vector2(270, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.disabled = deposit and bool(item.get_property("bound", false)) and not ComponentRolls.starter(item)
	button.tooltip_text = ComponentRolls.describe(item) + "\n" + ("点击存入箱子" if deposit else "点击取出到背包")
	button.pressed.connect(func() -> void: room.transfer(item, deposit))
	parent.add_child(button)

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false

func select_material(index: int, item: InventoryItem) -> void:
	_materials[index] = item
	if item != null and _materials[1 - index] == item:
		_materials[1 - index] = null
	_refresh_materials()
	show_message("从仓库拖入主体与材料；保留主体形态，升一品质，原型封顶。点击槽位取消。")

func _refresh_materials() -> void:
	if _material_buttons.is_empty():
		return
	for index in 2:
		var item: InventoryItem = _materials[index]
		if item != null and not room.chest.has_item(item):
			_materials[index] = null
		item = _materials[index]
		_material_buttons[index].text = ("主体" if index == 0 else "材料") + " · " + (ComponentRolls.title(item) if item != null else "从仓库拖入")
		_material_buttons[index].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_material_buttons[index].custom_minimum_size.x = 165
		_material_buttons[index].tooltip_text = ComponentRolls.describe(item) if item != null else "拖入同槽位同品质组件"
	_synthesis_button.disabled = not ComponentRolls.compatible(_materials[0], _materials[1])

func _synthesize() -> void:
	room.synthesize(_materials[0], _materials[1])
