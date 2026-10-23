extends SceneTree

const SAVE := "user://freight-atrium-check.json"
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
		manager.begin_run(800 + seed_value)
		var room: CombatRoom = load("res://scenes/levels/rooms/variants/freight_atrium.tscn").instantiate()
		room.configure_stage(0, 2)
		root.add_child(room)
		current_scene = room
		await settle()
		check(room.spawner.remaining_objectives() == 6, "atrium retains six objectives")
		check(room.small_obstacles.size() == 6, "atrium retains randomized cover")
		var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
		var map := room.get_world_2d().navigation_map
		var entry := Vector2(74, 180) * CombatRoom.ROOM_SCALE
		for frame in 40:
			if NavigationServer2D.map_get_closest_point_owner(map, entry) == region.get_rid():
				break
			await physics_frame
		# Check both outer routes, the central cross-lane, side rooms and exit.
		for destination in [Vector2(252, 62), Vector2(570, 64), Vector2(270, 300), Vector2(584, 315), Vector2(606, 280)]:
			var point: Vector2 = destination * CombatRoom.ROOM_SCALE
			var path := NavigationServer2D.map_get_path(map, entry, point, true)
			check(path.size() >= 2 and path[-1].distance_to(point) < 5, "atrium route to %s reachable for seed %d" % [destination, seed_value])
		for obstacle in room.small_obstacles:
			for lane in room.layout.clear_lanes:
				check(not lane.intersects(obstacle.grow(20)), "random cover preserves traversal lane")
		for lane in room.layout.clear_lanes:
			check(not lane.grow(22).has_point(room.layout.power_position), "solid station preserves traversal lane")
		var start := Vector2(225, 191) * CombatRoom.ROOM_SCALE
		var end := Vector2(475, 191) * CombatRoom.ROOM_SCALE
		var crossing := NavigationServer2D.map_get_path(map, start, end, true)
		var distance := 0.0
		for index in range(1, crossing.size()):
			distance += crossing[index - 1].distance_to(crossing[index])
		check(crossing.size() >= 2 and crossing[-1].distance_to(end) < 5 and distance < start.distance_to(end) * 1.35, "central cover leaves a short crossing for seed %d" % seed_value)
		if seed_value == 0:
			room.activate()
			for turret in get_nodes_in_group("sentry_turrets"):
				turret.set_physics_process(false)
			for enemy in room.get_node("Enemies").get_children():
				enemy.set_physics_process(false)
			var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
			room.add_child(player)
			player.set_physics_process(false)
			player.heat.set_physics_process(false)
			var doors := room.find_children("*", "AutomaticDoor", true, false)
			check(doors.size() == 12, "atrium connects its checkpoint, control rooms and loading bays with twelve doors")
			for door: AutomaticDoor in doors:
				var normal := door.global_transform.x.normalized()
				player.global_position = door.global_position - normal * 28
				await settle()
				for frame in 36:
					player.velocity = normal * 120
					player.move_and_slide()
					await physics_frame
				player.velocity = Vector2.ZERO
				check(door.opened and (player.global_position - door.global_position).dot(normal) > 10, "player physically opens and crosses atrium side-room door")
			player.position = start
			await settle()
			for frame in 130:
				player.velocity = Vector2.RIGHT * 180
				player.move_and_slide()
				await physics_frame
			player.velocity = Vector2.ZERO
			check(player.position.x >= end.x - 10 and absf(player.position.y - start.y) < 2, "player physically crosses between the central cover groups")
		room.queue_free()
		await settle()
	DirAccess.remove_absolute(SAVE)
	print("Freight atrium checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
