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
	var counts := {&"combat_synapse_sensor": 1, &"smart_fire": 1, &"tactical_coprocessor": 1, &"combat_synapse_sensor_hit": 1}
	player.cyberware.set_circuit_library_counts(counts)
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["combat_synapse_sensor", "smart_fire", "tactical_coprocessor"])).get("ok", false)), "fire starter circuit configures")
	player.cyberware.circuit.set_energy(100.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "manual input submits fire event")
	check(_projectiles().is_empty(), "manual input does not fire before circuit finishes")
	for index in 5:
		player.cyberware._physics_process(0.1)
	var shots := _projectiles()
	check(shots.size() == 2, "tactical coprocessor doubles end-of-round attack")
	check(shots.size() == 2 and shots[0].weapon_id == &"service_pistol" and shots[1].weapon_id == &"service_pistol", "copied attacks use the current weapon")
	check((player.cyberware.get_circuit_runtime_state().weapon_payload as Dictionary).is_empty(), "modifiers apply in the same round")
	for shot in shots:
		shot.queue_free()
	await process_frame
	player.cyberware.reset_transient_state()
	player.cyberware.set_circuit_library_counts(counts)
	check(player.cyberware.merge_event_starters(&"combat_synapse_sensor", &"combat_synapse_sensor_hit"), "forge merges distinct event starter effects")
	var combined := CyberwareController.event_starter_id(9)
	check(player.cyberware.circuit.get_slots()[0] == String(combined), "merged starter replaces the installed subject")
	check(CyberwareController.event_starter_mask(combined) == 9, "merged starter listens to fire and hit")
	await _test_saved_event_queue(combined)
	await _test_hit_event_chain()
	await _test_replay_attacks()
	await _test_attack_copy_without_cap()
	_test_attack_order_changes_signal_shape()
	print("Circuit attack phase one failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)


func _test_saved_event_queue(combined: StringName) -> void:
	player.cyberware.reset_transient_state()
	player.weapons.reset_transient_state()
	player.cyberware.circuit.set_energy(100.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "merged starter accepts fire before saving")
	var saved := player.cyberware.export_circuit_state()
	var has_event_queue := false
	var event_queue_has_weapon := false
	for key in saved.runtime.queues:
		if String(key).begins_with("event_0"):
			has_event_queue = true
			event_queue_has_weapon = (saved.runtime.queues[key] as Dictionary).has("weapon")
	check(has_event_queue and not event_queue_has_weapon, "queued attack exports without a Resource")
	player.cyberware.reset_transient_state()
	check(player.cyberware.import_circuit_state(saved), "merged starter and queued attack import")
	check(player.cyberware.circuit.get_slots()[0] == String(combined), "import preserves merged starter")
	for index in 5:
		player.cyberware._physics_process(0.1)
	check(_projectiles().size() == 2, "restored queue attacks with equipped weapon")
	for shot in _projectiles():
		shot.queue_free()
	await process_frame


func _test_hit_event_chain() -> void:
	player.cyberware.reset_transient_state()
	player.weapons.reset_transient_state()
	player.cyberware.set_circuit_library_counts({&"combat_synapse_sensor": 1, &"combat_synapse_sensor_hit": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["combat_synapse_sensor", "combat_synapse_sensor_hit"])).get("ok", false)), "fire and hit starters configure separately")
	player.cyberware.circuit.set_energy(100.0)
	var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(enemy)
	enemy.stationary_test_target = true
	enemy.global_position = player.global_position + Vector2.RIGHT * 80.0
	enemy.set_physics_process(false)
	await process_frame
	check(player.perform_persona_attack(Vector2.RIGHT), "fire event begins a circuit attack")
	for index in 4:
		player.cyberware._physics_process(0.1)
	var shots := _projectiles()
	check(shots.size() == 1, "fire starter emits one attack")
	if shots.size() == 1:
		shots[0]._on_area_entered(enemy.get_node("HurtBox") as Area2D)
	check(player.cyberware.get_circuit_runtime_state().queues.has(&"event_1"), "direct weapon hit queues the hit starter")
	for shot in _projectiles():
		if is_instance_valid(shot) and not shot.is_queued_for_deletion():
			shot.queue_free()
	await process_frame
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy.queue_free()
	await process_frame
	player.cyberware.reset_transient_state()


func _test_replay_attacks() -> void:
	player.cyberware.reset_transient_state()
	player.cyberware.set_circuit_library_counts({&"active_neural_switch": 1, &"tactical_coprocessor": 1, &"predatory_vestibular_ring": 1})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["active_neural_switch", "tactical_coprocessor", "predatory_vestibular_ring"])).get("ok", false)), "replay circuit configures")
	player.cyberware.circuit.set_energy(100.0)
	check(player.cyberware.submit_circuit_request(&"active"), "active starter submits replay attack")
	for index in 9:
		player.cyberware._physics_process(0.1)
	check(_projectiles().size() == 4, "original and replay each emit their own doubled attack")


func _test_attack_copy_without_cap() -> void:
	for shot in _projectiles():
		shot.queue_free()
	await process_frame
	player.cyberware.reset_transient_state()
	for capacity in [4, 5, 6]:
		player.cyberware.circuit.set_slot_capacity(capacity)
		player.cyberware.circuit.expand_capacity()
	player.cyberware.set_circuit_library_counts({&"active_neural_switch": 1, &"tactical_coprocessor": 5})
	check(bool(player.cyberware.set_circuit_slots(PackedStringArray(["active_neural_switch", "tactical_coprocessor", "tactical_coprocessor", "tactical_coprocessor", "tactical_coprocessor", "tactical_coprocessor"])).get("ok", false)), "five coprocessors fit six slots")
	player.cyberware.circuit.set_energy(140.0)
	check(player.cyberware.submit_circuit_request(&"active"), "large copy circuit starts")
	var request: Dictionary = player.cyberware._circuit_queues[&"active"]
	var spread := (request.weapon as WeaponComponentData).duplicate(true) as WeaponComponentData
	spread.attack_kind = WeaponComponentData.AttackKind.SPREAD
	spread.projectile_count = 2
	request["weapon"] = spread
	for index in 9:
		player.cyberware._physics_process(0.1)
	check(_projectiles().size() == 64, "five multipliers can create more than 32 attacks")


func _test_attack_order_changes_signal_shape() -> void:
	for ids in [
		PackedStringArray(["active_neural_switch", "tactical_coprocessor", "calamity_flame"]),
		PackedStringArray(["active_neural_switch", "calamity_flame", "tactical_coprocessor"]),
	]:
		player.cyberware.reset_transient_state()
		player.cyberware.set_circuit_library_counts({&"active_neural_switch": 1, &"tactical_coprocessor": 1, &"calamity_flame": 1})
		check(bool(player.cyberware.set_circuit_slots(ids).get("ok", false)), "ordering fixture configures: " + str(ids))
		player.cyberware.circuit.set_energy(100.0)
		check(player.cyberware.submit_circuit_request(&"active"), "ordering fixture starts")
		player.cyberware._physics_process(0.0)
		player.cyberware._physics_process(0.0)
		player.cyberware._physics_process(0.1)
		player.cyberware._physics_process(0.1)
		var expected := 3 if ids[1] == "tactical_coprocessor" else 4
		check(player.cyberware._signal_attacks.size() == expected, "ordering changes the pending attack count to %d" % expected)


func _projectiles() -> Array[CombatProjectile]:
	var result: Array[CombatProjectile] = []
	for child in world.get_children():
		if child is CombatProjectile:
			result.append(child as CombatProjectile)
	return result
