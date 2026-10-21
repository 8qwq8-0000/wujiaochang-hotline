extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(player)
	await process_frame
	player.inventory.allow_trial_equipment_changes = true
	check(player.inventory.pickup("smart_fire"), "cyberware enters the ordinary six-cell backpack")
	check(player.inventory.equip(0), "cyberware equips into its dedicated slot")
	check(player.inventory.cyberware_slot.get_item() != null and player.cyberware.has_module(CyberwareController.SMART_FIRE), "inventory equipment refreshes cyberware controller")
	check(player.inventory.unequip("cyberware"), "cyberware can be removed as one complete item")
	player.inventory.set_open(true)
	check(not player.inventory.put_in_blackbox(0), "cyberware cannot enter the blackbox")
	player.inventory.set_open(false)
	player.inventory.backpack.remove_item(player.inventory.backpack.get_items()[0])

	check(player.dash.start_dash(player, Vector2.RIGHT), "empty cyberware slot still permits fixed dash")
	check(player.dash.is_dashing(), "dash enters its active window")
	player.dash.reset_transient_state()

	var rng := RandomNumberGenerator.new()
	var smart := ComponentRolls.create("smart_fire", 1, rng)
	var explosive := ComponentRolls.create("explosive_magazine", 3, rng)
	var compound := ComponentRolls.fuse(smart, explosive, rng)
	player.cyberware.set_equipped_item(compound)
	check(player.cyberware.has_module(CyberwareController.SMART_FIRE), "compound equips smart fire")
	check(player.cyberware.has_module(CyberwareController.EXPLOSIVE_MAGAZINE), "compound equips explosive magazine")
	var four_module_compound := ComponentRolls.fuse(compound, ComponentRolls.create("tactical_coprocessor", 1, rng), rng)
	four_module_compound = ComponentRolls.fuse(four_module_compound, ComponentRolls.create("optical_intruder", 1, rng), rng)
	check(ComponentRolls.cyberware_modules(four_module_compound).size() == 4, "compound cyberware accepts four distinct modules")
	check(not ComponentRolls.compatible(four_module_compound, ComponentRolls.create("kill_heat_sink", 1, rng)), "compound cyberware rejects a fifth distinct module")

	var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(120, 0)
	await process_frame
	var projectile := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	world.add_child(projectile)
	projectile.global_position = player.global_position
	projectile.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 520.0)
	projectile.set_physics_process(false)
	player.cyberware.configure_projectile(projectile, Vector2.RIGHT)
	check(projectile.homing_target == enemy, "smart fire captures one target inside the confirmed cone")
	check(projectile.has_area_behavior and projectile.explosion_radius == 48.0, "explosive magazine snapshots area behavior")
	player.cyberware.clear()
	check(projectile.homing_target == enemy and projectile.has_area_behavior, "unequipping does not rewrite an existing projectile snapshot")
	var neighbor := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(neighbor)
	neighbor.global_position = enemy.global_position + Vector2(24, 0)
	var durable_profile := enemy.profile.duplicate() as EnemyProfile
	durable_profile.max_health = 3
	enemy.apply_profile(durable_profile)
	await process_frame
	projectile.global_position = enemy.global_position
	projectile.call("_on_area_entered", enemy.hurt_box)
	check(enemy.health.current_health == 1, "direct target receives projectile plus explosion damage")
	check(neighbor.health.is_dead(), "nearby target receives one explosion damage")

	var tactical := ComponentRolls.create("tactical_coprocessor", 1, rng)
	player.cyberware.set_equipped_item(tactical)
	check(player.cyberware.supports_automatic_fire(load("res://resources/weapons/service_pistol.tres")), "tactical coprocessor enables held fire for compatible gun")
	check(not player.cyberware.supports_automatic_fire(load("res://resources/weapons/rail_cannon.tres")), "tactical coprocessor rejects beam weapon")
	player.set("_attack_held", true)
	player.set("_attack_pressed", false)
	check(bool(player.call("_should_attack_this_frame")), "held semi-auto input is promoted while tactical coprocessor is installed")
	player.cyberware.clear()
	check(not bool(player.call("_should_attack_this_frame")), "held semi-auto input returns to one-click behavior after unequip")

	var optical := ComponentRolls.create("optical_intruder", 1, rng)
	player.cyberware.set_equipped_item(optical)
	enemy.set("_target", player)
	enemy.set("_alerted", true)
	player.cyberware.on_dash_started(player.global_position)
	check(float(enemy.get("_optical_disruption_remaining")) >= 0.79, "optical intruder covers dash plus confirmed reacquire buffer")
	check(enemy.get("_target") == null, "optical intruder immediately clears ordinary enemy lock")

	var kill_heat_sink := ComponentRolls.create("kill_heat_sink", 1, rng)
	player.cyberware.set_equipped_item(kill_heat_sink)
	player.heat.set_physics_process(false)
	player.heat.set_heat(90.0)
	var sink_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(sink_target)
	await process_frame
	var player_kill := DamageResult.new()
	player_kill.target = sink_target
	player_kill.target_defeated = true
	player_kill.final_damage = 1
	player_kill.packet = DamagePacket.new()
	player_kill.packet.source = player
	player_kill.packet.source_faction = CombatFaction.Id.PLAYER
	root.get_node("CombatEvents").damage_resolved.emit(player_kill)
	check(is_equal_approx(player.heat.current_heat, 60.0), "kill heat sink removes 30 percent of maximum heat on a player kill")
	var chained_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(chained_target)
	await process_frame
	var chained_kill := DamageResult.new()
	chained_kill.target = chained_target
	chained_kill.target_defeated = true
	chained_kill.final_damage = 1
	chained_kill.packet = DamagePacket.new()
	chained_kill.packet.source = player
	chained_kill.packet.source_faction = CombatFaction.Id.PLAYER
	root.get_node("CombatEvents").damage_resolved.emit(chained_kill)
	check(is_equal_approx(player.heat.current_heat, 60.0), "kill heat sink ignores chained kills during its half-second limiter")
	player.cyberware._physics_process(0.5)
	player.heat.set_heat(50.0)
	player.heat.is_overheated = true
	var recovery_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(recovery_target)
	await process_frame
	var recovery_kill := DamageResult.new()
	recovery_kill.target = recovery_target
	recovery_kill.target_defeated = true
	recovery_kill.final_damage = 1
	recovery_kill.packet = DamagePacket.new()
	recovery_kill.packet.source = player
	recovery_kill.packet.source_faction = CombatFaction.Id.PLAYER
	root.get_node("CombatEvents").damage_resolved.emit(recovery_kill)
	check(is_equal_approx(player.heat.current_heat, 20.0) and not player.heat.is_overheated, "kill heat sink immediately releases overheat below the weapon recovery threshold")
	player.cyberware._physics_process(0.5)
	player.heat.set_heat(50.0)
	var environment_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(environment_target)
	await process_frame
	var environment_kill := DamageResult.new()
	environment_kill.target = environment_target
	environment_kill.target_defeated = true
	environment_kill.final_damage = 1
	environment_kill.packet = DamagePacket.new()
	environment_kill.packet.source = world
	environment_kill.packet.source_faction = CombatFaction.Id.PLAYER
	root.get_node("CombatEvents").damage_resolved.emit(environment_kill)
	check(is_equal_approx(player.heat.current_heat, 50.0), "environment-attributed kills cannot trigger kill heat sink")

	var heat_threshold_pulser := ComponentRolls.create("heat_threshold_pulser", 1, rng)
	player.cyberware.set_equipped_item(heat_threshold_pulser)
	var pulse_near := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var pulse_far := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(pulse_near)
	world.add_child(pulse_far)
	pulse_near.stationary_test_target = true
	pulse_far.stationary_test_target = true
	pulse_near.global_position = player.global_position + Vector2(40.0, 0.0)
	pulse_far.global_position = player.global_position + Vector2(80.0, 0.0)
	await process_frame
	var near_health := pulse_near.health.current_health
	player.heat.is_overheated = false
	player.heat.set_heat(0.0)
	check(player.heat.try_add_heat(player.heat.effective_max()), "heat threshold pulser uses the ordinary overheat transition")
	check(pulse_near.state == EnemyController.State.STAGGERED and pulse_far.state != EnemyController.State.STAGGERED, "heat threshold pulse staggers only ordinary enemies inside 64 pixels")
	check(pulse_near.health.current_health == near_health, "heat threshold pulse applies control without damage")
	pulse_near.state = EnemyController.State.IDLE
	pulse_near.set("_stagger_remaining", 0.0)
	player.cyberware.clear()
	player.cyberware.set_equipped_item(heat_threshold_pulser)
	player.heat.is_overheated = false
	player.heat.set_heat(0.0)
	player.heat.try_add_heat(player.heat.effective_max())
	check(pulse_near.state != EnemyController.State.STAGGERED, "unequip and re-equip cannot bypass heat threshold pulser cooldown")
	player.cyberware._physics_process(8.0)
	player.heat.is_overheated = false
	player.heat.set_heat(0.0)
	player.heat.try_add_heat(player.heat.effective_max())
	check(pulse_near.state == EnemyController.State.STAGGERED, "heat threshold pulser becomes ready after eight seconds")

	player.inventory.cyberware_slot.equip(compound)
	player.inventory._apply_equipment()
	var run_state := player.inventory.export_run_state()
	check(not run_state.cyberware.is_empty(), "same-run snapshot retains equipped cyberware")
	var restored := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(restored)
	await process_frame
	restored.inventory.import_run_state(run_state)
	check(restored.cyberware.has_module(CyberwareController.SMART_FIRE) and restored.cyberware.has_module(CyberwareController.EXPLOSIVE_MAGAZINE), "serialized compound restores its complete module set")
	var recovery := player.inventory.export_recovery_inventory()
	check(recovery.cyberware.is_empty(), "action recovery clears equipped cyberware")

	world.queue_free()
	await process_frame
	print("Cyberware failures: ", failures)
	quit(0 if failures == 0 else 1)
