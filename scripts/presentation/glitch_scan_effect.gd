extends Node2D

const DURATION := 0.24

var _color := Color(0.35, 1.0, 0.4)
var _radius := 28.0
var _elapsed := 0.0


func start(color: Color, radius: float) -> void:
	_color = color
	_radius = maxf(radius, 1.0)
	z_index = 20
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var ratio := clampf(_elapsed / DURATION, 0.0, 1.0)
	var alpha := 1.0 - ratio
	var scan_y := lerpf(-_radius, _radius, ratio)
	for index in 3:
		var line_color := _color
		line_color.a *= alpha * (1.0 - absf(float(index - 1)) * 0.28)
		var y := scan_y + float(index - 1) * 4.0
		var offset := 3.0 if index % 2 == 0 else -3.0
		draw_line(Vector2(-_radius, y), Vector2(-4.0 + offset, y), line_color, 1.5)
		draw_line(Vector2(3.0 + offset, y), Vector2(_radius, y), line_color, 1.5)
	var rim_color := _color
	rim_color.a *= alpha * 0.45
	draw_arc(Vector2.ZERO, _radius * (0.78 + ratio * 0.22), 0.0, TAU, 20, rim_color, 1.0)
