extends SceneTree

var failures := 0
var lab: Node2D
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
	lab = load("res://scenes/debug/cyberware_circuit_lab.tscn").instantiate() as Node2D
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await process_frame
	check(lab.has_method("get_training_enemies") and lab.has_method("reset_circuit"), "circuit lab scene loads its gameplay script")
	if not lab.has_method("get_training_enemies") or not lab.has_method("reset_circuit"):
		print("Cyberware circuit lab failures: ", failures)
		quit(1)
		return
	player = lab.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.cyberware.set_physics_process(false)
	for enemy in lab.get_training_enemies():
		enemy.set_physics_process(false)

	_test_test_mode_entry()
	_test_trial_loadout()
	_test_resets_and_targets()

	print("Cyberware circuit lab failures: ", failures)
	quit(0 if failures == 0 else 1)


func _test_test_mode_entry() -> void:
	var tools = root.get_node("GameSettings").test_tools
	check(_has_button_text(tools, "义体构筑试验场"), "test-mode panel exposes the dedicated circuit lab entry")
	check(lab.is_in_group("combat_rooms"), "circuit lab is a real combat projectile room")


func _test_trial_loadout() -> void:
	var counts := player.cyberware.circuit.get_library_counts()
	check(counts.size() == 9, "lab grants all nine first-playable cyberware definitions")
	var enough := true
	for module_id in counts:
		enough = enough and int(counts[module_id]) >= CyberwareCircuitState.SLOT_COUNT
	check(enough, "lab grants enough copies for duplicate four-slot experiments")
	check(player.cyberware.circuit.get_slots() == PackedStringArray(lab.DEFAULT_SLOTS), "lab starts with the active smart explosive weapon chain")
	check(is_equal_approx(player.cyberware.circuit.maximum_energy, 100.0) and is_equal_approx(player.cyberware.circuit.current_energy, 100.0), "lab starts at 100 of 100 energy")
	check(InputMap.has_action("circuit_editor") and InputMap.has_action("circuit_activate"), "lab keeps C editing and F activation controls")


func _test_resets_and_targets() -> void:
	var enemies: Array[EnemyController] = lab.get_training_enemies()
	check(enemies.size() == 2, "lab provides a stationary shootable enemy and a melee enemy")
	var has_stationary := false
	var has_melee := false
	for enemy in enemies:
		has_stationary = has_stationary or enemy.stationary_test_target
		has_melee = has_melee or enemy.profile == lab.MELEE_PROFILE and not enemy.stationary_test_target
	check(has_stationary and has_melee, "lab enemy roles match the trial contract")
	var dummy := lab.get_node("InfiniteTarget") as Node2D
	check(dummy.is_in_group("enemies") and (dummy.get_node("HealthComponent") as HealthComponent).max_health == 999, "lab provides an independently targetable indestructible dummy")
	var packet := DamagePacket.new()
	packet.base_damage = 5
	packet.source = player
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.source_position = player.global_position
	packet.travel_direction = Vector2.RIGHT
	(dummy.get_node("HurtBox") as HurtBox2DComponent).receive_hit(packet)
	check((dummy.get_node("HealthComponent") as HealthComponent).current_health == 999, "indestructible dummy restores damage immediately")

	player.cyberware.circuit.set_energy(3.0)
	player.heat.set_heat(73.0)
	lab.reset_energy_and_heat()
	check(is_equal_approx(player.cyberware.circuit.current_energy, 100.0) and is_zero_approx(player.heat.current_heat), "trial control resets energy and heat")
	player.cyberware.set_circuit_slots(PackedStringArray(["combat_synapse_sensor", "guard_coprocessor", "", ""]))
	lab.reset_circuit()
	check(player.cyberware.circuit.get_slots() == PackedStringArray(lab.DEFAULT_SLOTS), "trial control restores the default sample circuit")
	var previous_ids := PackedInt64Array()
	for enemy in lab.get_training_enemies():
		previous_ids.append(enemy.get_instance_id())
	lab.reset_enemies()
	var reset_enemies: Array[EnemyController] = lab.get_training_enemies()
	var all_replaced := reset_enemies.size() == 2
	for enemy in reset_enemies:
		all_replaced = all_replaced and enemy.get_instance_id() not in previous_ids
	check(all_replaced, "trial control replaces both training enemies")


func _has_button_text(root_node: Node, expected: String) -> bool:
	for node in root_node.find_children("*", "Button", true, false):
		if (node as Button).text == expected:
			return true
	return false
