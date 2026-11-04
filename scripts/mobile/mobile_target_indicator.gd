class_name MobileTargetIndicator
extends Control

var target: Node2D
var manual_override := false
var enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not enabled or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var point := target.get_global_transform_with_canvas().origin
	if not Rect2(Vector2.ZERO, size).grow(20.0).has_point(point):
		return
	var color := Color(0.9, 0.96, 1.0, 0.9) if manual_override else Color(0.2, 0.9, 1.0, 0.82)
	draw_arc(point, 16.0, 0.0, TAU, 32, color, 2.0)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.from_angle(angle)
		draw_line(point + direction * 11.0, point + direction * 20.0, color, 2.0)
