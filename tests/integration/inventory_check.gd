extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func run() -> void:
	var scene := load("res://scenes/bootstrap/main.tscn").instantiate() as Node
	root.add_child(scene)
	current_scene = scene
	var player: PlayerController
	for frame in 600:
		player = get_first_node_in_group("player") as PlayerController
		if player != null and root.get_node("RunManager").mandatory_enemies_remaining > 0 and not scene.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	if player == null:
		check(false, "player failed to load")
		quit(1)
		return
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var inventory := player.get_node("ComponentInventory") as ComponentInventory
	check(inventory.backpack.get_item_count() == 0, "backpack starts empty")
	check(inventory.pickup("pistol"), "pickup pistol")
	check(not inventory.equip(0), "cannot equip during combat")
	for enemy in get_nodes_in_group("enemies"):
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	await process_frame
	check(inventory.can_change_equipment(), "cleared floor allows equipment")
	check(inventory.equip(0), "equip pistol")
	check(player.weapons.get_current_weapon().attack_kind == WeaponComponentData.AttackKind.PROJECTILE, "equipped pistol changes attacks")
	var equipped_id := str(inventory.weapon_slot.get_item().get_property("instance_id"))
	for index in 6:
		check(inventory.pickup("wheel" if index == 0 else "baton"), "fill backpack")
	check(not inventory.pickup("pistol"), "seventh pickup is rejected")
	check(not inventory.unequip("weapon"), "cannot unequip into full backpack")
	check(inventory.equip(1), "swap weapon with full backpack")
	check(inventory.backpack.get_item_count() == 6, "full swap keeps six items")
	check(player.weapons.get_current_weapon().attack_kind == WeaponComponentData.AttackKind.MELEE, "baton changes attacks")
	var returned := false
	var identifiers := {}
	for item in inventory.backpack.get_items():
		var instance_id := str(item.get_property("instance_id"))
		returned = returned or instance_id == equipped_id
		check(not identifiers.has(instance_id), "each item has a unique instance")
		identifiers[instance_id] = true
	check(returned, "old equipped item returns to backpack")
	check(inventory.equip(0), "equip mobility")
	check(player.mobility.get_current_mode().id == &"wheel", "wheel changes mobility")
	check(inventory.unequip("mobility"), "unequip mobility")
	check(player.mobility.get_current_mode().id == &"walk", "unequip restores walk")
	var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
	scene.add_child(pickup)
	pickup.global_position = player.global_position
	check(not pickup.try_pickup(inventory), "full backpack leaves world pickup")
	check(not pickup.is_queued_for_deletion(), "failed pickup remains")
	inventory.backpack.remove_item(inventory.backpack.get_items()[0])
	check(pickup.try_pickup(inventory), "world pickup succeeds with space")
	check(not pickup.try_pickup(inventory), "same world pickup cannot be collected twice")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	check(inventory.is_open, "Tab opens backpack")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not inventory.is_open, "Esc closes backpack")
	player.health.apply_damage(player.health.max_health, DamagePacket.new())
	check(not inventory.pickup("pistol"), "dead player cannot pick up")
	check(not inventory.equip(0), "dead player cannot change equipment")
	print("Inventory integration failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
