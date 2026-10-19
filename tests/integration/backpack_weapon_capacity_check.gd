extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	player.set_physics_process(false)
	var inv := player.inventory
	root.get_node("RunManager").set_mandatory_enemy_count(0)
	check(inv.backpack.get_item_count() == 0, "initial equipped weapon does not occupy backpack")
	check(inv.weapon_slot.get_item() != null, "initial service pistol remains equipped")
	check(inv.pickup("pistol"), "first weapon equips reserve")
	check(inv.backpack.get_item_count() == 0, "both equipped weapons are outside bag")
	var primary_id: String = inv.weapon_slot.get_item().get_property("instance_id")
	var reserve_id: String = inv.secondary_weapon_slot.get_item().get_property("instance_id")
	check(inv.pickup("wheel"), "pick mobility into bag")
	check(inv.equip(0), "equip mobility into independent slot")
	check(inv.backpack.get_item_count() == 0 and player.mobility.get_current_mode().id == &"wheel", "equipped mobility releases cell")
	for index in 6:
		check(inv.pickup("scattergun"), "six spare items fit alongside equipped loadout")
	check(inv.backpack.get_item_count() == 6, "six-cell bag capacity excludes equipment")
	check(not inv.pickup("baton"), "seventh spare item is rejected")
	check(not inv.unequip("weapon"), "full bag blocks primary unequip")
	check(not inv.unequip("weapon_secondary"), "full bag blocks reserve unequip")
	check(not inv.unequip("mobility"), "full bag blocks mobility unequip")
	check(inv.weapon_slot.get_item().get_property("instance_id") == primary_id, "failed unequip retains original weapon")
	check(inv.secondary_weapon_slot.get_item().get_property("instance_id") == reserve_id, "failed unequip retains reserve")
	check(inv.equip(0, 0), "full bag can exchange primary")
	check(inv.backpack.get_item_count() == 6, "exchange keeps six spare items")
	check(inv.backpack.get_items()[0].get_property("instance_id") == primary_id, "old primary returns without duplication")
	inv.backpack.remove_item(inv.backpack.get_items()[5])
	check(inv.unequip("weapon"), "free cell accepts unequipped weapon")
	check(inv.backpack.get_item_count() == 6 and inv.weapon_slot.get_item() == null, "unequipped weapon now uses cell")
	check(player.weapons.current_index == 1, "active selection falls back to reserve")
	inv.backpack.remove_item(inv.backpack.get_items()[5])
	check(inv.unequip("weapon_secondary"), "reserve can move back into free cell")
	check(player.weapons.get_current_weapon() == null, "empty weapon slots have no free fallback")
	check(not player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "empty loadout cannot attack")
	check(inv.equip(0, 0), "ordinary initial pistol can be equipped again")
	check(inv.backpack.get_item_count() == 5, "equipping into empty slot frees one cell")
	check(inv.unequip("mobility"), "free cell accepts mobility")
	check(inv.backpack.get_item_count() == 6 and player.mobility.get_current_mode().id == &"walk", "mobility unequip occupies cell and restores walking")
	var ids := {}
	var all_items := inv.backpack.get_items()
	for slot in [inv.weapon_slot, inv.secondary_weapon_slot, inv.mobility_slot]:
		if slot.get_item() != null:
			all_items.append(slot.get_item())
	for item in all_items:
		var id: String = item.get_property("instance_id")
		check(not ids.has(id), "no instance exists in two locations")
		ids[id] = true
	print("Backpack weapon capacity failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
