extends Node2D


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color("101722"), true)
	for x in range(0, 641, 32):
		draw_line(Vector2(x, 0), Vector2(x, 360), Color(0.14, 0.2, 0.28, 0.35), 1.0)
	for y in range(0, 361, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.14, 0.2, 0.28, 0.35), 1.0)
