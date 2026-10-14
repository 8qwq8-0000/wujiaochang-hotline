extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		if get_nodes_in_group("enemies").size() == 3 and not main.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	# Keep awareness out of this patrol-only check; verify the actual spawner.
	player.global_position = Vector2(-500, -500)
	var expected := {&"melee_pressure": Vector2(344,92), &"ranged_sightline": Vector2(512,178), &"heavy_anchor": Vector2(458,286)}
	var stats := {}
	for enemy in get_nodes_in_group("enemies"):
		var anchor: Vector2 = enemy.get("_patrol_anchor")
		check(anchor.is_equal_approx(expected[enemy.profile.id]), "actual spawner records the configured marker position")
		check(not anchor.is_zero_approx(), "spawned patrol anchor is not the world origin")
		stats[enemy.profile.id] = {"anchor":anchor,"min_y":anchor.y,"max_y":anchor.y,"lane_error":0.0,"returning":false}
	for frame in 300:
		await physics_frame
		for enemy in get_nodes_in_group("enemies"):
			var record: Dictionary = stats[enemy.profile.id]
			record.min_y = minf(record.min_y, enemy.global_position.y)
			record.max_y = maxf(record.max_y, enemy.global_position.y)
			record.lane_error = maxf(record.lane_error, absf(enemy.global_position.x-record.anchor.x))
			record.returning = record.returning or enemy.get("_returning_to_patrol")
	for enemy in get_nodes_in_group("enemies"):
		var record: Dictionary = stats[enemy.profile.id]
		if enemy.profile.patrol_enabled:
			check(enemy.get("_patrol_axis") == Vector2.DOWN, "main-scene enemies patrol parallel to nearby vertical walls")
			check(record.lane_error < 0.1, "actual main-scene patrol keeps its x coordinate")
			check(record.max_y > record.anchor.y+12 and record.min_y < record.anchor.y-12, "actual main-scene patrol visits both ends")
			check(not record.returning, "normal patrol never tries to return toward world origin")
		else:
			check(enemy.global_position.is_equal_approx(record.anchor), "heavy enemy remains stationary")
		print(enemy.profile.id, " patrol sample: ", record)
	main.queue_free()
	await process_frame
	# A nonzero parent transform must not change marker-to-enemy placement.
	var room: Node2D = load("res://scenes/levels/rooms/prototype_combat_room.tscn").instantiate()
	room.position = Vector2(100,50)
	root.add_child(room)
	current_scene = room
	for frame in 30:
		if get_nodes_in_group("enemies").size() == 3: break
		await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		check((enemy.get("_patrol_anchor") as Vector2).is_equal_approx(expected[enemy.profile.id]+Vector2(100,50)), "transformed room preserves world-space spawn anchor")
	room.queue_free()
	await process_frame
	print("Spawned patrol failures: ", failures)
	quit(0 if failures == 0 else 1)
