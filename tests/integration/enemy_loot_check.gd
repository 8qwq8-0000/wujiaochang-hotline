extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
func run() -> void:
	var scene: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in 600:
		if get_first_node_in_group("player") != null and get_nodes_in_group("enemies").size() == 3 and not scene.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	if player == null:
		check(false, "battle loaded")
		quit(1)
		return
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	# Closing in must not suppress the shooter's attack or make it back away.
	var ranged: EnemyController
	var melee: EnemyController
	for enemy in get_nodes_in_group("enemies"):
		if enemy.profile.role == EnemyProfile.Role.RANGED_SIGHTLINE:
			ranged = enemy
		if enemy.profile.role == EnemyProfile.Role.MELEE_PRESSURE:
			melee = enemy
	player.global_position = Vector2(210, 115)
	ranged.global_position = Vector2(235, 115)
	ranged.set("_target", player)
	ranged.velocity = Vector2(ranged.profile.move_speed, 0)
	ranged._physics_process(0.016)
	check(
		ranged._choose_tactical_intent(25.0, 0.016) == EnemyTacticalBrain.Intent.HOLD_AND_ATTACK,
		"ranged prepares to shoot at close range instead of retreating"
	)
	# Cover A lies between these points: no windup or through-wall melee.
	player.global_position = Vector2(230, 115)
	melee.global_position = Vector2(310, 115)
	melee.set("_target", player)
	await physics_frame
	await physics_frame
	check(not melee._has_line_of_sight(), "cover blocks line of sight")
	var initial := player.health.current_health
	melee.perform_attack()
	check(player.health.current_health == initial, "melee cannot hit through cover")
	# A previously alerted enemy follows its last known sighting around cover.
	melee._alert_to(player.global_position, false)
	melee.profile = melee.profile.duplicate()
	melee.profile.alert_memory_seconds = 10.0
	for frame in 360:
		melee._physics_process(1.0 / 60.0)
		if melee.global_position.distance_to(player.global_position) <= melee.profile.attack_range:
			break
		await physics_frame
	check(melee.global_position.distance_to(player.global_position) <= melee.profile.attack_range, "navigation routes around cover")
	melee.set("_attack_cooldown_remaining", 0.0)
	melee.state = EnemyController.State.IDLE
	melee._physics_process(0.016)
	check(melee.state == EnemyController.State.WINDUP, "attack starts with warning")
	check(player.health.current_health == initial, "warning does not deal immediate damage")
	player.global_position = Vector2(80, 300)
	melee._physics_process(melee.profile.attack_windup + 0.01)
	check(player.health.current_health == initial, "moving away avoids telegraphed melee")
	# Sweep test prevents bullets from passing through cover in a long frame.
	var projectile: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	scene.add_child(projectile)
	projectile.global_position = Vector2(230, 115)
	projectile.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 440)
	projectile.set_physics_process(false)
	projectile._physics_process(0.2)
	check(projectile.is_queued_for_deletion(), "projectile stops at cover")
	(scene.find_child("FloorAssembler", true, false) as FloorAssembler).enemy_drop_chance = 0.0
	var before := get_nodes_in_group("component_pickups").size()
	var enemies := get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
		enemy._on_died(DamagePacket.new())
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.state == EnemyController.State.SELF_DESTRUCT:
			enemy._physics_process(enemy.profile.self_destruct_delay + 0.01)
	await process_frame
	await process_frame
	check(get_nodes_in_group("component_pickups").size() == before + 1, "one floor guarantee; repeated ordinary deaths do not duplicate loot")
	check(root.get_node("RunManager").mandatory_enemies_remaining == 3, "next area objectives remain after first clear")
	var inventory := player.get_node("ComponentInventory") as ComponentInventory
	check(inventory.pickup("pistol") and inventory.pickup("pistol") and inventory.equip(0), "loot-compatible weapon can equip after clear")
	var shot_count := scene.find_children("Projectile*", "Area2D", true, false).size()
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "equipped weapon can fire")
	check(scene.find_children("Projectile*", "Area2D", true, false).size() > shot_count, "equipped pistol creates projectile")
	print("Enemy and loot integration failures: ", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
