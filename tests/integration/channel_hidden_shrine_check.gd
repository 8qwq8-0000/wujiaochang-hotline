extends SceneTree

const TEST_PATH := "user://channel-hidden-shrine-test.json"
var failures := 0
var checks := 0
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

func frames(count := 5) -> void:
	for _index in count:
		await process_frame

func wait_scene() -> Node:
	for _frame in 900:
		await process_frame
		if not flow._is_loading and main.get_node("SceneContainer").get_child_count():
			await frames()
			main.get_node("PersonaRestFlow").close(true)
			return main.get_node("SceneContainer").get_child(0)
	return null

func kill(enemies: Array) -> void:
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			enemy.health.apply_damage(100, packet)
	await create_timer(0.6).timeout
	await frames()

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hidden-shrine-" + name + ".png")

func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	run = root.get_node("RunManager")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "isolated shrine profile")
	check(store.commit([], {}, "", {"id": "original-clear", "personas": [], "semantic_leaks": []}, {"intro_seen": true}), "original ending prerequisite")
	run.begin_run(778820)
	run.persistent_run = true
	run.persona_authorization_floor = 0
	main = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	flow = main.get_node("SceneFlow")
	flow.fade_duration = 0
	var floor_scene := await wait_scene()
	var mission: ChannelMission = floor_scene.get_node("ChannelMission")
	var door: ChannelHiddenDoor = mission.get("door")
	var player: PlayerController = floor_scene.get_node("Player")
	var assembler: FloorAssembler = floor_scene.get_node("FloorAssembler")
	check(door != null and not door.available, "unlit door waits for entire first floor clear")
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.is_projectile = true
	door.receive_projectile_hit(packet)
	check(door.state == ChannelHiddenDoor.State.SEALED, "early shots do not trigger hidden route")
	await kill(assembler.generated_rooms[0].get_node("Enemies").get_children())
	player.global_position = assembler.generated_rooms[1].global_position + Vector2(120, 270)
	for _frame in 4:
		await physics_frame
	await kill(assembler.generated_rooms[1].get_node("Enemies").get_children())
	check(door.available and assembler.generated_rooms[1].exit_elevator.enabled, "both normal ring exit and unlit door available at floor end")
	check(assembler.generated_rooms[1].exit_elevator.get("_sigil").visible, "normal door retains its ring")
	player.set_physics_process(false)
	player.global_position = door.global_position + Vector2(-180, 0)
	player.health.configure_max_health(50, true)
	var shot: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	shot.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 420)
	floor_scene.add_child(shot)
	shot.global_position = door.global_position + Vector2(-180, 0)
	await create_timer(0.55).timeout
	check(door.state == ChannelHiddenDoor.State.SEALED and door.hits_received == 1, "first real projectile damages but does not open door")
	var top_before := player.camera.limit_top
	var right_before := player.camera.limit_right
	var center_before := player.camera.get_screen_center_position()
	check(top_before == -144, "ordinary floor retains north skyline allowance")
	check(floor_scene.get_node("ShrineSkyline").position == mission.room.position, "independent area owns its own skyline")
	var piercing_shot: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	piercing_shot.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 420)
	piercing_shot.circuit_pierce_remaining = 1
	floor_scene.add_child(piercing_shot)
	piercing_shot.global_position = door.global_position + Vector2(-20, 0)
	for _frame in 5:
		await physics_frame
	check(door.state == ChannelHiddenDoor.State.SEALED and door.hits_received == 2, "piercing projectile damages the sealed door exactly once")
	check(is_instance_valid(piercing_shot) and piercing_shot.circuit_pierce_remaining == 0 and piercing_shot.global_position.x > door.global_position.x, "projectile still penetrates the door")
	check(door.get("_impact_remaining") > 0.0, "hit starts visual damage animation")
	check(door.get("_shape").position == Vector2.ZERO, "visual recoil does not move collision")
	await capture("00-door-damage")
	await create_timer(0.25).timeout
	check(door.get("_impact_remaining") == 0.0, "damage flash and recoil settle after impact")
	await capture("00-before-break")
	door.receive_projectile_hit(packet)
	if "--capture" in OS.get_cmdline_user_args():
		for index in 8:
			await create_timer(0.06).timeout
			await capture("break-frame-%02d" % index)
	await frames()
	check(door.state == ChannelHiddenDoor.State.BROKEN and door.hits_received == 3, "third hit opens door immediately")
	check(player.camera.limit_top == top_before and player.camera.limit_right == right_before, "opening door preserves camera limits")
	check(player.camera.get_screen_center_position().distance_to(center_before) < 2, "opening door does not jump camera")
	check(floor_scene.get_children().filter(func(node): return node is CombatProjectile and node.faction == CombatFaction.Id.ENEMY).is_empty(), "door emits no enemy bullets")
	await create_timer(0.22).timeout
	await capture("01-open-door")
	await create_timer(0.3).timeout
	check(is_equal_approx(door.get("_break_elapsed"), ChannelHiddenDoor.BREAK_SECONDS), "door fracture settles after its short animation")
	check(is_equal_approx(float(door.get("_hit_material").get_shader_parameter("fracture")), 1.0), "broken door keeps its torn opening")
	await capture("01-broken-door-settled")
	check(door.get("_shape").disabled, "broken door removes physical barrier")
	player.global_position = door.global_position + Vector2(-28, 0)
	player.move_and_collide(Vector2(28, 0))
	await create_timer(0.55).timeout
	await frames()
	check(mission.inside and mission.room.started and mission.room.living_enemies().size() == 5, "crossing opened door transitions into independent combat area")
	check(not mission.get("_transitioning") and player.is_input_enabled(), "area transition fades back in and restores controls")
	check(player.camera.limit_left == int(mission.room.position.x) and player.camera.limit_top == -144, "new area frames its own room and north skyline")
	var chamber: ChannelShrineRoom = mission.room
	check(not chamber.terminal.enabled and not chamber.entrance_barrier.disabled, "altar and return are locked during combat")
	check(not chamber.exit_elevator.enabled, "right ascent door stays locked during combat")
	var guards := chamber.living_enemies()
	check(guards.filter(func(enemy): return enemy.profile.display_name == "重装盾兵").size() == 2, "shrine has exactly two shield guards")
	check(guards.filter(func(enemy): return enemy.profile.display_name == "狙击手").size() == 3, "shrine has exactly three snipers")
	var shrine_layout: CombatLayoutData = chamber.get_node("OrdinaryShrineFloor").layout
	check(shrine_layout.covers.size() == 5, "shrine keeps two partitions, the console and two marked crates")
	var map := chamber.get_world_2d().navigation_map
	var entry := chamber.to_global(Vector2(60, 180))
	for target: Vector2 in [Vector2(246, 120), Vector2(380, 268), Vector2(436, 100), Vector2(534, 294), Vector2(586, 104), Vector2(505, 180), Vector2(580, 288)]:
		var destination := chamber.to_global(target)
		var path := NavigationServer2D.map_get_path(map, entry, destination, true)
		check(not path.is_empty() and path[0].distance_to(entry) < 8 and path[-1].distance_to(destination) < 8, "entrance connects to guard or altar approach: " + str(target))

	player.move_and_collide(Vector2(-180, 0))
	check(chamber.to_local(player.global_position).x > 20, "physical room barrier prevents leaving during combat")
	await capture("02-hidden-room")
	await kill(chamber.living_enemies())
	check(chamber.cleared and chamber.terminal.enabled and chamber.entrance_barrier.disabled, "clearing enemies enables altar and return corridor")
	check(chamber.exit_elevator.enabled and chamber.exit_elevator.ascent_only, "clearing guards opens right door to second floor")
	var ascent_ui: Node = main.get_node("ExtractionFlow")
	ascent_ui.open_exit(chamber.exit_elevator)
	check(ascent_ui.get("_buttons").get_child_count() == 1 and ascent_ui.get("_buttons").get_child(0).text == "前往第二层", "right door offers ascent without requiring core pickup")
	ascent_ui.close_exit()

	player.global_position = chamber.to_global(Vector2(72, 180))
	player.move_and_collide(Vector2(-50, 0))
	await create_timer(0.55).timeout
	check(not mission.inside and player.global_position.distance_to(door.global_position + Vector2(-40, 0)) < 5, "cleared area returns through fade to original door")
	player.move_and_collide(Vector2(40, 0))
	await create_timer(0.55).timeout
	check(mission.inside and chamber.cleared and chamber.living_enemies().is_empty(), "return visit preserves cleared area: pos=%s inside=%s transition=%s" % [player.global_position, mission.inside, mission.get("_transitioning")])
	player.health.configure_max_health(player.config.max_health, true)
	player.global_position = chamber.to_global(Vector2(110, 40))
	await create_timer(0.8).timeout
	await capture("02-area-skyline")
	player.global_position = chamber.to_global(Vector2(360, 180))
	await create_timer(0.8).timeout
	await capture("02-room-ascent-door")


	player.health.configure_max_health(player.config.max_health, true)
	player.global_position = chamber.terminal.global_position + Vector2(-45, 0)
	for _frame in 3:
		await physics_frame
	check(player.interactor.get_best_target(player) == chamber.terminal, "altar is reachable by actual E interaction")
	await create_timer(0.8).timeout
	check(player.interactor.request_interaction(player), "E opens altar dialogue")
	check(paused and not player.channel_curse_active and not run.channel_route_active, "viewing altar does not grant curse or route")
	check("".join(mission.dialogue._pages).contains("生命上限变为 1"), "warning discloses curse before pickup")
	while mission.dialogue._page_index < mission.dialogue._pages.size() - 1:
		mission.dialogue._advance_page()
	check(mission.dialogue._buttons.get_child(0).text.begins_with("放弃") and mission.dialogue._buttons.get_child(1).text.begins_with("拾取"), "decline is left and pickup is right")
	await capture("03-altar-choice")
	mission.dialogue._choose(mission.decline_route)
	check(not run.channel_route_active and not player.channel_curse_active and chamber.terminal.enabled, "decline preserves ordinary run and revisitable altar")
	# A full bag must not silently evict existing equipment or activate the curse.
	for _index in ComponentInventory.CAPACITY:
		player.inventory.backpack.add_item(ComponentRolls.make_item("armor"))
	mission.accept_route()
	check(not run.channel_route_active and not player.channel_curse_active and player.inventory.backpack.get_item_count() == 6, "full backpack rejects core without changing route or losing items")
	mission.dialogue.close()
	for item in player.inventory.backpack.get_items().duplicate():
		player.inventory.backpack.remove_item(item)
	var base_speed: float = player.dash.config.walk_speed
	var base_cooldown: float = player.dash.config.dash_cooldown
	var base_cooling: float = player.heat.dissipation_per_second
	store.save_path = "user://hidden-shrine-missing-directory/test.json"
	mission.accept_route()
	check(not run.channel_route_active and not player.channel_curse_active and player.health.max_health == 3, "failed pickup save rolls back curse and route")
	mission.dialogue.close()
	store.save_path = TEST_PATH
	mission.accept_route()
	check(run.channel_route_active and run.channel_record_found and player.channel_curse_active, "pickup activates second-ending prerequisite")
	var core := player.inventory.item_at("backpack", 0)
	check(player.inventory.is_channel_core(core) and core.get_texture() != null, "core occupies first backpack cell with its actual icon")
	player.inventory.set_open(true)
	check(not player.inventory.can_discard(core) and not player.inventory.discard_backpack_item(core), "core cannot be discarded")
	check(not player.inventory.can_drop_item(core, "backpack", 1) and not player.inventory.put_in_blackbox(0), "core cannot move or enter blackbox")
	check(player.inventory.pickup("armor"), "ordinary item can be picked up after core")
	var armor := player.inventory.item_at("backpack", 1)
	check(not player.inventory.can_drop_item(armor, "backpack", 0), "other equipment cannot displace core from first cell")
	await capture("04-core-backpack")
	player.inventory.set_open(false)
	check(mission.get("_hud") == null and player.get("_channel_curse_status") == null, "removed permanent route and curse overlays stay absent")
	check(player.health.max_health == 1 and player.health.current_health == 1 and player.config.max_health == 1, "curse clamps current and maximum health to one")
	check(is_equal_approx(player.dash.config.walk_speed, base_speed * 0.85), "curse reduces movement")
	check(is_equal_approx(player.dash.config.dash_cooldown, base_cooldown * 1.4), "curse increases dash cooldown")
	check(is_equal_approx(player.heat.dissipation_per_second, base_cooling * 0.7), "curse reduces cooling")
	player.apply_channel_curse(true)
	check(is_equal_approx(player.dash.config.walk_speed, base_speed * 0.85), "curse is idempotent")
	check(not run.finish_extraction(player) and not chamber.terminal.enabled, "pickup locks extraction and cannot repeat")
	player.health.repair(10)
	check(player.health.current_health == 1, "healing cannot exceed cursed maximum")
	var checkpoint: Dictionary = store.get_channel_checkpoint()
	check(checkpoint.shrine_claimed and checkpoint.hidden_room_cleared and checkpoint.hidden_door_broken and checkpoint.player.channel_curse, "safe checkpoint includes hidden geometry and curse")
	await capture("04-curse")
	check(run.restore_channel_checkpoint(checkpoint), "shrine checkpoint restores")
	flow.request_scene("res://scenes/levels/floors/combat_prototype.tscn")
	floor_scene = await wait_scene()
	mission = floor_scene.get_node("ChannelMission")
	player = floor_scene.get_node("Player")
	assembler = floor_scene.get_node("FloorAssembler")
	check(assembler.active_area_index == 1 and assembler._rooms_remaining == 0, "completed-floor resume selects final area")
	check(mission.room.cleared and mission.get("door").state == ChannelHiddenDoor.State.BROKEN and mission.room.living_enemies().is_empty(), "resume restores open passage and empty cleared shrine")
	check(player.health.max_health == 1 and player.channel_curse_active, "resume retains curse")
	check(player.inventory.is_channel_core(player.inventory.item_at("backpack", 0)), "checkpoint restore keeps core in first cell")
	player.global_position = mission.room.exit_elevator.global_position
	await frames()
	var ui: Node = main.get_node("ExtractionFlow")
	ui.open_exit(mission.room.exit_elevator)
	check(ui.get("_buttons").get_child_count() == 1, "cursed normal exit only offers ascent")
	ui.continue_floor()
	floor_scene = await wait_scene()
	player = floor_scene.get_node("Player")
	check(run.floor_index == 1 and player.channel_curse_active and player.health.max_health == 1, "curse persists into second floor")
	check(player.inventory.is_channel_core(player.inventory.item_at("backpack", 0)), "core persists in first cell across floors")
	var recovery := player.export_recovery_state()
	check(not recovery.channel_curse and recovery.current_health == 3, "death settlement clears curse and restores normal maximum")
	var fresh: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(fresh)
	await frames()
	check(fresh.health.max_health == 3 and is_equal_approx(fresh.dash.config.walk_speed, base_speed), "curse does not mutate shared player or dash resources")
	fresh.queue_free()
	main.queue_free()
	await frames()
	paused = false
	DirAccess.remove_absolute(TEST_PATH)
	print("Hidden shrine checks: ", checks, "; failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
