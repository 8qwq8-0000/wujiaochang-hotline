extends CanvasLayer

var inventory: ComponentInventory
var _overlay: Control
var _status: Label
var _message: Label
var _buttons: Array[Button] = []
var _weapon: Button
var _secondary: Button
var _weapon_target: OptionButton
var _mobility: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.add_theme_font_size_override("font_size", 14)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
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
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "组件背包    Tab / Esc 关闭"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_status = Label.new()
	column.add_child(_status)
	_weapon_target = OptionButton.new()
	_weapon_target.add_item("新武装放入：主武装槽", 0)
	_weapon_target.add_item("新武装放入：副武装槽", 1)
	column.add_child(_weapon_target)
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	for index in ComponentInventory.CAPACITY:
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 44)
		button.expand_icon = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color("23364a")
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("365671")
		button.add_theme_stylebox_override("hover", hover)
		var empty := style.duplicate() as StyleBoxFlat
		empty.bg_color = Color("1b2b3d")
		button.add_theme_stylebox_override("disabled", empty)
		button.add_theme_constant_override("icon_max_width", 28)
		button.pressed.connect(func() -> void: inventory.equip(index, _weapon_target.selected))
		grid.add_child(button)
		_buttons.append(button)
	var weapon_row := HBoxContainer.new()
	column.add_child(weapon_row)
	_weapon = Button.new()
	_weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon.pressed.connect(func() -> void: inventory.unequip("weapon"))
	weapon_row.add_child(_weapon)
	_secondary = Button.new()
	_secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secondary.pressed.connect(func() -> void: inventory.unequip("weapon_secondary"))
	weapon_row.add_child(_secondary)
	_mobility = Button.new()
	_mobility.pressed.connect(func() -> void: inventory.unequip("mobility"))
	column.add_child(_mobility)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 420
	column.add_child(_message)
	inventory.changed.connect(refresh)
	inventory.feedback.connect(func(text: String, _cue: StringName) -> void: _message.text = text)
	set_open(false)

func set_open(value: bool) -> void:
	_overlay.visible = value
	if value:
		_message.text = "选槽后点击组件装备；Q/滚轮切换。全图已暂停。"
		refresh()
	else:
		for button in _buttons:
			button.release_focus()
		_weapon_target.release_focus()
		_secondary.release_focus()
		_weapon.release_focus()
		_mobility.release_focus()

func _process(_delta: float) -> void:
	if not _overlay.visible:
		return
	if inventory.player.health.is_dead():
		inventory.set_open(false)
		return
	_status.text = "背包 %d / 6    %s" % [inventory.backpack.get_item_count(), "安全：可换装" if inventory.can_change_equipment() else "战斗中：清场后可换装"]

func refresh() -> void:
	var items := inventory.backpack.get_items()
	for index in _buttons.size():
		var item: InventoryItem = items[index] if index < items.size() else null
		var tag := ""
		if item != null and inventory.weapon_slot.get_item() == item:
			tag = " [主]"
		elif item != null and inventory.secondary_weapon_slot.get_item() == item:
			tag = " [副]"
		_buttons[index].text = item.get_title().replace("（绑定）", "") + tag if item != null else "空格"
		_buttons[index].icon = item.get_texture() if item != null else null
		_buttons[index].disabled = item == null
		_buttons[index].tooltip_text = "点击装备：%s" % item.get_title() if item != null else ""
	var weapon := inventory.weapon_slot.get_item()
	var secondary := inventory.secondary_weapon_slot.get_item()
	var mode := inventory.mobility_slot.get_item()
	_weapon.text = "主：%s · 卸下" % (weapon.get_title() if weapon != null else "空")
	_secondary.text = "副：%s · 卸下" % (secondary.get_title() if secondary != null else "空")
	_secondary.disabled = secondary == null
	_mobility.text = "机动：%s · 卸下" % (mode.get_title() if mode != null else "基础步行")
	_weapon.disabled = weapon == null
	_mobility.disabled = mode == null
