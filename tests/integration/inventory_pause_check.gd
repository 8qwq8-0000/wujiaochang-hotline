extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.physical_keycode = code
	Input.parse_input_event(release)
func run() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for frame in 600:
		if get_first_node_in_group("player") != null and get_nodes_in_group("enemies").size() == 3 and not main.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	if player == null:
		quit(1)
		return
	var inventory := player.get_node("ComponentInventory") as ComponentInventory
	var enemy := get_first_node_in_group("enemies") as EnemyController
	var projectile: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	main.add_child(projectile)
	projectile.global_position = Vector2(160, 300)
	projectile.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 60)
	player.heat.current_heat = 30.0
	player.weapons.set("_cooldown_remaining", 1.0)
	key(KEY_TAB)
	await process_frame
	check(paused and inventory.is_open, "opening backpack pauses the whole tree")
	var enemy_position := enemy.global_position
	var bullet_position := projectile.global_position
	var heat := player.heat.current_heat
	var cooldown: float = player.weapons.get("_cooldown_remaining")
	await create_timer(0.2, true).timeout
	check(enemy.global_position == enemy_position, "enemy stops")
	check(projectile.global_position == bullet_position, "projectile stops")
	check(player.heat.current_heat == heat, "heat stops")
	check(player.weapons.get("_cooldown_remaining") == cooldown, "weapon cooldown stops")
	check(inventory.panel.can_process(), "panel remains interactive")
	key(KEY_ESCAPE)
	await process_frame
	check(not paused and not inventory.is_open, "Esc resumes")
	await create_timer(0.1, true).timeout
	check(projectile.global_position != bullet_position, "world resumes movement")
	key(KEY_TAB)
	await process_frame
	key(KEY_TAB)
	await process_frame
	check(not paused, "Tab can close while paused")
	# Existing pause from another owner must survive closing this panel.
	paused = true
	inventory.set_open(true)
	inventory.set_open(false)
	check(paused, "closing does not undo an existing pause")
	paused = false
	inventory.set_open(true)
	player.health.apply_damage(player.health.max_health, DamagePacket.new())
	check(not paused and not inventory.is_open, "death releases inventory pause")
	# Restart input from a paused panel must reach the normal restart handler.
	player.health.current_health = player.health.max_health
	inventory.set_open(true)
	key(KEY_R)
	for frame in 600:
		if current_scene != main and get_first_node_in_group("player") != null:
			break
		await process_frame
	check(not paused and current_scene != main, "R restarts from paused backpack")
	var next_player := get_first_node_in_group("player") as PlayerController
	if next_player != null:
		var next_inventory := next_player.get_node("ComponentInventory") as ComponentInventory
		next_inventory.set_open(true)
		current_scene.queue_free()
		await process_frame
		check(not paused, "scene removal releases pause")
	print("Inventory pause failures: ", failures)
	quit(0 if failures == 0 else 1)
