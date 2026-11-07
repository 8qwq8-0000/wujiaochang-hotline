extends CanvasLayer

const DRAG_SLOT := preload("res://scripts/ui/inventory_drag_slot.gd")
const TRASH_ZONE := preload("res://scripts/ui/inventory_trash_drop_zone.gd")
var inventory: ComponentInventory
var _overlay: Control
var _status: Label
var _message: Label
var _buttons: Array[Button] = []
var _weapon: Button
var _secondary: Button
var _defense: Button
var _discard_menu: PopupMenu
var _discard_target: InventoryItem
var _blackbox: Button
var _trash_zone: InventoryTrashDropZone
var _panel: Panel
var _close_button: Button
var _scroll: ScrollContainer
var _scroll_touch := -1
var _scroll_origin := Vector2.ZERO
var _scroll_start := 0
var _swiping := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = CyberUITheme.create_os_theme()
	add_child(_overlay)
	_overlay.add_theme_font_size_override("font_size", 13)
	var shade := ColorRect.new()
	shade.color = Color("171d20cc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var panel := Panel.new()
	_panel = panel
	panel.clip_contents = true
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("20262a")
	panel_style.set_border_width_all(0)
	panel.add_theme_stylebox_override("panel", panel_style)
	_overlay.add_child(panel)
	CyberUITheme.add_os_frame(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "装备背包"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	header.add_child(title)
	_close_button = Button.new()
	_close_button.text = "关闭 ×" if OS.has_feature("mobile") else "关闭 [Tab]"
	_close_button.custom_minimum_size = Vector2(100, 36)
	_close_button.pressed.connect(func() -> void: inventory.set_open(false))
	_close_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed and not event.canceled:
			inventory.set_open(false)
			_close_button.accept_event())
	header.add_child(_close_button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	column.add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.scroll_deadzone = 18
	column.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	_scroll.add_child(body)
	var equipment := GridContainer.new()
	equipment.columns = 2
	equipment.add_theme_constant_override("h_separation", 6)
	equipment.add_theme_constant_override("v_separation", 5)
	body.add_child(equipment)
	_weapon = _make_slot(equipment, "weapon")
	_secondary = _make_slot(equipment, "weapon_secondary")
	_defense = _make_slot(equipment, "defense")
	_blackbox = _make_slot(equipment, "blackbox")
	# Click shortcuts remain available; dragging explicitly chooses the target slot.
	_weapon.pressed.connect(func() -> void: inventory.unequip("weapon"))
	_secondary.pressed.connect(func() -> void: inventory.unequip("weapon_secondary"))
	_defense.pressed.connect(func() -> void: inventory.unequip("defense"))
	_blackbox.pressed.connect(func() -> void: inventory.take_from_blackbox())
	var separator := HSeparator.new()
	body.add_child(separator)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	for index in ComponentInventory.CAPACITY:
		var button := _make_slot(grid, "backpack", index)
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(func() -> void:
			var position := 1 if inventory.weapon_slot.get_item() != null and inventory.secondary_weapon_slot.get_item() == null else 0
			inventory.equip(index, position))
		_buttons.append(button)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.max_lines_visible = 2
	_message.custom_minimum_size = Vector2(0, 32)
	_message.add_theme_font_size_override("font_size", 12)
	column.add_child(_message)
	_trash_zone = TRASH_ZONE.new()
	_trash_zone.inventory = inventory
	column.add_child(_trash_zone)
	_discard_menu = PopupMenu.new()
	_discard_menu.add_item("丢到地上", 0)
	_overlay.add_child(_discard_menu)
	_discard_menu.id_pressed.connect(func(_id: int) -> void:
		var item := _discard_target
		_discard_target = null
		inventory.discard_backpack_item(item))
	inventory.changed.connect(refresh)
	inventory.feedback.connect(func(text: String, _cue: StringName) -> void: _message.text = text)
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	set_open(false)

func _fit_panel() -> void:
	var safe := get_viewport().get_visible_rect().grow(-6.0)
	var mobile := get_node_or_null("/root/MobileInput")
	if mobile != null:
		safe = mobile._safe_rect()
	_panel.size = Vector2(minf(520, safe.size.x), minf(424, safe.size.y))
	_panel.position = safe.get_center() - _panel.size * 0.5


func _input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _scroll_touch < 0 and _scroll.get_global_rect().has_point(event.position) and not _scroll.get_v_scroll_bar().get_global_rect().has_point(event.position):
			_scroll_touch = event.index
			_scroll_origin = event.position
			_scroll_start = _scroll.scroll_vertical
			_swiping = false
		elif not event.pressed and event.index == _scroll_touch:
			if get_viewport().gui_is_dragging():
				_finish_touch_drop(event.position, event.canceled)
			_scroll_touch = -1
			if _swiping:
				get_viewport().set_input_as_handled()
			_swiping = false
	elif event is InputEventScreenDrag and event.index == _scroll_touch and not get_viewport().gui_is_dragging():
		var distance: float = event.position.y - _scroll_origin.y
		if not _swiping and absf(distance) > 18.0:
			_swiping = true
			# A swipe cancels the slot tap/long-press before GUI dispatch.
			for slot in _buttons + [_weapon, _secondary, _defense, _blackbox]:
				slot._reset_touch_hold()
		if _swiping:
			_scroll.scroll_vertical = _scroll_start - int(distance)
			get_viewport().set_input_as_handled()


func _finish_touch_drop(point: Vector2, canceled: bool) -> void:
	var payload: Variant = get_viewport().gui_get_drag_data()
	var target: Control
	if not canceled:
		if _trash_zone.get_global_rect().has_point(point):
			target = _trash_zone
		elif _scroll.get_global_rect().has_point(point):
			for slot in _buttons + [_weapon, _secondary, _defense, _blackbox]:
				if slot.get_global_rect().has_point(point):
					target = slot
					break
	var accepted: bool = target != null and target._can_drop_data(Vector2.ZERO, payload)
	# Native touches do not reliably deliver the emulated mouse-up used by
	# Godot drag/drop. Finish once, through the same validated item transaction.
	get_viewport().gui_cancel_drag()
	if accepted:
		target._drop_data(Vector2.ZERO, payload)
	get_viewport().set_input_as_handled()


func _make_slot(parent: Control, location: String, index: int = -1) -> Button:
	var button: Button = DRAG_SLOT.new()
	button.inventory = inventory
	button.location = location
	button.cell_index = index
	button.custom_minimum_size = Vector2(0, 42)
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
	_scroll_touch = -1
	_swiping = false
	_discard_menu.hide()
	_discard_target = null
	if value:
		_fit_panel()
		call_deferred("_fit_panel")
		_scroll.scroll_vertical = 0
		_message.text = "上下滑动查看装备；义体会直接进入独立回路库，按 C 编辑。"
		refresh()
	else:
		_close_button.release_focus()
		for button in _buttons + [_weapon, _secondary, _defense, _blackbox]:
			button.release_focus()

func _process(_delta: float) -> void:
	if not _overlay.visible:
		return
	if inventory.player.health.is_dead():
		inventory.set_open(false)
		return
	_fit_panel()
	_status.text = "背包 %d/6    黑匣保护 1 格    %s" % [inventory.backpack.get_item_count(), "可以换装" if inventory.can_change_equipment() else "战斗中不能换装"]

func refresh() -> void:
	for index in _buttons.size():
		var item := inventory.item_at("backpack", index)
		_buttons[index].text = ComponentRolls.title(item).replace("（绑定）", "") if item != null else "空位（可拖入）"
		ComponentRolls.apply_quality_color(_buttons[index], item)
		_buttons[index].icon = item.get_texture() if item != null else null
		_buttons[index].tooltip_text = (ComponentRolls.describe(item) + "\n长按拖到槽位即可装备或交换，也可拖到丢弃区" if item != null else "把槽内装备拖到这里")
		if inventory.is_channel_core(item):
			_buttons[index].tooltip_text = "残损频道核心\n第二结局前置道具，固定占用第一格，不可丢弃、移动或存入黑匣。\n携带期间：生命上限 1、移速 -15%、突进冷却 +40%、散热 -30%。"
		# Empty cells stay enabled so Godot can deliver drops to them.
	for entry in [{"button": _weapon, "location": "weapon", "title": "主武器"}, {"button": _secondary, "location": "weapon_secondary", "title": "副武器"}, {"button": _defense, "location": "defense", "title": "防御槽"}, {"button": _blackbox, "location": "blackbox", "title": "黑匣"}]:
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
