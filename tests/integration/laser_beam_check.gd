extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.global_position = Vector2(100, 200)
	player.set_physics_process(false)
	player.health.configure_max_health(100)
	player.equip_weapon(load("res://resources/weapons/rail_cannon.tres"))
	var targets: Array[EnemyController] = []
	for position in [Vector2(250, 200), Vector2(650, 225), Vector2(1100, 180), Vector2(650, 260), Vector2(1200, 200), Vector2(80, 200)]:
		var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
		enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
		enemy.profile.max_health = 20
		room.add_child(enemy)
		enemy.global_position = position
		enemy.set_physics_process(false)
		targets.append(enemy)
	await physics_frame
	await physics_frame
	check(player.weapons.try_attack(Vector2(150, 200), Vector2.RIGHT, player), "laser fires")
	check(targets[0].health.current_health == 17, "laser deals full damage inside its formation distance")
	check(targets[1].health.current_health == 18, "laser damage begins fading after five body lengths")
	check(targets[2].health.current_health == 19, "laser remains damaging but weak at maximum depth")
	for index in range(3, 6):
		check(targets[index].health.current_health == 20, "outside width, length or rear is safe: %d" % index)
	check(player.health.current_health == 100, "beam never hits shooter")
	var beams := get_nodes_in_group("laser_beams")
	check(beams.size() == 1 and is_equal_approx(beams[0].get("beam_length"), 1000.0) and beams[0].get("beam_width") == 48.0, "visible beam uses damage dimensions")
	check(beams.size() == 1 and beams[0].material is ShaderMaterial and is_equal_approx(beams[0].material.get_shader_parameter("falloff_start_ratio"), 0.16), "beam visual carries the same near-to-deep falloff gradient")
	for child in room.get_children():
		check(not child is CombatProjectile, "beam emits no ordinary projectile")
	if "--capture-laser" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hotline-wide-laser.png")
	await create_timer(0.4).timeout
	check(get_nodes_in_group("laser_beams").is_empty(), "beam visual finishes and cleans up")
	check(targets[0].health.current_health == 17, "visual duration cannot repeatedly damage a target")
	var near_wall := StaticBody2D.new()
	near_wall.collision_layer = 1
	var near_collider := CollisionShape2D.new()
	var near_rectangle := RectangleShape2D.new()
	near_rectangle.size = Vector2(12, 120)
	near_collider.shape = near_rectangle
	near_wall.add_child(near_collider)
	room.add_child(near_wall)
	near_wall.global_position = Vector2(220, 200)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 120)
	collider.shape = rectangle
	wall.add_child(collider)
	room.add_child(wall)
	wall.global_position = Vector2(500, 200)
	var barrels: Array[FuelBarrel] = []
	for position in [Vector2(400, 200), Vector2(700, 200), Vector2(400, 300)]:
		var barrel: FuelBarrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate()
		room.add_child(barrel)
		barrel.global_position = position
		barrels.append(barrel)
	for enemy in targets:
		enemy.health.set_current_health(20)
		enemy.hurt_box.clear_invulnerability()
	await physics_frame
	await physics_frame
	player.weapons.reset_transient_state()
	player.heat.current_heat = 0
	player.weapons.try_attack(Vector2(150, 200), Vector2.RIGHT, player)
	check(targets[0].health.current_health == 17, "wall inside five body lengths is penetrated")
	check(targets[1].health.current_health == 20 and targets[2].health.current_health == 20, "wall stops laser damage")
	beams = get_nodes_in_group("laser_beams")
	check(beams.size() == 1 and beams[0].get("beam_length") < 341.0, "wall clips visual to the same damage endpoint")
	check(barrels[0].broken, "beam hits explosive barrels as well as actor hurtboxes")
	check(not barrels[1].broken, "wall protects barrel behind it")
	check(not barrels[2].broken, "barrel outside beam width is safe")
	await process_frame
	await process_frame
	check(is_instance_valid(barrels[0].patch) and barrels[0].patch.burning and barrels[0].patch.explosion_count == 1, "beam-hit barrel explodes exactly once")
	room.queue_free()
	await process_frame
	print("Laser beam checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
