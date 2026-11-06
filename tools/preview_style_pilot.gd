extends SceneTree

const OUTPUT := "res://docs/art/validation/style_pilot_v1/"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.get_node("WarehouseStore").save_path = "user://style-pilot-preview.json"
	root.get_node("RunManager").begin_run(4287)
	var room: CombatRoom = load("res://scenes/levels/rooms/variants/loading_workshop.tscn").instantiate()
	room.configure_stage(0, 2)
	root.add_child(room)
	current_scene = room
	room.open_side("Left")
	room.activate()
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(115, 270)
	room.add_child(player)
	player.set_physics_process(false)
	player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * 0.64
	camera.position = CombatRoom.ROOM_SIZE * 0.5
	room.add_child(camera)
	camera.make_current()
	for actor in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
	var hud: CanvasLayer = load("res://scenes/ui/combat_hud.tscn").instantiate()
	room.add_child(hud)
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var resolution := DisplayServer.window_get_size()
	var suffix := "%d_%d" % [resolution.x, resolution.y]
	root.get_texture().get_image().save_png(OUTPUT + "workshop_" + suffix + ".png")
	var settings := load("res://scenes/ui/pause_settings_menu.tscn").instantiate() as PauseSettingsMenu
	room.add_child(settings)
	settings.open_settings_only()
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "settings_" + suffix + ".png")
	settings.close_menu()
	room.queue_free()
	await process_frame
	print("Style pilot captures saved: ", OUTPUT)
	quit()
