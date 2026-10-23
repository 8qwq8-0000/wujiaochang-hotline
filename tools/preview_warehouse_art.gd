extends SceneTree

## Render-only preview with an isolated save; never opens the real profile.
const SAVE_PATH := "user://warehouse-art-preview.json"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.01
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	for frame in 15:
		await process_frame
	var near_door := "--near-door" in OS.get_cmdline_user_args()
	if near_door:
		var room := main.get_node("SceneContainer").get_child(0)
		room.get_node("Player").position = room.get_node("Deploy").position + Vector2(-42, 0)
		await create_timer(0.5).timeout
	var front_wall := "--front-wall" in OS.get_cmdline_user_args()
	if front_wall:
		var room := main.get_node("SceneContainer").get_child(0)
		room.get_node("Player").position = Vector2(350, 306)
		for frame in 3:
			await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/art/validation/warehouse_safehouse_v1")
	var filename := "warehouse_walls_v2.png" if "--walls-v2" in OS.get_cmdline_user_args() else "warehouse.png"
	if "--props-v2" in OS.get_cmdline_user_args():
		filename = "warehouse_props_v2.png"
	if front_wall:
		filename = "warehouse_front_wall_v2.png"
	if "--door-sigils" in OS.get_cmdline_user_args():
		filename = "warehouse_door_sigils_near.png" if near_door else "warehouse_door_sigils.png"
	var result := root.get_texture().get_image().save_png("res://docs/art/validation/warehouse_safehouse_v1/" + filename)
	print("Warehouse art capture: ", result)
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	quit(result)
