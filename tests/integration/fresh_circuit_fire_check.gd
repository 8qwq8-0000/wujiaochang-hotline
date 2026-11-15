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
	world.add_to_group(&"combat_rooms")
	root.add_child(world)
	current_scene = world
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.cyberware.set_physics_process(false)
	check(ComponentRolls.cyberware_resource_path(&"combat_synapse_sensor") != "", "fire starter resource is discoverable")
	check(player.cyberware.circuit.get_definition(&"combat_synapse_sensor") != null, "fire starter definition is loaded")
	check(player.cyberware.circuit.get_slots()[0] == "combat_synapse_sensor", "new player has the fire starter installed")
	check(player.perform_persona_attack(Vector2.RIGHT), "new player can submit fire through the circuit")
	for index in 5:
		player.cyberware._physics_process(0.1)
	var shots := 0
	for child in world.get_children():
		if child is CombatProjectile and child.weapon_id == &"service_pistol":
			shots += 1
	check(shots == 1, "new player fires one issued-pistol projectile")
	print("Fresh circuit fire failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
