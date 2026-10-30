extends SceneTree

const TEST_PATH := "user://warehouse-archive-check.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func tick() -> void:
	for frame in 20:
		await physics_frame

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "create isolated profile")
	check(store.get_codex().get("enemies", []).is_empty(), "new profile starts locked")
	var old: Dictionary = store.get_profile()
	old.codex.erase("enemies")
	check(store._valid_profile(old) and store._normalize_profile(old).codex.enemies.is_empty(), "old v1 profiles remain compatible and start locked")
	var invalid := old.duplicate(true)
	invalid.codex.enemies = [123]
	check(not store._valid_profile(invalid), "invalid encounter data rejected")
	check(not store.record_enemy_encounter("unknown"), "unknown identity rejected")
	var world := Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(100, 100)
	world.add_child(player)
	player.set_physics_process(false)
	player.get_node("Camera2D").enabled = false
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.position = Vector2(900, 100)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	var run_manager := root.get_node("RunManager")
	run_manager.persistent_run = true
	await tick()
	check(store.get_codex().get("enemies", []).is_empty(), "offscreen spawn does not unlock")
	var wall := StaticBody2D.new()
	wall.position = Vector2(150, 100)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 120)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	enemy.position = Vector2(200, 100)
	await tick()
	check(store.get_codex().get("enemies", []).is_empty(), "wall blocks discovery")
	wall.queue_free()
	run_manager.persistent_run = false
	await tick()
	check(store.get_codex().get("enemies", []).is_empty(), "nonpersistent debug scene does not discover")
	run_manager.persistent_run = true
	await tick()
	check("melee_pressure" in store.get_codex().get("enemies", []), "visible unobstructed actual enemy unlocks automatically")
	check(store.record_enemy_encounter("melee_pressure") and store.get_codex().enemies.size() == 1, "repeat encounters deduplicated")
	var reader := Node.new()
	reader.set_script(load("res://scripts/core/warehouse_store.gd"))
	reader.save_path = TEST_PATH
	root.add_child(reader)
	check(reader.load_profile() and "melee_pressure" in reader.get_codex().get("enemies", []), "encounters survive a fresh store load")
	reader.queue_free()
	var raw := FileAccess.get_file_as_string(TEST_PATH)
	store.begin_test_session()
	var turret: Node2D = load("res://scenes/environment/sentry_turret.tscn").instantiate()
	turret.position = Vector2(240, 100)
	world.add_child(turret)
	turret.set_physics_process(false)
	var boss: Node2D = load("res://scenes/actors/bosses/rooftop_whale_goddess.tscn").instantiate()
	boss.position = Vector2(320, 100)
	world.add_child(boss)
	await tick()
	check("sentry_turret" in store.get_codex().enemies, "actual turret encounter is recorded in test memory")
	check("rooftop_whale_goddess" in store.get_codex().enemies, "actual boss encounter is recorded in test memory")
	check(FileAccess.get_file_as_string(TEST_PATH) == raw, "test encounter does not touch formal file")
	store.end_test_session()
	check(not "sentry_turret" in store.get_codex().enemies, "test discoveries discarded on exit")
	var good_path: String = store.save_path
	store.save_path = "user://missing-archive-directory/save.json"
	check(not store.record_enemy_encounter("signal_amplifier") and not "signal_amplifier" in store.get_codex().enemies, "failed save rolls back discovery")
	store.save_path = good_path
	world.queue_free()
	await process_frame
	var warehouse: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(warehouse)
	current_scene = warehouse
	var panel: WarehouseArchivePanel = warehouse.archive_panel
	panel.open()
	check(paused and panel.is_open, "archive opens and pauses game")
	check(panel._content.text.contains("完整通关"), "empty wine rack explains how to collect")
	panel._select_tab(2)
	check(panel._rows.size() == EnemyCatalog.ENTRIES.size(), "all catalog entries have a slot")
	check(panel._entry_title.text == "近战施压者" and panel._portrait.texture != null, "discovered enemy shows identity and image")
	panel._select_entry(1)
	check(panel._entry_title.text == "未解锁" and panel._portrait.texture == null and not panel._content.text.contains("狙击手"), "locked entry hides image and identity")
	panel._select_tab(1)
	check(panel._rows.size() == 3 and panel._entry_title.text == "未解锁", "persona archive has three locked cards")
	var cancel := InputEventAction.new()
	cancel.action = "pause"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await process_frame
	check(not paused and not panel.is_open and warehouse.player.get("_input_enabled") == true, "Esc action closes archive and restores game")
	paused = true
	panel.open()
	panel.close()
	check(paused, "preexisting pause is preserved")
	paused = false
	for entry in EnemyCatalog.ENTRIES:
		check(EnemyCatalog.portrait(entry) != null, "catalog portrait loads: " + entry.id)
	if "--capture" in OS.get_cmdline_user_args():
		store.begin_test_session()
		for entry in EnemyCatalog.ENTRIES:
			store.record_enemy_encounter(entry.id)
		store.commit(store.get_profile().chest, store.get_profile().loadout, "", {
			"id": "archive-preview", "created_unix": 1793318400, "clear_seconds": 724.5,
			"run_seed": 88421, "last_persona_id": "deep_ninja", "highest_marked_kill_chain": 12,
			"manual_perfect_guards": 8, "personas": [{"id": "deep_ninja", "level": 3, "tier_3_talent": "ceaseless_hunt"}],
		})
		panel.open()
		panel._select_tab(0)
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("/tmp/hotline-archive-wine.png")
		panel._select_tab(1)
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("/tmp/hotline-archive-personas.png")
		panel._select_tab(2)
		panel._select_entry(4)
		await process_frame
		await process_frame
		await process_frame
		check(panel._list.get_parent().scroll_vertical > 0, "selected enemy scrolls into view")
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("/tmp/hotline-archive-enemies.png")
		panel._select_entry(6)
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("/tmp/hotline-archive-boss.png")
		panel.close()
		store.end_test_session()
	warehouse.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PATH)
	print("Warehouse archive checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
