extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	await _check_backpack_grant_and_run_lock()
	await _check_full_backpack_world_drop()
	print("Calamity flame failures: ", failures)
	quit(0 if failures == 0 else 1)


func _check_backpack_grant_and_run_lock() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group(&"player") as PlayerController
	var inventory := player.inventory
	check(inventory.backpack.get_item_count() == 0, "special weapon is not granted before ninja becomes active")
	player.talent_core.consume_persona_drink(TalentCoreController.DEEP_NINJA)
	await process_frame
	check(inventory.backpack.get_item_count() == 1, "first ninja activation grants one calamity flame into backpack")
	var weapon := inventory.backpack.get_items()[0] as InventoryItem
	check(weapon.get_prototype().get_prototype_id() == "calamity_flame", "granted item uses calamity flame prototype")
	check(bool(weapon.get_property("bound", false)), "granted calamity flame remains persona-bound")
	check(inventory.secondary_weapon_slot.get_item() == null, "persona grant never auto-equips the secondary slot")
	var flame_data := load("res://resources/weapons/calamity_flame.tres") as WeaponComponentData
	var mount := player.get_node("VisualRoot/WeaponPivot") as WeaponMount
	mount.set_weapon(flame_data)
	await process_frame
	var flame_view := mount.current_view as CalamityFlameWeaponView
	flame_view.play_attack()
	flame_view._process(0.04)
	check(flame_view.get_live_particle_count() >= 8, "calamity swing emits a dense red particle trail even in reduced feedback mode")
	var extraction_contains_flame := false
	for entry in inventory.get_extraction_items():
		if str(entry.get("item", {}).get("prototype_id", "")) == "calamity_flame":
			extraction_contains_flame = true
	check(not extraction_contains_flame, "bound persona weapon is excluded from warehouse extraction")
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.set_persona(TalentCoreController.DEEP_NINJA)
	await process_frame
	check(inventory.backpack.get_item_count() == 1, "switching back to ninja does not duplicate the run grant")
	var snapshot := inventory.export_run_state()
	check(bool(snapshot.get("calamity_flame_granted", false)), "run snapshot persists the one-time grant marker")
	scene.queue_free()
	await process_frame
	await process_frame


func _check_full_backpack_world_drop() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group(&"player") as PlayerController
	var inventory := player.inventory
	for index in ComponentInventory.CAPACITY:
		check(inventory.pickup("armor"), "fill backpack cell %d before persona grant" % index)
	player.talent_core.consume_persona_drink(TalentCoreController.DEEP_NINJA)
	await process_frame
	var drops: Array[Node] = []
	for node in get_nodes_in_group(&"component_pickups"):
		if node is ComponentPickup and node.component_id == "calamity_flame":
			drops.append(node)
	check(drops.size() == 1, "full backpack creates exactly one calamity flame ground pickup")
	if not drops.is_empty():
		var drop := drops[0] as ComponentPickup
		check(drop.rolled_item.get_texture() == load("res://assets/art/weapons/placeholder/placeholder_arm_lock_baton_unpainted.png"), "ground pickup uses the reused melee weapon texture")
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.set_persona(TalentCoreController.DEEP_NINJA)
	await process_frame
	var after_switch := 0
	for node in get_nodes_in_group(&"component_pickups"):
		if node is ComponentPickup and node.component_id == "calamity_flame":
			after_switch += 1
	check(after_switch == 1, "ground grant still consumes the once-per-run allowance")
	scene.queue_free()
	await process_frame
