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
	check(player.get_weapon_display_name() == "试验·油枪","sandbox starts with oil gun")
	var target = scene.get_node("Targets").get_child(0)
	player.weapons.try_attack(Vector2(300,165),Vector2.RIGHT,player)
	await create_timer(0.2).timeout
	check(target.get_node("StatusComponent").has_status(&"oiled"),"actual debug oil projectile applies oil")
	await create_timer(0.15).timeout
	var key := InputEventKey.new()
	key.keycode = KEY_Q
	key.physical_keycode = KEY_Q
	key.pressed = true
	root.push_input(key,true)
	await process_frame
	check(player.get_weapon_display_name() == "试验·火焰枪","real Q selects fire gun")
	player.weapons.try_attack(Vector2(300,165),Vector2.RIGHT,player)
	await create_timer(0.2).timeout
	check(target.get_node("StatusComponent").has_status(&"burning"),"actual fire projectile ignites oil")
	check(target.get_node("StatusIndicator").visible and target.get_node("StatusIndicator").label.text.contains("燃烧"),"burning countdown appears")
	await create_timer(3.05).timeout
	check(target.health.current_health == 3,"two debug shots plus three real burn ticks")
	for enemy in scene.get_node("Targets").get_children():
		enemy.health.apply_damage(100,DamagePacket.new())
	check(scene.cleared,"burn trial uses normal clear flow")
	key = InputEventKey.new()
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
