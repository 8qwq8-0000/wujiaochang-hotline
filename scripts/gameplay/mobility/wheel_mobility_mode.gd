class_name WheelMobilityMode
extends MobilityMode

@export_range(1, 10, 1) var ram_damage: int = 1
@export_range(0.0, 2.0, 0.05) var ram_stagger_seconds: float = 0.65
@export_range(1.0, 40.0, 1.0) var ram_radius: float = 14.0


func calculate_velocity(input_vector: Vector2, current_velocity: Vector2, _facing: Vector2, delta: float) -> Vector2:
	var desired := input_vector.normalized() * max_speed
	var rate := braking if input_vector.is_zero_approx() or current_velocity.dot(input_vector) < 0.0 else acceleration
	return current_velocity.move_toward(desired, rate * delta)
