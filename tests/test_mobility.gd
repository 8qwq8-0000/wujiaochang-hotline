@tool
extends McpTestSuite


func suite_name() -> String:
	return "mobility"


func test_walking_is_unequipped_default() -> void:
	var mode: MobilityMode = load("res://resources/mobility/walk.tres")
	assert_eq(mode.id, &"walk")
	assert_eq(mode.ability_cooldown, 0.0)
	assert_false(mode.crosses_low_obstacles)


func test_quadruped_crosses_only_authored_low_obstacles() -> void:
	var mode: QuadrupedMobilityMode = load("res://resources/mobility/quadruped.tres")
	assert_eq(mode.id, &"quadruped")
	assert_true(mode.crosses_low_obstacles)
	assert_true(mode.knockback_multiplier < 1.0)
	assert_true(mode.rough_terrain_multiplier >= 0.9)


func test_wheel_has_higher_top_speed_than_quadruped() -> void:
	var wheel: MobilityMode = load("res://resources/mobility/wheel.tres")
	var quadruped: MobilityMode = load("res://resources/mobility/quadruped.tres")
	assert_gt(wheel.max_speed, quadruped.max_speed)
	assert_gt(wheel.ability_cooldown, 0.0)
	var walk: MobilityMode = load("res://resources/mobility/walk.tres")
	assert_true(wheel.max_speed >= walk.max_speed * 1.5)


func test_flight_ignores_ground_slow() -> void:
	var flight: MobilityMode = load("res://resources/mobility/flight.tres")
	assert_true(flight.ignores_ground_slow)
	assert_true(flight.crosses_low_obstacles)
