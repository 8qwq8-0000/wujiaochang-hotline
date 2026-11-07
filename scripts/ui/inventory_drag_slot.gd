extends Button

## Native Godot drag/drop: ownership changes only after a valid drop.
const LONG_PRESS_SECONDS := 0.36
const TOUCH_CANCEL_DISTANCE := 18.0

var inventory: ComponentInventory
var location := "backpack"
var cell_index := -1
var _touch_index := -1
var _touch_started_usec := 0
var _touch_start := Vector2.ZERO
var _touch_cancelled := false
var _long_press_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _get_drag_data(_position: Vector2) -> Variant:
	var item := inventory.item_at(location, cell_index)
	if item == null or not inventory.is_open or inventory.is_channel_core(item):
		return null
	var preview := _make_drag_preview(item)
	set_drag_preview(preview)
	return {"inventory": inventory, "item": item}


func _make_drag_preview(item: InventoryItem) -> Control:
	var preview := HBoxContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := item.get_texture()
	if texture != null:
		var icon_view := TextureRect.new()
		icon_view.texture = texture
		icon_view.custom_minimum_size = Vector2(28, 28)
		icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(icon_view)
	var label := Label.new()
	label.text = ComponentRolls.title(item)
	ComponentRolls.apply_quality_color(label, item)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	preview.add_child(label)
	return preview

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var valid := _valid_payload(data) and inventory.can_drop_item(data.item, location, cell_index)
	modulate = Color("a4efc3") if valid else Color("e6a2a2")
	return valid

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _valid_payload(data):
		inventory.drop_item(data.item, location, cell_index)
	modulate = Color.WHITE

func _valid_payload(data: Variant) -> bool:
	return data is Dictionary and data.get("inventory") == inventory and data.get("item") is InventoryItem

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		modulate = Color.WHITE
	if what == NOTIFICATION_DRAG_END:
		_reset_touch_hold()


func _gui_input(event: InputEvent) -> void:
	# Touch is handled explicitly for long-press drag. Suppress its emulated
	# mouse duplicate (and the editor mouse's emulated touch duplicate).
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0:
			_touch_index = touch.index
			_touch_started_usec = Time.get_ticks_usec()
			_touch_start = touch.position
			_touch_cancelled = false
			_long_press_started = false
			set_process(true)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			if not _long_press_started and not _touch_cancelled:
				pressed.emit()
			_reset_touch_hold()
			accept_event()
		return
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		if not _long_press_started and (event as InputEventScreenDrag).position.distance_to(_touch_start) > TOUCH_CANCEL_DISTANCE:
			_touch_cancelled = true
			set_process(false)
		accept_event()
		return
	if location == "backpack" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var item := inventory.item_at(location, cell_index)
		if inventory.can_discard(item):
			inventory.panel.show_discard_menu(item)
			accept_event()


func _process(_delta: float) -> void:
	if _touch_index < 0 or _touch_cancelled or _long_press_started:
		set_process(false)
		return
	if Time.get_ticks_usec() - _touch_started_usec < int(LONG_PRESS_SECONDS * 1_000_000.0):
		return
	var item := inventory.item_at(location, cell_index)
	if item == null or not inventory.is_open:
		_reset_touch_hold()
		return
	_long_press_started = true
	set_process(false)
	force_drag({"inventory": inventory, "item": item}, _make_drag_preview(item))


func _reset_touch_hold() -> void:
	_touch_index = -1
	_touch_started_usec = 0
	_touch_start = Vector2.ZERO
	_touch_cancelled = false
	_long_press_started = false
	set_process(false)
