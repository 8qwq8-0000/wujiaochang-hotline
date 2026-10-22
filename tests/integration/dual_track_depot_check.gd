extends SceneTree

const SAVE := "user://dual-track-depot-check.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 3:
		await physics_frame
	await process_frame

func run() -> void:
	root.get_node("WarehouseStore").save_path = SAVE
	var manager := root.get_node("RunManager")
	for seed_value in 16:
		manager.begin_run(900 + seed_value)
		var room: CombatRoom = load("res://scenes/levels/rooms/variants/dual_track_depot.tscn").instantiate()
		room.configure_stage(seed_value % 2, 2)
		root.add_child(room)
		current_scene = room
		await settle()
		check(room.spawner.remaining_objectives() == 6, "depot retains six objectives")
		check(room.small_obstacles.size() == 6, "depot retains six random obstacles; seed=%d count=%d" % [seed_value, room.small_obstacles.size()])
		check(room.layout.doors.is_empty() and room.find_children("*", "AutomaticDoor", true, false).is_empty(), "depot remains an open station hall")
		for obstacle in room.small_obstacles:
			for lane in room.layout.clear_lanes:
				check(not lane.intersects(obstacle.grow(20)), "random cover preserves cross-links and long lanes")
		for lane in room.layout.clear_lanes:
			check(not lane.grow(22).has_point(room.layout.power_position), "station does not obstruct cross-links or sightlines")
		var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
		var map := room.get_world_2d().navigation_map
		var entry := Vector2(111, 270)
		for frame in 40:
			if NavigationServer2D.map_get_closest_point_owner(map, entry) == region.get_rid():
				break
			await physics_frame
		for y in [108, 270, 432]:
			var start := Vector2(150, y)
			var end := Vector2(810, y)
			var path := NavigationServer2D.map_get_path(map, start, end, true)
			var distance := 0.0
			for index in range(1, path.size()):
				distance += path[index - 1].distance_to(path[index])
			check(path.size() >= 2 and path[-1].distance_to(end) < 5 and distance < start.distance_to(end) * 1.05, "cross-link %d stays direct across seed %d" % [y, seed_value])
		for x in [180, 778]:
			var ray := PhysicsRayQueryParameters2D.create(Vector2(x, 72), Vector2(x, 468), 1)
			check(room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "long sightline stays clear across seed %d" % seed_value)
		var cover_ray := PhysicsRayQueryParameters2D.create(Vector2(230, 180), Vector2(430, 180), 1)
		check(not room.get_world_2d().direct_space_state.intersect_ray(cover_ray).is_empty(), "freight clusters provide real projectile cover")
		var destinations: Array[Vector2] = [room.layout.power_position, room.get_node("ExitElevator").position]
		destinations.append_array(room.layout.enemy_positions)
		for point in destinations:
			var path := NavigationServer2D.map_get_path(map, entry, point, true)
			check(path.size() >= 2 and path[-1].distance_to(point) < 5, "seed %d destination %s remains reachable; path=%s" % [seed_value, point, path])
		if seed_value == 0:
			room.activate()
			for turret in get_nodes_in_group("sentry_turrets"):
				turret.set_physics_process(false)
			var ranged: Array[EnemyController] = []
			for enemy: EnemyController in room.get_node("Enemies").get_children():
				enemy.set_physics_process(false)
				if enemy.profile.role == EnemyProfile.Role.RANGED_SIGHTLINE:
					ranged.append(enemy)
			check(ranged.size() == 2 and ranged[0].profile.attack_range == 420, "depot has two long-lane marksmen")
			check(load("res://resources/enemies/ranged_sightline.tres").attack_range == 235, "other maps retain their original ranged profile")
			var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
			room.add_child(player)
			player.set_physics_process(false)
			player.heat.set_physics_process(false)
			for y in [108, 270, 432]:
				player.position = Vector2(150, y)
				await settle()
				for frame in 112:
					player.velocity = Vector2.RIGHT * 360
					player.move_and_slide()
					await physics_frame
				player.velocity = Vector2.ZERO
				check(player.position.x >= 810 and absf(player.position.y - y) < 2, "player physically crosses link %d" % y)
			player.position = Vector2(180, 400)
			var shooter := ranged[0]
			shooter._target = player
			shooter._attack_direction = Vector2.DOWN
			var defense := player.get_node("DefenseComponent") as DefenseComponent
			defense.set_physics_process(false)
			await settle()
			var before := player.health.current_health + defense.charges()
			shooter.perform_attack()
			for frame in 80:
				await physics_frame
				if player.health.current_health + defense.charges() < before:
					break
			check(player.health.current_health + defense.charges() == before - 1, "actual marksman bullet traverses a 328-pixel lane and hits")
		room.queue_free()
		await settle()
	DirAccess.remove_absolute(SAVE)
	print("Dual-track depot checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
