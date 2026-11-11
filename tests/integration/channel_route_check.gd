extends SceneTree

const TEST_PATH := "user://channel-route-integration-test.json"
const FLOOR := "res://scenes/levels/floors/combat_prototype.tscn"
var checks := 0
var failures := 0
var main: Node
var flow: SceneContainerManager
var run: Node
var store: Node


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func frames(count := 4) -> void:
	for _index in count:
		await process_frame


func wait_scene() -> Node:
	for _frame in 600:
		await process_frame
		if flow.get_node(flow.scene_container_path).get_child_count() > 0 and not flow._is_loading:
			await frames()
			main.get_node("PersonaRestFlow").close(true)
			return flow.get_node(flow.scene_container_path).get_child(0)
	return null


func kill(enemies: Array) -> void:
	var packet := DamagePacket.new()
	packet.base_damage = 100
	packet.source_faction = CombatFaction.Id.PLAYER
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			enemy.health.apply_damage(100, packet)
	await create_timer(0.6).timeout
	await frames()


func clear_area(floor_scene: Node, index: int) -> void:
	var area: CombatRoom = floor_scene.get_node("FloorAssembler").generated_rooms[index]
	if not area.active:
		area.activate()
	await frames()
	await kill(area.get_node("Enemies").get_children())


func new_floor(index: int) -> Node:
	run.floor_index = index
	run.persona_authorization_floor = index
	run.persona_authorization_pending = false
	check(flow.request_scene(FLOOR, {"player_state": run.get_player_state()}), "floor request accepted")
	return await wait_scene()


func prepare_hidden_room(floor_scene: Node) -> ChannelMission:
	await clear_area(floor_scene, 0)
	var assembler: FloorAssembler = floor_scene.get_node("FloorAssembler")
	var player: PlayerController = floor_scene.get_node("Player")
	player.global_position = assembler.generated_rooms[1].global_position + Vector2(110, 270)
	for _frame in 4:
		await physics_frame
	await clear_area(floor_scene, 1)
	var mission: ChannelMission = floor_scene.get_node("ChannelMission")
	mission.get("door").break_open()
	player.global_position = mission.room.to_global(Vector2(90, 180))
	await frames()
	await kill(mission.room.living_enemies())
	return mission


func capture(name: String) -> void:
	if "--channel-visual" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/channel-route-preview")
	root.get_texture().get_image().save_png("/tmp/channel-route-preview/" + name + ".png")


