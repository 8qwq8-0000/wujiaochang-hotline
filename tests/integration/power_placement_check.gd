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

func check_placement(layout: CombatLayoutData, point: Vector2) -> void:
	var allowed := false
	for index in layout.power_spawn_zones:
		allowed = allowed or layout.zones[index].grow(-EncounterPropPlacement.CLEARANCE).has_point(point)
	check(allowed, "%s station stays in eligible combat zones" % layout.id)
	for index in layout.zones.size():
		if not layout.power_spawn_zones.has(index):
			check(not layout.zones[index].has_point(point), "%s station never enters excluded zone %d" % [layout.id, index])
	var blockers: Array[Rect2] = []
	blockers.append_array(layout.covers)
	blockers.append_array(layout.windows)
	var terminal := Rect2(point - Vector2.ONE * EncounterPropPlacement.POWER_CLEARANCE, Vector2.ONE * EncounterPropPlacement.POWER_CLEARANCE * 2)
	for blocker in blockers:
		check(not terminal.intersects(blocker), "enlarged station artwork clears obstacles")
	var footprint := EncounterPropPlacement.power_footprint(point).grow(8)
	for lane in layout.clear_lanes:
		check(not footprint.intersects(lane), "enlarged station leaves walking lanes clear")
	check(EncounterPropPlacement.is_safe(point, layout.enemy_positions, blockers, layout.doors, Vector2(INF, INF), layout.room_size), "station clears obstacles, enemies and entrances")
	for door in layout.doors:
		check(not EncounterPropPlacement.door_bounds(door, 40, 32).has_point(point), "station leaves doorway approaches clear")
		check(not EncounterPropPlacement.door_bounds(door, 12, 8).intersects(footprint), "enlarged station leaves door opening clear")

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = "user://power_placement_check.json"
	var manager := root.get_node("RunManager")
	for id in ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot"]:
		var source: CombatLayoutData = load("res://resources/rooms/layouts/" + id + ".tres")
		var authored_power := source.power_position
		var layout := source.scaled_for_room(CombatRoom.ROOM_SCALE)
		var seen := {}
		for seed_value in 128:
			var point := EncounterPropPlacement.choose_power_position(layout, seed_value)
			check_placement(layout, point)
			seen[point] = true
			check(point == EncounterPropPlacement.choose_power_position(layout, seed_value), "same seed reproduces station placement")
		check(seen.size() > 32, "%s varies placement across seeds" % id)
		var runtime_seen := {}
		for seed_value in 8:
			manager.begin_run(seed_value + 400)
			var room: CombatRoom = load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate()
			room.configure_stage(0, 2)
			root.add_child(room)
			current_scene = room
			var point: Vector2 = room.get_node("PowerBox").position
			check_placement(room.layout, point)
			runtime_seen[point] = true
			check(room.find_children("*", "PowerBox", true, false).size() == 1, "room keeps exactly one station")
			for barrel in room.find_children("*", "FuelBarrel", true, false):
				check(point.distance_to(barrel.position) >= 48, "random bomb boxes clear station")
			room.queue_free()
			await process_frame
			await physics_frame
		check(runtime_seen.size() > 1, "real room generation randomizes station")
		check(source.power_position == authored_power, "runtime placement preserves authored resource")
	DirAccess.remove_absolute(store.save_path)
	print("Power placement checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
