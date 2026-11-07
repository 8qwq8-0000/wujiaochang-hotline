extends SceneTree

## Start the actual second-ending room, including entry story and settlement,
## using the existing memory-only test session.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	await process_frame
	var store := root.get_node("WarehouseStore")
	var tools: CanvasLayer = root.get_node("GameSettings").test_tools
	if not tools.set_enabled(true) or not store.create_new_profile():
		push_error("Cannot create memory-only second-ending playtest")
		quit(1)
		return
	store.commit([], {}, "", {"id": "test-original-ending", "ending": "core_destroyed", "personas": [], "semantic_leaks": []})
	store.acknowledge_channel_intro()
	var run_manager := root.get_node("RunManager")
	run_manager.begin_run(20261104)
	var actor: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.camera.enabled = false
	actor.inventory.grant_channel_core()
	actor.apply_channel_curse(true)
	var checkpoint := {"scene": "res://scenes/levels/bosses/rooftop_boss_arena.tscn", "seed": 20261104, "floor": 3,
		"route": {"active": true, "record": true, "key": false, "isolated": false,
			"codex": {"joined": true, "health": 3, "arrived": true, "ambush_complete": true}},
		"player": actor.export_run_state(), "elapsed": 0.0, "medical_used": false}
	actor.queue_free()
	await process_frame
	if not store.save_channel_progress(checkpoint) or not run_manager.restore_channel_checkpoint(checkpoint):
		push_error("Cannot prepare second-ending checkpoint")
		quit(1)
		return
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	for frame in 900:
		await process_frame
		if not flow._is_loading and main.get_node("SceneContainer").get_child_count() > 0:
			var arena := main.get_node("SceneContainer").get_child(0) as RooftopBossArena
			if arena != null and arena.channel_duel != null:
				DisplayServer.window_set_title("五角场热线 · 频道归还正式战斗试玩（内存存档）")
				if DisplayServer.get_name() != "headless":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_size(Vector2i(1280, 720))
				print("Second-ending playtest ready. Enter/click continues the entry story; WASD, mouse fire and normal dash during combat. Memory-only profile.")
				if "--check" in OS.get_cmdline_user_args():
					arena.route_dialogue.close()
					quit()
				return
	push_error("Second-ending room failed to load")
	quit(1)
