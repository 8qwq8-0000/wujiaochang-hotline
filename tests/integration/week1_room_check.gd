extends SceneTree
var failures := 0
const ROOM := "res://scenes/levels/week1_combat_room.tscn"
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func wait_room(previous: Node = null) -> PlayerController:
	for frame in 600:
		var player := get_first_node_in_group("player") as PlayerController
		var loading := false
		if current_scene != null and current_scene.has_node("SceneFlow"):
			loading = current_scene.get_node("SceneFlow").get("_is_loading")
		if current_scene != null and current_scene != previous and player != null and not loading:
			player.set_physics_process(false)
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(false)
			return player
		await process_frame
	check(false, "week1 room load timeout")
	return null
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = code
	Input.parse_input_event(release)
func run() -> void:
	if not ResourceLoader.exists(ROOM):
		print("SKIP: PR #2 room is not merged; apply the integration patch after it becomes available")
		quit()
		return
	for standalone in [true, false]:
		var scene: Node
		if standalone:
			scene = load(ROOM).instantiate()
		else:
			scene = load("res://scenes/bootstrap/main.tscn").instantiate()
			scene.get_node("SceneFlow").initial_scene = ROOM
		root.add_child(scene)
		current_scene = scene
		var player := await wait_room()
		if player == null:
			quit(1)
			return
		var actual_count := get_nodes_in_group("enemies").size()
		check(root.get_node("RunManager").mandatory_enemies_remaining == actual_count, "count uses actual enemies")
		var inventory := player.get_node("ComponentInventory") as ComponentInventory
		var component := get_first_node_in_group("component_pickups") as ComponentPickup
		check(component != null, "placeholder is a real pickup")
		if component != null:
			player.global_position = component.global_position
			await physics_frame
			await process_frame
			key(KEY_E)
			await process_frame
		check(inventory.backpack.get_item_count() == 1, "E adds component to backpack")
		for enemy in get_nodes_in_group("enemies"):
			enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
		await process_frame
		await process_frame
		check(root.get_node("RunManager").mandatory_enemies_remaining == 0, "room clear updates objective")
		check(get_nodes_in_group("component_pickups").size() == actual_count, "one drop per enemy in teammate room")
		check(inventory.equip(0), "can equip after teammate room clears")
		key(KEY_R)
		player = await wait_room(scene)
		check(player != null, "standalone and Main support restart")
		if player != null:
			inventory = player.get_node("ComponentInventory") as ComponentInventory
			check(inventory.backpack.get_item_count() == 0, "restart clears teammate-room inventory")
		current_scene.queue_free()
		await process_frame
		print("Week1 room mode complete: ", "F6" if standalone else "Main")
	print("Week1 room integration failures: ", failures)
	quit(0 if failures == 0 else 1)
