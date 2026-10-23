extends SceneTree

const FORMAL_IDS := ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot"]
const IDS := ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot", "staggered_cover", "central_server", "storage_lanes", "cross_checkpoint", "offset_workshop", "split_office"]
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
	await physics_frame
	await physics_frame
	await process_frame

func inside_cover(point: Vector2, covers: Array[Rect2], clearance: float = 0.0) -> bool:
	for rect in covers:
		if rect.grow(clearance).has_point(point):
			return true
	return false

func run() -> void:
	root.get_node("WarehouseStore").save_path = "user://bc_room_layouts_check.json"
	DirAccess.remove_absolute("user://bc_room_layouts_check.json")
	var run_manager := root.get_node("RunManager")
	run_manager.begin_run(4287)
	var seen_pairs := {}
	var seen_layouts := {}
	var seen_slots := {}
	for seed in [41, 63, 87, 105, 229, 4287, 800, 801, 802, 803]:
		var pair_at_zero := ""
		for level in [0, 0, 1]:
			run_manager.begin_run(seed)
			run_manager.floor_index = level
			var floor_node: Node2D = load("res://scenes/levels/floors/combat_prototype.tscn").instantiate()
			root.add_child(floor_node)
			current_scene = floor_node
			var assembler: FloorAssembler = floor_node.get_node("FloorAssembler")
			check(assembler.room_pool.size() == FORMAL_IDS.size(), "formal floor wires all four selected layouts")
			var paths: Array[String] = []
			for room in assembler.generated_rooms:
				paths.append(room.scene_file_path)
				seen_layouts[room.scene_file_path] = true
				seen_slots["%s:%d" % [room.layout.id, paths.size() - 1]] = true
			check(paths[0] != paths[1], "two areas never repeat same layout")
			var pair := "|".join(paths)
			seen_pairs[pair] = true
			if level == 0:
				if pair_at_zero.is_empty():
					pair_at_zero = pair
				else:
					check(pair_at_zero == pair, "same seed and floor regenerate identical layouts")
			await settle()
			check(run_manager.mandatory_enemies_remaining == 12, "all layouts preserve two-area objectives")
			assembler.passages[0].unlock()
			var entry := CombatLayoutData._scaled_point(Vector2(74,180), CombatRoom.ROOM_SCALE, CombatRoom.BASE_ROOM_SIZE)
			var next_entry: Vector2 = assembler.generated_rooms[1].to_global(entry)
			var route_connected := false
			for wait_frame in 30:
				await physics_frame
				var path := NavigationServer2D.map_get_path(floor_node.get_world_2d().navigation_map, entry, next_entry, true)
				route_connected = path.size() > 1 and path[-1].distance_to(next_entry) < 5.0
				if route_connected:
					break
			check(route_connected, "unlocked passage links different navigation meshes")
			floor_node.queue_free()
			await settle()
	check(seen_layouts.size() == FORMAL_IDS.size(), "seed samples reach all four selected layouts")
	check(seen_pairs.size() > 4, "seeds and floors provide varied pairs from four layouts")
	for id in FORMAL_IDS:
		check(seen_slots.has(id + ":0") and seen_slots.has(id + ":1"), id + " appears as both first and final area")
	for id in IDS:
		var template: RoomTemplateData = load("res://resources/rooms/templates/" + id + ".tres")
		var room := template.scene.instantiate() as CombatRoom
		room.configure_stage(0, 2)
		root.add_child(room)
		current_scene = room
		var camera := Camera2D.new()
		camera.position = CombatRoom.ROOM_SIZE * 0.5
		room.add_child(camera)
		camera.make_current()
		var covers: Array[Rect2] = []
		if room.layout != null:
			covers.assign(room.layout.covers)
		else:
			for cover_name in ["CoverA", "CoverB"]:
				var cover := room.get_node(cover_name) as StaticBody2D
				var cover_shape := cover.get_node("CollisionShape2D").shape as RectangleShape2D
				covers.append(Rect2(cover.position - cover_shape.size * 0.5, cover_shape.size))
		if room.layout != null:
			covers.append_array(room.layout.windows)
		await settle()
		var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
		var entry := CombatLayoutData._scaled_point(Vector2(74,180), CombatRoom.ROOM_SCALE, CombatRoom.BASE_ROOM_SIZE)
		for wait_frame in 30:
			if NavigationServer2D.map_get_closest_point_owner(room.get_world_2d().navigation_map, entry) == region.get_rid():
				break
			await physics_frame
		check(region.navigation_polygon.get_polygon_count() > 0, "%s has baked navigation" % id)
		var destinations: Array[Vector2] = [room.get_node("ExitElevator").position, room.get_node("PowerBox").position, room.get_node("FuelBarrel").position]
		for marker in room.get_node("EnemySpawnPoints").get_children():
			destinations.append(marker.position)
		var all_reachable := true
		var all_clear := true
		var no_wall_crossing := true
		for destination in destinations:
			all_clear = all_clear and not inside_cover(destination, covers, 12.0)
			var path := NavigationServer2D.map_get_path(room.get_world_2d().navigation_map, entry, destination, true)
			all_reachable = all_reachable and path.size() >= 2 and path[-1].distance_to(destination) < 5.0
			for index in range(1, path.size()):
				var steps := maxi(1, ceili(path[index - 1].distance_to(path[index]) / 4.0))
				for step in steps + 1:
					no_wall_crossing = no_wall_crossing and not inside_cover(path[index - 1].lerp(path[index], float(step) / steps), covers, 10.0)
		check(all_clear, "%s spawns props and exit outside blocking cover" % id)
		check(all_reachable, "%s all encounters and exit reachable from entry" % id)
		check(no_wall_crossing, "%s navigation segments respect collider clearance" % id)
		var target := Node2D.new()
		target.add_to_group("player")
		target.position = entry
		room.add_child(target)
		var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
		enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate(true)
		enemy.profile.move_speed = 500.0
		enemy.profile.patrol_enabled = false
		enemy.profile.awareness_range = 1000.0
		enemy.profile.alert_memory_seconds = 20.0
		enemy.position = room.layout.enemy_positions.back() if room.layout != null else Vector2(560,180)
		room.get_node("Enemies").add_child(enemy)
		enemy.navigation_agent.max_speed = enemy.profile.move_speed
		enemy._alert_to(target.global_position, false)
		var clipped_cover := false
		for frame in 360:
			await physics_frame
			clipped_cover = clipped_cover or inside_cover(enemy.position, covers)
		check(not clipped_cover, "%s real AI never clips through interior walls" % id)
		check(enemy.position.distance_to(target.position) < 100.0, "%s real AI routes from far side to entry; final=%s state=%s" % [id, enemy.position, enemy.state])
		if DisplayServer.get_name() != "headless":
			var title := Label.new()
			title.text = room.layout.display_name if room.layout != null else "错列掩体（原构型）"
			title.position = Vector2(28,22)
			title.add_theme_font_size_override("font_size", 16)
			room.add_child(title)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/hotline-room-" + id + ".png")
		room.queue_free()
		await settle()
	print("Room layout checks: ", checks, "; failures: ", failures)
	DirAccess.remove_absolute("user://bc_room_layouts_check.json")
	quit(0 if failures == 0 else 1)
