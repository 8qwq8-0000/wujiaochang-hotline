class_name ChargingSigil
extends Node2D

## Animated floor projection. Uses engine geometry, no bitmap frames needed.
var phase := 0.0
var active := false

func _ready() -> void:
	z_as_relative = false
	z_index = -1
	refresh()

func refresh() -> void:
	var station := get_parent() as PowerBox
	active = station.state == PowerBox.State.READY and station.scope_room().get("cleared") != true
	visible = active
	queue_redraw()

func _process(delta: float) -> void:
	refresh()
	if active:
		phase = fmod(phase + delta, TAU * 20.0)
		queue_redraw()

func _draw() -> void:
	if not active:
		return
	# Compress the ground plane, keeping the terminal's upright facade intact.
	draw_set_transform(Vector2(0, 13), 0, Vector2(1, 0.48))
	var pulse := 0.72 + 0.22 * sin(phase * 2.2)
	for radius in range(48, 29, -3):
		draw_circle(Vector2.ZERO, radius, Color(0.12, 0.85, 0.83, 0.025 * pulse))
	draw_arc(Vector2.ZERO, 39, 0, TAU, 80, Color(0.3, 1, 0.91, 0.75 * pulse), 1.2, true)
	draw_arc(Vector2.ZERO, 30, 0, TAU, 64, Color(0.15, 0.72, 0.84, 0.45 * pulse), 1, true)
	for index in 6:
		var angle := index * TAU / 6.0 + phase * 0.22
		draw_arc(Vector2.ZERO, 44, angle, angle + 0.58, 12, Color(0.45, 1, 0.92, pulse), 2, true)
		var center := Vector2.from_angle(angle + 0.28) * 34
		var radial := Vector2.from_angle(angle + 0.28) * 3
		var tangent := radial.orthogonal() * 0.7
		draw_polyline(PackedVector2Array([center - radial, center + tangent, center + radial, center - tangent, center - radial]), Color(0.6, 1, 0.92, pulse), 1, true)
	for index in 12:
		var angle := index * TAU / 12.0 - phase * 0.12
		draw_line(Vector2.from_angle(angle) * 23, Vector2.from_angle(angle) * 26, Color(0.18, 0.85, 0.9, pulse), 1, true)
	draw_set_transform(Vector2.ZERO)
