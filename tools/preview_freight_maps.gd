extends SceneTree

## Actual scenes and existing art with isolated progress and a full-room camera.
const SAVE := "user://freight-maps-preview.json"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.get_node("WarehouseStore").save_path = SAVE
	root.get_node("RunManager").begin_run(800)
	for id in ["freight_atrium", "dual_track_depot"]:
		var room: CombatRoom = load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate()
		room.configure_stage(0, 2)
		root.add_child(room)
		current_scene = room
		room.open_side("Left")
		room.activate()
		for turret in get_nodes_in_group("sentry_turrets"):
			turret.set_physics_process(false)
		for enemy in room.get_node("Enemies").get_children():
			enemy.set_physics_process(false)
		var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
		player.position = Vector2(111, 270)
		room.add_child(player)
		player.set_physics_process(false)
		player.heat.set_physics_process(false)
		player.get_node("Camera2D").enabled = false
		var camera := Camera2D.new()
		camera.position = CombatRoom.ROOM_SIZE * 0.5
		camera.zoom = Vector2.ONE * 0.64
		room.add_child(camera)
		camera.make_current()
		for frame in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var output: String = "res://docs/art/validation/" + id + "_v1/" + id + ".png"
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var error := root.get_texture().get_image().save_png(output)
		print("Freight map capture: ", output, "; error: ", error)
		if error != OK:
			quit(error)
			return
		room.queue_free()
		await process_frame
	DirAccess.remove_absolute(SAVE)
	quit()
