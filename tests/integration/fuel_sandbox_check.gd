extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var scene = load("res://scenes/debug/fuel_reaction_sandbox.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var player: PlayerController = scene.get_node("Player")
	player.set_physics_process(false)
	check(player.inventory.secondary_weapon_slot.get_item() == null,"fuel trial gives no extra weapon")
	check(player.weapons.get_current_weapon().id == &"initial_baton","fuel trial retains ordinary starting weapon")
	player.position = Vector2(390,250)
	await physics_frame
	await physics_frame
	player.weapons.try_attack(player.position,Vector2.RIGHT,player)
	for frame in 12:
		player.weapons.update_attack_pose(player.position,Vector2.RIGHT,player)
		await physics_frame
	var barrel: FuelBarrel = scene.get_node("FuelBarrel")
	check(barrel.broken and is_instance_valid(barrel.patch),"ordinary melee explodes trial bomb")
	await process_frame
	check(barrel.patch.burning and barrel.patch.explosion_count == 1,"melee leaves one fire zone")
	check(player.health.current_health == 2,"close melee blast also damages player")
	player.position = Vector2(140,215)
	var button: Button = scene.get_node("UI/Ignite")
	for click in 2:
		var click_point := button.get_global_transform_with_canvas()*(button.size/2)
		for pressed in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = pressed
			mouse.position = click_point
			root.push_input(mouse,true)
			await process_frame
		await process_frame
		var target = scene.get_node("Targets").get_child(0)
		check(target.health.current_health == 7-click,"each test discharge damages target once")
	# Stationary test targets still use real knockdown timers and recovery.
	player.position = Vector2(270,165)
	player.velocity = Vector2.ZERO
	player.equip_mobility(load("res://resources/mobility/wheel.tres"))
	await physics_frame
	await physics_frame
	player.mobility.activate_ability(player,Vector2.RIGHT)
	for frame in 20:
		player.mobility.tick(player,Vector2.RIGHT,Vector2.RIGHT,1.0/60)
		await physics_frame
		if scene.get_node("AutomaticDoor").opened:
			break
	await process_frame
	var door_target = scene.get_node("Targets").get_child(0)
	check(scene.get_node("AutomaticDoor").slammed and door_target.state == EnemyController.State.STAGGERED,"trial door knocks stationary target down")
	await create_timer(0.9).timeout
	check(door_target.state != EnemyController.State.STAGGERED and not door_target.get_node("StatusComponent").has_status(&"knocked_down"),"trial target recovers from actual knockdown timer")
	for enemy in scene.get_node("Targets").get_children():
		enemy.health.apply_damage(100,DamagePacket.new())
	check(scene.cleared,"burn trial uses normal clear flow")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	key.pressed = true
	root.push_input(key,true)
	for frame in 5:
		await process_frame
	check(current_scene != scene and current_scene.remaining_targets == 3,"R resets fuel sandbox")
	current_scene.queue_free()
	await process_frame
	print("Fuel sandbox checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
