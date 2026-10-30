extends Node2D

var start: Vector2
var finish: Vector2
var remaining := 0.28
var _redraw_step := 0

func setup(from: Vector2, to: Vector2) -> void:
	start = from
	finish = to
	z_index = 18
func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()
	else:
		_redraw_step += 1
		queue_redraw()

func _draw() -> void:
	var a := to_local(start)
	var b := to_local(finish)
	var delta := b - a
	if delta.is_zero_approx():
		return
	var normal := delta.normalized().orthogonal()
	var points := PackedVector2Array()
	var segment_count := clampi(ceili(delta.length() / 10.0), 5, 12)
	for index in segment_count + 1:
		var t := float(index) / float(segment_count)
		var jitter := 0.0
		if index > 0 and index < segment_count:
			jitter = sin(float(index * 29 + _redraw_step * 17) * 1.73) * minf(6.0, delta.length() * 0.12)
		points.append(a.lerp(b, t) + normal * jitter)
	var alpha := clampf(remaining / 0.28, 0.0, 1.0)
	draw_polyline(points, Color(0.12, 0.55, 1.0, alpha * 0.46), 6.0, true)
	draw_polyline(points, Color(0.42, 0.9, 1.0, alpha), 3.0, true)
	draw_polyline(points, Color(0.94, 0.99, 1.0, alpha), 1.0, true)
	if points.size() >= 6:
		var branch_index := 2 + (_redraw_step % (points.size() - 4))
		var branch_start := points[branch_index]
		var branch_direction := normal * (5.0 + float((_redraw_step + branch_index) % 4))
		draw_line(branch_start, branch_start + branch_direction, Color(0.42, 0.9, 1.0, alpha * 0.8), 1.5, true)
	draw_circle(b, 4.0, Color(0.55, 0.94, 1.0, alpha * 0.75))
