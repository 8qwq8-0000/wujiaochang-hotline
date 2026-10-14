extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	var inventory := player.inventory
	root.get_node("RunManager").set_mandatory_enemy_count(0)
	check(inventory.pickup("pistol"), "reserve weapon is available")
	check(inventory.unequip("weapon"), "primary moves into backpack")
	check(inventory.unequip("weapon_secondary"), "secondary moves into backpack")
	check(inventory.weapon_slot.get_item() == null, "primary slot starts empty")
	check(inventory.secondary_weapon_slot.get_item() == null, "secondary slot starts empty")

	inventory.set_open(true)
	var panel := inventory.panel
	var target := panel.get("_weapon_target") as OptionButton
	var buttons: Array = panel.get("_buttons")
	check(target.selected == 0, "empty loadout starts with primary target")
	buttons[0].pressed.emit()
	check(inventory.weapon_slot.get_item() != null, "first weapon fills primary")
	check(inventory.secondary_weapon_slot.get_item() == null, "reserve remains empty after first equip")
	check(target.selected == 1, "target advances to the empty reserve slot")
	buttons[0].pressed.emit()
	check(inventory.weapon_slot.get_item() != null, "second equip preserves primary")
	check(inventory.secondary_weapon_slot.get_item() != null, "second weapon fills reserve")
	check(inventory.backpack.get_item_count() == 0, "both equipped weapons leave the backpack")
	var primary := inventory.weapon_slot.get_item()
	var secondary := inventory.secondary_weapon_slot.get_item()
	if primary != null and secondary != null:
		check(
			primary.get_property("instance_id") != secondary.get_property("instance_id"),
			"weapon instances remain distinct"
		)
	target.select(0)
	panel.refresh()
	check(target.selected == 0, "full loadout preserves the manually selected target slot")

	inventory.set_open(false)
	scene.queue_free()
	await process_frame
	print("Weapon slot refill failures: ", failures)
	quit(0 if failures == 0 else 1)
