extends SceneTree

const SAVE_PATH := "user://codex-supplies-check.json"
const PASSAGE_PATH := "res://scenes/levels/intermissions/codex_service_passage.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_scene(flow: SceneContainerManager) -> Node:
	for frame in 600:
		await process_frame
		var container := flow.get_node(flow.scene_container_path)
		if container.get_child_count() > 0 and not flow.get("_is_loading"):
			return container.get_child(0)
	return null


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func settle() -> void:
	for frame in 4:
		await physics_frame
	await process_frame


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/codex-supplies-" + name + ".png")


func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	store.create_new_profile()
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow := main.get_node("SceneFlow") as SceneContainerManager
	flow.fade_duration = 0.0
	var initial := await wait_scene(flow)
	var run := root.get_node("RunManager")
	run.begin_run(90424)
	run.persistent_run = true
	run.floor_index = 1
	var player := initial.get_node("Player") as PlayerController
	player.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 918
	var pistol := ComponentRolls.create("pistol", 2, rng)
	var stored_id := str(pistol.get_property("instance_id"))
	player.inventory.weapon_slot.clear()
	player.inventory.weapon_slot.equip(pistol)
	player.inventory.secondary_weapon_slot.clear()
	player.inventory.secondary_weapon_slot.equip(ComponentRolls.create("scattergun", 1, rng))
	player.inventory._apply_equipment()
	check(store.commit([], player.export_settlement_state(true)), "fixture saves the starting weapon in the safe loadout")
	player.inventory.cyberware_slot.equip(ComponentRolls.create("smart_fire", 1, rng))
	var bag_weapon := ComponentRolls.create("pistol", 1, rng)
	var bag_id := str(bag_weapon.get_property("instance_id"))
	player.inventory.backpack.add_item(bag_weapon)
	player.inventory.backpack.add_item(ComponentRolls.create("armor", 1, rng))
	player.inventory._apply_equipment()
	run.set_player_state(player.export_run_state())
	check(flow.request_scene(PASSAGE_PATH, {"player_state": player.export_run_state()}), "load passage with carried equipment")
	var passage := await wait_scene(flow)
	player = passage.player
	player.set_physics_process(false)
	await capture("room")
	var medicine := passage.get_node("MedicalCrates/Medicine")
	player.global_position = medicine.global_position + Vector2(0, 44)
	player.health.set_current_health(player.health.max_health)
	await settle()
	check(player.interactor.get_best_target(player) == medicine, "table bottle is reachable through the real interaction query")
	await key(KEY_E)
	check(is_instance_valid(medicine) and not run.codex_medical_supply_used, "full health leaves the bottle on the table")
	player.health.set_current_health(1)
	var disk_before_healing := FileAccess.get_file_as_string(SAVE_PATH)
	await key(KEY_E)
	check(player.health.current_health == 2, "real E restores exactly one health point")
	check(passage.get_node_or_null("MedicalCrates/Medicine") == null and run.codex_medical_supply_used, "used bottle disappears and is consumed once")
	await key(KEY_E)
	check(player.health.current_health == 2, "repeated interaction cannot heal again")
	check(FileAccess.get_file_as_string(SAVE_PATH) == disk_before_healing, "healing updates only the current run")
	var snapshot := player.export_run_state()
	check(flow.request_scene(PASSAGE_PATH, {"player_state": snapshot}), "reload passage fixture")
	passage = await wait_scene(flow)
	player = passage.player
	player.set_physics_process(false)
	await settle()
	check(passage.get_node_or_null("MedicalCrates/Medicine") == null, "re-entering the passage cannot respawn a used bottle")
	player.position = passage.get_node("SafeChest").position + Vector2(0, 36)
	await settle()
	await key(KEY_E)
	var storage: Node = passage.safe_storage
	check(storage.panel.is_open and paused and not player.is_input_enabled(), "real E opens the safe chest and pauses passage movement")
	check(storage.panel.get("_bag_list").get_child_count() == 3, "deposit list offers only the three carried weapons")
	await capture("storage")
	pistol = player.inventory.weapon_slot.get_item()
	storage.panel.get("_bag_list").get_child(0).pressed.emit()
	check(player.inventory.weapon_slot.get_item() == null and storage.chest.get_item_count() == 1, "equipped weapon moves to the permanent chest")
	var saved: Dictionary = store.get_profile()
	check(saved.chest.size() == 1 and saved.loadout.inventory.primary.is_empty(), "saved starting weapon is removed from the safe loadout to avoid duplicate IDs")
	check(saved.loadout.inventory.cyberware.is_empty(), "deposit never smuggles equipped run cyberware into permanent loadout")
	check(not storage.transfer(pistol, true) and storage.chest.get_item_count() == 1, "repeated deposit cannot duplicate the weapon")
	check(not storage.transfer(pistol, false), "passage storage cannot withdraw deposited weapons")
	var armor: InventoryItem
	for item in player.inventory.backpack.get_items():
		if item.get_property("slot", "") == "defense":
			armor = item
	check(not storage.transfer(armor, true), "passage storage rejects non-weapon items")
	for item in player.inventory.backpack.get_items():
		if str(item.get_property("instance_id")) == bag_id:
			bag_weapon = item
	player.heat.dissipation_per_second = 0.0
	player.heat.set_heat(70.0)
	player.heat.is_overheated = true
	var before_failed_deposit := player.export_run_state()
	var disk_before_failure := FileAccess.get_file_as_string(SAVE_PATH)
	store.save_path = "user://missing-codex-deposit-folder/storage.json"
	check(not storage.transfer(bag_weapon, true), "save failure rejects the deposit")
	check(player.export_run_state() == before_failed_deposit and storage.chest.get_item_count() == 1, "save failure restores equipped gear and backpack identities")
	check(player.heat.current_heat == 70.0 and player.heat.is_overheated, "failed deposit preserves carried heat and overheat state")
	store.save_path = SAVE_PATH
	check(FileAccess.get_file_as_string(SAVE_PATH) == disk_before_failure, "failed deposit does not change the original save")
	for item in player.inventory.backpack.get_items():
		if str(item.get_property("instance_id")) == bag_id:
			bag_weapon = item
	check(storage.transfer(bag_weapon, true), "backpack weapon can be deposited after storage is writable again")
	check(storage.chest.get_item_count() == 2 and player.inventory.item_location(bag_weapon).is_empty(), "deposited backpack weapon has a single owner")
	await capture("deposited")
	await key(KEY_ESCAPE)
	check(not paused and player.is_input_enabled(), "closing chest restores passage input")
	player.inventory.blackbox_slot.clear()
	player.inventory._apply_equipment()
	player.health.apply_damage(100, DamagePacket.new())
	for frame in 6:
		await process_frame
	check(run.run_finished and store.get_profile().chest.size() == 2, "death settlement retains both deposited weapons")
	var fresh: Node = load("res://scripts/core/warehouse_store.gd").new()
	fresh.save_path = SAVE_PATH
	root.add_child(fresh)
	check(fresh.load_profile() and fresh.get_profile().chest.size() == 2, "a fresh store instance reads the deposited weapons from disk after death")
	var ids: Array = []
	for entry: Dictionary in fresh.get_profile().chest:
		var restored_item := InventoryItem.new()
		check(restored_item.deserialize(entry), "stored weapon deserializes with its original properties")
		ids.append(str(restored_item.get_property("instance_id")))
	check(ids.count(stored_id) == 1 and ids.count(bag_id) == 1, "deposited weapon instance IDs are preserved exactly once")
	fresh.queue_free()
	main.get_node("ExtractionFlow").return_to_warehouse()
	var warehouse := await wait_scene(flow)
	check(warehouse.is_in_group("warehouse") and warehouse.chest.get_item_count() == 2, "returning after death loads the shared warehouse chest")
	check(warehouse.transfer(warehouse.chest.get_items()[0], false), "player can withdraw the safely deposited weapon in the warehouse")
	run.begin_run(90424)
	check(not run.codex_medical_supply_used, "a new action replenishes its own medical bottle even with the same seed")
	main.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(SAVE_PATH)
	print("Codex supplies checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
