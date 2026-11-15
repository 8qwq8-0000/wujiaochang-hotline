extends SceneTree

var failures := 0
var world: Node2D
var player: PlayerController


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


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

	var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(120.0, 0.0)
	enemy.set_physics_process(false)
	await process_frame

	_test_active_weapon_chain(enemy)
	await _clear_projectiles()
	_test_spread_weapon_payload()
	await _clear_projectiles()
	_test_guard_mirror(enemy)
	_test_heat_sink_fixed_refund()
	_test_real_event_and_timer_triggers()
	_test_queue_run_state_persistence()
	_test_queue_priority()
	_test_expanded_module_runtime(enemy)
	_test_expanded_hit_effects(enemy)
	_test_world_stop_scatter_fire()
	_test_seamless_hold_during_world_stop()

	print("Cyberware circuit runtime failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)


func _test_active_weapon_chain(enemy: EnemyController) -> void:
	_configure([
		"active_neural_switch",
		"smart_fire",
		"explosive_magazine",
		"tactical_coprocessor",
	])
	player.cyberware.circuit.set_energy(100.0)
	check(InputMap.has_action("circuit_activate"), "project input map exposes the F circuit action")
	var active_input := InputEventAction.new()
	active_input.action = &"circuit_activate"
	active_input.pressed = true
	player._unhandled_input(active_input)
	check(player.cyberware.get_circuit_runtime_state().queues.has(&"active"), "real active input submits the active starter request")
	player.cyberware._physics_process(0.0)
	check(is_equal_approx(player.cyberware.circuit.current_energy, 90.0), "active sample pays only the starter at launch")
	_advance_circuit_steps(5)
	var called_shot: CombatProjectile
	var starter_pulses := 0
	var weapon_shots := 0
	for child in world.get_children():
		if not child is CombatProjectile:
			continue
		var projectile := child as CombatProjectile
		if projectile.weapon_id == &"cyberware_pulse":
			starter_pulses += 1
		else:
			weapon_shots += 1
			called_shot = projectile
	check(weapon_shots == 2 and starter_pulses == 0, "starter fires after the circuit and tactical coprocessor doubles it")
	check(called_shot != null and called_shot.homing_target == enemy and called_shot.has_area_behavior, "same-round attack receives tracking and explosion")
	check(called_shot != null and called_shot.status_tags.has("cyberware_chain"), "circuit weapon attacks carry the anti-recursion tag")
	check(not player.cyberware.get_circuit_runtime_state().queues.keys().any(func(key: Variant) -> bool: return String(key).contains("_fire_")), "generated attack does not recursively queue the fire starter")
	check((player.cyberware.get_circuit_runtime_state().weapon_payload as Dictionary).is_empty(), "same-round attack leaves no pending payload")


func _test_spread_weapon_payload() -> void:
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "smart_fire", "explosive_magazine", "arc_ballistic_cortex"])
	var original_weapon := player.weapons.get_current_weapon()
	player.weapons.equip_weapon(load("res://resources/weapons/scattergun.tres") as WeaponComponentData)
	player.weapons.reset_transient_state()
	player.heat.set_heat(0.0)
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(5)
	check((player.cyberware.get_circuit_runtime_state().weapon_payload as Dictionary).is_empty(), "spread attack uses its circuit payload immediately")
	var shots: Array[CombatProjectile] = []
	for child in world.get_children():
		if child is CombatProjectile:
			shots.append(child as CombatProjectile)
	check(shots.size() == 5, "one spread attack still produces five projectiles")
	if shots.size() == 5:
		var group_id := shots[0].circuit_payload_group_id
		var all_share_payload := true
		for shot in shots:
			all_share_payload = all_share_payload and shot.circuit_payload_group_id == group_id and shot.has_area_behavior and shot.circuit_arc_chains == 2
		check(all_share_payload, "every pellet carries the same attack payload until first impact")
		check(player.cyberware.claim_weapon_payload_hit(group_id) and not player.cyberware.claim_weapon_payload_hit(group_id), "spread secondary effects can trigger only once per attack")
	player.weapons.equip_weapon(original_weapon)
	player.weapons.reset_transient_state()


