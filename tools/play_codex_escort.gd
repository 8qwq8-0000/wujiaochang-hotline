extends SceneTree

# Interactive playtest: only skips earlier floors. Combat and escort rules stay
# unchanged, and all saves remain in a separate per-process profile.
var ready_for_playtest := false
const PASSAGE := "res://scenes/levels/intermissions/codex_service_passage.tscn"

func _initialize() -> void:
	call_deferred("start_playtest")

func start_playtest() -> void:
	var store := root.get_node("WarehouseStore")
	var run := root.get_node("RunManager")
	store.save_path = "user://codex-escort-playtest-%d.json" % OS.get_process_id()
	if not store.create_new_profile():
		push_error("Cannot create isolated escort playtest profile")
		quit(1)
		return
	store.commit([], {}, "", {"id": "playtest-original-ending", "personas": [], "semantic_leaks": []})
	store.acknowledge_channel_intro()
	run.begin_run(20261103)
	var actor: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.camera.enabled = false
	actor.inventory.grant_channel_core()
	actor.apply_channel_curse(true)
	var snapshot := actor.export_run_state()
	actor.queue_free()
	await process_frame
	var ambush_preview := "--ambush" in OS.get_cmdline_user_args()
	var target_scene := "res://scenes/levels/floors/combat_prototype.tscn" if ambush_preview else PASSAGE
	var checkpoint := {"scene": target_scene, "seed": 20261103, "floor": 2 if ambush_preview else 1,
		"route": {"active": true, "record": true, "key": false, "isolated": false, "codex": {}},
		"player": snapshot, "cleared": [], "pickups": [],
		"medical_used": false, "elapsed": 0.0}
	if "--with-codex" in OS.get_cmdline_user_args() or ambush_preview:
		checkpoint.route.codex = {"joined": true, "health": 3, "arrived": false}
	if not store.save_channel_progress(checkpoint) or not run.restore_channel_checkpoint(checkpoint):
		push_error("Cannot prepare isolated escort playtest checkpoint")
		quit(1)
		return
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	for _frame in 900:
		await process_frame
		if not flow._is_loading and main.get_node("SceneContainer").get_child_count() > 0:
			var room: Node = main.get_node("SceneContainer").get_child(0)
			if room.scene_file_path == target_scene:
				main.get_node("PersonaRestFlow").close(true)
				var preview_player: PlayerController = room.get_node("Player")
				if not ambush_preview:
					preview_player.position = room.get_node("SynthesisNPC").position + Vector2(0, 56)
				preview_player.set_input_enabled(true)
				DisplayServer.window_set_title("五角场热线 · Codex 同行体验（独立存档）")
				await physics_frame
				await process_frame
				if "--test-panel" in OS.get_cmdline_user_args():
					var tools: CanvasLayer = root.get_node("GameSettings").test_tools
					tools.set_enabled(true)
					tools.open_panel()
					await process_frame
				await RenderingServer.frame_post_draw
				if "--test-panel" in OS.get_cmdline_user_args():
					root.get_texture().get_image().save_png("/tmp/hotline-f8-test-panel.png")
				root.get_texture().get_image().save_png("/tmp/codex-escort-playtest-ready.png")
				ready_for_playtest = true
				print("Codex escort playtest ready. " + ("Codex already following." if "--with-codex" in OS.get_cmdline_user_args() else "Press E to talk.") + " Formal profile is untouched.")
				return
	push_error("Escort playtest passage did not finish loading")
	quit(1)
