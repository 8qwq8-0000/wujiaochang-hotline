class_name WheelMobilityMode
extends MobilityMode

@export_range(0.1, 20.0, 0.1) var steering_response: float = 5.0
@export_range(0.0, 1.0, 0.05) var lateral_grip: float = 0.72


func calculate_velocity(input_vector: Vector2, current_velocity: Vector2, facing: Vector2, delta: float) -> Vector2:
	if input_vector.is_zero_approx():
		return current_velocity.move_toward(Vector2.ZERO, braking * delta)
	var desired_direction := input_vector.normalized()
	var current_direction := current_velocity.normalized() if current_velocity.length() > 4.0 else facing.normalized()
	if current_direction.is_zero_approx():
		current_direction = desired_direction
	var turn_weight := clampf(steering_response * delta, 0.0, 1.0)
	var steered_direction := current_direction.lerp(desired_direction, turn_weight).normalized()
	var forward_speed := current_velocity.dot(steered_direction)
	var lateral := current_velocity - steered_direction * forward_speed
	var gripped_velocity := current_velocity - lateral * lateral_grip * clampf(delta * 10.0, 0.0, 1.0)
	return gripped_velocity.move_toward(steered_direction * max_speed, acceleration * delta)