func _test_guard_mirror(enemy: EnemyController) -> void:
	player.cyberware.reset_transient_state()
	_configure(["combat_synapse_sensor_guard", "guard_coprocessor", "instruction_mirror_synapse"])
	player.cyberware.circuit.set_energy(100.0)
	check(player.cyberware.submit_event_starters(4, Vector2.RIGHT, PackedStringArray(["格挡"])), "guard starter accepts an event request")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(2)
	check(int(player.cyberware.get_circuit_runtime_state().cyber_guard_count) == 2, "instruction mirror creates a second independent cyber guard")
	check(player.guard.state == GuardComponent.State.IDLE, "cyber guards do not occupy manual guard state")
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source = enemy
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = player.global_position + Vector2.RIGHT * 24.0
	packet.travel_direction = Vector2.LEFT
	packet.is_projectile = true
	packet.reflectable = true
	var before_health := player.health.current_health
	var result := player.receive_damage(packet)
	check(result != null and result.perfect and result.reflected, "cyber guard perfectly reflects a frontal projectile")
	check(player.health.current_health == before_health, "cyber guard prevents damage")
	check(not player.cyberware.get_circuit_runtime_state().queues.has(&"event_0"), "cyber perfect guard does not recursively trigger the same guard action")


func _test_heat_sink_fixed_refund() -> void:
	player.cyberware.reset_transient_state()
	_configure(["rhythm_pulser", "kill_energy_sink", "instruction_mirror_synapse"])
	player.cyberware.circuit.set_energy(50.0)
	player.heat.set_heat(30.0)
	check(player.cyberware.submit_circuit_request(&"timed", Vector2.RIGHT, PackedStringArray(["击杀"])), "rhythm starter accepts a timed kill-tag request")
	player.cyberware._physics_process(0.0)
	check(is_equal_approx(player.cyberware.circuit.current_energy, 42.0), "timed round pays only its eight-point starter at launch")
	_advance_circuit_steps(3)
	check(is_equal_approx(player.cyberware.circuit.current_energy, 80.0), "two thirty-point kill-tag refunds and step-time regeneration apply during gradual spending")
	check(is_equal_approx(player.heat.current_heat, 30.0), "energy sink no longer changes legacy heat state")


func _test_real_event_and_timer_triggers() -> void:
	player.cyberware.reset_transient_state()
	_configure(["combat_synapse_sensor", "guard_coprocessor"])
	player.weapons.reset_transient_state()
	player.heat.set_heat(0.0)
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "ordinary weapon attack succeeds for combat-sensor trigger")
	check(player.cyberware.get_circuit_runtime_state().queues.keys().any(func(key: Variant) -> bool: return String(key).begins_with("event_0_fire_")), "ordinary weapon input queues the fire starter")
	player.cyberware.reset_transient_state()
	_configure(["rhythm_pulser", "kill_energy_sink"])
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware._physics_process(2.5)
	var active: Dictionary = player.cyberware.get_circuit_runtime_state().active
	check(StringName((active.get("request", {}) as Dictionary).get("kind", "")) == &"timed", "2.5 seconds automatically starts the rhythm request")


func _test_queue_priority() -> void:
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "combat_synapse_sensor", "rhythm_pulser", "guard_coprocessor"])
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"timed", Vector2.RIGHT, PackedStringArray(["定时"]))
	player.cyberware.submit_circuit_request(&"event", Vector2.RIGHT, PackedStringArray(["武器攻击"]))
	player.cyberware.submit_circuit_request(&"active", Vector2.RIGHT, PackedStringArray(["主动"]))
	player.cyberware._physics_process(0.0)
	var active: Dictionary = player.cyberware.get_circuit_runtime_state().active
	check(StringName((active.get("request", {}) as Dictionary).get("kind", "")) == &"active", "active request wins active-event-timed priority")
	check(player.cyberware.get_circuit_runtime_state().queues.has(&"event") and player.cyberware.get_circuit_runtime_state().queues.has(&"timed"), "lower-priority request types remain queued")


