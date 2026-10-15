extends Node2D

var start: Vector2
var finish: Vector2
var remaining := 0.28
func setup(from: Vector2, to: Vector2) -> void:
	start = from
	finish = to
	z_index = 18
func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()
	else:
		queue_redraw()
func _draw() -> void:
	var a := to_local(start)
	var b := to_local(finish)
	var normal := (b-a).normalized().orthogonal() * 5
	var points := PackedVector2Array([a,a.lerp(b,0.3)+normal,a.lerp(b,0.65)-normal,b])
	var color := Color("77e8ff")
	color.a = clampf(remaining/0.28,0,1)
	draw_polyline(points,color,3)
	draw_circle(b,4,color)
