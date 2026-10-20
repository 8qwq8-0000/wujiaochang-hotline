extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	var dropped: InventoryItem
	for index in 256:
		var item := ComponentRolls.floor_drop(1, rng)
		if item.get_prototype().get_prototype_id() == "rail_cannon":
			dropped = item
			break
	check(dropped != null, "normal floor loot can roll the rail cannon")
	if dropped == null:
		quit(1)
		return
	check(ComponentRolls.ordinary(dropped) and not ComponentRolls.affixes(dropped).is_empty(), "rail cannon receives normal quality and affixes")
	var restored := InventoryItem.new()
	check(restored.deserialize(dropped.serialize()), "rail cannon survives item serialization")
	check(ComponentRolls.weapon(restored).id == &"rail_cannon", "restored item resolves the runtime weapon")
	var room: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	player.set_physics_process(false)
	var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
	pickup.component_id = "rail_cannon"
	pickup.rolled_item = dropped
	room.add_child(pickup)
	pickup.global_position = player.global_position
	check(pickup.try_pickup(player.inventory), "world drop is picked up into the free secondary slot")
	check(not pickup.try_pickup(player.inventory), "same world drop cannot be collected twice")
	player.weapons.cycle_weapon(1)
	var weapon := player.weapons.get_current_weapon()
	check(weapon != null and weapon.id == &"rail_cannon", "picked-up cannon equips and switches normally")
	check(player.visuals.weapon_pivot.current_view.muzzle_flash != null, "equipped weapon has its beam visual")
	player.heat.current_heat = 0
	player.weapons.reset_transient_state()
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "equipped cannon fires")
	var beams := get_nodes_in_group("laser_beams")
	check(beams.size() == 1 and beams[0].get("beam_width") == weapon.beam_width, "shot creates a full-width laser instead of a bullet")
	check(player.heat.current_heat == weapon.heat_per_attack, "cannon consumes its configured heat")
	room.queue_free()
	await process_frame
	print("Rail cannon loot checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