func _test_queue_run_state_persistence() -> void:
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "combat_synapse_sensor", "guard_coprocessor"])
	player.cyberware.submit_circuit_request(&"active", Vector2.RIGHT, PackedStringArray(["主动"]))
	player.cyberware.submit_circuit_request(&"event", Vector2.LEFT, PackedStringArray(["武器攻击"]))
	var run_state := player.export_run_state()
	player.reset_transient_state()
	check(player.cyberware.get_circuit_runtime_state().queues.is_empty(), "ordinary transient reset clears circuit queues")
	player.import_run_state(run_state)
	var restored_queues: Dictionary = player.cyberware.get_circuit_runtime_state().queues
	check(restored_queues.has(&"active") and restored_queues.has(&"event"), "run-state import preserves pending circuit request types")
	check(Vector2((restored_queues[&"event"] as Dictionary).get("direction", Vector2.ZERO)) == Vector2.LEFT, "run-state import preserves queued request context")


func _test_expanded_module_runtime(enemy: EnemyController) -> void:
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "micro_rotor_reflex_bundle", "guard_coprocessor"])
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(2)
	check(is_equal_approx(float(player.cyberware.get("_circuit_step_interval")), 0.0125), "micro rotor quarters the default remaining step interval")
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "omnidirectional_reflection_matrix"])
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active", Vector2.RIGHT)
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(2)
	var rear := DamagePacket.new()
	rear.base_damage = 1
	rear.source = enemy
	rear.source_faction = CombatFaction.Id.ENEMY
	rear.source_position = player.global_position + Vector2.LEFT * 24.0
	rear.travel_direction = Vector2.RIGHT
	rear.is_projectile = true
	rear.reflectable = true
	var blocked := player.cyberware.try_cyberware_guard(rear)
	check(blocked != null and blocked.perfect and blocked.reflected, "reflection matrix perfect-guards a rear projectile")
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "momentum_recovery_tendon"])
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(2)
	check((player.cyberware.get_circuit_runtime_state().active as Dictionary).is_empty() and is_equal_approx(player.cyberware.circuit.current_energy, 100.0), "momentum tendon settles early and restores energy")
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "calamity_flame"])
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(4)
	var found_blade := false
	for child in world.get_children():
		if child is CombatProjectile and child.calamity_blade:
			found_blade = true
			check(is_equal_approx(child.calamity_max_distance, player.weapons.get_current_weapon().attack_range), "calamity blade retains the current weapon range")
	check(found_blade, "calamity flame creates a blade projectile without a separate weapon item")


func _test_expanded_hit_effects(enemy: EnemyController) -> void:
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "optical_intruder", "shock_pulser"])
	enemy.global_position = player.global_position + Vector2(40.0, 0.0)
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(3)
	check(float(enemy.get("_optical_disruption_remaining")) > 0.0, "optical intruder breaks enemy targeting from the circuit")
	check(float(enemy.get("_stagger_remaining")) >= 0.35, "heat threshold pulse staggers a nearby enemy")
	player.cyberware.reset_transient_state()
	_configure(["active_neural_switch", "ballistic_takeover_protocol"])
	var hostile := (load("res://scenes/combat/projectile.tscn") as PackedScene).instantiate() as CombatProjectile
	world.add_child(hostile)
	hostile.global_position = player.global_position + Vector2(20.0, 0.0)
	hostile.setup(enemy, CombatFaction.Id.ENEMY, Vector2.LEFT, 1, 200.0)
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active")
	player.cyberware._physics_process(0.0)
	_advance_circuit_steps(2)
	check(hostile.faction == CombatFaction.Id.PLAYER and hostile.takeover_consumed, "ballistic takeover captures an enemy shot")
	player.cyberware.reset_transient_state()
	var second := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(second)
	second.global_position = enemy.global_position + Vector2(28.0, 0.0)
	second.set_physics_process(false)
	var shot := (load("res://scenes/combat/projectile.tscn") as PackedScene).instantiate() as CombatProjectile
	world.add_child(shot)
	shot.global_position = enemy.global_position - Vector2(24.0, 0.0)
	shot.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 2, 360.0)
	shot.circuit_arc_chains = 2
	shot.circuit_echo_layers = 1
	shot.configure_explosion(48.0, 1)
	shot.configure_homing(enemy, 360.0)
	shot.configure_calamity_blade(120.0)
	var hit := DamageResult.new()
	hit.target = enemy
	hit.final_damage = 2
	var before := second.health.current_health
	player.cyberware.on_circuit_projectile_hit(shot, hit)
	check(second.health.current_health < before, "circuit arc deals damage to a new nearby target")
	check((player.cyberware.get("_circuit_pending_echoes") as Array).size() == 1, "trajectory echo schedules one delayed duplicate")
	player.cyberware._tick_circuit_echoes(0.18)
	var echoes := 0
	var echoed_shot: CombatProjectile
	for child in world.get_children():
		if child is CombatProjectile and child.status_tags.has("circuit_echo"):
			echoes += 1
			echoed_shot = child
	check(echoes == 1, "trajectory echo spawns a non-recursive projectile able to hit its original target")
	if echoed_shot != null:
		check(echoed_shot.has_area_behavior and echoed_shot.circuit_arc_chains == 2 and echoed_shot.circuit_echo_layers == 0 and echoed_shot.calamity_blade and is_instance_valid(echoed_shot.homing_target), "trajectory echo inherits final attack modifiers without echo recursion")
		var original_health := enemy.health.current_health
		echoed_shot._on_area_entered(enemy.get_node("HurtBox"))
		check(enemy.health.current_health < original_health, "trajectory echo can damage the original target again")


