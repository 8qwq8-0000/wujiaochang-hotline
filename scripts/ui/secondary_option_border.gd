extends Control

const REST_COLOR := Color("65737c")
const ACTIVE_COLOR := Color("e7ac62")

var selected := false:
	set(value):
		selected = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var button := get_parent() as BaseButton
	if button != null:
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var button := get_parent() as BaseButton
	if button == null or size.x < 16.0 or size.y < 12.0:
		return
	var highlighted := selected or button.is_hovered() or button.has_focus() or button.button_pressed
	var tint := ACTIVE_COLOR if highlighted else REST_COLOR
	tint.a = 0.9 if highlighted else 0.6
	var cut := minf(5.0, size.y * 0.22)
	var right := size.x - 1.0
	var bottom := size.y - 1.0
	var outline := PackedVector2Array([
		Vector2(cut, 0.5), Vector2(right - cut, 0.5),
		Vector2(right, cut), Vector2(right, bottom - cut),
		Vector2(right - cut, bottom), Vector2(cut, bottom),
		Vector2(0.5, bottom - cut), Vector2(0.5, cut), Vector2(cut, 0.5),
	])
	draw_polyline(outline, tint, 1.0, true)
