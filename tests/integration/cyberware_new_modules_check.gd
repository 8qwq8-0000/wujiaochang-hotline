extends SceneTree

var failures := 0
var world: Node2D
var player: PlayerController


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func run() -> void:
	world = Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	player = load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.cyberware.set_physics_process(false)
	_test_splice_order()
	_test_fission_and_relay()
	_test_fire_event_relay()
	await _test_world_stop()
	await _test_penetration()
	print("New cyberware failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)


func _configure(ids: PackedStringArray) -> void:
	player.cyberware.reset_transient_state()
	if player.cyberware.circuit.slot_capacity < ids.size():
		player.cyberware.circuit.set_slot_capacity(ids.size())
		player.cyberware.circuit.expand_capacity()
	var counts: Dictionary = {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	player.cyberware.set_circuit_library_counts(counts)
	check(bool(player.cyberware.set_circuit_slots(ids).get("ok", false)), "new module circuit configures: " + str(ids))
	player.cyberware.circuit.set_energy(100.0)
	check(player.cyberware.submit_circuit_request(&"active"), "new module circuit queues")
	player.cyberware._physics_process(0.0)
	player.cyberware._physics_process(0.0)
	for _index in range(ids.size() - 1):
		player.cyberware._physics_process(0.1)


func _test_splice_order() -> void:
	_configure(PackedStringArray(["active_neural_switch", "tactical_coprocessor", "ballistic_splicer"]))
	var attacks: Array = player.cyberware._signal_attacks
	check(attacks.size() == 1 and is_equal_approx(float(attacks[0].damage_scale), 2.0) and int(attacks[0].pierce) == -1, "copy then splice becomes one double-damage penetrating attack")
	_configure(PackedStringArray(["active_neural_switch", "ballistic_splicer", "tactical_coprocessor"]))
	check(player.cyberware._signal_attacks.size() == 2, "splice before copy leaves two attacks")


func _test_fission_and_relay() -> void:
	_configure(PackedStringArray(["active_neural_switch", "fission_core"]))
	var attacks: Array = player.cyberware._signal_attacks
	check(attacks.size() == 3 and is_equal_approx(float(attacks[0].damage_scale), 0.5) and is_equal_approx(rad_to_deg(float(attacks[0].angle_offset)), -20.0) and is_equal_approx(rad_to_deg(float(attacks[2].angle_offset)), 20.0), "fission creates three half-damage trajectories")
	_configure(PackedStringArray(["active_neural_switch", "smart_fire", "relay_starter"]))
	attacks = player.cyberware._signal_attacks
	check(attacks.size() == 2 and int((attacks[0].modifiers as Dictionary).get(&"homing", 0)) == 1 and int((attacks[1].modifiers as Dictionary).get(&"homing", 0)) == 0, "relay adds an unmodified base attack after smart fire")
	check(is_equal_approx(float(attacks[1].get("origin_offset", 0.0)), 7.0), "relay shot uses a separate muzzle position")
	_configure(PackedStringArray(["active_neural_switch", "relay_starter", "smart_fire"]))
	attacks = player.cyberware._signal_attacks
	check(attacks.size() == 2 and int((attacks[0].modifiers as Dictionary).get(&"homing", 0)) == 1 and int((attacks[1].modifiers as Dictionary).get(&"homing", 0)) == 1, "smart fire after relay modifies both attacks")


func _test_fire_event_relay() -> void:
	player.cyberware.reset_transient_state()
	var ids := PackedStringArray(["combat_synapse_sensor", "relay_starter"])
	player.cyberware.set_circuit_library_counts({&"combat_synapse_sensor": 1, &"relay_starter": 1})
	check(bool(player.cyberware.set_circuit_slots(ids).get("ok", false)), "fire event relay circuit configures")
	player.cyberware.circuit.set_energy(100.0)
	var before := get_nodes_in_group("combat_projectiles").size()
	check(player.cyberware.submit_weapon_fire(Vector2.RIGHT, player.weapons.get_current_weapon()), "fire event queues relay circuit")
	for _index in 5:
		player.cyberware._physics_process(0.1)
	check(get_nodes_in_group("combat_projectiles").size() - before == 2, "fire event relay emits two projectiles")


func _test_world_stop() -> void:
	_configure(PackedStringArray(["active_neural_switch", "world"]))
	check(paused and player.cyberware.is_world_stopped() and player.cyberware._world_stop_uses == 1, "world pauses combat and spends one floor use")
	var before := player.global_position
	Input.action_press("move_right")
	player._physics_process(0.1)
	Input.action_release("move_right")
	check(player.global_position.distance_to(before) > 1.0, "player can move during world stop")
	player.cyberware._physics_process(1.5)
	check(not paused and not player.cyberware.is_world_stopped() and is_equal_approx(player.cyberware.circuit.current_energy, player.cyberware.circuit.maximum_energy), "world resumes after 1.5 seconds while energy regenerates to the cap")
	var saved := player.cyberware.export_circuit_state()
	player.cyberware._world_stop_uses = 0
	check(player.cyberware.import_circuit_state(saved) and player.cyberware._world_stop_uses == 1, "world floor usage survives circuit save and load")
	player.cyberware.reset_transient_state()
	player.cyberware._world_stop_uses = 10
	check(not player.cyberware._world_stop_available(), "world disables after ten floor uses")


func _test_penetration() -> void:
	var first := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var second := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(first)
	world.add_child(second)
	first.stationary_test_target = true
	second.stationary_test_target = true
	first.set_physics_process(false)
	second.set_physics_process(false)
	await process_frame
	first.health.configure_max_health(10)
	second.health.configure_max_health(10)
	var shot := (load("res://scenes/combat/projectile.tscn") as PackedScene).instantiate() as CombatProjectile
	world.add_child(shot)
	shot.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 360.0)
	shot.circuit_pierce_remaining = 1
	shot.circuit_penetration_boost = true
	var first_before := first.health.current_health
	var second_before := second.health.current_health
	shot._on_area_entered(first.get_node("HurtBox"))
	shot._on_area_entered(second.get_node("HurtBox"))
	check(first.health.current_health == first_before - 1 and second.health.current_health == second_before - 2, "penetration booster raises the next enemy hit by base damage")
