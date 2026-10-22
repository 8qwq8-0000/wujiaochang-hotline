extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var run := root.get_node("RunManager")
	for id in ["interlinked_apartment", "loading_workshop"]:
		var snapshots: Array = []
		for seed_value in [4287,4287,800]:
			run.begin_run(seed_value)
			var room: CombatRoom = load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate()
			room.configure_stage(0,2)
			root.add_child(room)
			current_scene = room
			var blood = room.get_node("FloorBloodDecals")
			check(blood.decals.size() > 0 and blood.decals.size() <= 6, id + " has only a few blood stains")
			check(blood.z_index == -1 and not blood.is_processing() and blood.get_child_count() == 0, "static blood remains below actors without colliders or per-frame processing")
			for decal in blood.decals:
				var radius: float = decal.width * 0.65
				var bounds := Rect2(decal.position - Vector2.ONE * radius, Vector2.ONE * radius * 2)
				var clear := Rect2(Vector2(16,16), CombatRoom.ROOM_SIZE - Vector2(32,32)).encloses(bounds)
				for rect in room.layout.covers + room.layout.windows:
					clear = clear and not rect.intersects(bounds)
				check(clear, "whole blood stain stays on open floor rather than walls or props")
			snapshots.append(blood.decals.duplicate(true))
			print(id, " seed=", seed_value, " stains=", blood.decals.size())
			room.queue_free()
			await process_frame
		check(snapshots[0] == snapshots[1], "same run regenerates the same decorative stains")
		check(snapshots[0] != snapshots[2], "a different run produces a different arrangement")
	print("Floor blood checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
