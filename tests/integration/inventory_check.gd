extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func run() -> void:
	var scene: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player: PlayerController
	for frame in 600:
		player = get_first_node_in_group("player") as PlayerController
		if player != null and root.get_node("RunManager").mandatory_enemies_remaining > 0 and not scene.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var inv := player.inventory
	check(inv.backpack.get_item_count() == 0, "new run has no free bag items")
	check(inv.pickup("pistol") and inv.secondary_weapon_slot.get_item() != null, "first weapon fills reserve")
	check(inv.pickup("scattergun"), "later weapon enters bag")
	check(not inv.equip(0), "combat blocks manual equipment")
	check(not inv.unequip("weapon_secondary"), "combat blocks unequip")
	for enemy in get_nodes_in_group("enemies"):
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	await process_frame
	check(inv.can_change_equipment(), "clearing enables manual equipment")
	inv.set_open(true)
	inv.panel.get("_buttons")[0].pressed.emit()
	check(player.weapons.get_current_weapon().id == &"scattergun", "actual panel exchanges primary weapon")
	check(inv.backpack.get_item_count() == 1, "replaced initial weapon returns to bag")
	inv.set_open(false)
	for index in 5:
		check(inv.pickup("baton"), "fill spare capacity")
	check(inv.backpack.get_item_count() == 6, "full bag contains six spare items")
	var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
	scene.add_child(pickup)
	pickup.global_position = player.global_position
	check(not pickup.try_pickup(inv), "full bag leaves later world weapon untouched")
	check(not pickup.is_queued_for_deletion(), "failed pickup remains on ground")
	inv.backpack.remove_item(inv.backpack.get_items()[5])
	check(pickup.try_pickup(inv), "free cell permits world pickup")
	check(not pickup.try_pickup(inv), "same pickup cannot be collected twice")
	check(inv.backpack.get_item_count() == 6, "later pickup occupies freed cell")
	player.circuit_breaker.set_equipped(false)
	player.health.apply_damage(player.health.max_health, DamagePacket.new())
	check(not inv.can_change_equipment(), "dead player cannot change equipment")
	check(not inv.pickup("baton"), "dead player cannot pick up")
	print("Inventory integration failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
