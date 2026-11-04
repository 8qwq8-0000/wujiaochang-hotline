class_name InventoryTrashDropZone
extends PanelContainer

var inventory: ComponentInventory
var _label: Label
var _normal_style: StyleBoxFlat
var _active_style: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(0, 44)
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.16, 0.06, 0.08, 0.9)
	_normal_style.border_color = Color(0.7, 0.22, 0.25, 0.9)
	_normal_style.set_border_width_all(2)
	_normal_style.set_corner_radius_all(6)
	_active_style = _normal_style.duplicate() as StyleBoxFlat
	_active_style.bg_color = Color(0.52, 0.08, 0.1, 0.95)
	_active_style.border_color = Color(1.0, 0.5, 0.42)
	add_theme_stylebox_override("panel", _normal_style)
	_label = Label.new()
	_label.text = "丢到地上 · 长按装备并拖到这里"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = 2
	_label.add_theme_font_size_override("font_size", 12)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.66))
	add_child(_label)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var valid := _valid_payload(data) and inventory.can_discard(data.item)
	add_theme_stylebox_override("panel", _active_style if valid else _normal_style)
	_label.text = "松手：把装备丢到玩家附近" if valid else "只能丢弃背包内装备"
	return valid


func _drop_data(_position: Vector2, data: Variant) -> void:
	if _valid_payload(data) and inventory.discard_backpack_item(data.item):
		inventory.set_open(false)
	_reset_visual()


func _valid_payload(data: Variant) -> bool:
	return data is Dictionary and data.get("inventory") == inventory and data.get("item") is InventoryItem


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_reset_visual()


func _reset_visual() -> void:
	if _normal_style == null or _label == null:
		return
	add_theme_stylebox_override("panel", _normal_style)
	_label.text = "丢到地上 · 长按装备并拖到这里"
