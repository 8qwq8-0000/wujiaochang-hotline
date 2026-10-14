class_name MobilityMode
extends Resource

@export var id: StringName = &"walk"
@export var display_name: String = "步行（无套件）"
@export_range(1.0, 1000.0, 1.0) var max_speed: float = 150.0
@export_range(1.0, 5000.0, 1.0) var acceleration: float = 1200.0
@export_range(1.0, 5000.0, 1.0) var braking: float = 1600.0
@export_range(0.0, 10.0, 0.1) var ability_cooldown: float = 0.0
@export_range(0.0, 1000.0, 1.0) var ability_impulse: float = 0.0
@export_range(0.0, 1.0, 0.05) var knockback_multiplier: float = 1.0
@export var ignores_ground_slow: bool = false
@export var crosses_low_obstacles: bool = false
@export_range(0.0, 2.0, 0.01) var ability_active_seconds: float = 0.0
@export var locks_attack: bool = false
@export var locks_guard: bool = false


func calculate_velocity(input_vector: Vector2, current_velocity: Vector2, _facing: Vector2, delta: float) -> Vector2:
	var desired := input_vector.normalized() * max_speed
	var rate := acceleration if not input_vector.is_zero_approx() else braking
	return current_velocity.move_toward(desired, rate * delta)


func ability_velocity(facing: Vector2, current_velocity: Vector2) -> Vector2:
	if ability_impulse <= 0.0:
		return current_velocity
	var heading := facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	return heading * ability_impulse


func terrain_speed_multiplier(terrain_tag: StringName) -> float:
	if ignores_ground_slow:
		return 1.0
	match terrain_tag:
		&"mud", &"rubble":
			return 0.7
		_:
			return 1.0
