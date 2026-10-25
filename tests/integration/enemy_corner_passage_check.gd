extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	# These seeds place a 56 px crate at (80, 464): 36 px remain to the wall.
	# An 11 px radius enemy fits, but the former 20 px navigation bake sealed it.
	for seed_value in [10, 27]:
		for role in ["melee_pressure", "heavy_anchor"]:
			root.get_node("RunManager").begin_run(seed_value)
			var room: CombatRoom = load("res://scenes/levels/rooms/variants/interlinked_apartment.tscn").instantiate()
			room.get_node("EnemySpawner").auto_spawn = false
			root.add_child(room)
			current_scene = room
			check(room.small_obstacles.has(Rect2(52, 450, 56, 28)), "fixture reproduces screenshot's wall/crate passage")
			var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
			player.position = Vector2(24, 480)
			room.add_child(player)
			player.set_physics_process(false)
			player.health.configure_max_health(1000)
			var enemies: Array[EnemyController] = []
			for index in 2:
				var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
				enemy.profile = load("res://resources/enemies/" + role + ".tres").duplicate()
				enemy.profile.patrol_enabled = false
				enemy.profile.full_room_awareness = true
				enemy.position = Vector2(42, 438 - index * 35)
				room.get_node("Enemies").add_child(enemy)
				enemy._target = player
				enemy._alert_to(player.global_position, false)
				enemies.append(enemy)
			await physics_frame
			await physics_frame
			var map_rid := room.get_world_2d().navigation_map
			var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
			for frame in 40:
				if NavigationServer2D.map_get_closest_point_owner(map_rid, Vector2(34, 420)) == region.get_rid():
					break
				await physics_frame
			var path := NavigationServer2D.map_get_path(map_rid, Vector2(34, 420), Vector2(34, 490), true)
			var path_length := 0.0
			for index in range(1, path.size()):
				path_length += path[index - 1].distance_to(path[index])
			check(path.size() >= 2 and path_length < 90, "navigation keeps the physically walkable short passage open: %s" % path)
			var initial_health := player.health.current_health
			for frame in 480:
				await physics_frame
				if player.health.current_health < initial_health:
					break
			check(player.health.current_health < initial_health, "%s front enemy reaches and actually damages wall-side player, seed %d" % [role, seed_value])
			# Remove whichever enemy reached the player; the queued one must follow.
			var front: EnemyController = enemies[0] if enemies[0].global_position.distance_to(player.global_position) < enemies[1].global_position.distance_to(player.global_position) else enemies[1]
			var follower: EnemyController = enemies[1] if front == enemies[0] else enemies[0]
			var packet := DamagePacket.new()
			packet.source_faction = CombatFaction.Id.PLAYER
			front.health.apply_damage(999, packet)
			for frame in 40:
				await physics_frame
			initial_health = player.health.current_health
			for frame in 480:
				await physics_frame
				if player.health.current_health < initial_health:
					break
			check(player.health.current_health < initial_health, "%s follower passes after front enemy dies, seed %d" % [role, seed_value])
			check(follower.navigation_agent.avoidance_enabled, "crowd avoidance stays enabled")
			check(follower.global_position.x >= 26.5, "enemy collider stays outside left wall")
			room.queue_free()
			await process_frame
			await physics_frame
	print("Enemy corner passage checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
