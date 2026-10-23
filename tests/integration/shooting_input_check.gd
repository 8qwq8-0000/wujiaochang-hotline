extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run_checks() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: PlayerController
	for frame in 600:
		await process_frame
		player = get_first_node_in_group("player") as PlayerController
		if player != null and not main.get_node("SceneFlow").get("_is_loading"):
			break
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	player.inventory.pickup("pistol")
	player.weapons.select_weapon(1)
	await process_frame
	var barrel_direction := Vector2(3, 4).normalized()
	player.visuals.update_weapon_aim(barrel_direction)
	var attack_transform := player._get_attack_transform()
	check(attack_transform.x.normalized().is_equal_approx(barrel_direction), "projectile transform follows the exact rendered barrel axis")
	check(attack_transform.origin.is_equal_approx(player.weapons.clamp_projectile_origin(player.visuals.get_weapon_mount_global_position(), player.visuals.get_weapon_muzzle_global_position())), "projectile still originates at the rendered muzzle")
	# Real GUI dispatch: decorative HUD must not consume firing/guard clicks.
	var hud: Node = main.get_node("CombatHUD")
	for path in ["Overlay/MinimalStatus", "Overlay/TopRightPersona/PersonaStatus", "Overlay/NoticeQueue"]:
		var control: Control = hud.get_node(path)
		var point := control.get_global_rect().get_center()
		player.set("_attack_pressed", false)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, true)
		check(player.get("_attack_pressed"), "HUD click reaches attack input: " + path)
	# Projectile code must support negative Y as well as other headings.
	for heading in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		player.weapons.reset_transient_state()
		player.heat.current_heat = 0
		check(player.weapons.try_attack(player.global_position, heading, player), "fire heading " + str(heading))
		var room := CombatProjectile.room_for_actor(player)
		var shot: CombatProjectile
		for child in room.get_children():
			if child is CombatProjectile:
				shot = child
		check(shot != null and shot.direction.is_equal_approx(heading), "projectile heading " + str(heading))
		if shot != null:
			var origin := shot.global_position
			# Include real overlap callbacks, not just the projectile movement method.
			for frame in 4:
				await physics_frame
			check(is_instance_valid(shot), "projectile survives its shooter " + str(heading))
			if is_instance_valid(shot):
				check((shot.global_position - origin).dot(heading) > 0, "projectile moves forward " + str(heading))
				room.remove_child(shot)
				shot.queue_free()
	main.queue_free()
	await process_frame
	print("Shooting input failures: ", failures)
	quit(0 if failures == 0 else 1)
