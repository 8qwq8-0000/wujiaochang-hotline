extends CanvasLayer

const DRAG_SLOT := preload("res://scripts/ui/inventory_drag_slot.gd")
var inventory: ComponentInventory
var _overlay: Control
var _status: Label
var _message: Label
var _buttons: Array[Button] = []
var _weapon: Button
var _secondary: Button
var _cyberware: Button
var _defense: Button
var _discard_menu: PopupMenu
var _discard_target: InventoryItem
var _blackbox: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.add_theme_font_size_override("font_size", 13)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 500
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("152233")
	panel_style.border_color = Color("49718f")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var title := Label.new()
	title.text = "装备背包                         [Tab] 关闭"
	title.add_theme_font_size_override("font_size", 17)
	column.add_child(title)
	_status = Label.new()
	column.add_child(_status)
	var equipment := GridContainer.new()
	equipment.columns = 2
	equipment.add_theme_constant_override("h_separation", 6)
	equipment.add_theme_constant_override("v_separation", 5)
	column.add_child(equipment)
	_weapon = _make_slot(equipment, "weapon")
	_secondary = _make_slot(equipment, "weapon_secondary")
	_cyberware = _make_slot(equipment, "cyberware")
	_defense = _make_slot(equipment, "defense")
	_blackbox = _make_slot(equipment, "blackbox")
	# Click shortcuts remain available; dragging explicitly chooses the target slot.
	_weapon.pressed.connect(func() -> void: inventory.unequip("weapon"))
	_secondary.pressed.connect(func() -> void: inventory.unequip("weapon_secondary"))
	_defense.pressed.connect(func() -> void: inventory.unequip("defense"))
	_cyberware.pressed.connect(func() -> void: inventory.unequip("cyberware"))
	_blackbox.pressed.connect(func() -> void: inventory.take_from_blackbox())
	var separator := HSeparator.new()
	column.add_child(separator)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	for index in ComponentInventory.CAPACITY:
		var button := _make_slot(grid, "backpack", index)
		button.custom_minimum_size = Vector2(153, 40)
		button.pressed.connect(func() -> void:
			var position := 1 if inventory.weapon_slot.get_item() != null and inventory.secondary_weapon_slot.get_item() == null else 0
			inventory.equip(index, position))
		_buttons.append(button)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(470, 32)
	_message.add_theme_font_size_override("font_size", 12)
	column.add_child(_message)
	_discard_menu = PopupMenu.new()
	_discard_menu.add_item("丢到地上", 0)
	_overlay.add_child(_discard_menu)
	_discard_menu.id_pressed.connect(func(_id: int) -> void:
		var item := _discard_target
		_discard_target = null
		inventory.discard_backpack_item(item))
	inventory.changed.connect(refresh)
	inventory.feedback.connect(func(text: String, _cue: StringName) -> void: _message.text = text)
	set_open(false)

func _make_slot(parent: Control, location: String, index: int = -1) -> Button:
	var button: Button = DRAG_SLOT.new()
	button.inventory = inventory
	button.location = location
	button.cell_index = index
	button.custom_minimum_size = Vector2(234, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	button.add_theme_font_size_override("font_size", 12)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("23364a")
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = Color("3c5971")
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("365671")
	hover.border_color = Color("8eacbd")
	button.add_theme_stylebox_override("hover", hover)
	parent.add_child(button)
	return button

func set_open(value: bool) -> void:
	_overlay.visible = value
	_discard_menu.hide()
	_discard_target = null
	if value:
		_message.text = "拖动装备到高亮槽位；右键背包装备可丢弃。"
		refresh()
	else:
		for button in _buttons + [_weapon, _secondary, _cyberware, _defense, _blackbox]:
			button.release_focus()

func _process(_delta: float) -> void:
	if not _overlay.visible:
		return
	if inventory.player.health.is_dead():
		inventory.set_open(false)
		return
	_status.text = "背包 %d/6    黑匣保护 1 格    %s" % [inventory.backpack.get_item_count(), "可以换装" if inventory.can_change_equipment() else "战斗中不能换装"]

func refresh() -> void:
	for index in _buttons.size():
		var item := inventory.item_at("backpack", index)
		_buttons[index].text = ComponentRolls.title(item).replace("（绑定）", "") if item != null else "空位（可拖入）"
		ComponentRolls.apply_quality_color(_buttons[index], item)
		_buttons[index].icon = item.get_texture() if item != null else null
		_buttons[index].tooltip_text = (ComponentRolls.describe(item) + "\n拖到槽位即可装备或交换；右键可丢弃" if item != null else "把槽内装备拖到这里")
		# Empty cells stay enabled so Godot can deliver drops to them.
	for entry in [{"button": _weapon, "location": "weapon", "title": "主武器"}, {"button": _secondary, "location": "weapon_secondary", "title": "副武器"}, {"button": _cyberware, "location": "cyberware", "title": "义体槽"}, {"button": _defense, "location": "defense", "title": "防御槽"}, {"button": _blackbox, "location": "blackbox", "title": "黑匣"}]:
		var item := inventory.item_at(entry.location)
		var name := ComponentRolls.title(item).replace("（绑定）", "") if item != null else "空位（可拖入）"
		if entry.location == "blackbox" and item != null:
			name += "（已触发）" if bool(item.get_property("circuit_breaker_used", false)) else ("（保险就绪）" if item.get_property("slot", "") == "insurance" else "（死亡保留）")
		entry.button.text = "%s：%s" % [entry.title, name]
		ComponentRolls.apply_quality_color(entry.button, item)
		entry.button.icon = item.get_texture() if item != null else null
		entry.button.tooltip_text = (ComponentRolls.describe(item) + "\n" if item != null else "") + "%s：%s\n拖入可装备或交换，拖回背包可取出。" % [entry.title, name]


func show_discard_menu(item: InventoryItem) -> void:
	if not inventory.can_discard(item):
		return
	_discard_target = item
	_discard_menu.position = Vector2i(_overlay.get_viewport().get_mouse_position())
	_discard_menu.popup()
