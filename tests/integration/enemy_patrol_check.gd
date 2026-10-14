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
	for frame in 220:
		enemy._physics_process(1.0 / 60.0)
		minimum_x = minf(minimum_x, enemy.global_position.x)
		maximum_x = maxf(maximum_x, enemy.global_position.x)
		largest_distance = maxf(largest_distance, enemy.global_position.distance_to(anchor))
		await physics_frame
	check(minimum_x < anchor.x - 12 and maximum_x > anchor.x + 12, "patrol visits both sides without a player in scene")
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
	room.queue_free()
	await process_frame
	print("Enemy patrol failures: ", failures)
	quit(0 if failures == 0 else 1)