func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	run = root.get_node("RunManager")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "isolated profile created")
	check(not store.is_channel_route_unlocked(), "new profile has no second ending")
	run.begin_run(20261103)
	run.persistent_run = true
	run.persona_authorization_floor = 0
	main = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	flow = main.get_node("SceneFlow")
	flow.fade_duration = 0
	var floor_scene := await wait_scene()
	check(floor_scene.get_node_or_null("ChannelMission") == null, "first playthrough has no locked quest room")
	check(store.commit([], {}, "", {"id": "old-clear", "personas": [], "semantic_leaks": []}), "old original-ending record saved")
	check(store.is_channel_route_unlocked(), "old victory unlocks second route without migration loss")
	store.acknowledge_channel_intro()
	floor_scene = await new_floor(0)
	var mission: ChannelMission = floor_scene.get_node("ChannelMission")
	check(mission != null and not run.channel_route_active, "unlocked run starts as ordinary action")
	check(not run.activate_channel_route(), "cannot activate without first-floor record")
	mission = await prepare_hidden_room(floor_scene)
	check(mission.room.cleared and mission.room.terminal.enabled, "hidden shrine clears before altar pickup")
	await capture("01-hidden-shrine")
	mission.use_task_terminal()
	check(paused and not run.channel_record_found and not run.channel_route_active, "altar warns before granting prerequisite or curse")
	while mission.dialogue._page_index < mission.dialogue._pages.size() - 1:
		mission.dialogue._advance_page()
	await capture("02-connection-choice")
	mission.dialogue._choose(mission.decline_route)
	check(not paused and not run.channel_route_active, "declining retains normal action")
	var player: PlayerController = floor_scene.get_node("Player")
	check(run.finish_extraction(player), "declined route can extract")
	run.begin_run(20261104)
	run.persistent_run = true
	floor_scene = await new_floor(0)
	mission = await prepare_hidden_room(floor_scene)
	mission.use_task_terminal()
	# A failed durable save must not silently lock the player into the route.
	store.save_path = "user://channel-missing-directory/checkpoint.json"
	mission.dialogue._choose(mission.accept_route)
	check(not run.channel_route_active and mission.dialogue.visible, "failed commitment save leaves extraction available")
	mission.dialogue.close()
	store.save_path = TEST_PATH
	mission.accept_route()
	check(run.channel_route_active and not paused, "explicit pickup locks route and applies curse")
	player = floor_scene.get_node("Player")
	check(not run.finish_extraction(player), "extraction blocked at model layer")
	var checkpoint: Dictionary = store.get_channel_checkpoint()
	check(checkpoint.route.active and checkpoint.route.record and checkpoint.cleared[0], "commitment checkpoint contains route and cleared area")
	check(store.get_profile().channel_story.discoveries.has("shrine_core"), "discovery persists separately from run prerequisites")
	check(store.commit(store.get_profile().chest, store.get_profile().loadout), "ordinary save succeeds")
	check(not store.get_channel_checkpoint().is_empty(), "ordinary save retains active checkpoint")
	check(run.restore_channel_checkpoint(checkpoint), "route checkpoint restores run")
	floor_scene = await new_floor(0)
	mission = floor_scene.get_node("ChannelMission")
	check(run.channel_route_active and mission.task_done, "resume retains first prerequisite and lock")
	check(floor_scene.get_node("FloorAssembler").generated_rooms[0].cleared, "resume does not regenerate cleared-area enemies")
	await clear_area(floor_scene, 1)
	var ui: Node = main.get_node("ExtractionFlow")
	ui.open_exit()
	check(ui.get("_buttons").get_child_count() == 1, "locked floor exit only offers ascent")
	ui.close_exit()
	floor_scene = await new_floor(1)
	mission = floor_scene.get_node("ChannelMission")
	check(mission.room == null and floor_scene.get_node_or_null("ChannelTaskEntrance") == null, "second floor has no maintenance room or quest entrance")
	await clear_area(floor_scene, 0)
	check(mission.allows_next_area() and mission.assembler.passages[0].unlocked, "second-floor passage opens after ordinary clear")
	check(run.channel_floor_ready() and not run.channel_key_found, "second floor does not require the retired signature key")
	check(store.get_channel_checkpoint().floor == 1, "second-floor arrival still saves a recovery checkpoint")
	await clear_area(floor_scene, 1)
	ui.continue_floor()
	var passage := await wait_scene()
	check(passage.is_in_group("intermission"), "second route preserves Codex service passage")
	check(store.get_channel_checkpoint().scene == "res://scenes/levels/intermissions/codex_service_passage.tscn", "Codex arrival saves its own recovery checkpoint")
	floor_scene = await new_floor(2)
	mission = floor_scene.get_node("ChannelMission")
	check(mission.room == null and floor_scene.get_node_or_null("ChannelTaskEntrance") == null, "third floor has no isolation room or quest entrance")
	await clear_area(floor_scene, 0)
	check(mission.assembler.generated_rooms.size() == 1 and mission.assembler.passages.is_empty(), "ordinary third floor is a single area")
	check(run.channel_floor_ready() and not run.channel_isolated, "third floor does not require retired isolation work")
	check(not run.channel_boss_ready(), "core alone cannot bypass the living Codex prerequisite")
	check(store.get_channel_checkpoint().floor == 2, "third-floor checkpoint accepts an uncollected key and isolation")
	ui.continue_floor()
	var arena := await wait_scene() as RooftopBossArena
	check(arena != null and run.floor_index == 3, "third floor reaches rooftop")
	if arena == null:
		root.get_node("GameSettings").quit_game(1)
		return
	check(store.get_channel_checkpoint().floor == 3, "rooftop checkpoint saved")
	arena.attack_loop_enabled = false
	arena.player.health.configure_max_health(100, true)
	await kill(arena.get_node("Enemies").get_children())
	await create_timer(2.4).timeout
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE, "existing awakening retained")
	await kill(arena.get_node("SupportEnemies").get_children())
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE, "without living Codex original boss retains its second phase")
	check(arena.boss.health.damage_enabled and arena.boss.health.current_health == 1, "original ending exposes final hit after guards")
	check(arena.get_node_or_null("ChannelTakeover") == null, "retired takeover is never started by core alone")
	var final_hit := DamagePacket.new()
	final_hit.source_faction = CombatFaction.Id.PLAYER
	arena.boss.health.apply_damage(100, final_hit)
	check(arena.phase == RooftopBossArena.Phase.CLEARED, "original boss opens settlement exit")
	ui.open_exit(arena.exit_elevator)
	ui.complete_victory()
	check(run.run_finished and paused, "original ending settles while carrying core")
	await capture("06-settlement")
	var records: Array = store.get_legacy_drinks()
	check(records.size() == 2 and records.back().ending == "core_destroyed", "core without escort saves original ending once")
	check(store.get_channel_checkpoint().is_empty() and not run.channel_route_active, "success clears run lock and checkpoint")
	ui.complete_victory()
	check(store.get_legacy_drinks().size() == 2, "repeat settlement cannot duplicate ending record")
	ui.return_to_warehouse()
	var warehouse := await wait_scene()
	check(warehouse.is_in_group("warehouse") and not paused, "original ending returns safely to warehouse")
	check(warehouse.get_node_or_null("HotlineTerminal") == null, "warehouse removes redundant hotline terminal")
	warehouse.archive_panel.open()
	warehouse.archive_panel._select_tab(1)
	warehouse.archive_panel._select_entry(1)
	check(warehouse.archive_panel._entry_tag.text == "已解锁", "original ending does not fabricate second-ending completion")
	warehouse.archive_panel.close()
	await capture("07-warehouse")
	# Test-mode isolation applies to the entire extended profile.
	var formal: Dictionary = store.get_profile()
	check(store.begin_test_session(), "test session begins")
	store.save_channel_progress(checkpoint, ["test-only"])
	store.end_test_session()
	check(store.get_profile() == formal, "test session restores formal story and checkpoints")
	main.queue_free()
	await frames()
	paused = false
	DirAccess.remove_absolute(TEST_PATH)
	print("Channel route checks: ", checks, "; failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