func _test_world_stop_scatter_fire() -> void:
	for child in world.get_children():
		if child is CombatProjectile:
			child.free()
	player.cyberware.reset_transient_state()
	_configure(["combat_synapse_sensor"])
	var original_weapon := player.weapons.get_current_weapon()
	player.weapons.equip_weapon(load("res://resources/weapons/scattergun.tres") as WeaponComponentData)
	player.weapons.reset_transient_state()


	player.cyberware.circuit.set_energy(40.0)
	player.cyberware._start_world_stop()
	check(paused and player.weapons.process_mode == Node.PROCESS_MODE_ALWAYS, "world stop keeps player weapon cooldown active")
	player.cyberware._physics_process(0.25)
	check(player.cyberware.circuit.current_energy > 40.0, "circuit energy regenerates during world stop")
	player.cyberware.circuit.set_energy(100.0)
	var press := InputEventAction.new()
	press.action = &"attack"
	press.pressed = true
	var release := InputEventAction.new()
	release.action = &"attack"
	release.pressed = false
	player._unhandled_input(press)
	player._physics_process(0.016)
	player._unhandled_input(release)
	var cooldown_after_first := player.weapons.get_cooldown_remaining()
	player.weapons._physics_process(0.95)
	check(cooldown_after_first > 0.0 and is_zero_approx(player.weapons.get_cooldown_remaining()), "weapon cooldown continues during world stop")
	player._unhandled_input(press)
	player._physics_process(0.016)
	player._unhandled_input(release)
	var fire_queues := 0
	for key in player.cyberware.get_circuit_runtime_state().queues:
		if String(key).contains("_fire_"):
			fire_queues += 1
	check(fire_queues == 2, "one fire request is queued per scatter input")
	for index in 6:
		player.cyberware._physics_process(0.05)
	var shots: Array[CombatProjectile] = []
	for child in world.get_children():
		if child is CombatProjectile:
			shots.append(child as CombatProjectile)
	check(shots.size() == 5, "first scatter request emits exactly five pellets during world stop")
	if not shots.is_empty():
		var shot := shots[0]
		var start := shot.global_position
		shot._physics_process(0.25)
		var first_distance := shot.global_position.distance_to(start)
		var first_lifetime := shot.lifetime
		shot._physics_process(0.25)
		var frozen_position := shot.global_position
		var second_distance := frozen_position.distance_to(start) - first_distance
		shot._physics_process(0.1)
		check(first_distance > second_distance and second_distance > 0.0 and shot.global_position.is_equal_approx(frozen_position) and is_equal_approx(shot.lifetime, first_lifetime - second_distance / shot.speed), "new pellet slows for 0.5 seconds then freezes without aging")
	for index in 20:
		player.cyberware._physics_process(0.05)
	shots.clear()
	for child in world.get_children():
		if child is CombatProjectile:
			shots.append(child as CombatProjectile)
	check(shots.size() == 10, "two scatter inputs emit ten pellets without duplicate fire events")
	if not shots.is_empty():
		var resumed := shots[0]
		var frozen_position := resumed.global_position
		resumed._physics_process(0.1)
		check(resumed.global_position.distance_to(frozen_position) > resumed.speed * 0.09 and resumed.process_mode == Node.PROCESS_MODE_INHERIT, "frozen pellet resumes its original speed after world stop")
	player.cyberware._end_world_stop()
	player.weapons.equip_weapon(original_weapon)
	player.weapons.reset_transient_state()


