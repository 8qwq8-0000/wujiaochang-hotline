extends SceneTree

const TEST_PATH := "user://victory-flow-integration-test.json"
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_scene(flow: SceneContainerManager) -> Node:
	for _frame in 600:
		await process_frame
		var container := flow.get_node(flow.scene_container_path)
		if container.get_child_count() > 0 and not flow.get("_is_loading"):
			return container.get_child(0)
	return null


func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "victory flow profile can be created")
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow := main.get_node("SceneFlow") as SceneContainerManager
	flow.fade_duration = 0
	var floor := await wait_scene(flow)
	check(floor != null, "initial combat floor loads")
	if floor == null:
		quit(1)
		return
	var run := root.get_node("RunManager")
	run.begin_run(88421)
	run.persistent_run = true
	run.floor_index = 3
	run.set_mandatory_enemy_count(0)
	var floor_player := floor.get_node("Player") as PlayerController
	check(floor_player.consume_persona_drink(TalentCoreController.DEEP_NINJA), "fixture installs the final active persona")
	var ui: Node = main.get_node("ExtractionFlow")
	ui.continue_floor()
	var arena := await wait_scene(flow) as RooftopBossArena
	check(arena != null and arena.scene_file_path == "res://scenes/levels/bosses/rooftop_boss_arena.tscn", "continuing after floor four loads rooftop boss")
	check(run.floor_index == 4 and run.persistent_run, "rooftop is the fifth and final run stage")
	if arena == null:
		quit(1)
		return
	arena._set_phase(RooftopBossArena.Phase.CLEARED)
	arena.exit_elevator.set_enabled(true)
	run.set_mandatory_enemy_count(0)
	ui.open_exit(arena.exit_elevator)
	check(ui.get("_overlay").visible and ui.get("_title").text.begins_with("完整通关"), "cleared production rooftop offers legacy minting")
	check(ui.get("_buttons").get_child_count() == 1, "rooftop victory has no ordinary extraction or continue option")
	ui.complete_victory()
	check(paused and run.run_finished, "legacy minting settles and pauses the completed run")
	check(store.get_legacy_drinks().size() == 1, "victory flow saves exactly one legacy drink")
	ui.complete_victory()
	check(store.get_legacy_drinks().size() == 1, "repeated victory UI calls cannot duplicate the record")
	ui.return_to_warehouse()
	var warehouse := await wait_scene(flow)
	check(warehouse != null and warehouse.is_in_group("warehouse") and not paused, "completed victory returns to warehouse")
	check(warehouse.get_node_or_null("ArchiveTerminal") != null, "warehouse exposes the archive terminal")
	warehouse.archive_panel.open()
	var archive_text: String = warehouse.archive_panel.get("_content").text
	check(paused and archive_text.contains("遗产饮料 · 1 瓶"), "archive panel renders the saved legacy drink")
	check(archive_text.contains("黑匣封型：深渊忍者瓶型"), "archive renders the final persona bottle silhouette")
	warehouse.archive_panel.close()
	main.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(TEST_PATH)
	print("Victory flow checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
