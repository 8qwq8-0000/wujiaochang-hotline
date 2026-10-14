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
		var inv := player.inventory
		root.get_node("RunManager").set_mandatory_enemy_count(1)
		check(not inv.can_change_equipment(), "manual battle equipment remains locked")
		if scenario == 2:
			var old := InventoryItem.new(ComponentInventory.PROTOTYPES, "baton")
			inv.secondary_weapon_slot.equip(old)
			check(inv.pickup("pistol"), "occupied reserve sends first weapon into bag")
			check(inv.secondary_weapon_slot.get_item() == old and inv.backpack.get_item_count() == 1, "existing reserve is not replaced")
			inv.secondary_weapon_slot.clear()
			check(inv.pickup("scattergun"), "later weapon enters bag")
			check(inv.secondary_weapon_slot.get_item() == null, "automatic exception triggers only once")
		else:
			if scenario == 1:
				for index in 6:
					check(inv.pickup("wheel"), "fill six spare cells")
			var count := inv.backpack.get_item_count()
			var active := player.weapons.current_index
			var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
			pickup.component_id = "pistol"
			scene.add_child(pickup)
			pickup.global_position = player.global_position
			check(pickup.try_pickup(inv), "first weapon can directly fill free reserve even with full bag")
			check(pickup.is_queued_for_deletion(), "successful pickup removes world item")
			check(not pickup.try_pickup(inv), "same pickup cannot be duplicated")
			check(inv.backpack.get_item_count() == count, "equipped reserve consumes no cell")
			check(player.weapons.current_index == active, "automatic equip preserves active weapon")
			player.weapons.cycle_weapon(1)
			check(player.weapons.get_current_weapon().id == &"service_pistol", "reserve is immediately usable")
			if scenario == 0:
				check(inv.pickup("scattergun") and inv.backpack.get_item_count() == 1, "later weapon occupies spare cell")
				check(not inv.equip(0, 1), "manual replacement is still locked")
			else:
				check(not inv.pickup("scattergun"), "later weapon cannot bypass full bag")
		scene.queue_free()
		await process_frame
		await process_frame
	print("First weapon pickup failures: ", failures)
	quit(0 if failures == 0 else 1)
