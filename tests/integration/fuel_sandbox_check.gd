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
	check(barrel.broken and is_instance_valid(barrel.patch),"ordinary melee breaks trial barrel")
	player.position = Vector2(140,215)
	var target = scene.get_node("Targets").get_child(0)
	target.position = Vector2(450,250)
	await create_timer(0.25).timeout
	check(target.get_node("StatusComponent").has_status(&"oiled"),"barrel oil alone applies oil")
	var button: Button = scene.get_node("UI/Ignite")
	var click_point := button.get_global_transform_with_canvas()*(button.size/2)
	for pressed in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = click_point
		root.push_input(mouse,true)
		await process_frame
	await process_frame
	check(barrel.patch.burning and barrel.patch.explosion_count == 1,"real test-button click ignites spilled oil")
	await process_frame
	check(target.get_node("StatusIndicator").visible and target.get_node("StatusIndicator").label.text.contains("燃烧"),"environment ignition shows burning countdown")
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
