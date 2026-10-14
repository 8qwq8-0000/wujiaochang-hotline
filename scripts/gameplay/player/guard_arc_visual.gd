class_name GuardArcVisual
extends Node2D

var _state: GuardComponent.State = GuardComponent.State.IDLE
var _direction := Vector2.RIGHT
var _arc_degrees: float = 120.0


func update_guard(state: GuardComponent.State, direction: Vector2, arc_degrees: float) -> void:
	_state = state
	if not direction.is_zero_approx():
		_direction = direction.normalized()
	_arc_degrees = arc_degrees
	queue_redraw()


func _draw() -> void:
	if _state != GuardComponent.State.PERFECT and _state != GuardComponent.State.NORMAL:
		return
	var half_arc := deg_to_rad(_arc_degrees * 0.5)
	var center_angle := _direction.angle()
	var color := Color(1.0, 0.75, 0.15) if _state == GuardComponent.State.PERFECT else Color(0.25, 0.8, 1.0)
	draw_arc(Vector2(0.0, -10.0), 19.0, center_angle - half_arc, center_angle + half_arc, 20, color, 3.0)
