extends SceneTree

var failures := 0
var checks := 0
const TEST_PATH := "user://loot_synthesis_loop_test.json"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 3:
		await physics_frame
	await process_frame

func wait_room(main: Node) -> Node:
	for frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			var room := container.get_child(0)
			var player := get_first_node_in_group("player") as PlayerController
			if player != null:
				player.set_physics_process(false)
				return room
	check(false, "scene load completes")
	return null

func pair_seed() -> int:
	# Select a reproducible test seed yielding compatible guarantees on floors 1/2.
	# Production still uses its ordinary run seed and authored quality weights.
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 1000):
		rng.seed = seed_value + 7919
		var a := ComponentRolls.floor_drop(1, rng)
		rng.seed = seed_value + 15838
		var b := ComponentRolls.floor_drop(2, rng)
		if ComponentRolls.compatible(a, b):
			return seed_value
	return 0

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	var warehouse := await wait_room(main)
	var starting_id: String = warehouse.player.inventory.weapon_slot.get_item().get_property("instance_id")
	check(warehouse.depart(), "warehouse action enters formal run")
	root.get_node("RunManager").run_seed = pair_seed()
	var collected: Array[Dictionary] = []
	var ui: Node = main.get_node("ExtractionFlow")
	for floor_number in 2:
		await wait_room(main)
		var player := get_first_node_in_group("player") as PlayerController
		(main.find_child("FloorAssembler", true, false) as FloorAssembler).enemy_drop_chance = 0.0
		player.health.configure_max_health(1000)
		await preload("res://tests/integration/combat_test_flow.gd").clear_floor(self)
		check(get_nodes_in_group("component_pickups").size() == 2, "each completed floor has one physical guarantee per area")
		var pickup := get_first_node_in_group("component_pickups") as ComponentPickup
		var rolled := pickup.rolled_item
		var data := rolled.serialize()
		player.global_position = pickup.global_position
		await settle()
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_E
			event.physical_keycode = KEY_E
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame
		await settle()
		check(get_nodes_in_group("component_pickups").size() == 1 and player.inventory.item_location(rolled) != "", "real E input collects same rolled instance while other area loot remains")
		check(get_first_node_in_group("component_pickups").get_parent().area_index == 1, "second-area guarantee remains independent and is not auto-collected")
		if player.inventory.backpack.has_item(rolled):
			check(player.inventory.equip(player.inventory.backpack.get_item_index(rolled)), "collected guarantee equips after local clear")
		check(rolled.serialize() == data, "equipping never changes rolled quality affixes or ID")
		collected.append(data)
		var assembler := main.find_child("FloorAssembler", true, false) as FloorAssembler
		player.global_position = assembler.generated_rooms.back().exit_elevator.global_position
		await settle()
		check(ui.get("_overlay").visible and not paused, "real final Area2D entry opens extraction choice")
		if floor_number == 0:
			ui.continue_floor()
		else:
			ui.extract()
			check(paused and root.get_node("RunManager").run_finished, "extraction saves full loadout before return")
			ui.return_to_warehouse()
	warehouse = await wait_room(main)
	var inv: ComponentInventory = warehouse.player.inventory
	for item in inv.backpack.get_items() + [inv.weapon_slot.get_item(), inv.secondary_weapon_slot.get_item(), inv.mobility_slot.get_item(), inv.defense_slot.get_item()]:
		if ComponentRolls.ordinary(item):
			check(warehouse.transfer(item, true), "extracted rolled gear deposits into chest")
	check(warehouse.chest.get_item_count() == 3, "two collected guarantees plus ordinary starting baton arrive without duplication")
	if warehouse.chest.get_item_count() != 3:
		quit(1)
		return
	var materials := []
	for item in warehouse.chest.get_items():
		if item.get_property("instance_id") != starting_id:
			check(item.serialize() in collected, "warehouse retains exact floor instance data")
			materials.append(item)
	check(materials.size() == 2, "starting ordinary baton is kept separate from the two collected upgrade materials")
	var subject: InventoryItem = materials[0]
	var subject_id: String = subject.get_prototype().get_prototype_id()
	var next_tier := mini(ComponentRolls.quality(subject) + 1, 3)
	check(warehouse.synthesize(subject, materials[1]), "two actually looted guarantees synthesize")
	var result: InventoryItem = warehouse.chest.get_items().back()
	check(warehouse.chest.get_item_count() == 2 and ComponentRolls.quality(result) == next_tier and result.get_prototype().get_prototype_id() == subject_id, "complete loot pickup loadout extraction warehouse synthesis loop")
	main.queue_free()
	await settle()
	DirAccess.remove_absolute(TEST_PATH)
	print("Loot synthesis loop checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
