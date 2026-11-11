extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func defeat(enemy: EnemyController) -> void:
	enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	if enemy.state == EnemyController.State.SELF_DESTRUCT:
		enemy._physics_process(enemy.profile.self_destruct_delay + 0.01)

func disable_navigation(room: CombatRoom) -> void:
	var navigation := room.get_node("NavigationRegion2D") as NavigationRegion2D
	navigation.enabled = false
	for frame in 3:
		await physics_frame

func run() -> void:
	root.get_node("RunManager").begin_run(28)
	var floor_node: Node2D = load("res://scenes/levels/floors/combat_prototype.tscn").instantiate()
	var assembler := floor_node.get_node("FloorAssembler") as FloorAssembler
	assembler.room_count = 1
	assembler.enemy_drop_chance = 1.0
	assembler.cyberware_drop_chance = 1.0
	root.add_child(floor_node)
	current_scene = floor_node
	var player := floor_node.get_node("Player") as PlayerController
	player.set_physics_process(false)
	for frame in 4:
		await physics_frame
	var room: CombatRoom = assembler.generated_rooms[0]
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await disable_navigation(room)
	var enemy := get_first_node_in_group("enemies") as EnemyController
	var death_position := enemy.global_position
	defeat(enemy)
	assembler.try_enemy_drop(enemy, room, death_position)
	for frame in 3:
		await physics_frame
	check(get_nodes_in_group("component_pickups").is_empty(), "navigation delay does not spawn loot at an unchecked fallback position")
	(room.get_node("NavigationRegion2D") as NavigationRegion2D).enabled = true
	for frame in 90:
		await physics_frame
		if get_nodes_in_group("component_pickups").size() == 2:
			break
	var pickups := get_nodes_in_group("component_pickups")
	check(pickups.size() == 2, "one defeated enemy grants exactly one equipment and one cyberware drop after navigation sync")
	if pickups.size() == 2:
		check(pickups[0].global_position.distance_to(pickups[1].global_position) >= 54.0, "simultaneous delayed drops keep their spacing")
	var bounds := Rect2(Vector2.ONE * 24.0, CombatRoom.ROOM_SIZE - Vector2.ONE * 48.0)
	for pickup: ComponentPickup in pickups:
		check(pickup.get_parent() == room and assembler._drop_position_reachable(room, pickup.global_position, bounds), "delayed drop belongs to the live room and is reachable")
		player.global_position = pickup.global_position
		check(pickup.try_pickup(player.inventory), "delayed world loot can be collected normally")
	await physics_frame
	await disable_navigation(room)
	enemy = get_first_node_in_group("enemies") as EnemyController
	defeat(enemy)
	await process_frame
	floor_node.queue_free()
	for frame in 6:
		await physics_frame
	check(get_nodes_in_group("component_pickups").is_empty(), "removing the floor cancels waiting drops without leaking loot into the next scene")
	print("Enemy drop navigation checks: %d; failures: %d" % [checks, failures])
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
