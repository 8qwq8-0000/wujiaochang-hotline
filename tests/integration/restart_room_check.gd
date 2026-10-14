extends SceneTree

# Run: godot --headless --path . --script res://tests/integration/restart_room_check.gd
var _failures := 0

func _initialize() -> void:
	call_deferred("_run_checks")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _wait_for_battle(previous: Node = null) -> Node:
	for frame in range(600):
		var player := get_first_node_in_group("player")
		if current_scene != null and current_scene != previous and player != null:
			if root.get_node("RunManager").mandatory_enemies_remaining > 0:
				if not current_scene.get_node("SceneFlow").get("_is_loading"):
					player.set_physics_process(false)
					player.heat.set_physics_process(false)
					for enemy in get_nodes_in_group("enemies"):
						enemy.set_physics_process(false)
					return player
		await process_frame
	_check(false, "Timed out waiting for a fresh battle")
	return null

func _press_restart(echo: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = true
	key.echo = echo
	Input.parse_input_event(key)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_R
	release.keycode = KEY_R
	Input.parse_input_event(release)

func _run_checks() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player := await _wait_for_battle()
	if player == null:
		quit(1)
		return
	var run_manager := root.get_node("RunManager")
	var initial_enemy_count: int = get_nodes_in_group("enemies").size()
	var initial_required_count: int = run_manager.mandatory_enemies_remaining
	var initial_seed: int = run_manager.run_seed
	_check(initial_enemy_count > 0, "Battle must contain enemies")
	_press_restart(true)
	await process_frame
	await process_frame
	_check(current_scene == main, "Key-repeat must not restart the battle")

	for round_index in range(3):
		player = get_first_node_in_group("player")
		player.heat.try_add_heat(player.heat.max_heat)
		run_manager.set_scene_payload({"stale": true})
		if round_index == 1:
			player.core.equip_core(&"", false)
			player.health.apply_damage(player.health.max_health, DamagePacket.new())
			_check(player.get("_dead"), "Player should be dead before restart")
		if round_index == 2:
			for enemy in get_nodes_in_group("enemies"):
				enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
			await process_frame
			_check(run_manager.mandatory_enemies_remaining == 0, "All required enemies must be cleared")
			for elevator in current_scene.find_children("ExitElevator", "Area2D", true, false):
				_check(elevator.enabled, "Exit should be enabled before restart")
		# A projectile attached to Main must also disappear on restart.
		var projectile: Node = load("res://scenes/combat/projectile.tscn").instantiate()
		current_scene.add_child(projectile)
		projectile.set_physics_process(false)
		var old_scene := current_scene
		_press_restart()
		_press_restart()
		player = await _wait_for_battle(old_scene)
		if player == null:
			quit(1)
			return
		_check(not is_instance_valid(old_scene), "Old scene must be freed")
		_check(not is_instance_valid(projectile), "Old projectiles must be freed")
		_check(get_nodes_in_group("player").size() == 1, "Restart must not duplicate the player")
		_check(get_nodes_in_group("enemies").size() == initial_enemy_count, "Enemy count should reset")
		_check(run_manager.mandatory_enemies_remaining == initial_required_count, "Objective count should reset")
		_check(run_manager.run_seed == initial_seed, "Restart should preserve the encounter seed")
		_check(run_manager.scene_payload.is_empty(), "Stale scene payload should be cleared")
		_check(player.health.current_health == player.health.max_health and not player.get("_dead"), "Player should respawn at full health")
		_check(is_zero_approx(player.heat.current_heat) and not player.heat.is_overheated, "Heat should reset")
		for elevator in current_scene.find_children("ExitElevator", "Area2D", true, false):
			_check(not elevator.enabled, "Exit should be locked until the new battle is cleared")
		print("Restart check ", round_index + 1, " complete")
	print("Restart integration failures: ", _failures)
	current_scene.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
