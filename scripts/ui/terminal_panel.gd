@tool
class_name TerminalPanel
extends MarginContainer

@export var title := "SYSTEM" :
	set(value):
		title = value
		queue_redraw()
@export var accent_color := CyberUITheme.PHOSPHOR :
	set(value):
		accent_color = value
		queue_redraw()
@export var panel_color := CyberUITheme.PANEL :
	set(value):
		panel_color = value
		queue_redraw()
@export_range(0.0, 12.0, 1.0) var cut_size := 6.0 :
	set(value):
		cut_size = value
		queue_redraw()


func _ready() -> void:
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_top", 20)
	add_theme_constant_override("margin_bottom", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var cut := minf(cut_size, minf(size.x, size.y) * 0.25)
	var points := PackedVector2Array([
		Vector2(0.0, cut), Vector2(cut, 0.0), Vector2(size.x - cut, 0.0),
		Vector2(size.x, cut), Vector2(size.x, size.y - cut), Vector2(size.x - cut, size.y),
		Vector2(cut, size.y), Vector2(0.0, size.y - cut), Vector2(0.0, cut),
	])
	draw_colored_polygon(points, panel_color)
	draw_polyline(points, accent_color, 1.0, false)
	if not title.is_empty():
		draw_rect(Rect2(8.0, 1.0, minf(size.x - 20.0, title.length() * 7.0 + 12.0), 16.0), panel_color)
		draw_string(CyberUITheme.FONT, Vector2(12.0, 14.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, accent_color)
	for x in range(12, mini(84, int(size.x - 8.0)), 12):
		draw_line(Vector2(x, size.y - 3.0), Vector2(x + 5.0, size.y - 3.0), Color(accent_color, 0.45), 1.0)
