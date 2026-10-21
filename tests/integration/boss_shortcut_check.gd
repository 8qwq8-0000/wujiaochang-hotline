extends SceneTree

const TEST_PATH := "res://.godot/boss-shortcut-check.json"

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_scene(main: Node) -> Node:
	for _frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			return container.get_child(0)
	return null


func wait_scene_path(main: Node, path: String) -> Node:
	for _frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() == 0 or main.get_node("SceneFlow").get("_is_loading"):
			continue
		var scene: Node = container.get_child(0)
		if scene.scene_file_path == path:
			return scene
	return null


func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	var absolute_test_path := ProjectSettings.globalize_path(TEST_PATH)
	DirAccess.remove_absolute(absolute_test_path)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.0
	root.add_child(main)
	current_scene = main
	var warehouse: Node = await wait_scene(main)
	check(warehouse != null and warehouse.is_in_group("warehouse"), "shortcut test starts in warehouse")
	if warehouse == null:
		quit(1)
		return
	var saved_before: Dictionary = store.get_profile()
	var player: PlayerController = warehouse.player
	player.set_physics_process(false)
	player.position = Vector2(420.0, 270.0)
	for _frame in 4:
		await physics_frame
	var shortcut: Node = warehouse.get_node("BossTest")
	check(shortcut.can_interact(player), "boss shortcut accepts the nearby warehouse player")
	check(player.interactor.get_best_target(player) == shortcut, "player detector selects the boss shortcut")
	check(not bool(warehouse.get("_departing")) and not paused, "warehouse is ready to enter boss test")
	check(warehouse.save_loadout(), "warehouse profile is writable before boss shortcut")
	check(main.get_node_or_null("SceneFlow") != null, "boss shortcut can resolve the shared scene flow")
	check(warehouse.enter_boss_test(), "warehouse accepts boss shortcut transition")
	var arena: RooftopBossArena = await wait_scene_path(main, "res://scenes/levels/bosses/rooftop_boss_arena.tscn") as RooftopBossArena
	check(arena != null, "warehouse shortcut loads rooftop boss")
	if arena == null:
		quit(1)
		return
	check(arena.scene_file_path == "res://scenes/levels/bosses/rooftop_boss_arena.tscn", "shortcut targets the boss arena")
	check(bool(arena.get("_test_mode")), "shortcut enables isolated boss test mode")
	check(not root.get_node("RunManager").persistent_run, "boss shortcut does not create a persistent action")
	check(store.get_profile() == saved_before, "entering boss test does not mutate warehouse profile")
	var initial_health := arena.player.health.current_health
	var previous_arena := arena.get_instance_id()
	arena.attack_loop_enabled = false
	arena.boss.activate_immediately()
	arena._set_phase(RooftopBossArena.Phase.BOSS_ACTIVE)
	arena.boss.health.set_current_health(1)
	await create_timer(1.3).timeout
	arena._spawn_support_guards()
	check(arena.get_node("SupportEnemies").get_child_count() == 5 and arena.boss.health.guard_link_active, "restart test reaches shielded boss with five supports")
	var restart := InputEventAction.new()
	restart.action = &"restart_room"
	restart.pressed = true
	root.push_input(restart, true)
	await process_frame
	arena = await wait_scene_path(main, "res://scenes/levels/bosses/rooftop_boss_arena.tscn") as RooftopBossArena
	check(arena != null and arena.get_instance_id() != previous_arena, "real restart input replaces boss scene")
	check(arena.phase == RooftopBossArena.Phase.MINIONS and arena.boss.health.current_health == 6, "restart restores six boss health and opening phase")
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.NONE, "restart removes pending attacks")
	check(arena.get_node("SupportEnemies").get_child_count() == 0 and not arena.support_spawner._spawned, "restart resets second phase supports")
	check(not arena.boss.health.guard_link_active and arena.boss.health.get_health_ratio() == 1, "restart resets linked damage and shield state")
	check(arena.boss.opening_guards_remaining == 3, "restart restores three opening guards")
	check(arena.player.health.current_health == initial_health, "restart restores entry player snapshot")
	check(store.get_profile() == saved_before, "boss phase and restart preserve warehouse save")
	check(arena._return_to_warehouse(), "boss test return uses the existing scene flow")
	warehouse = await wait_scene_path(main, "res://scenes/levels/base/warehouse.tscn")
	check(warehouse != null and warehouse.is_in_group("warehouse"), "boss test returns to warehouse")
	check(store.get_profile() == saved_before, "returning from boss test preserves warehouse profile")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(absolute_test_path)
	print("Boss shortcut checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
