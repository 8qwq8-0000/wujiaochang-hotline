extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var scene: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in 600:
		if get_first_node_in_group("player") != null and get_nodes_in_group("enemies").size() == 3 and not scene.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var inv := player.get_node("ComponentInventory") as ComponentInventory
	check(inv.backpack.get_item_count() == 1, "initial weapon is the only starting inventory item")
	check(get_nodes_in_group("component_pickups").is_empty(), "no free starting world components")
	check(inv.weapon_slot.get_item() == inv.backpack.get_items()[0], "primary references the initial backpack item")
	check(inv.pickup("pistol"), "first pickup succeeds")
	check(inv.backpack.get_item_count() == 2, "primary and reserve consume two cells")
	check(inv.secondary_weapon_slot.get_item().get_inventory() == inv.backpack, "reserve is owned by backpack")
	for enemy in get_nodes_in_group("enemies"):
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	await process_frame
	inv.pickup("scattergun")
	check(inv.equip(2, 0), "select third weapon into primary")
	check(inv.backpack.get_item_count() == 3, "equipping does not free a cell")
	check(inv.equip(1, 0), "move reserve into primary")
	check(inv.weapon_slot.get_item() != inv.secondary_weapon_slot.get_item(), "same item never occupies both positions")
	check(str(inv.secondary_weapon_slot.get_item().get_property("effect")).ends_with("scattergun.tres"), "previous primary moves to reserve")
	for index in 3:
		inv.pickup("wheel")
	check(inv.backpack.get_item_count() == 6, "equipped weapons are included in full capacity")
	check(not inv.pickup("baton"), "seventh item is rejected")
	check(inv.unequip("weapon"), "full bag can deselect primary")
	check(inv.backpack.get_item_count() == 6, "deselecting does not free capacity")
	var active := inv.secondary_weapon_slot.get_item()
	inv.backpack.remove_item(active)
	check(inv.secondary_weapon_slot.get_item() == null, "removing a backpack item clears its equipment reference")
	check(player.weapons.get_current_weapon() == null, "empty slots do not generate a free fallback weapon")
	check(not player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "no equipped weapon cannot attack")
	check(inv.equip(0, 0), "initial weapon can be selected again from its existing cell")
	var identifiers := {}
	for item in inv.backpack.get_items():
		var id: String = item.get_property("instance_id")
		check(not identifiers.has(id), "physical items are not duplicated")
		identifiers[id] = true
	print("Backpack weapon capacity failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
