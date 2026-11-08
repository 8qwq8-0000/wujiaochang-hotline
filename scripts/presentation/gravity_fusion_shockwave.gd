extends Node2D

const DURATION := 0.32
const MAX_RADIUS := 130.0

var _age := 0.0


func _ready() -> void:
	add_to_group("gravity_fusion_shockwaves")
	z_index = 2
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_age / DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var fade := pow(1.0 - progress, 1.5)
	var radius := lerpf(18.0, MAX_RADIUS, eased)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.74, 0.39, 1.0, 0.75 * fade), 4.0 * (1.0 - progress) + 1.0, true)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 64, Color(0.45, 0.78, 1.0, 0.36 * fade), 2.0, true)
