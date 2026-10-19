@tool
extends McpTestSuite


func suite_name() -> String:
	return "enemy_navigation"


func test_enemy_scene_enables_bounded_soft_avoidance() -> void:
	var enemy := track(load("res://scenes/actors/enemies/enemy.tscn").instantiate()) as EnemyController
	var agent := enemy.get_node("NavigationAgent2D") as NavigationAgent2D
	assert_true(agent.avoidance_enabled)
	assert_eq(agent.neighbor_distance, 48.0)
	assert_eq(agent.max_neighbors, 6)
	assert_eq(agent.time_horizon_agents, 0.5)
	assert_true(is_equal_approx(agent.time_horizon_obstacles, 0.35))


func test_enemy_scene_owns_sprite_and_animation_player() -> void:
	var enemy := track(load("res://scenes/actors/enemies/enemy.tscn").instantiate()) as EnemyController
	(Engine.get_main_loop() as SceneTree).root.add_child(enemy)
	var sprite := enemy.get_node("Sprite2D") as Sprite2D
	assert_true(sprite != null)
	assert_true(sprite.texture != null)
	assert_true((enemy.get_node("AnimationPlayer") as AnimationPlayer) != null)


func test_direct_retreat_fallback_increases_distance() -> void:
	var enemy := track(load("res://scenes/actors/enemies/enemy.tscn").instantiate()) as EnemyController
	(Engine.get_main_loop() as SceneTree).root.add_child(enemy)
	enemy.position = Vector2(100, 100)
	var threat := Vector2(80, 100)
	var destination := enemy._select_retreat_destination(threat)
	assert_true(destination.x != INF)
	assert_gt(destination.distance_to(threat), enemy.global_position.distance_to(threat))


func test_enemy_noise_does_not_replace_own_last_known_target() -> void:
	var enemy := track(load("res://scenes/actors/enemies/enemy.tscn").instantiate()) as EnemyController
	(Engine.get_main_loop() as SceneTree).root.add_child(enemy)
	var target_position := Vector2(96, 48)
	enemy._alert_to(target_position, false)
	enemy._on_noise(enemy, Vector2(8, 0), 1000.0)
	assert_eq(enemy._last_known_position, target_position)
