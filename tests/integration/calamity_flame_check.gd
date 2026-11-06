extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func run_checks() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group(&"player") as PlayerController
	var inventory := player.inventory
	player.talent_core.consume_persona_drink(TalentCoreController.DEEP_NINJA)
	await process_frame
	check(inventory.backpack.get_item_count() == 0, "ninja drink does not grant the retired weapon")
	check(int(player.cyberware.circuit.get_library_counts().get(&"calamity_flame", 0)) == 0, "ninja drink does not grant the new module")
	check(inventory.pickup("calamity_flame"), "normal calamity drop can be picked up")
	check(int(player.cyberware.circuit.get_library_counts().get(&"calamity_flame", 0)) == 1, "calamity drop enters independent circuit library")
	check(inventory.backpack.get_item_count() == 0, "calamity module does not occupy backpack")
	var old_item := ComponentRolls.make_item("calamity_flame")
	check(inventory.backpack.add_item(old_item), "legacy weapon snapshot fixture stores an old item")
	var snapshot := inventory.export_run_state()
	var equipped_snapshot := snapshot.duplicate(true)
	equipped_snapshot.backpack["items"] = []
	equipped_snapshot.primary = {"item": old_item.serialize()}
	scene.queue_free()
	await process_frame
	await process_frame
	var restored_scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(restored_scene)
	current_scene = restored_scene
	await process_frame
	var restored := get_first_node_in_group(&"player") as PlayerController
	restored.inventory.import_run_state(snapshot)
	check(int(restored.cyberware.circuit.get_library_counts().get(&"calamity_flame", 0)) == 1, "legacy owned weapon migrates into one circuit module")
	check(restored.inventory.backpack.get_item_count() == 0, "migrated weapon is removed from old backpack")
	restored_scene.queue_free()
	await process_frame
	await process_frame
	var equipped_scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(equipped_scene)
	current_scene = equipped_scene
	await process_frame
	var equipped_player := get_first_node_in_group(&"player") as PlayerController
	equipped_player.inventory.import_run_state(equipped_snapshot)
	check(int(equipped_player.cyberware.circuit.get_library_counts().get(&"calamity_flame", 0)) == 1, "legacy equipped calamity weapon migrates into the circuit")
	check(equipped_player.inventory.weapon_slot.get_item() == null, "migrated calamity weapon leaves the old weapon slot")
	print("Calamity flame failures: ", failures)
	quit(0 if failures == 0 else 1)
