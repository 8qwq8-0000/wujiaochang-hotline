extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func wait_floor(flow: SceneContainerManager) -> PlayerController:
	for frame in 600:
		await process_frame
		var player := get_first_node_in_group("player") as PlayerController
		if player != null and not flow.get("_is_loading"):
			player.set_physics_process(false)
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(false)
			return player
	return null

func clear_floor() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	await process_frame
	await process_frame

func run_checks() -> void:
	var store: Node = root.get_node("WarehouseStore")
	store.save_path = "user://warehouse-extraction-test.json"
	DirAccess.remove_absolute(store.save_path)
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	flow.fade_duration = 0
	var ui: Node = main.get_node("ExtractionFlow")
	var run: Node = root.get_node("RunManager")
	var player := await wait_floor(flow)
	if player == null:
		quit(1)
		return
	ui.open_exit()
	check(not paused, "uncleared floor cannot open exit")
	check(not run.finish_extraction(player), "uncleared run cannot settle")
	player.inventory.pickup("pistol")
	player.inventory.pickup("wheel")
	player.inventory.pickup("scattergun")
	await clear_floor()
	check(player.inventory.equip(0), "equip mobility after clear")
	var before := player.export_run_state()
	var exit: ExitElevator = main.find_child("ExitElevator", true, false)
	player.global_position = exit.global_position
	for frame in 4:
		await physics_frame
	check(not paused and ui.get("_overlay").visible, "real cleared exit opens choice without pausing")
	check(ui.get("_overlay").size.x <= 300, "exit choice is a small panel")
	player.global_position = exit.global_position - Vector2(100, 0)
	for frame in 4:
		await physics_frame
	check(not ui.get("_overlay").visible and not paused, "leaving exit closes choice")
	player.global_position = exit.global_position
	for frame in 4:
		await physics_frame
	check(ui.get("_overlay").visible, "re-entering reopens choice")
	ui.close_exit()
	ui.open_exit()
	ui.continue_floor()
	check(not paused, "continue restores world")
	player = await wait_floor(flow)
	check(run.floor_index == 1, "continue advances floor")
	check(player.export_run_state() == before, "continue preserves equipment and bag")
	await clear_floor()
	ui.open_exit()
	await process_frame
	await process_frame
	var position: Vector2 = ui.get("_buttons").get_child(0).get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	check(paused and run.run_finished, "extraction ends run and stops world")
	if not run.run_finished:
		quit(1)
		return
	check(run.extraction_result.items.size() == 4, "both weapons, mobility and spare bag extracted once")
	check(run.extraction_result.player_state == before, "extraction retains full serialized state")
	var result: Dictionary = run.extraction_result.duplicate(true)
	ui.extract()
	check(run.extraction_result == result, "repeat extraction does not duplicate rewards")
	check(not run.finish_extraction(player), "manager rejects duplicate settlement")
	ui.close_exit()
	check(paused, "settled run cannot return to combat")
	ui.return_to_warehouse()
	player = await wait_floor(flow)
	var warehouse: Node = main.get_node("SceneContainer").get_child(0)
	check(warehouse.is_in_group("warehouse"), "settlement returns to warehouse")
	check(player.inventory.get_extraction_items().size() == 4, "warehouse retains extracted equipment")
	check(warehouse.depart(), "warehouse can start the next run")
	player = await wait_floor(flow)
	check(not paused and not run.run_finished and run.floor_index == 0, "new run resumes fresh floor")
	check(player.inventory.get_extraction_items().size() == 4, "new run carries chosen equipment")
	await clear_floor()
	player.set_circuit_breaker_equipped(false)
	player.health.apply_damage(100, DamagePacket.new())
	check(player.health.is_dead(), "death fixture bypasses one-time insurance")
	check(not run.finish_extraction(player), "dead player cannot extract")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(store.save_path)
	print("Extraction failures: ", failures)
	quit(0 if failures == 0 else 1)
