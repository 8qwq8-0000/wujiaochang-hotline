extends SceneTree

# A cross-scene production-flow smoke check. Combat damage is accelerated; scene
# transitions, persona authorization, settlement and durable loading stay real.
const SAVE := "res://.godot/release-journey-check.json"
const PERSONA := TalentCoreController.DEEP_NINJA
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_room(flow: SceneContainerManager, previous: Node = null) -> Node:
	for _frame in 900:
		await process_frame
		if flow._is_loading or flow._scene_container.get_child_count() == 0:
			continue
		var room := flow._scene_container.get_child(0)
		if room != previous:
			for _settle in 5:
				await process_frame
			return room
	return null


func choose_rest(main: Node, player: PlayerController) -> void:
	var rest: PersonaRestFlow = main.get_node("PersonaRestFlow")
	for _frame in 120:
		if rest.is_open:
			break
		await process_frame
	check(rest.is_open, "mandatory persona rest opens on the new floor")
	if not rest.is_open:
		return
	check(rest.choose_persona(PERSONA), "persona drink can be selected in production rest")
	var tier: int = player.talent_core.get_persona_level(PERSONA)
	check(rest.choose_talent(tier, TalentCoreController.TALENT_OPTIONS[PERSONA][tier][0]), "new talent tier can be selected")
	check(rest.close(), "persona rest confirms and returns to combat")


func run_checks() -> void:
	var save_path := ProjectSettings.globalize_path(SAVE)
	DirAccess.remove_absolute(save_path)
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE
	check(store.create_new_profile(), "fresh journey creates an isolated durable save")
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.0
	root.add_child(main)
	current_scene = main
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	var warehouse := await wait_room(flow)
	check(warehouse != null and warehouse.is_in_group("warehouse"), "fresh journey opens the warehouse")
	if warehouse == null:
		root.get_node("GameSettings").quit_game(1)
		return
	check(warehouse.depart(), "warehouse departure starts a persistent action")
	var room: Node = warehouse
	var run := root.get_node("RunManager")
	var exit_flow := main.get_node("ExtractionFlow")
	for floor_index in 3:
		room = await wait_room(flow, room)
		check(room != null and room.has_node("FloorAssembler") and run.floor_index == floor_index, "production route reaches floor %d" % (floor_index + 1))
		if room == null:
			root.get_node("GameSettings").quit_game(1)
			return
		await choose_rest(main, room.get_node("Player"))
		await preload("res://tests/integration/combat_test_flow.gd").clear_floor(self)
		check(run.mandatory_enemies_remaining == 0, "floor %d objective clears through combat events" % (floor_index + 1))
		exit_flow.continue_floor()
		if floor_index == 1:
			var passage := await wait_room(flow, room)
			check(passage != null and passage.is_in_group("intermission"), "second floor leads through the Codex passage")
			if passage == null:
				root.get_node("GameSettings").quit_game(1)
				return
			passage.talk_to_codex()
			while passage.panel.is_open:
				passage.panel.advance()
			passage.upgrade_panel.close()
			check(passage.depart(), "Codex passage departs to floor three")
			room = passage
	var arena := await wait_room(flow, room) as RooftopBossArena
	check(arena != null and run.floor_index == 3, "third floor leads to the production rooftop")
	if arena == null:
		root.get_node("GameSettings").quit_game(1)
		return
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	arena.boss.health.end_guard_link()
	arena.boss.health.set_current_health(0)
	arena.boss.health.died.emit(packet)
	for enemy in get_nodes_in_group("enemies"):
		if arena.is_ancestor_of(enemy) and enemy is EnemyController and not enemy.health.is_dead():
			enemy.health.set_current_health(0)
			enemy._finalize_defeat()
	check(arena.phase == RooftopBossArena.Phase.CLEARED, "rooftop reaches the normal cleared phase")
	exit_flow.open_exit(arena.exit_elevator)
	exit_flow.complete_victory()
	check(run.run_finished and store.get_legacy_drinks().size() == 1, "first ending commits exactly one durable record")
	exit_flow.return_to_warehouse()
	warehouse = await wait_room(flow, arena)
	check(warehouse != null and warehouse.is_in_group("warehouse"), "settled journey returns to warehouse")
	check(store.load_profile() and store.get_legacy_drinks().size() == 1, "record survives loading from disk")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("Release journey checks: ", checks, "; failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
