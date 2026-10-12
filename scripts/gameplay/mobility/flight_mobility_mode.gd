class_name FlightMobilityMode
extends MobilityMode

@export_range(0.1, 1.0, 0.05) var inertia_ratio: float = 0.82


func calculate_velocity(input_vector: Vector2, current_velocity: Vector2, _facing: Vector2, delta: float) -> Vector2:
	var desired := input_vector.normalized() * max_speed
	if input_vector.is_zero_approx():
		return current_velocity.move_toward(Vector2.ZERO, braking * (1.0 - inertia_ratio) * delta)
	return current_velocity.move_toward(desired, acceleration * delta)
