extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	for scenario in 3:
		var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		await process_frame
		var player := get_first_node_in_group("player") as PlayerController
		player.set_physics_process(false)
		var inventory := player.get_node("ComponentInventory") as ComponentInventory
		root.get_node("RunManager").set_mandatory_enemy_count(1)
		check(not inventory.can_change_equipment(), "battle is locked for manual equipment")
		if scenario == 1:
			for index in 5:
				check(inventory.pickup("wheel"), "fill bag without consuming weapon exception")
		if scenario == 2:
			# A future starting loadout can already occupy reserve; never replace it.
			var old := inventory.backpack.create_item("baton")
			inventory.backpack.add_item(old)
			inventory.secondary_weapon_slot.equip(old)
			check(inventory.pickup("pistol"), "first weapon enters bag when reserve is occupied")
			check(inventory.secondary_weapon_slot.get_item() == old, "occupied reserve is not replaced")
			inventory.secondary_weapon_slot.clear()
			check(inventory.pickup("scattergun"), "later pickup succeeds")
			check(inventory.secondary_weapon_slot.get_item() == null, "exception is only the first successful weapon pickup")
		else:
			var count := inventory.backpack.get_item_count()
			var active := player.weapons.current_index
			var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
			pickup.component_id = "pistol"
			scene.add_child(pickup)
			pickup.global_position = player.global_position
			if scenario == 1:
				check(not pickup.try_pickup(inventory), "full bag rejects even first weapon")
				check(not pickup.is_queued_for_deletion(), "full bag leaves weapon on ground")
				check(inventory.secondary_weapon_slot.get_item() == null, "failed pickup cannot equip reserve")
				inventory.backpack.remove_item(inventory.backpack.get_items()[5])
				count -= 1
			check(pickup.try_pickup(inventory), "first world weapon auto-equips during combat")
			check(pickup.is_queued_for_deletion(), "successful pickup removes world item")
			check(not pickup.try_pickup(inventory), "same world weapon cannot duplicate")
			check(inventory.secondary_weapon_slot.get_item() != null, "reserve is equipped")
			check(inventory.backpack.get_item_count() == count + 1, "equipped reserve occupies a backpack cell")
			check(player.weapons.current_index == active, "auto-equip does not force active weapon switch")
			player.weapons.cycle_weapon(1)
			check(player.weapons.get_current_weapon().id == &"service_pistol", "reserve weapon is immediately usable")
			if scenario == 0:
				check(inventory.pickup("scattergun"), "second weapon enters backpack")
				check(inventory.backpack.get_item_count() == 3, "initial, reserve and later weapon all use backpack")
				check(not inventory.equip(0, 1), "manual replacement still requires clear")
			else:
				check(not inventory.pickup("scattergun"), "later weapon obeys full backpack limit")
		scene.queue_free()
		await process_frame
		await process_frame
	print("First weapon pickup failures: ", failures)
	quit(0 if failures == 0 else 1)
