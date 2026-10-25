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
func run() -> void:
	var manager := root.get_node("RunManager")
	for id in ["interlinked_apartment","loading_workshop","freight_atrium","dual_track_depot"]:
		var snapshots: Array = []
		for seed in [4287,4287,800]:
			manager.begin_run(seed)
			var room := load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate() as CombatRoom
			room.configure_stage(0,2)
			root.add_child(room)
			current_scene = room
			var clutter := room.get_node("FloorClutter")
			check(not clutter.is_processing() and clutter.get_child_count() == 0 and clutter.z_index == -1,"clutter is one static ground canvas without physics nodes")
			var kinds := {}
			check(clutter.details.size() >= 24 and clutter.details.size() <= 45,"sparse clutter count in " + id)
			for detail in clutter.details:
				kinds[detail.kind] = true
				var radius: float = detail.size * 0.65 + 4
				var bounds := Rect2(detail.position - Vector2.ONE * radius, Vector2.ONE * radius * 2)
				var safe := true
				for rect in room.layout.covers + room.layout.windows + room.layout.navigation_obstacles + room.small_obstacles:
					safe = safe and not rect.grow(6).intersects(bounds)
				for door in room.layout.doors:
					safe = safe and not EncounterPropPlacement.door_bounds(door,30,24).intersects(bounds)
				for lane in room.layout.clear_lanes:
					safe = safe and not lane.grow(6).intersects(bounds)
				check(safe,"clutter avoids walls, cover, turrets, doorways and clear lanes")
			check(kinds.size() == 4,"blood, stones, metal and broken-door chips are represented")
			snapshots.append(clutter.details.duplicate(true))
			if OS.get_cmdline_user_args().has("--capture") and seed == 800:
				var camera := Camera2D.new()
				camera.position = CombatRoom.ROOM_SIZE * 0.5
				camera.zoom = Vector2.ONE * 0.64
				room.add_child(camera)
				camera.make_current()
				for frame in 4:
					await process_frame
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://docs/art/validation/floor_clutter_v1")
				root.get_texture().get_image().save_png("res://docs/art/validation/floor_clutter_v1/" + id + ".png")
			room.queue_free()
			await process_frame
		check(snapshots[0] == snapshots[1],"same seed recreates identical decoration")
		check(snapshots[0] != snapshots[2],"different run changes the distribution")
	print("Floor clutter checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