func _test_seamless_hold_during_world_stop() -> void:
	player.cyberware.reset_transient_state()
	_configure(["combat_synapse_sensor", "world", "trajectory_echo_processor"])
	player.talent_core.set_persona_level(TalentCoreController.ROCK_VIGILANTE, 2)
	player.talent_core.set_persona(TalentCoreController.ROCK_VIGILANTE)
	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 2, &"seamless_switch")
	player.persona_combat.set("_seamless_switch_window", 1.2)
	player.weapons.reset_transient_state()
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware._start_world_stop()
	var press := InputEventAction.new()
	press.action = &"attack"
	press.pressed = true
	var release := InputEventAction.new()
	release.action = &"attack"
	release.pressed = false
	player._unhandled_input(press)
	player._physics_process(0.016)
	player.cyberware._physics_process(0.016)
	check(player.cyberware.has_active_round(), "first held shot starts the fire circuit")
	for _index in 20:
		player._physics_process(0.016)
	var queued_fires := 0
	for key in player.cyberware.get_circuit_runtime_state().queues:
		if String(key).contains("_fire_"):
			queued_fires += 1
	check(queued_fires == 0, "holding attack cannot bypass cooldown to flood the seamless fire queue")
	player.weapons.set_cooldown_remaining(0.0)
	player._physics_process(0.016)
	player.weapons.set_cooldown_remaining(0.0)
	player._physics_process(0.016)
	queued_fires = 0
	for key in player.cyberware.get_circuit_runtime_state().queues:
		if String(key).contains("_fire_"):
			queued_fires += 1
	check(queued_fires == 1, "held automatic fire keeps at most one pending request")
	player._input(release)
	check(player.cyberware.get_circuit_runtime_state().queues.is_empty(), "releasing attack cancels the pending automatic repeat")
	player._unhandled_input(press)
	player._physics_process(0.016)
	queued_fires = 0
	for key in player.cyberware.get_circuit_runtime_state().queues:
		if String(key).contains("_fire_"):
			queued_fires += 1
	check(queued_fires == 1, "a deliberate second click can prestore its own seamless fire request")
	player._input(release)
	var queued_after_release := queued_fires
	for _index in 10:
		player._physics_process(0.016)
	queued_fires = 0
	for key in player.cyberware.get_circuit_runtime_state().queues:
		if String(key).contains("_fire_"):
			queued_fires += 1
	check(queued_fires == queued_after_release, "releasing attack submits no more fire requests")
	player.cyberware._end_world_stop()


func _configure(ids: Array[String]) -> void:
	if ids.size() > player.cyberware.circuit.slot_capacity:
		player.cyberware.circuit.set_slot_capacity(ids.size())
		player.cyberware.circuit.expand_capacity()
	var counts: Dictionary = {}
	for module_id in ids:
		counts[module_id] = int(counts.get(module_id, 0)) + 1
	player.cyberware.set_circuit_library_counts(counts)
	var result := player.cyberware.set_circuit_slots(PackedStringArray(ids))
	check(bool(result.get("ok", false)), "fixture circuit is valid: " + str(ids))


func _advance_circuit_steps(step_count: int) -> void:
	player.cyberware._physics_process(0.0)
	for _index in maxi(step_count - 1, 0):
		player.cyberware._physics_process(0.1)


func _clear_projectiles() -> void:
	for child in world.get_children():
		if child is CombatProjectile:
			child.queue_free()
	await process_frame
