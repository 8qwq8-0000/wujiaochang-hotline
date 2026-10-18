extends Button

var panel: CanvasLayer
var item: InventoryItem
var target_index := -1

func _get_drag_data(_position: Vector2) -> Variant:
	if item == null or not panel.owns_item(item):
		return null
	var label := Label.new()
	label.text = ComponentRolls.title(item)
	set_drag_preview(label)
	return {"synthesis_panel": panel, "item": item}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return target_index >= 0 and data is Dictionary and data.get("synthesis_panel") == panel and ComponentRolls.synthesizable(data.get("item")) and panel.owns_item(data.item)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		panel.select_material(target_index, data.item)
