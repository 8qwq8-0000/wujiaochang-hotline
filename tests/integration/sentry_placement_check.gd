extends SceneTree

const IDS := ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot"]
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("WarehouseStore").save_path = "user://sentry-placement-check.json"
	var manager := root.get_node("RunManager")
	for id in IDS:
		for seed_value in 16:
			manager.begin_run(500 + seed_value)
			var room: CombatRoom = load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate()
			room.configure_stage(seed_value % 2, 2)
			root.add_child(room)
			current_scene = room
			var turrets := room.find_children("*", "StaticBody2D", true, false).filter(func(node) -> bool: return node.is_in_group("sentry_turrets"))
			check(turrets.size() >= 1, "%s always generates at least one turret" % id)
			check(room.spawner.remaining_objectives() == 6, "turret remains an environmental threat rather than changing enemy objectives")
			check(room.small_obstacles.size() == 6, "%s preserves six random small obstacles" % id)
			for turret: SentryTurret in turrets:
				check(not turret.operational(), "pending room keeps turret inactive")
				var footprint := Rect2(turret.position - Vector2(48, 48), Vector2(96, 96))
				check(room.layout.navigation_obstacles.has(footprint), "solid turret is included in navigation")
				check(Rect2(Vector2(16, 16), room.ROOM_SIZE - Vector2(32, 32)).encloses(footprint), "turret footprint stays inside walls")
				for cover in room.layout.covers:
					check(not footprint.grow(4).intersects(cover), "turret clears authored and random cover")
				for lane in room.layout.clear_lanes:
					check(not footprint.grow(4).intersects(lane), "turret leaves protected traversal lanes clear")
				for door in room.layout.doors:
					check(not footprint.intersects(EncounterPropPlacement.door_bounds(door, 32, 12)), "turret leaves doors clear")
				check(not footprint.grow(22).has_point(room.get_node("PowerBox").position), "station clears turret footprint")
				for barrel in room.find_children("*", "FuelBarrel", true, false):
					check(not footprint.grow(22).has_point(barrel.position), "bomb boxes clear turret footprint")
				for enemy in room.layout.enemy_positions:
					check(not footprint.grow(12).has_point(enemy), "enemy spawns clear turret footprint")
			await physics_frame
			await physics_frame
			var entry := Vector2(111, 270)
			var map := room.get_world_2d().navigation_map
			var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
			for frame in 40:
				if NavigationServer2D.map_get_closest_point_owner(map, entry) == region.get_rid():
					break
				await physics_frame
			var destinations: Array[Vector2] = [room.get_node("ExitElevator").position, room.get_node("PowerBox").position]
			destinations.append_array(room.layout.enemy_positions)
			for point in destinations:
				var path := NavigationServer2D.map_get_path(map, entry, point, true)
				check(path.size() >= 2 and path[-1].distance_to(point) < 5, "%s seed %d preserves route to %s" % [id, seed_value, point])
			room.queue_free()
			await process_frame
			await physics_frame
	DirAccess.remove_absolute("user://sentry-placement-check.json")
	print("Sentry placement checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
