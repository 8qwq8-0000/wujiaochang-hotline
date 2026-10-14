extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func new_enemy(room: Node, location: Vector2) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	enemy.profile.patrol_axis = EnemyProfile.PatrolAxis.HORIZONTAL
	enemy.profile.patrol_distance = 24
	enemy.profile.patrol_pause_seconds = 0.1
	enemy.profile.patrol_speed_ratio = 0.75
	enemy.profile.patrol_blocked_timeout = 0.2
	enemy.profile.alert_memory_seconds = 0.2
	enemy.profile.awareness_range = 100
	enemy.profile.ally_alert_range = 0
	enemy.position = location
	room.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func run() -> void:
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var enemy := new_enemy(room, Vector2(200, 200))
	var anchor := enemy.global_position
	await physics_frame
	enemy._physics_process(0.05)
	check(enemy.state == EnemyController.State.IDLE and enemy.global_position == anchor, "patrol waits before walking")
	var minimum_x := anchor.x
	var maximum_x := anchor.x
	var largest_distance := 0.0
	var largest_lane_error := 0.0
	for frame in 220:
		enemy._physics_process(1.0 / 60.0)
		minimum_x = minf(minimum_x, enemy.global_position.x)
		maximum_x = maxf(maximum_x, enemy.global_position.x)
		largest_distance = maxf(largest_distance, enemy.global_position.distance_to(anchor))
		largest_lane_error = maxf(largest_lane_error, absf(enemy.global_position.y - anchor.y))
		await physics_frame
	check(minimum_x < anchor.x - 12 and maximum_x > anchor.x + 12, "patrol visits both sides without a player in scene")
	check(largest_lane_error < 0.1, "horizontal patrol stays on one line without navigation detours")
	check(largest_distance <= 28, "patrol remains near original spawn")
	enemy.set_physics_process(true)
	paused = true
	var position_before := enemy.global_position
	var wait_before: float = enemy.get("_patrol_wait_remaining")
	await create_timer(0.15, true).timeout
	check(enemy.global_position == position_before and enemy.get("_patrol_wait_remaining") == wait_before, "world pause stops patrol movement and wait timer")
	paused = false
	enemy.set_physics_process(false)
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = enemy.global_position + Vector2(20, 0)
	room.add_child(player)
	root.get_node("CombatEvents").publish_noise(player, player.global_position, 100.0)
	check(enemy.is_alerted() and enemy.state == EnemyController.State.CHASE, "sound immediately interrupts patrol")
	player.position = Vector2(1000, 1000)
	enemy._physics_process(0.3)
	check(not enemy.is_alerted(), "lost target returns to non-alerted movement")
	var reached_anchor := enemy.global_position.distance_to(anchor) <= 5
	var resumed_patrol := false
	for frame in 140:
		enemy._physics_process(1.0 / 60.0)
		reached_anchor = reached_anchor or enemy.global_position.distance_to(anchor) <= 5
		resumed_patrol = resumed_patrol or enemy.state == EnemyController.State.PATROL
		await physics_frame
	check(reached_anchor and resumed_patrol, "enemy returns to original anchor and resumes patrol after search")
	check(enemy.get("_patrol_anchor") == anchor, "chase does not move patrol spawn anchor")
	var blocker := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 80)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = Vector2(185, 350)
	room.add_child(blocker)
	var blocked := new_enemy(room, Vector2(200, 350))
	await physics_frame
	await physics_frame
	var visited_clear_side := false
	var crossed_wall := false
	for frame in 180:
		blocked._physics_process(1.0 / 60.0)
		visited_clear_side = visited_clear_side or blocked.global_position.x > 210
		crossed_wall = crossed_wall or blocked.global_position.x < 189
		await physics_frame
	check(visited_clear_side and not crossed_wall, "blocked endpoint is skipped without passing through wall")
	blocked.profile.patrol_enabled = false
	var held_position := blocked.global_position
	blocked._physics_process(1.0)
	check(blocked.state == EnemyController.State.IDLE and blocked.global_position == held_position, "stationary profiles can disable patrol")
	var dead_position := blocked.global_position
	blocked.health.apply_damage(blocked.health.max_health, DamagePacket.new())
	blocked._physics_process(1.0)
	check(blocked.state == EnemyController.State.DEAD and blocked.global_position == dead_position, "dead enemy does not resume patrol")
	# Automatic selection reads the nearest wall normal after physics registration.
	var vertical_wall := StaticBody2D.new()
	var vertical_shape := CollisionShape2D.new()
	var vertical_rectangle := RectangleShape2D.new()
	vertical_rectangle.size = Vector2(8, 160)
	vertical_shape.shape = vertical_rectangle
	vertical_wall.add_child(vertical_shape)
	vertical_wall.position = Vector2(480, 200)
	room.add_child(vertical_wall)
	var vertical := new_enemy(room, Vector2(500, 200))
	vertical.profile.patrol_axis = EnemyProfile.PatrolAxis.AUTO_WALL
	var horizontal_wall := StaticBody2D.new()
	var horizontal_shape := CollisionShape2D.new()
	var horizontal_rectangle := RectangleShape2D.new()
	horizontal_rectangle.size = Vector2(160, 8)
	horizontal_shape.shape = horizontal_rectangle
	horizontal_wall.add_child(horizontal_shape)
	horizontal_wall.position = Vector2(700, 180)
	room.add_child(horizontal_wall)
	var horizontal := new_enemy(room, Vector2(700, 200))
	horizontal.profile.patrol_axis = EnemyProfile.PatrolAxis.AUTO_WALL
	await physics_frame
	await physics_frame
	var vertical_min := 200.0
	var vertical_max := 200.0
	var horizontal_min := 700.0
	var horizontal_max := 700.0
	var stable_lanes := true
	for frame in 150:
		vertical._physics_process(1.0 / 60.0)
		horizontal._physics_process(1.0 / 60.0)
		vertical_min = minf(vertical_min, vertical.global_position.y)
		vertical_max = maxf(vertical_max, vertical.global_position.y)
		horizontal_min = minf(horizontal_min, horizontal.global_position.x)
		horizontal_max = maxf(horizontal_max, horizontal.global_position.x)
		stable_lanes = stable_lanes and absf(vertical.global_position.x - 500.0) < 0.1 and absf(horizontal.global_position.y - 200.0) < 0.1
		await physics_frame
	check(vertical.get("_patrol_axis") == Vector2.DOWN and vertical_min < 188 and vertical_max > 212, "vertical wall selects up/down patrol")
	check(horizontal.get("_patrol_axis") == Vector2.RIGHT and horizontal_min < 688 and horizontal_max > 712, "horizontal wall selects left/right patrol")
	check(stable_lanes, "automatic patrol remains parallel to each wall without drifting")
	room.queue_free()
	await process_frame
	print("Enemy patrol failures: ", failures)
	quit(0 if failures == 0 else 1)
