extends SceneTree

## Native rooftop animation preview, with actual player controls and memory-only saves.
const PREVIEW := preload("res://tools/channel_boss_preview.gd")
const OUTPUT := "res://docs/art/validation/channel_boss_preview_v1/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	await process_frame
	var store := root.get_node("WarehouseStore")
	if not store.begin_test_session():
		push_error("Cannot isolate the boss animation preview")
		quit(1)
		return
	root.get_node("RunManager").begin_run(20261104)
	var room: Node2D = load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate()
	# Reuse the authored room and player, without executing either ending's combat flow.
	room.set_script(null)
	for name in ["Boss", "Enemies", "EnemySpawnPoints", "EnemySpawner", "SupportEnemies", "SupportSpawnPoints", "SupportSpawner", "AttackTelegraph", "ExitElevator"]:
		var child := room.get_node_or_null(name)
		if child != null:
			room.remove_child(child)
			child.free()
	room.add_to_group("combat_rooms")
	room.add_to_group("environment_areas")
	root.add_child(room)
	current_scene = room
	room.get_node("RoomLighting").activate_immediately()
	var player: PlayerController = room.get_node("Player")
	player.position = Vector2(480, 430)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(480, 270)
	camera.zoom = Vector2.ONE * (2.0 / 3.0)
	room.add_child(camera)
	camera.make_current()
	var preview := PREVIEW.new()
	preview.player = player
	room.add_child(preview)
	DisplayServer.window_set_title("五角场热线 · 频道归还 Boss 动画预览")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	print("Channel boss preview ready: WASD move; 1/2/3 skills; Space auto; P pause; Esc close. No damage or formal save writes.")
	if "--check" in OS.get_cmdline_user_args():
		preview.automatic = false
		for index in 3:
			preview.play_skill(index)
			for frame in 25:
				preview._process(0.05)
			assert(preview.skills_shown[index] == 1)
			assert(not preview.effects.is_empty(), "Skill has no active effects")
		preview.clear_effects()
		assert(preview.effects.is_empty())
		assert(store.test_session_active)
		print("Channel boss preview checks: 3 skill sequences, 64 textures, effect cleanup and save isolation passed.")
		quit()
	elif "--capture" in OS.get_cmdline_user_args():
		preview.automatic = false
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
		for index in 3:
			preview.play_skill(index)
			await create_timer([1.05, 0.90, 1.12][index]).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + ["echo.png", "halo.png", "protect.png"][index])
		preview.clear_effects()
		preview.cast = ""
		preview.automatic = true
		preview.cycle_clock = 3.8
		print("Captured all 3 skills; preview remains open for the user.")
