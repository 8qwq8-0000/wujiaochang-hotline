extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func run() -> void:
	var world := Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.cyberware.set_physics_process(false)
	var circuit: CyberwareCircuitState = player.cyberware.circuit
	check(is_equal_approx(circuit.ENERGY_REGEN_PER_SECOND, 40.0), "energy regenerates at 40 per second")
	player.cyberware.set_circuit_library_counts({&"combat_synapse_sensor": 1, &"smart_fire": 1, &"explosive_magazine": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["combat_synapse_sensor", "smart_fire", "explosive_magazine"])).get("ok", false)), "three-step circuit configures")
	circuit.set_energy(11.0)
	check(not player.perform_persona_attack(Vector2.RIGHT), "starter rejects energy below its own 12 cost")
	check(circuit.current_energy == 11.0, "rejected request spends no energy")
	circuit.set_energy(12.0)
	player.weapons.set_cooldown_remaining(0.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "fire request can enter the queue at starter cost")
	check(player.weapons.get_cooldown_remaining() > 0.0, "queued fire reserves weapon cooldown")
	circuit.set_energy(0.0)
	player.cyberware._physics_process(0.0)
	check((player.cyberware.get_circuit_runtime_state().queues as Dictionary).is_empty() and is_zero_approx(player.weapons.get_cooldown_remaining()), "unaffordable queued fire is dropped and cooldown refunded")
	circuit.set_energy(12.0)
	player.weapons.set_cooldown_remaining(0.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "starter accepts energy below the old whole-round threshold")
	player.cyberware._physics_process(0.0)
	check(is_zero_approx(circuit.current_energy), "only starter cost is charged at round start")
	player.cyberware._execute_next_circuit_step()
	check(int(player.cyberware.get_circuit_runtime_state().get("abort_slot", -1)) == 1, "unaffordable next slot aborts the round")
	check(_projectile_count(world) == 1, "abort still emits the round attack")
	for child in world.get_children():
		if child is CombatProjectile:
			child.queue_free()
	await process_frame
	player.cyberware.reset_transient_state()
	player.weapons.reset_transient_state()
	player.cyberware.set_circuit_library_counts({&"combat_synapse_sensor": 1, &"momentum_recovery_tendon": 1, &"smart_fire": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["combat_synapse_sensor", "momentum_recovery_tendon", "smart_fire"])).get("ok", false)), "momentum circuit configures")
	circuit.set_energy(24.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "momentum round submits")
	player.cyberware._physics_process(0.0)
	player.cyberware._execute_next_circuit_step()
	check(is_equal_approx(circuit.current_energy, 40.0), "momentum costs 12 then restores 40")
	check((player.cyberware.get_circuit_runtime_state().get("active", {}) as Dictionary).is_empty(), "momentum jumps directly to round settlement")
	check(_projectile_count(world) == 1, "momentum settlement emits one attack")
	player.cyberware.reset_transient_state()
	player.weapons.reset_transient_state()
	player.cyberware.set_circuit_library_counts({&"active_neural_switch": 1, &"axon_recycler": 1, &"explosive_magazine": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["active_neural_switch", "axon_recycler", "explosive_magazine"])).get("ok", false)), "axon discount circuit configures")
	circuit.set_energy(35.0)
	check(player.cyberware.submit_circuit_request(&"active", Vector2.RIGHT), "ordinary round submits")
	player.cyberware._physics_process(0.0)
	player.cyberware._execute_next_circuit_step()
	check(is_equal_approx(circuit.current_energy, 7.0), "axon costs 18 after the starter's 10")
	player.cyberware._execute_next_circuit_step()
	check(is_zero_approx(circuit.current_energy) and int(player.cyberware.get_circuit_runtime_state().get("abort_slot", -1)) == -1, "axon halves the next 14-point cost without a kill tag")
	for child in world.get_children():
		if child is CombatProjectile:
			child.queue_free()
	await process_frame
	player.cyberware.reset_transient_state()
	player.weapons.reset_transient_state()
	player.cyberware.set_circuit_library_counts({&"active_neural_switch": 1, &"momentum_recovery_tendon": 1, &"predatory_vestibular_ring": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["active_neural_switch", "momentum_recovery_tendon", "predatory_vestibular_ring"])).get("ok", false)), "momentum and replay circuit configures")
	circuit.set_energy(80.0)
	check(player.cyberware.submit_circuit_request(&"active"), "momentum replay request submits")
	player.cyberware._physics_process(0.0)
	for index in 6:
		if (player.cyberware.get_circuit_runtime_state().active as Dictionary).is_empty():
			break
		player.cyberware._execute_next_circuit_step()
	check(_projectile_count(world) == 2, "early round settlement retains the compiled free replay")
	var legacy := {"library": {"active_neural_switch": 1, "kill_heat_sink": 1}, "slots": ["active_neural_switch", "kill_heat_sink"], "slot_capacity": 3, "current_energy": 27.0, "maximum_energy": 80.0}
	check(circuit.import_state(legacy), "old heat-sink save imports")
	check(circuit.get_slots()[1] == "kill_energy_sink" and int(circuit.get_library_counts().get(&"kill_energy_sink", 0)) == 1, "old cyberware ID migrates to energy sink")
	player.cyberware.reset_transient_state()
	player.weapons.reset_transient_state()
	player.talent_core.consume_persona_drink(TalentCoreController.ROCK_VIGILANTE)
	player.talent_core.set_persona(TalentCoreController.ROCK_VIGILANTE)
	player.cyberware.set_circuit_library_counts({&"combat_synapse_sensor": 1, &"smart_fire": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["combat_synapse_sensor", "smart_fire"])).get("ok", false)), "frenzy circuit configures")
	player.persona_combat._encore_remaining = 4.0
	circuit.set_energy(5.0)
	check(player.cyberware.submit_weapon_fire(Vector2.RIGHT, player.weapons.get_current_weapon()), "frenzy accepts starter on credit")
	player.cyberware._physics_process(0.0)
	check(is_equal_approx(circuit.current_energy, -7.0), "frenzy starter spends into debt")
	player.persona_combat._encore_remaining = 0.0
	player.cyberware._execute_next_circuit_step()
	check(is_equal_approx(circuit.current_energy, -15.0), "started round keeps credit after frenzy ends")
	check(not player.cyberware.submit_weapon_fire(Vector2.RIGHT, player.weapons.get_current_weapon()), "new round cannot borrow after frenzy")
	print("Circuit energy phase two failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)


func _projectile_count(world: Node2D) -> int:
	var count := 0
	for child in world.get_children():
		if child is CombatProjectile:
			count += 1
	return count
