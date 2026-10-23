extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle(frames: int = 4) -> void:
	for frame in frames:
		await physics_frame
	await process_frame

func run() -> void:
	# A three-enemy group must win over a two-enemy group behind a full wall.
	var enemies: Array[Vector2] = [Vector2(270,140),Vector2(310,140),Vector2(290,188),Vector2(505,130),Vector2(545,170)]
	var blockers: Array[Rect2] = [Rect2(420,16,8,328)]
	var doors: Array[Vector4] = []
	var positions := {}
	for seed in 32:
		var point := EncounterPropPlacement.choose_barrel_position(enemies,blockers,doors,Vector2(62,290),seed,Vector2(110,110))
		var repeat := EncounterPropPlacement.choose_barrel_position(enemies,blockers,doors,Vector2(62,290),seed,Vector2(110,110))
		check(point == repeat, "same seed replays barrel position")
		check(point.x < 398 and point.distance_to(enemies[0]) <= 92 and point.distance_to(enemies[1]) <= 92 and point.distance_to(enemies[2]) <= 92, "barrel favors all three clustered enemies rather than isolated pair")
		positions[point] = true
	check(positions.size() > 20, "different seeds vary positions around the same group")
	var empty: Array[Vector2] = []
	check(EncounterPropPlacement.choose_barrel_position(empty,blockers,doors,Vector2.ZERO,1,Vector2(100,70)) == Vector2(100,70), "empty encounter keeps authored fallback")
	var run_manager := root.get_node("RunManager")
	for id in ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot"]:
		var safe_count := 0
		var multi_hit_count := 0
		var varied := {}
		for seed in 16:
			run_manager.begin_run(seed + 300)
			var room: CombatRoom = load("res://scenes/levels/rooms/variants/"+id+".tscn").instantiate()
			room.configure_stage(0,2)
			root.add_child(room)
			current_scene = room
			var barrel: FuelBarrel = room.get_node("FuelBarrel")
			var point := barrel.position
			var layout: CombatLayoutData = room.layout
			var all_blockers: Array[Rect2] = []
			all_blockers.append_array(layout.covers)
			all_blockers.append_array(layout.windows)
			var boxes := room.find_children("*", "FuelBarrel", true, false)
			check(boxes.size() == 3, id + " has exactly three bomb boxes")
			for box: FuelBarrel in boxes:
				check(EncounterPropPlacement.is_safe(box.position, layout.enemy_positions, all_blockers, layout.doors, layout.power_position, room.ROOM_SIZE), "each box avoids geometry, doorways, entry, exit and actors")
				for other: FuelBarrel in boxes:
					if box.get_index() < other.get_index():
						check(box.position.distance_to(other.position) >= 54, "bomb boxes remain separated")
			if EncounterPropPlacement.is_safe(point,layout.enemy_positions,all_blockers,layout.doors,layout.power_position,room.ROOM_SIZE):
				safe_count += 1
			var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
			for frame in 40:
				await physics_frame
				if NavigationServer2D.map_get_iteration_id(room.get_world_2d().navigation_map) > 0 and NavigationServer2D.map_get_closest_point_owner(room.get_world_2d().navigation_map, point) == region.get_rid():
					break
			var snapped := NavigationServer2D.map_get_closest_point(room.get_world_2d().navigation_map,point)
			check(snapped.distance_to(point) < 2, id + " barrel lies on reachable clear floor")
			room.activate()
			var health_before := {}
			for enemy in room.get_node("Enemies").get_children():
				enemy.set_physics_process(false)
				health_before[enemy] = enemy.health.current_health
			check(barrel.position == point and room.spawner.required_remaining == 6 and boxes.size() == 3, "activation preserves three boxes and all six objectives")
			await settle()
			var packet := DamagePacket.new()
			packet.base_damage = 1
			for box: FuelBarrel in boxes:
				box.receive_hit(packet)
			await settle(6)
			var damaged := 0
			for enemy in health_before:
				if not is_instance_valid(enemy) or enemy.health.current_health < health_before[enemy]:
					damaged += 1
			if damaged >= 2:
				multi_hit_count += 1
			for box: FuelBarrel in boxes:
				check(box.broken and is_instance_valid(box.patch) and box.patch.explosion_count == 1, "each of the three actual boxes creates exactly one explosion")
			varied[point] = true
			room.queue_free()
			await settle()
		check(safe_count == 16, id + " all seeded positions avoid geometry, enemies, entry and doors")
		check(multi_hit_count == 16, id + " three-box encounter explosions reach at least two enemies for every sampled seed")
		check(varied.size() >= 12, id + " random offsets produce varied valid positions")
	# Verify open workshop clearances without depending on decorative art.
	var open_layout: CombatLayoutData = load("res://resources/rooms/layouts/loading_workshop.tres")
	check(open_layout.covers[2].size.x < 45 and open_layout.covers[2].size.y < 36, "central machine footprint shrinks to preserve dodge space")
	check(open_layout.doors.all(func(door: Vector4) -> bool: return door.w >= 75), "all workshop doorways widened to at least 75 pixels")
	print("Encounter barrel checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
