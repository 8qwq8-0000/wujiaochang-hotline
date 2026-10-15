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
var _blackbox: Button

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
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "组件背包    Tab / Esc 关闭"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_status = Label.new()
	column.add_child(_status)
	_blackbox = Button.new()
	_blackbox.custom_minimum_size.y = 34
	_blackbox.add_theme_font_size_override("font_size", 13)
	_blackbox.pressed.connect(func() -> void: inventory.take_from_blackbox())
	column.add_child(_blackbox)
	_weapon_target = OptionButton.new()
	_weapon_target.add_item("新武装放入：主武装槽", 0)
	_weapon_target.add_item("新武装放入：副武装槽", 1)
	_weapon_target.add_item("操作：把背包物品放入黑匣 / 交换", 2)
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
		button.pressed.connect(func() -> void:
			if _weapon_target.selected == 2:
				inventory.put_in_blackbox(index)
			else:
				inventory.equip(index, _weapon_target.selected))
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
		_message.text = "已装备物品不占背包格。选槽后点击装备；全图已暂停。"
		refresh()
	else:
		for button in _buttons:
			button.release_focus()
		_weapon_target.release_focus()
		_secondary.release_focus()
		_weapon.release_focus()
		_mobility.release_focus()
		_blackbox.release_focus()

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
		_buttons[index].text = item.get_title().replace("（绑定）", "") if item != null else "空格"
		_buttons[index].icon = item.get_texture() if item != null else null
		_buttons[index].disabled = item == null
		_buttons[index].tooltip_text = "点击装备：%s" % item.get_title() if item != null else ""
	var weapon := inventory.weapon_slot.get_item()
	var secondary := inventory.secondary_weapon_slot.get_item()
	var mode := inventory.mobility_slot.get_item()
	var protected := inventory.blackbox_slot.get_item()
	var protection := "空 · 可选择背包物品放入"
	if protected != null:
		protection = protected.get_title()
		if protected.get_property("slot", "") == "insurance":
			protection += " · 已触发" if bool(protected.get_property("circuit_breaker_used", false)) else " · 保险就绪"
		else:
			protection += " · 死亡保留"
	_blackbox.text = "黑匣：%s%s" % [protection, " · 点击取出" if protected != null else ""]
	_blackbox.disabled = protected == null
	_blackbox.tooltip_text = "只保护其中一件物品。保险核心在黑匣中才生效；取出和交换不会刷新保险次数。"
	_sync_weapon_target(weapon, secondary)
	_weapon.text = "主：%s · 卸下" % (weapon.get_title() if weapon != null else "空")
	_secondary.text = "副：%s · 卸下" % (secondary.get_title() if secondary != null else "空")
	_secondary.disabled = secondary == null
	_mobility.text = "机动：%s · 卸下" % (mode.get_title() if mode != null else "基础步行")
	_weapon.disabled = weapon == null
	_mobility.disabled = mode == null


func _sync_weapon_target(primary: InventoryItem, secondary: InventoryItem) -> void:
	# Prefer the empty weapon slot after each successful equipment change.
	# When both slots are occupied, preserve the player's explicit selection.
	if _weapon_target.selected == 2:
		return
	if primary == null:
		_weapon_target.select(0)
	elif secondary == null:
		_weapon_target.select(1)
