extends Node2D

var progress := 0.0


func _draw() -> void:
	if progress <= 0.0:
		return
	var box := Rect2(-35.0, -53.0, 70.0, 8.0)
	draw_rect(box.grow(2.0), Color(0.02, 0.02, 0.04, 0.95))
	draw_rect(box, Color(0.12, 0.13, 0.17, 0.95))
	var fill := Rect2(box.position, Vector2(box.size.x * progress, box.size.y))
	draw_rect(fill, Color(0.2, 0.65, 1.0) if progress < 0.5 else Color(1.0, 0.24, 0.27))
	draw_line(Vector2(0.0, -55.0), Vector2(0.0, -43.0), Color.WHITE, 1.0)
	if progress >= 1.0:
		draw_rect(box.grow(3.0), Color(1.0, 0.4, 0.5, 0.9), false, 2.0)
