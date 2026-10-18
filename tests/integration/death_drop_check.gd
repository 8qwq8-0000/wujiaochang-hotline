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

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func kill(enemy: EnemyController) -> void:
	enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	if enemy.state == EnemyController.State.SELF_DESTRUCT:
		enemy._physics_process(enemy.profile.self_destruct_delay + 0.01)

func run() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		if get_nodes_in_group("enemies").size() == 3 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	var player := get_first_node_in_group("player") as PlayerController
	player.set_physics_process(false)
	player.health.configure_max_health(1000)
	var assembler := main.find_child("FloorAssembler", true, false) as FloorAssembler
	var first: CombatRoom = assembler.generated_rooms[0]
	var second: CombatRoom = assembler.generated_rooms[1]
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var enemies := get_nodes_in_group("enemies")
	assembler.enemy_drop_chance = 0.0
	kill(enemies[0])
	await settle()
	check(get_nodes_in_group("component_pickups").is_empty() and not first.cleared, "missed ordinary death roll creates no loot before clear")
	assembler.enemy_drop_chance = 1.0
	var target: EnemyController = get_first_node_in_group("enemies")
	var death_position := target.global_position
	var enemy_id := target.get_instance_id()
	kill(target)
	root.get_node("CombatEvents").entity_defeated.emit(target)
	await settle()
	var drops := get_nodes_in_group("component_pickups")
	check(drops.size() == 1, "successful death roll emits one pickup despite repeated death notification")
	if drops.is_empty():
		quit(1)
		return
	var pickup: ComponentPickup = drops[0]
	check(pickup.global_position.distance_to(death_position) < 0.01 and pickup.get_parent() == first, "pickup spawns at snapshotted enemy death position in its own area")
	check(pickup.get_meta("enemy_drop") == enemy_id and pickup.has_meta("floor_guarantee"), "first natural drop fulfils floor guarantee")
	check(ComponentRolls.affixes(pickup.rolled_item).size() >= 1, "enemy drop has real quality and affixes")
	assembler.enemy_drop_chance = 0.0
	for enemy in get_nodes_in_group("enemies"):
		kill(enemy)
	await settle()
	check(first.cleared and get_nodes_in_group("component_pickups").size() == 1, "first clear adds no fixed-position reward after a natural drop")
	player.global_position = pickup.global_position
	await settle()
	check(pickup.try_pickup(player.inventory), "death-location loot remains reachable through real physics frames")
	await settle()
	first._on_all_required_defeated()
	assembler._on_room_cleared(first)
	await settle()
	check(get_nodes_in_group("component_pickups").is_empty(), "collected floor minimum is not reissued by duplicate clear")
	player.global_position = second.global_position + Vector2(74, 180)
	await settle()
	assembler.enemy_drop_chance = 1.0
	var locations := {}
	var enemies2 := get_nodes_in_group("enemies")
	for enemy in enemies2:
		enemy.set_physics_process(false)
		locations[enemy.get_instance_id()] = enemy.global_position
	for enemy in enemies2:
		kill(enemy)
	await settle()
	check(get_nodes_in_group("component_pickups").size() == enemies2.size(), "later enemies may each drop loot without extra clear reward")
	for drop in get_nodes_in_group("component_pickups"):
		check(drop.get_parent() == second and locations.has(drop.get_meta("enemy_drop")) and drop.global_position.distance_to(locations[drop.get_meta("enemy_drop")]) < 0.01, "each later drop uses its own death position")
	# A fresh floor with every probability roll forced to miss must still issue one
	# pickup from the first area's last actual death, never from a fixed marker.
	assembler.assemble()
	await settle()
	assembler.enemy_drop_chance = 0.0
	first = assembler.generated_rooms[0]
	var last_position := Vector2.ZERO
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		last_position = enemy.global_position
		kill(enemy)
	await settle()
	check(get_nodes_in_group("component_pickups").size() == 1 and first.reward_count == 1, "all missed rolls produce exactly one guaranteed death drop")
	var guaranteed: ComponentPickup = get_first_node_in_group("component_pickups")
	check(guaranteed.global_position.distance_to(last_position) < 0.01 and guaranteed.has_meta("floor_guarantee"), "guaranteed drop uses last enemy death location")
	first._on_all_required_defeated()
	await settle()
	check(get_nodes_in_group("component_pickups").size() == 1, "repeat first clear cannot duplicate guaranteed death loot")
	main.queue_free()
	await settle()
	print("Death drop checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
