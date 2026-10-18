extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func press_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	Input.parse_input_event(release)
func wait_battle(previous: Node = null) -> PlayerController:
	for frame in 600:
		var player := get_first_node_in_group("player") as PlayerController
		if current_scene != null and current_scene != previous and player != null and get_nodes_in_group("enemies").size() == 3 and not current_scene.get_node("SceneFlow").get("_is_loading"):
			player.set_physics_process(false)
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(false)
			return player
		await process_frame
	check(false, "battle load timeout")
	return null
func defeat_all_enemies() -> void:
	await preload("res://tests/integration/combat_test_flow.gd").clear_floor(self)

func run() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for cycle in 3:
		var player := await wait_battle()
		if player == null:
			quit(1)
			return
		var inventory := player.get_node("ComponentInventory") as ComponentInventory
		check(inventory.backpack.get_item_count() == 0 and inventory.weapon_slot.get_item() != null and inventory.secondary_weapon_slot.get_item() == null, "fresh run has no stale inventory")
		check(get_nodes_in_group("component_pickups").is_empty(), "no free starter pickups")
		(current_scene.find_child("FloorAssembler", true, false) as FloorAssembler).enemy_drop_chance = 0.0
		# Isolate the first-area fallback while preserving three restart cycles.
		for enemy in get_nodes_in_group("enemies"):
			enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
		for enemy in get_nodes_in_group("enemies"):
			if enemy.state == EnemyController.State.SELF_DESTRUCT:
				enemy._physics_process(enemy.profile.self_destruct_delay + 0.01)
		await process_frame
		await process_frame
		var drop := get_first_node_in_group("component_pickups") as ComponentPickup
		check(drop != null, "first clear supplies floor guarantee")
		if drop == null:
			quit(1)
			return
		player.global_position = drop.global_position
		await physics_frame
		await process_frame
		press_key(KEY_E)
		await process_frame
		check(not is_instance_valid(drop) or drop.is_queued_for_deletion(), "E collects the rolled floor guarantee")
		# Continue the existing UI and combat-lock regression with a known weapon.
		inventory.backpack.clear()
		inventory.secondary_weapon_slot.clear()
		inventory._has_picked_up_weapon = false
		inventory.pickup("pistol")
		check(inventory.pickup("pistol"), "later weapon enters backpack")
		press_key(KEY_TAB)
		await process_frame
		check(inventory.is_open, "Tab opens actual panel")
		player.global_position = Vector2(754, 180)
		await physics_frame
		await physics_frame
		inventory.panel.get("_buttons")[0].pressed.emit()
		check(str(inventory.weapon_slot.get_item().get_property("effect")).ends_with("/baton.tres"), "panel blocks combat equipment change")
		press_key(KEY_TAB)
		await defeat_all_enemies()
		await process_frame
		await process_frame
		check(root.get_node("RunManager").mandatory_enemies_remaining == 0, "floor is cleared")
		check(get_nodes_in_group("component_pickups").size() == 1, "second area supplies its own guarantee after first-area loot was collected")
		check(get_first_node_in_group("component_pickups").get_parent().area_index == 1, "final clear loot belongs to second area rather than repeating first-area guarantee")
		press_key(KEY_TAB)
		await process_frame
		inventory.panel.get("_buttons")[0].pressed.emit()
		check(player.weapons.get_current_weapon().id == &"service_pistol", "panel equipment changes weapon")
		# Exercise the second cell's captured index and a real mobility component.
		inventory.pickup("wheel")
		inventory.pickup("baton")
		inventory.panel.get("_buttons")[2].pressed.emit()
		check(player.weapons.get_current_weapon().id == &"baton", "second cell equips the selected item")
		inventory.panel.get("_buttons")[1].pressed.emit()
		check(player.mobility.get_current_mode().id == &"wheel", "first cell equips wheel independently")
		press_key(KEY_ESCAPE)
		await process_frame
		check(not inventory.is_open, "Esc closes panel")
		var old := current_scene
		press_key(KEY_R)
		player = await wait_battle(old)
		check(player != null and not is_instance_valid(old), "R restarts full playthrough")
		print("Full playthrough cycle ", cycle + 1, " complete")
	print("Full playthrough failures: ", failures)
	current_scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
