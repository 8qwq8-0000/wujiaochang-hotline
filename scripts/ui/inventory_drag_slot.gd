extends Button

## Native Godot drag/drop: ownership changes only after a valid drop.
var inventory: ComponentInventory
var location := "backpack"
var cell_index := -1

func _get_drag_data(_position: Vector2) -> Variant:
	var item := inventory.item_at(location, cell_index)
	if item == null or not inventory.is_open:
		return null
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
	set_drag_preview(preview)
	return {"inventory": inventory, "item": item}

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


func _gui_input(event: InputEvent) -> void:
	if location == "backpack" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var item := inventory.item_at(location, cell_index)
		if inventory.can_discard(item):
			inventory.panel.show_discard_menu(item)
			accept_event()
