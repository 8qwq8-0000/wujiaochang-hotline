extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func press(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	Input.parse_input_event(release)
func run() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	player.set_physics_process(false)
	player.weapons.set_physics_process(false)
	player.heat.set_physics_process(false)
	var inventory := player.get_node("ComponentInventory") as ComponentInventory
	press(KEY_Q)
	await process_frame
	check(player.weapons.current_index == 0, "empty reserve is skipped")
	check(inventory.pickup("baton"), "first weapon equips reserve")
	check(inventory.pickup("pistol"), "pickup reserve replacement")
	inventory.set_open(true)
	inventory.panel.get("_weapon_target").select(1)
	inventory.panel.get("_buttons")[0].pressed.emit()
	check(inventory.secondary_weapon_slot.get_item() != null, "UI equips reserve slot")
	check(inventory.weapon_slot.get_item() != null, "primary initial weapon is preserved")
	check(player.weapons.get_current_weapon().id == &"service_pistol", "new reserve is selected")
	press(KEY_Q)
	await process_frame
	check(player.weapons.current_index == 1, "paused inventory blocks weapon cycling")
	inventory.set_open(false)
	check(inventory.backpack.get_item_count() == 1, "only unequipped replacement remains in bag")
	inventory.backpack.remove_item(inventory.backpack.get_items()[0])
	root.get_node("RunManager").set_mandatory_enemy_count(1)
	player.weapons.set("_cooldown_remaining", 0.8)
	player.heat.current_heat = 30
	press(KEY_Q)
	await process_frame
	check(player.weapons.current_index == 0, "Q switches weapons during combat")
	check(player.weapons.get("_cooldown_remaining") == 0.8 and player.heat.current_heat == 30, "switch preserves heat and attack cooldown")
	press(KEY_Q, true)
	await process_frame
	check(player.weapons.current_index == 0, "held-key repeat does not switch repeatedly")
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll.pressed = true
	Input.parse_input_event(scroll)
	await process_frame
	check(player.weapons.current_index == 1, "scroll switches to carried reserve")
	check(inventory.pickup("scattergun"), "pickup new weapon")
	check(not inventory.equip(0, 1), "combat blocks replacing carried weapons")
	check(not inventory.unequip("weapon_secondary"), "combat blocks unequipping reserve")
	root.get_node("RunManager").set_mandatory_enemy_count(0)
	for index in 5:
		inventory.pickup("baton")
	check(inventory.backpack.get_item_count() == 6, "fill backpack")
	var old_id: String = inventory.secondary_weapon_slot.get_item().get_property("instance_id")
	check(inventory.equip(0, 1), "full backpack swaps reserve safely")
	check(inventory.backpack.get_item_count() == 6, "swap retains capacity")
	var returned := false
	for item in inventory.backpack.get_items():
		returned = returned or item.get_property("instance_id") == old_id
	check(returned, "replaced reserve returns to backpack")
	check(not inventory.unequip("weapon_secondary"), "full bag blocks reserve unequip")
	inventory.backpack.remove_item(inventory.backpack.get_items()[5])
	check(inventory.unequip("weapon_secondary"), "free cell accepts reserve")
	check(player.weapons.current_index == 0, "removing active reserve falls back to primary")
	press(KEY_Q)
	await process_frame
	check(player.weapons.current_index == 0, "cycling still skips empty reserve")
	player.core.equip_core(&"", false)
	player.health.apply_damage(player.health.max_health, DamagePacket.new())
	press(KEY_Q)
	await process_frame
	check(player.weapons.current_index == 0, "dead player cannot switch")
	print("Two-weapon switch failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
