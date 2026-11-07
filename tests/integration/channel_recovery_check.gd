extends SceneTree

const TEST_PATH := "user://channel-recovery-integration-test.json"
var checks := 0
var failures := 0
var store: Node
var run: Node


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func frames(count := 5) -> void:
	for _frame in count:
		await process_frame


func wait_main() -> Node:
	for _frame in 900:
		await process_frame
		if current_scene != null and current_scene.has_node("SceneFlow"):
			var flow: SceneContainerManager = current_scene.get_node("SceneFlow")
			if not flow._is_loading and flow.get_node(flow.scene_container_path).get_child_count() > 0:
				await frames()
				current_scene.get_node("PersonaRestFlow").close(true)
				return current_scene
	return null


func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	run = root.get_node("RunManager")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "isolated recovery profile")
	check(store.commit([], {}, "", {"id": "first", "personas": [], "semantic_leaks": []}), "original ending fixture")
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(player)
	await frames()
	var saved := {"seed": 77441, "floor": 0, "route": {"active": true, "record": true, "key": false, "isolated": false},
		"player": player.export_run_state(), "cleared": [true, false], "x": 870, "y": 270,
		"persona_floor": 0, "persona_pending": false, "persona_refilled": 0, "elapsed": 20}
	player.queue_free()
	await frames()
	check(store.save_channel_progress(saved, ["call_record"]), "checkpoint saved")
	var bytes := FileAccess.get_file_as_string(TEST_PATH)
	var malformed: Dictionary = saved.duplicate(true)
	malformed.route = {"active": true}
	check(not store.save_channel_progress(malformed), "malformed checkpoint rejected")
	check(FileAccess.get_file_as_string(TEST_PATH) == bytes, "invalid checkpoint preserves durable file")
	check(store.get_channel_checkpoint() == saved, "invalid checkpoint preserves in-memory profile")
	var menu: Node = load("res://scenes/ui/start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	check(menu.get("_status").text.contains("安全检查点"), "menu describes resuming active operation")
	menu.continue_game()
	var main := await wait_main()
	check(main != null, "continue game creates playable main")
	if main == null:
		quit(1)
		return
	var floor_scene: Node = main.get_node("SceneContainer").get_child(0)
	check(not floor_scene.is_in_group("warehouse") and floor_scene.has_node("ChannelMission"), "continue resumes action instead of bypassing lock through warehouse")
	check(run.channel_route_active and run.channel_record_found, "continued action retains route prerequisites")
	check(floor_scene.get_node("FloorAssembler").generated_rooms[0].cleared, "continued cleared area is restored")
	player = floor_scene.get_node("Player")
	check(player.position.distance_to(Vector2(870, 270)) < 5, "resume restores safe position")
	var ui: Node = main.get_node("ExtractionFlow")
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.ENEMY
	player.health.apply_damage(1000, packet)
	if not player.health.is_dead():
		player.health.apply_damage(1000, packet)
	await frames()
	check(run.run_finished and paused, "death settles resumed action")
	check(store.get_channel_checkpoint().is_empty() and not run.channel_route_active, "death clears both durable checkpoint and live lock")
	check(store.get_profile().channel_story.discoveries.has("call_record"), "death retains discovered story")
	ui.return_to_warehouse()
	for _frame in 600:
		await process_frame
		if main.get_node("SceneContainer").get_child_count() and main.get_node("SceneContainer").get_child(0).is_in_group("warehouse"):
			break
	await frames()
	# Resume another fixture and exercise the actual existing abandon path.
	check(store.save_channel_progress(saved), "second resume fixture saved")
	check(run.restore_channel_checkpoint(saved), "second run restored")
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	check(flow.request_scene("res://scenes/levels/floors/combat_prototype.tscn"), "abandon fixture loads")
	for _frame in 600:
		await process_frame
		if not flow._is_loading:
			break
	await frames()
	main.get_node("PersonaRestFlow").close(true)
	main.get_node("PauseSettingsMenu").open_menu()
	check(main.get_node("PauseSettingsMenu").get("_channel_note").visible, "pause explains checkpoint semantics")
	main.get_node("PauseSettingsMenu").close_menu()
	main._restart_combat()
	for _frame in 600:
		await process_frame
		if not flow._is_loading:
			break
	await frames()
	check(store.get_channel_checkpoint().is_empty() and not run.channel_route_active, "abandon clears checkpoint and route")
	check(main.get_node("SceneContainer").get_child(0).is_in_group("warehouse"), "abandon returns to warehouse")
	# Rooftop resume must select its scene before SceneFlow queues initial loading.
	var rooftop: Dictionary = saved.duplicate(true)
	rooftop.floor = 3
	rooftop.route.key = false
	rooftop.route.isolated = false
	rooftop.player.current_health = 2
	check(store.save_channel_progress(rooftop), "rooftop resume fixture saved")
	check(change_scene_to_file("res://scenes/ui/start_menu.tscn") == OK, "return to actual menu for rooftop resume")
	await frames()
	current_scene.continue_game()
	main = await wait_main()
	var arena := main.get_node("SceneContainer").get_child(0) as RooftopBossArena
	check(arena != null and run.floor_index == 3, "menu resumes rooftop scene rather than ordinary floor")
	if arena != null:
		check(arena.player.health.current_health == 2, "rooftop resume imports saved player state before checkpointing")
		check(store.get_channel_checkpoint().floor == 3 and store.get_channel_checkpoint().player.current_health == 2, "rooftop resume does not overwrite checkpoint with default equipment or health")
	# Legacy checkpoints inside the removed third-floor isolation room must remain playable.
	var removed_room: Dictionary = saved.duplicate(true)
	removed_room.floor = 2
	removed_room.x = 544
	removed_room.y = -520
	check(store.save_channel_progress(removed_room), "old third-floor checkpoint accepted without retired prerequisites")
	change_scene_to_file("res://scenes/ui/start_menu.tscn")
	await frames()
	current_scene.continue_game()
	main = await wait_main()
	var ordinary: Node = main.get_node("SceneContainer").get_child(0)
	check(ordinary.get_node("ChannelMission").room == null, "resumed third floor does not recreate removed room")
	check(ordinary.get_node("Player").position.distance_to(Vector2(924, 270)) < 5, "removed-room checkpoint relocates player to ordinary floor")
	check(run.channel_floor_ready() and not run.channel_boss_ready(), "legacy resume advances but cannot invent a living escort")
	var codex: Dictionary = saved.duplicate(true)
	codex.floor = 1
	codex.scene = "res://scenes/levels/intermissions/codex_service_passage.tscn"
	codex.route.key = true
	codex.player.current_health = 2
	check(store.save_channel_progress(codex), "Codex resume fixture saved")
	change_scene_to_file("res://scenes/ui/start_menu.tscn")
	await frames()
	current_scene.continue_game()
	main = await wait_main()
	var service: Node = main.get_node("SceneContainer").get_child(0)
	check(service.is_in_group("intermission") and run.floor_index == 1, "menu resumes Codex service checkpoint")
	check(service.get_node("Player").health.current_health == 2 and run.channel_key_found, "Codex resume retains health and key")
	main.queue_free()
	await frames()
	paused = false
	DirAccess.remove_absolute(TEST_PATH)
	print("Channel recovery checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
