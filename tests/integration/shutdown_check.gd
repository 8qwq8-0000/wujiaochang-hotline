extends SceneTree

# Run through tools/check_shutdown.py: leaks are reported after this script ends.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mode := "menu"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shutdown-mode="):
			mode = arg.trim_prefix("--shutdown-mode=")
	var settings := root.get_node("GameSettings")
	if mode == "menu":
		var menu: Node = load("res://scenes/ui/start_menu.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		for button in menu.find_children("*", "Button", true, false):
			if button.text == "退出游戏":
				button.pressed.emit()
				# Repeated close requests must preserve the first exit code.
				settings.quit_game(1)
				print("Shutdown check: menu button")
				return
		push_error("Shutdown check: missing menu exit button")
		settings.quit_game(1)
		return
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	if mode in ["boss", "channel"]:
		main.get_node("SceneFlow").initial_scene = "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
	root.add_child(main)
	current_scene = main
	if mode != "loading":
		for frame in 600:
			await process_frame
			if get_first_node_in_group("player") != null and not main.get_node("SceneFlow").get("_is_loading"):
				break
		if get_first_node_in_group("player") == null:
			push_error("Shutdown check: combat scene never became ready")
			settings.quit_game(1)
			return
	if mode in ["boss", "channel"]:
		var room: RooftopBossArena = main.get_node("SceneContainer").get_child(0)
		room.boss.activate_immediately()
		room.boss.channel_form = mode == "channel"
		room.presentation.cast(&"halo", room.boss.global_position, 0.96)
		room.presentation.release(&"halo", room.boss.global_position)
		room.presentation.moment(&"phase")
	if mode == "paused":
		var player: PlayerController = get_first_node_in_group("player")
		player.inventory.set_open(true)
		if not paused:
			push_error("Shutdown check: inventory did not pause")
			settings.quit_game(1)
			return
	elif mode == "scene_loader":
		var loader := root.get_node("SceneLoader")
		loader.load_scene("res://scenes/levels/base/warehouse.tscn", true)
		for frame in 600:
			await process_frame
			if loader.get_status() == ResourceLoader.THREAD_LOAD_LOADED:
				break
		if not loader.get_resource() is PackedScene:
			push_error("Shutdown check: menu loader did not retain its resource")
			settings.quit_game(1)
			return
	# This is the notification delivered by the native window close request.
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	settings.quit_game(1)
	print("Shutdown check: ", mode)
