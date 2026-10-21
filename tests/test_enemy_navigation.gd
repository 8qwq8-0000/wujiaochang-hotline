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
	var sprite := enemy.get_node("BodyVisual") as AnimatedSprite2D
	assert_true(sprite != null)
	assert_true(sprite.sprite_frames != null)
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


func test_wide_door_expands_collision_without_stretching_leaf() -> void:
	var door := track(load("res://scenes/environment/automatic_door.tscn").instantiate()) as AutomaticDoor
	door.configure_opening_width(96.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(door)
	var body_shape := door.get_node("Body/Shape").shape as RectangleShape2D
	var contact_shape := door.get_node("Contact/Shape").shape as RectangleShape2D
	var art := door.get_node("RefinedArt") as RefinedEnvironmentArt
	assert_eq(door.scale, Vector2.ONE)
	assert_eq(body_shape.size, Vector2(12, 96))
	assert_eq(contact_shape.size, Vector2(30, 104))
	assert_eq(art.draw_size, Vector2(40, 72))


func test_enemy_door_breach_preserves_position_and_velocity() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var door := track(load("res://scenes/environment/automatic_door.tscn").instantiate()) as AutomaticDoor
	var enemy := track(load("res://scenes/actors/enemies/enemy.tscn").instantiate()) as EnemyController
	tree.root.add_child(door)
	tree.root.add_child(enemy)
	door.position = Vector2(100, 100)
	enemy.position = Vector2(84, 100)
	enemy.velocity = Vector2(70, 0)
	var position_before := enemy.global_position
	var velocity_before := enemy.velocity
	door._on_contact(enemy)
	assert_true(door.opened)
	assert_eq(enemy.global_position, position_before)
	assert_eq(enemy.velocity, velocity_before)
