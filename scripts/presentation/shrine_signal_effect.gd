extends Node2D

## Industrial signal projection: a floor beacon and rising packet fragments.
var floor_pass := false
var external_strength := -1.0
var _phase := 0.0
var _strength := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	var shrine := get_parent() as ChannelShrineRoom
	var target := external_strength
	if shrine != null and shrine.terminal != null:
		target = 1.0 if shrine.cleared and shrine.terminal.enabled else (0.28 if not shrine.cleared else 0.0)
	if target < 0:
		return
	_strength = move_toward(_strength, target, delta * 1.8)
	_phase = fmod(_phase + delta, 120.0)
	visible = _strength > 0.001
	queue_redraw()


func _draw() -> void:
	if _strength <= 0.001:
		return
	var pulse := (0.82 + sin(_phase * 2.4) * 0.18) * _strength
	if floor_pass:
		# Flattened rings sit below the machine and actors, on the floor.
		draw_set_transform(Vector2(0, 6), 0, Vector2(1, 0.46))
		for radius in range(76, 20, -4):
			draw_circle(Vector2.ZERO, radius, Color(0.06, 0.72, 0.88, 0.018 * pulse))
		draw_arc(Vector2.ZERO, 62, 0, TAU, 80, Color(0.22, 0.91, 1.0, 0.65 * pulse), 1.5)
		draw_arc(Vector2.ZERO, 52, 0, TAU, 72, Color(0.12, 0.72, 0.88, 0.4 * pulse), 1)
		for index in 8:
			var angle := index * TAU / 8.0 + _phase * 0.22
			draw_arc(Vector2.ZERO, 68, angle, angle + 0.22, 8, Color(0.52, 0.98, 1.0, 0.8 * pulse), 2)
		for side: int in [-1, 1]:
			var x := side * 80.0
			draw_line(Vector2(x, -14), Vector2(x, 14), Color(0.28, 0.91, 1.0, 0.7 * pulse), 2)
			draw_line(Vector2(x, -14), Vector2(x - side * 9, -14), Color(0.28, 0.91, 1.0, 0.7 * pulse), 2)
		draw_set_transform(Vector2.ZERO)
		return
	# Narrow, translucent signal column leaves surrounding projectiles readable.
	for index in 7:
		var half_width := 6.0 + index * 2
		draw_rect(Rect2(-half_width, -84, half_width * 2, 72), Color(0.12, 0.78, 1.0, 0.014 * pulse))
	for index in 14:
		var progress := fposmod(_phase * 0.36 + index / 14.0, 1.0)
		var x := sin(index * 7.13) * 34.0 * (1.0 - progress * 0.7)
		var y := 10.0 - progress * 94.0
		var alpha := sin(progress * PI) * pulse
		draw_rect(Rect2(Vector2(x, y).floor(), Vector2(2, 3)), Color(0.48, 0.98, 1.0, alpha * 0.85))
	# Small targeting brackets identify the floating core as the focus.
	var center := Vector2(0, -59 + sin(_phase * 3.0) * 2)
	for side: int in [-1, 1]:
		var point := center + Vector2(side * 22, -12)
		draw_line(point, point + Vector2(-side * 7, 0), Color(0.65, 1.0, 1.0, pulse), 1)
		draw_line(point, point + Vector2(0, 8), Color(0.65, 1.0, 1.0, pulse), 1)
