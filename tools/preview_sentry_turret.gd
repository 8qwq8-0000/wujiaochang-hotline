extends SceneTree

const OUTPUT := "res://docs/art/validation/sentry_turret_v1/"

class Arena extends Node2D:
	signal room_cleared
	var active := true
	var cleared := false
	func _enter_tree() -> void:
		add_to_group("environment_areas")
		add_to_group("combat_rooms")
	func contains_world_point(point: Vector2) -> bool:
		return Rect2(Vector2.ZERO, Vector2(960, 540)).has_point(to_local(point))

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.get_node("WarehouseStore").save_path = "user://sentry-preview.json"
	root.get_node("RunManager").begin_run(800)
	DirAccess.make_dir_recursive_absolute(OUTPUT + "frames")
	for id in ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot"]:
		var room: CombatRoom = load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate()
		room.configure_stage(0, 2)
		root.add_child(room)
		current_scene = room
		room.open_side("Left")
		room.activate()
		for enemy in get_nodes_in_group("enemies"):
			enemy.set_physics_process(false)
		for turret: SentryTurret in get_nodes_in_group("sentry_turrets"):
			turret.set_physics_process(false)
			turret.gun.rotation = -PI * 0.25
		var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
		player.position = Vector2(111, 270)
		room.add_child(player)
		player.set_physics_process(false)
		player.get_node("Camera2D").enabled = false
		var camera := Camera2D.new()
		camera.position = Vector2(480, 270)
		camera.zoom = Vector2.ONE * 0.64
		room.add_child(camera)
		camera.make_current()
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + id + ".png")
		room.queue_free()
		await process_frame
	var arena := Arena.new()
	root.add_child(arena)
	current_scene = arena
	var layout := CombatLayoutData.new()
	layout.room_size = Vector2(960, 540)
	for floor_pass: bool in [true, false]:
		var art := WorkshopArt.new()
		art.layout = layout
		art.floor_pass = floor_pass
		art.z_index = -2 if floor_pass else 0
		arena.add_child(art)
	var turret: SentryTurret = load("res://scenes/environment/sentry_turret.tscn").instantiate()
	turret.position = Vector2(480, 270)
	arena.add_child(turret)
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	player.heat.set_physics_process(false)
	player.get_node("HurtBox").set_invulnerable(1000)
	player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(480, 270)
	camera.zoom = Vector2.ONE * 0.85
	arena.add_child(camera)
	camera.make_current()
	for frame in 240:
		var angle := PI * 0.5 + frame * TAU / 240.0
		player.position = turret.position + Vector2.from_angle(angle) * 170
		await process_frame
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			root.get_texture().get_image().save_png(OUTPUT + "frames/%03d.png" % frame)
	print("Sentry gameplay preview saved: ", OUTPUT, "; volleys: ", turret.volleys_fired)
	arena.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://sentry-preview.json")
	quit()
