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


func enemy_pickups() -> Array[Node]:
	var result: Array[Node] = []
	for pickup in get_nodes_in_group("component_pickups"):
		if pickup.has_meta("enemy_drop"):
			result.append(pickup)
	return result

func run() -> void:
	root.get_node("WarehouseStore").save_path = "user://bc_death_drop_check.json"
	DirAccess.remove_absolute("user://bc_death_drop_check.json")
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		if get_nodes_in_group("enemies").size() == 6 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	var player := get_first_node_in_group("player") as PlayerController
	player.set_physics_process(false)
	player.health.configure_max_health(1000)
	var assembler := main.find_child("FloorAssembler", true, false) as FloorAssembler
	# Formal floor loot must not depend on a listener owned by the player. That
	# listener can disappear when player/scene lifecycle changes, which previously
	# made every enemy death silently produce no pickup.
	var player_loot_listener := player.get_node_or_null("ComponentInventory/EnemyLoot")
	check(player_loot_listener != null, "fixture includes the legacy player-owned loot listener")
	player_loot_listener.free()
	await settle()
	var first: CombatRoom = assembler.generated_rooms[0]
	var second: CombatRoom = assembler.generated_rooms[1]
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var enemies := get_nodes_in_group("enemies")
	assembler.enemy_drop_chance = 0.0
	assembler.cyberware_drop_chance = 0.0
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
	check(pickup.get_meta("enemy_drop") == enemy_id and not pickup.has_meta("area_guarantee"), "natural drop has no area guarantee")
	var dropped_slot := str(pickup.rolled_item.get_property("slot", ""))
	check(
		(
			dropped_slot == "cyberware"
			and ComponentRolls.quality(pickup.rolled_item) == 0
			and not ComponentRolls.cyberware_modules(pickup.rolled_item).is_empty()
		)
		or (dropped_slot != "cyberware" and ComponentRolls.affixes(pickup.rolled_item).size() >= 1),
		"enemy drop follows its slot-specific roll contract"
	)
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
	check(get_nodes_in_group("component_pickups").is_empty(), "collected area minimum is not reissued by duplicate clear")
	player.global_position = second.global_position + Vector2(74, 180)
	await settle()
	assembler.enemy_drop_chance = 1.0
	assembler.cyberware_drop_chance = 1.0
	var enemies2 := get_nodes_in_group("enemies")
	var enemy_ids2: Array[int] = []
	for enemy in enemies2:
		enemy.set_physics_process(false)
		enemy_ids2.append(enemy.get_instance_id())
	for enemy in enemies2:
		kill(enemy)
	await settle()
	check(enemy_pickups().size() == enemies2.size() * 2, "equipment and cyberware roll separately for each enemy")
	check(get_nodes_in_group("component_pickups").size() == enemies2.size() * 2, "final enemy follows the same two drop rolls as other enemies")
	check(get_nodes_in_group("component_pickups").all(func(drop: Node) -> bool: return not drop.has_meta("floor_cyberware_reward") and not drop.has_meta("area_guarantee")), "random drops carry no guarantee markers")
	for source_id in enemy_ids2:
		var pair := enemy_pickups().filter(func(drop: Node) -> bool: return drop.get_meta("enemy_drop") == source_id)
		check(pair.size() == 2, "each enemy produces separate equipment and cyberware pickups")
		if pair.size() == 2:
			check(pair[0].global_position.distance_to(pair[1].global_position) >= 54.0, "paired pickup textures do not overlap")
			check(str(pair[0].rolled_item.get_property("slot", "")) != str(pair[1].rolled_item.get_property("slot", "")), "paired pickups have different item categories")
	# A fresh floor with every probability roll forced to miss produces no loot.
	assembler.assemble()
	await settle()
	assembler.enemy_drop_chance = 0.0
	assembler.cyberware_drop_chance = 0.0
	first = assembler.generated_rooms[0]
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		kill(enemy)
	await settle()
	check(get_nodes_in_group("component_pickups").is_empty() and first.reward_count == 0, "all missed rolls produce no guaranteed death drop")
	first._on_all_required_defeated()
	await settle()
	check(get_nodes_in_group("component_pickups").is_empty(), "repeat first clear does not create loot")
	second = assembler.generated_rooms[1]
	player.global_position = second.global_position + Vector2(74, 180)
	await settle()
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		kill(enemy)
	await settle()
	check(second.cleared and second.reward_count == 0 and enemy_pickups().is_empty(), "second area also has no forced drop")
	first._on_all_required_defeated()
	second._on_all_required_defeated()
	assembler._on_room_cleared(first)
	assembler._on_room_cleared(second)
	await settle()
	check(get_nodes_in_group("component_pickups").is_empty() and first.reward_count == 0 and second.reward_count == 0, "repeated clears cannot create loot")
	main.queue_free()
	await settle()
	print("Death drop checks: ", checks, "; failures: ", failures)
	DirAccess.remove_absolute("user://bc_death_drop_check.json")
	quit(0 if failures == 0 else 1)
