extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func wait_room(flow: SceneContainerManager) -> PlayerController:
	for frame in 600:
		var player := get_first_node_in_group("player") as PlayerController
		if player != null and not flow.get("_is_loading"):
			player.set_physics_process(false)
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(false)
			return player
		await process_frame
	return null
func run() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	flow.fade_duration = 0
	var player := await wait_room(flow)
	if player == null:
		quit(1)
		return
	player.inventory.pickup("pistol")
	player.inventory.pickup("wheel")
	player.inventory.pickup("scattergun")
	player.weapons.cycle_weapon(1)
	var before := player.inventory.export_run_state()
	var enemies := get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	await process_frame
	await process_frame
	var drop := get_first_node_in_group("component_pickups") as ComponentPickup
	check(drop != null and drop.get_parent().is_in_group("combat_rooms"), "drop is owned by combat room")
	player.weapons.set("_cooldown_remaining", 0)
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "carried reserve can fire")
	var bullet := main.find_child("Projectile*", true, false)
	check(bullet != null and bullet.get_parent().is_in_group("combat_rooms"), "projectile is owned by combat room")
	var state: Dictionary = root.get_node("RunManager").capture_player_state(player)
	check(flow.request_scene("res://scenes/levels/floors/combat_prototype.tscn", {"player_state": state}), "request next room")
	player = await wait_room(flow)
	check(player != null, "next room loaded")
	if player != null:
		check(player.inventory.export_run_state() == before, "next room preserves spare bag, both slots, active weapon, instance ids and first-pickup flag")
	check(not is_instance_valid(drop) and not is_instance_valid(bullet), "old room drops and projectiles do not leak across rooms")
	check(get_nodes_in_group("component_pickups").is_empty(), "new room has no stale drops")
	main.queue_free()
	await process_frame
	print("Room transition failures: ", failures)
	quit(0 if failures == 0 else 1)
