extends SceneTree

var failures := 0
var checks := 0
var store: Node
const TEST_PATH := "user://warehouse-integration-test.json"
const LOBBY_MUSIC := preload("res://assets/audio/music/lobby/lobby_theme.ogg")

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_scene(main: Node) -> Node:
	for frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			return container.get_child(0)
	return null

func press_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	# Reproduce the real menu hand-off: its music player remains "busy" while a
	# 0.75 second fade-out is pending. The warehouse must cancel that fade.
	root.get_node("SoundManager").play_music(LOBBY_MUSIC)
	await process_frame
	root.get_node("SoundManager").stop_music(0.75)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.01
	root.add_child(main)
	current_scene = main
	var room := await wait_scene(main)
	check(room != null and room.is_in_group("warehouse"), "project entry opens warehouse")
	if room == null:
		quit(1)
		return
	var player: PlayerController = room.player
	player.set_physics_process(false)
	check(get_nodes_in_group("enemies").is_empty(), "warehouse is safe")
	await create_timer(0.9).timeout
	check(root.get_node("SoundManager").is_music_playing(LOBBY_MUSIC), "warehouse keeps the lobby music playing")
	check(not main.get_node("CombatHUD/Overlay").visible, "warehouse hides combat HUD")
	var inventory: ComponentInventory = player.inventory
	var original_starter := inventory.weapon_slot.get_item()
	var stored_scattergun := ComponentRolls.create("scattergun", 1, RandomNumberGenerator.new())
	room.chest.add_item(stored_scattergun)
	inventory.weapon_slot.clear()
	room._ensure_fallback_weapon()
	var fallback := inventory.weapon_slot.get_item()
	check(fallback != null and fallback.serialize().get("prototype_id") == "pistol", "empty loadout receives issued pistol even with scattergun in chest")
	check(room.chest.has_item(stored_scattergun), "fallback never auto-equips stored loot")
	room._ensure_fallback_weapon()
	check(inventory.weapon_slot.get_item() == fallback, "existing equipped weapon remains unchanged")
	inventory.weapon_slot.clear()
	inventory.weapon_slot.equip(original_starter)
	inventory._apply_equipment()
	room.chest.remove_item(stored_scattergun)
	player.position = room.get_node("Chest").position + Vector2(40, 20)
	for frame in 4:
		await physics_frame
	await press_key(KEY_E)
	check(room.panel.is_open and paused, "real E interaction opens chest and pauses world")
	check(not player.is_input_enabled(), "open chest disables player attacks and movement")
	var starter := inventory.weapon_slot.get_item()
	check(room.transfer(starter, true), "starter can be stored")
	check(player.export_recovery_state().inventory.primary.is_empty(), "stored starter is not copied into recovery loadout")
	check(room.transfer(starter, false) and inventory.equip(0), "starter withdraws to bag and re-equips")
	check(inventory.pickup("pistol"), "fixture picks up reserve weapon")
	var pistol := inventory.secondary_weapon_slot.get_item()
	var id: String = pistol.get_property("instance_id")
	pistol.set_property("quality", 3)
	pistol.set_property("heat", 37.5)
	check(room.transfer(pistol, true), "equipped reserve can be stored directly")
	check(inventory.secondary_weapon_slot.get_item() == null, "deposit clears equipment slot")
	check(room.chest.get_items()[0] == pistol, "deposit moves same item instance")
	check(player.weapons.weapons[1] == null, "deposit synchronizes weapon controller")
	check(not room.transfer(pistol, true), "repeated deposit cannot duplicate an item")
	var foreign := InventoryItem.new(ComponentInventory.PROTOTYPES, "armor")
	check(not room.transfer(foreign, false), "cannot withdraw an item absent from chest")
	check(room.transfer(pistol, false), "withdrawal goes into backpack")
	check(inventory.backpack.has_item(pistol), "withdraw does not auto-equip or replace weapons")
	check(pistol.get_property("instance_id") == id and pistol.get_property("quality") == 3 and pistol.get_property("heat") == 37.5, "instance id and custom properties survive transfer")
	check(room.transfer(pistol, true), "backpack item can be deposited")
	for index in 6:
		check(inventory.pickup("armor"), "fill all six bag cells")
	check(not room.transfer(pistol, false), "full bag rejects withdrawal")
	check(room.chest.get_item_count() == 1 and inventory.backpack.get_item_count() == 6, "full bag rejection leaves both inventories unchanged")
	# Force a real I/O failure, then verify both disk and runtime ownership roll back.
	var prior_profile: Dictionary = store.get_profile()
	store.save_path = "user://missing-warehouse-directory/profile.json"
	var armor := inventory.backpack.get_items()[0]
	check(not room.transfer(armor, true), "save failure cancels transfer")
	check(inventory.backpack.get_item_count() == 6 and room.chest.get_item_count() == 1, "save failure restores both inventories")
	check(store.get_profile() == prior_profile, "failed save leaves committed profile unchanged")
	store.save_path = TEST_PATH
	check(room.save_loadout(), "save recovers after writable path restored")
	await press_key(KEY_ESCAPE)
	check(not room.panel.is_open and not paused and player.is_input_enabled(), "Esc closes chest and restores world and player")
	# Read through a fresh service instance, as on the next application launch.
	var reloaded: Node = load("res://scripts/core/warehouse_store.gd").new()
	reloaded.save_path = TEST_PATH
	root.add_child(reloaded)
	check(reloaded.load_profile(), "fresh service reads saved JSON")
	check(reloaded.get_profile().chest.size() == 1, "chest contents persist across fresh load")
	check(reloaded.get_profile().chest[0].properties.heat.value == "37.5", "custom item state persists on disk")
	reloaded.queue_free()
	# Exercise the actual UI button through the engine's GUI event path.
	room.panel.open()
	await process_frame
	await process_frame
	var item_button: Button
	for button in room.panel.get("_bag_list").get_children():
		if button.text.begins_with("背包"):
			item_button = button
			break
	var point := item_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	check(room.chest.get_item_count() == 2 and inventory.backpack.get_item_count() == 5, "real GUI click deposits an item")
	await press_key(KEY_TAB)
	check(not paused and not room.panel.is_open, "Tab closes storage without opening backpack")
	# Reconstruct the complete warehouse, proving the saved equipped/bag state imports.
	check(main.get_node("SceneFlow").request_scene("res://scenes/levels/base/warehouse.tscn"), "request fresh warehouse scene")
	room = await wait_scene(main)
	player = room.player
	player.set_physics_process(false)
	check(room.chest.get_item_count() == 2 and player.inventory.backpack.get_item_count() == 5, "new warehouse restores chest and safe loadout without duplicates")
	check(player.inventory.equip(0), "warehouse supports existing defense equip flow")
	await process_frame
	await process_frame
	check(not store.get_profile().loadout.inventory.defense.is_empty(), "warehouse equipment changes automatically persist")
	check(player.inventory.unequip("defense"), "restore defense fixture into bag")
	await process_frame
	player.circuit_breaker.circuit_breaker_used = true
	player.talent_core.takeover_charges = 0
	check(room.depart(), "warehouse departure accepted")
	check(store.get_profile().loadout.inventory.backpack.get("items", []).is_empty() and store.get_profile().loadout.inventory.secondary.is_empty(), "only protected and bound items retain safe recovery copies")
	var battle := await wait_scene(main)
	check(not battle.is_in_group("warehouse") and get_nodes_in_group("enemies").size() > 0, "departure loads real combat floor")
	check(battle.scene_file_path == "res://scenes/levels/floors/combat_prototype.tscn", "departure enables the procedural combat floor")
	player = battle.get_node("Player")
	var rest := main.get_node("PersonaRestFlow") as PersonaRestFlow
	check(paused and rest.is_open, "persistent departure opens mandatory persona rest")
	await create_timer(0.3, true).timeout
	var fade := main.get_node("TransitionLayer/Fade") as ColorRect
	check(fade.modulate.a <= 0.01, "combat fade clears even when persona rest pauses the tree")
	check(rest.choose_persona(TalentCoreController.LEGENDARY_MASTER) and rest.close(), "warehouse flow consumes first-floor persona authorization")
	check(player.inventory.backpack.get_item_count() == 5, "departure preserves chosen backpack")
	check(not player.circuit_breaker.circuit_breaker_used and player.talent_core.takeover_charges == player.talent_core.takeover_charge_max, "new run refreshes per-run insurance and takeover resources")
	await preload("res://tests/integration/combat_test_flow.gd").clear_floor(self)
	var settlement: Node = main.get_node("ExtractionFlow")
	settlement.open_exit()
	settlement.extract()
	check(root.get_node("RunManager").run_finished and paused, "extraction commits safe loadout and pauses")
	check(not store.get_profile().loadout.is_empty(), "extracted gear is persisted before returning")
	settlement.return_to_warehouse()
	room = await wait_scene(main)
	check(room.is_in_group("warehouse") and not paused, "return to warehouse restores world")
	check(root.get_node("SoundManager").is_music_playing(LOBBY_MUSIC), "returning to the base restores lobby music")
	check(room.chest.get_item_count() == 2 and room.player.inventory.backpack.get_item_count() == 5, "extraction preserves both safe and returned equipment")
	await press_key(KEY_R)
	check(current_scene == main and room.is_inside_tree(), "debug restart is ignored in the warehouse")
	# Malformed save must remain recoverable, never silently overwritten.
	var corrupt_path := "user://warehouse-corrupt-test.json"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var corrupt: Node = load("res://scripts/core/warehouse_store.gd").new()
	corrupt.save_path = corrupt_path
	root.add_child(corrupt)
	check(not corrupt.load_profile() and not corrupt.commit([], {}), "corrupt profile blocks writes")
	check(FileAccess.get_file_as_string(corrupt_path) == "{broken", "corrupt original is preserved")
	corrupt.queue_free()
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PATH)
	DirAccess.remove_absolute(corrupt_path)
	print("Warehouse checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
