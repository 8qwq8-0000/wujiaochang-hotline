extends SceneTree

## Real room/actor rendering with isolated progress and a fixed inspection camera.
const OUTPUT := "res://docs/art/validation/combat_architecture_v1/"

func _initialize() -> void:
	call_deferred("play" if "--play" in OS.get_cmdline_user_args() else "capture")

func play() -> void:
	root.get_node("WarehouseStore").save_path = "user://combat-art-playtest.json"
	root.get_node("RunManager").begin_run(4287)
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.1
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		if main.get_node("SceneContainer").get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	var floor_node := main.get_node("SceneContainer").get_child(0)
	var first: CombatRoom = floor_node.get_node("FloorAssembler").generated_rooms[0]
	floor_node.get_node("Player").global_position = first.get_node("PowerBox").global_position + Vector2(45, 0)

func capture() -> void:
	root.get_node("WarehouseStore").save_path = "user://combat-art-preview.json"
	root.get_node("RunManager").begin_run(4287)
	var floor_node: Node2D = load("res://scenes/levels/floors/combat_prototype.tscn").instantiate()
	root.add_child(floor_node)
	current_scene = floor_node
	var player := floor_node.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * 0.64
	floor_node.add_child(camera)
	camera.make_current()
	for actor in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var assembler := floor_node.get_node("FloorAssembler") as FloorAssembler
	for room: CombatRoom in assembler.generated_rooms:
		camera.position = room.position + room.ROOM_SIZE * 0.5
		player.position = room.position + Vector2(115, 270)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + str(room.layout.id) + ".png")
	# Keep a closer inspection of both authored doorway orientations.
	var room: CombatRoom = assembler.generated_rooms[0]
	var station := room.get_node("PowerBox") as PowerBox
	camera.position = station.global_position + Vector2(180, -70)
	camera.zoom = Vector2.ONE * 1.2
	player.global_position = station.global_position + Vector2(40, 0)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "charging_sigil.png")
	camera.position = room.position + Vector2(430, 245)
	camera.zoom = Vector2.ONE
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "closed_doors.png")
	camera.position = room.position + Vector2(600, 185)
	for point in [Vector2(600, 169), Vector2(600, 206)]:
		player.position = room.position + point
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + ("behind_wall.png" if point.y < 180 else "in_front_of_wall.png"))
	camera.position = room.position + Vector2(430, 245)
	for node in room.get_node("LayoutGeometry").get_children():
		if node is AutomaticDoor:
			player.global_position = node.global_position + node.global_transform.x.normalized() * 12
			node._on_contact(player)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "door_break.png")
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "open_doors.png")
	var bomb := room.get_node("FuelBarrel") as FuelBarrel
	camera.position = Vector2(clampf(bomb.global_position.x, room.position.x + 320, room.position.x + 640), clampf(bomb.global_position.y, 180, 360))
	player.global_position = room.position + Vector2(80, 400)
	var hit := DamagePacket.new()
	hit.base_damage = 1
	bomb.receive_hit(hit)
	for stage in [[0.04, "explosion_flash"], [0.14, "explosion_flames"], [0.24, "explosion_smoke"]]:
		await create_timer(stage[0]).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + stage[1] + ".png")
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "bomb_debris.png")
	floor_node.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://combat-art-preview.json")
	print("Combat art captures saved: ", OUTPUT)
	quit()
