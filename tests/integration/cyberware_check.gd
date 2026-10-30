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
	current_scene = world
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

	var momentum_recovery_tendon := ComponentRolls.create("momentum_recovery_tendon", 1, rng)
	player.cyberware.set_equipped_item(momentum_recovery_tendon)
	player.dash.dash_damaged_enemy.emit(pulse_near)
	check(is_equal_approx(player.cyberware.get_momentum_charge_remaining(), 1.5), "damaging fixed dash primes one 1.5-second zero-heat charge")
	player.dash.dash_damaged_enemy.emit(pulse_far)
	check(is_equal_approx(player.cyberware.get_momentum_charge_remaining(), 1.5), "additional hit signals never stack momentum charges")
	player.heat.is_overheated = false
	player.heat.set_heat(0.0)
	player.weapons.equip_weapon(load("res://resources/weapons/baton.tres"))
	player.weapons.set_cooldown_remaining(0.0)
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "naturally zero-heat attack still succeeds while momentum is primed")
	check(is_equal_approx(player.cyberware.get_momentum_charge_remaining(), 1.5), "naturally zero-heat attack does not consume momentum")
	player.weapons.equip_weapon(load("res://resources/weapons/service_pistol.tres"))
	var already_free_context := {"heat_multiplier": 0.0}
	player.cyberware.augment_attack_context(player.weapons.get_current_weapon(), already_free_context)
	check(not already_free_context.has("momentum_free_heat"), "an attack already made zero-heat by another effect does not reserve momentum")
	player.weapons.set_cooldown_remaining(0.0)
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "heat-producing attack consumes the primed momentum charge")
	check(is_zero_approx(player.heat.current_heat) and is_zero_approx(player.cyberware.get_momentum_charge_remaining()), "primed attack adds zero heat and consumes exactly one charge")
	player.dash.dash_damaged_enemy.emit(pulse_near)
	player.heat.set_heat(player.heat.effective_max())
	player.heat.is_overheated = true
	player.weapons.set_cooldown_remaining(0.0)
	check(not player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "momentum cannot fire a weapon while it is overheated")
	check(is_equal_approx(player.cyberware.get_momentum_charge_remaining(), 1.5), "blocked overheated attack does not consume momentum")
	player.heat.is_overheated = false
	player.heat.set_heat(0.0)
	player.cyberware._physics_process(1.5)
	check(is_zero_approx(player.cyberware.get_momentum_charge_remaining()), "unused momentum expires after 1.5 seconds")
	player.dash.dash_damaged_enemy.emit(pulse_near)
	player.cyberware.clear()
	check(is_zero_approx(player.cyberware.get_momentum_charge_remaining()), "unequipping momentum tendon clears its transient charge")

	var trajectory_echo_processor := ComponentRolls.create("trajectory_echo_processor", 1, rng)
	player.cyberware.set_equipped_item(trajectory_echo_processor)
	var echo_origin := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var echo_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(echo_origin)
	world.add_child(echo_target)
	echo_origin.stationary_test_target = true
	echo_target.stationary_test_target = true
	echo_origin.global_position = Vector2(420.0, 400.0)
	echo_target.global_position = Vector2(480.0, 400.0)
	echo_origin.health.configure_max_health(10)
	echo_target.health.configure_max_health(10)
	await process_frame
	var echo_target_health := echo_target.health.current_health
	var projectile_echo := DamageResult.new()
	projectile_echo.target = echo_origin
	projectile_echo.final_damage = 1
	projectile_echo.packet = DamagePacket.new()
	projectile_echo.packet.source = player
	projectile_echo.packet.source_faction = CombatFaction.Id.PLAYER
	projectile_echo.packet.weapon_id = &"service_pistol"
	projectile_echo.packet.is_projectile = true
	projectile_echo.packet.allows_trajectory_echo = true
	root.get_node("CombatEvents").damage_resolved.emit(projectile_echo)
	check(echo_target.health.current_health == echo_target_health - 1, "single projectile echoes to the nearest second target for at least one damage")
	check(is_zero_approx(player.cyberware.get_module_readiness(CyberwareController.TRAJECTORY_ECHO_PROCESSOR)), "successful echo starts the four-second internal cooldown")
	root.get_node("CombatEvents").damage_resolved.emit(projectile_echo)
	check(echo_target.health.current_health == echo_target_health - 1, "trajectory echo cannot retrigger during its cooldown")
	player.cyberware._physics_process(4.0)
	echo_target.global_position = Vector2(540.0, 400.0)
	root.get_node("CombatEvents").damage_resolved.emit(projectile_echo)
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.TRAJECTORY_ECHO_PROCESSOR), 1.0), "missing a second target does not spend trajectory echo cooldown")
	echo_target.global_position = Vector2(480.0, 400.0)
	var before_beam_echo := echo_target.health.current_health
	var beam_echo := DamageResult.new()
	beam_echo.target = echo_origin
	beam_echo.final_damage = 3
	beam_echo.packet = DamagePacket.new()
	beam_echo.packet.source = player
	beam_echo.packet.source_faction = CombatFaction.Id.PLAYER
	beam_echo.packet.weapon_id = &"rail_cannon"
	beam_echo.packet.is_beam = true
	beam_echo.packet.allows_trajectory_echo = true
	root.get_node("CombatEvents").damage_resolved.emit(beam_echo)
	check(echo_target.health.current_health == before_beam_echo - 2, "laser echo deals half damage rounded up")
	player.cyberware._physics_process(4.0)
	var before_scatter := echo_target.health.current_health
	var scatter_hit := DamageResult.new()
	scatter_hit.target = echo_origin
	scatter_hit.final_damage = 1
	scatter_hit.packet = DamagePacket.new()
	scatter_hit.packet.source = player
	scatter_hit.packet.source_faction = CombatFaction.Id.PLAYER
	scatter_hit.packet.weapon_id = &"scattergun"
	scatter_hit.packet.is_projectile = true
	scatter_hit.packet.allows_trajectory_echo = false
	root.get_node("CombatEvents").damage_resolved.emit(scatter_hit)
	check(echo_target.health.current_health == before_scatter, "scatter projectiles are excluded from trajectory echo")
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.TRAJECTORY_ECHO_PROCESSOR), 1.0), "excluded attacks do not spend trajectory echo cooldown")

	var ballistic_takeover_protocol := ComponentRolls.create("ballistic_takeover_protocol", 1, rng)
	player.cyberware.set_equipped_item(ballistic_takeover_protocol)
	player.cyberware.set_physics_process(false)
	player.global_position = Vector2(1000.0, 1000.0)
	var takeover_source := echo_origin
	var untargeted_projectile := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	world.add_child(untargeted_projectile)
	untargeted_projectile.global_position = player.global_position + Vector2(10.0, 0.0)
	untargeted_projectile.setup(takeover_source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	untargeted_projectile.status_tags = PackedStringArray(["burn"])
	untargeted_projectile.set_physics_process(false)
	player.cyberware._physics_process(0.0)
	check(untargeted_projectile.faction == CombatFaction.Id.ENEMY, "takeover leaves a hostile projectile unchanged when no enemy target exists")
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.BALLISTIC_TAKEOVER_PROTOCOL), 1.0), "failed takeover does not spend cooldown")
	var takeover_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(takeover_target)
	takeover_target.stationary_test_target = true
	takeover_target.global_position = player.global_position + Vector2(110.0, 0.0)
	await process_frame
	var takeover_scans: Array[bool] = []
	root.get_node("CombatEvents").glitch_scan_requested.connect(func(_position: Vector2, _color: Color, _radius: float, _room: Node) -> void: takeover_scans.append(true))
	player.cyberware._physics_process(0.0)
	check(untargeted_projectile.faction == CombatFaction.Id.PLAYER and untargeted_projectile.source == player, "nearby hostile projectile is reassigned to the player")
	check(untargeted_projectile.homing_target == takeover_target and untargeted_projectile.status_tags.is_empty(), "takeover removes hostile status and guides the projectile to the nearest enemy")
	check(untargeted_projectile.takeover_consumed and takeover_scans.size() == 1, "successful takeover is single-use and publishes the green scan effect")
	check(is_zero_approx(player.cyberware.get_module_readiness(CyberwareController.BALLISTIC_TAKEOVER_PROTOCOL)), "successful takeover starts its six-second cooldown")
	var cooldown_projectile := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	world.add_child(cooldown_projectile)
	cooldown_projectile.global_position = player.global_position + Vector2(16.0, 0.0)
	cooldown_projectile.setup(takeover_source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	cooldown_projectile.set_physics_process(false)
	player.cyberware._physics_process(0.0)
	check(cooldown_projectile.faction == CombatFaction.Id.ENEMY, "takeover ignores additional projectiles during cooldown")
	player.cyberware._physics_process(6.0)
	check(cooldown_projectile.faction == CombatFaction.Id.PLAYER, "takeover becomes ready again after six seconds")
	var area_projectile := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	world.add_child(area_projectile)
	area_projectile.global_position = player.global_position + Vector2(12.0, 0.0)
	area_projectile.setup(takeover_source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	area_projectile.configure_explosion(32.0, 1)
	area_projectile.set_physics_process(false)
	player.cyberware._physics_process(6.0)
	check(area_projectile.faction == CombatFaction.Id.ENEMY, "takeover excludes projectiles with area behavior")
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.BALLISTIC_TAKEOVER_PROTOCOL), 1.0), "excluded area projectile does not spend takeover cooldown")

	var arc_ballistic_cortex := ComponentRolls.create("arc_ballistic_cortex", 1, rng)
	var arc_takeover_compound := ComponentRolls.fuse(ballistic_takeover_protocol, arc_ballistic_cortex, rng)
	player.cyberware.set_equipped_item(arc_takeover_compound)
	var electric_takeover := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	world.add_child(electric_takeover)
	electric_takeover.global_position = player.global_position + Vector2(8.0, 0.0)
	electric_takeover.setup(takeover_source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	electric_takeover.set_physics_process(false)
	player.cyberware._physics_process(0.0)
	check(electric_takeover.faction == CombatFaction.Id.PLAYER and electric_takeover.electric_arc_enabled, "taken-over projectile inherits the installed arc effect")

	player.cyberware.set_equipped_item(arc_ballistic_cortex)
	var electric_projectile := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	world.add_child(electric_projectile)
	electric_projectile.global_position = player.global_position
	electric_projectile.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 520.0)
	electric_projectile.feedback_group_id = 7000
	electric_projectile.set_physics_process(false)
	player.cyberware.configure_projectile(electric_projectile, Vector2.RIGHT)
	check(electric_projectile.electric_arc_enabled, "every player projectile can render the blue-white electric trail")
	var existing_projectile_ids := {}
	for existing in get_nodes_in_group("combat_projectiles"):
		existing_projectile_ids[existing.get_instance_id()] = true
	player.heat.is_overheated = false
	player.heat.set_heat(0.0)
	player.weapons.equip_weapon(load("res://resources/weapons/scattergun.tres"))
	player.weapons.set_cooldown_remaining(0.0)
	check(player.weapons.try_attack(player.global_position, Vector2.RIGHT, player), "scatter weapon fires while arc cortex is installed")
	var electric_pellets: Array[CombatProjectile] = []
	for candidate in get_nodes_in_group("combat_projectiles"):
		if candidate is CombatProjectile and not existing_projectile_ids.has(candidate.get_instance_id()):
			electric_pellets.append(candidate as CombatProjectile)
	var shared_scatter_group := electric_pellets[0].feedback_group_id if not electric_pellets.is_empty() else 0
	var all_pellets_electric := electric_pellets.size() == 5 and shared_scatter_group > 0
	for pellet in electric_pellets:
		all_pellets_electric = all_pellets_electric and pellet.electric_arc_enabled and pellet.feedback_group_id == shared_scatter_group
		pellet.set_physics_process(false)
	check(all_pellets_electric, "all five scatter pellets are electrified and share one attack group")
	var arc_primary := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var arc_neighbor_a := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var arc_neighbor_b := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var arc_spare := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	for arc_enemy in [arc_primary, arc_neighbor_a, arc_neighbor_b, arc_spare]:
		world.add_child(arc_enemy)
		arc_enemy.stationary_test_target = true
	await process_frame
	arc_primary.global_position = Vector2(1400.0, 1000.0)
	arc_neighbor_a.global_position = Vector2(1430.0, 1000.0)
	arc_neighbor_b.global_position = Vector2(1460.0, 1000.0)
	arc_spare.global_position = Vector2(1490.0, 1000.0)
	var arc_health := [
		arc_primary.health.current_health,
		arc_neighbor_a.health.current_health,
		arc_neighbor_b.health.current_health,
		arc_spare.health.current_health,
	]
	var arc_events: Array[bool] = []
	root.get_node("CombatEvents").electric_arc_requested.connect(func(_from: Vector2, _to: Vector2, _room: Node) -> void: arc_events.append(true))
	var arc_hit := DamageResult.new()
	arc_hit.target = arc_primary
	arc_hit.final_damage = 1
	arc_hit.packet = DamagePacket.new()
	arc_hit.packet.source = player
	arc_hit.packet.source_faction = CombatFaction.Id.PLAYER
	arc_hit.packet.source_position = player.global_position
	arc_hit.packet.feedback_group_id = 7001
	arc_hit.packet.is_projectile = true
	root.get_node("CombatEvents").damage_resolved.emit(arc_hit)
	check(arc_primary.state == EnemyController.State.STAGGERED and is_equal_approx(float(arc_primary.get("_stagger_remaining")), 0.2), "direct electric projectile hit paralyzes its primary target for 0.2 seconds")
	check(arc_neighbor_a.state == EnemyController.State.STAGGERED and arc_neighbor_b.state == EnemyController.State.STAGGERED, "electric hit chains to at most two nearby enemies")
	check(arc_spare.state != EnemyController.State.STAGGERED and arc_events.size() >= 3, "electric chain stops after two additional targets and publishes visible arcs")
	check([
		arc_primary.health.current_health,
		arc_neighbor_a.health.current_health,
		arc_neighbor_b.health.current_health,
		arc_spare.health.current_health,
	] == arc_health, "electric arcs add no damage")
	for arc_enemy in [arc_primary, arc_neighbor_a, arc_neighbor_b, arc_spare]:
		arc_enemy.state = EnemyController.State.IDLE
		arc_enemy.set("_stagger_remaining", 0.0)
	arc_hit.target = arc_neighbor_a
	root.get_node("CombatEvents").damage_resolved.emit(arc_hit)
	check(arc_neighbor_a.state != EnemyController.State.STAGGERED, "one scatter attack cannot paralyze a target twice across pellet hits")
	var beam_arc := DamageResult.new()
	beam_arc.target = arc_spare
	beam_arc.final_damage = 2
	beam_arc.packet = arc_hit.packet.duplicate_packet()
	beam_arc.packet.feedback_group_id = 7002
	beam_arc.packet.is_projectile = false
	beam_arc.packet.is_beam = true
	beam_arc.packet.is_area_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(beam_arc)
	check(arc_spare.state == EnemyController.State.STAGGERED, "laser hits trigger electric paralysis even though beam packets use area geometry")
	for arc_enemy in [arc_primary, arc_neighbor_a, arc_neighbor_b, arc_spare]:
		arc_enemy.state = EnemyController.State.IDLE
		arc_enemy.set("_stagger_remaining", 0.0)
	var melee_arc := DamageResult.new()
	melee_arc.target = arc_primary
	melee_arc.final_damage = 1
	melee_arc.packet = arc_hit.packet.duplicate_packet()
	melee_arc.packet.feedback_group_id = 7003
	melee_arc.packet.is_projectile = false
	melee_arc.packet.is_melee = true
	root.get_node("CombatEvents").damage_resolved.emit(melee_arc)
	check(arc_primary.state == EnemyController.State.STAGGERED, "melee hits trigger electric paralysis")
	for arc_enemy in [arc_primary, arc_neighbor_a, arc_neighbor_b, arc_spare]:
		arc_enemy.state = EnemyController.State.IDLE
		arc_enemy.set("_stagger_remaining", 0.0)
	var excluded_arc := DamageResult.new()
	excluded_arc.target = arc_primary
	excluded_arc.final_damage = 1
	excluded_arc.packet = arc_hit.packet.duplicate_packet()
	excluded_arc.packet.feedback_group_id = 7004
	excluded_arc.packet.is_continuous_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_arc)
	excluded_arc.packet.is_continuous_damage = false
	excluded_arc.packet.is_projectile = false
	excluded_arc.packet.is_area_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_arc)
	check(arc_primary.state != EnemyController.State.STAGGERED, "continuous status and secondary area damage cannot trigger the arc cortex")
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.ARC_BALLISTIC_CORTEX), 1.0), "arc ballistic cortex has no internal cooldown")

	var axon_recycler := ComponentRolls.create("axon_recycler", 1, rng)
	var inverter_for_recycler := ComponentRolls.create("inertial_inversion_vertebra", 1, rng)
	var recycler_compound := ComponentRolls.fuse(trajectory_echo_processor, ballistic_takeover_protocol, rng)
	recycler_compound = ComponentRolls.fuse(recycler_compound, inverter_for_recycler, rng)
	recycler_compound = ComponentRolls.fuse(recycler_compound, axon_recycler, rng)
	player.cyberware.set_equipped_item(recycler_compound)
	player.cyberware.set("_trajectory_echo_cooldown_remaining", 4.0)
	player.cyberware.set("_ballistic_takeover_cooldown_remaining", 6.0)
	player.cyberware.set("_inertial_inversion_cooldown_remaining", 3.0)
	player.cyberware.set("_kill_heat_sink_cooldown_remaining", 2.0)
	var recycle_target_a := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	var recycle_target_b := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	world.add_child(recycle_target_a)
	world.add_child(recycle_target_b)
	recycle_target_a.stationary_test_target = true
	recycle_target_b.stationary_test_target = true
	recycle_target_a.global_position = Vector2(2000.0, 1000.0)
	recycle_target_b.global_position = Vector2(2160.0, 1000.0)
	await process_frame
	var recycle_kill := DamageResult.new()
	recycle_kill.target = recycle_target_a
	recycle_kill.target_defeated = true
	recycle_kill.final_damage = 1
	recycle_kill.packet = DamagePacket.new()
	recycle_kill.packet.source = player
	recycle_kill.packet.source_faction = CombatFaction.Id.PLAYER
	recycle_kill.packet.feedback_group_id = 8100
	recycle_kill.packet.is_projectile = true
	root.get_node("CombatEvents").damage_resolved.emit(recycle_kill)
	check(is_equal_approx(float(player.cyberware.get("_trajectory_echo_cooldown_remaining")), 3.25), "direct kill reduces trajectory echo cooldown by 0.75 seconds")
	check(is_equal_approx(float(player.cyberware.get("_ballistic_takeover_cooldown_remaining")), 5.25) and is_equal_approx(float(player.cyberware.get("_inertial_inversion_cooldown_remaining")), 2.25), "axon recycler reduces every other installed cyberware cooldown")
	check(is_equal_approx(float(player.cyberware.get("_kill_heat_sink_cooldown_remaining")), 2.0), "axon recycler leaves unequipped cyberware cooldown state unchanged")
	recycle_kill.target = recycle_target_b
	root.get_node("CombatEvents").damage_resolved.emit(recycle_kill)
	check(is_equal_approx(float(player.cyberware.get("_trajectory_echo_cooldown_remaining")), 3.25), "multiple kills from one attack group recycle cooldown only once")
	recycle_kill.packet.feedback_group_id = 8101
	recycle_kill.packet.is_projectile = false
	recycle_kill.packet.is_beam = true
	root.get_node("CombatEvents").damage_resolved.emit(recycle_kill)
	check(is_equal_approx(float(player.cyberware.get("_trajectory_echo_cooldown_remaining")), 2.5), "a later direct laser kill can recycle cooldown again")
	var before_excluded_recycle := float(player.cyberware.get("_ballistic_takeover_cooldown_remaining"))
	var excluded_recycle := DamageResult.new()
	excluded_recycle.target = recycle_target_a
	excluded_recycle.target_defeated = true
	excluded_recycle.final_damage = 1
	excluded_recycle.packet = DamagePacket.new()
	excluded_recycle.packet.source = player
	excluded_recycle.packet.source_faction = CombatFaction.Id.PLAYER
	excluded_recycle.packet.feedback_group_id = 8102
	excluded_recycle.packet.is_area_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_recycle)
	excluded_recycle.packet.feedback_group_id = 8103
	excluded_recycle.packet.is_projectile = true
	excluded_recycle.packet.is_continuous_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_recycle)
	excluded_recycle.packet.feedback_group_id = 8104
	excluded_recycle.packet.is_continuous_damage = false
	excluded_recycle.packet.source = world
	root.get_node("CombatEvents").damage_resolved.emit(excluded_recycle)
	check(is_equal_approx(float(player.cyberware.get("_ballistic_takeover_cooldown_remaining")), before_excluded_recycle), "secondary area, continuous, and environment kills cannot trigger axon recycling")
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.AXON_RECYCLER), 1.0), "axon recycler itself is always ready")

	var micro_rotor := ComponentRolls.create("micro_rotor_reflex_bundle", 1, rng)
	player.cyberware.set_equipped_item(micro_rotor)
	var pistol_data := load("res://resources/weapons/service_pistol.tres") as WeaponComponentData
	player.weapons.equip_weapon(pistol_data)
	player.weapons.set_cooldown_remaining(1.0)
	var pistol_duration := player.weapons.get_cooldown_duration_for_weapon_id(pistol_data.id)
	var rotor_hit := DamageResult.new()
	rotor_hit.target = recycle_target_a
	rotor_hit.final_damage = 1
	rotor_hit.packet = DamagePacket.new()
	rotor_hit.packet.source = player
	rotor_hit.packet.source_faction = CombatFaction.Id.PLAYER
	rotor_hit.packet.weapon_id = pistol_data.id
	rotor_hit.packet.feedback_group_id = 9100
	rotor_hit.packet.is_projectile = true
	root.get_node("CombatEvents").damage_resolved.emit(rotor_hit)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - pistol_duration * 0.25), "micro rotor refunds 25 percent of a direct pistol hit cooldown")
	root.get_node("CombatEvents").damage_resolved.emit(rotor_hit)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - pistol_duration * 0.25), "one attack group cannot stack repeated hit refunds")
	rotor_hit.target_defeated = true
	root.get_node("CombatEvents").damage_resolved.emit(rotor_hit)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - pistol_duration * 0.50), "a later kill in the same attack group supplements the refund to 50 percent")
	root.get_node("CombatEvents").damage_resolved.emit(rotor_hit)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - pistol_duration * 0.50), "one attack group never refunds more than its 50 percent kill allowance")

	var scatter_data := load("res://resources/weapons/scattergun.tres") as WeaponComponentData
	player.weapons.equip_weapon(scatter_data)
	player.weapons.set_cooldown_remaining(1.0)
	var scatter_duration := player.weapons.get_cooldown_duration_for_weapon_id(scatter_data.id)
	var rotor_scatter_hit := DamageResult.new()
	rotor_scatter_hit.target = recycle_target_a
	rotor_scatter_hit.final_damage = 1
	rotor_scatter_hit.packet = DamagePacket.new()
	rotor_scatter_hit.packet.source = player
	rotor_scatter_hit.packet.source_faction = CombatFaction.Id.PLAYER
	rotor_scatter_hit.packet.weapon_id = scatter_data.id
	rotor_scatter_hit.packet.feedback_group_id = 9101
	rotor_scatter_hit.packet.is_projectile = true
	root.get_node("CombatEvents").damage_resolved.emit(rotor_scatter_hit)
	rotor_scatter_hit.target = recycle_target_b
	root.get_node("CombatEvents").damage_resolved.emit(rotor_scatter_hit)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - scatter_duration * 0.25), "scatter pellets share one 25 percent refund across every target")

	var beam_data := load("res://resources/weapons/rail_cannon.tres") as WeaponComponentData
	player.weapons.equip_weapon(beam_data)
	player.weapons.set_cooldown_remaining(1.0)
	var beam_duration := player.weapons.get_cooldown_duration_for_weapon_id(beam_data.id)
	var beam_hit := DamageResult.new()
	beam_hit.target = recycle_target_a
	beam_hit.final_damage = 1
	beam_hit.packet = DamagePacket.new()
	beam_hit.packet.source = player
	beam_hit.packet.source_faction = CombatFaction.Id.PLAYER
	beam_hit.packet.weapon_id = beam_data.id
	beam_hit.packet.feedback_group_id = 9102
	beam_hit.packet.is_beam = true
	root.get_node("CombatEvents").damage_resolved.emit(beam_hit)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - beam_duration * 0.25), "direct laser hits trigger the micro rotor refund")

	var baton_data := load("res://resources/weapons/baton.tres") as WeaponComponentData
	player.weapons.equip_weapon(baton_data)
	player.weapons.set_cooldown_remaining(1.0)
	var baton_duration := player.weapons.get_cooldown_duration_for_weapon_id(baton_data.id)
	var melee_kill := DamageResult.new()
	melee_kill.target = recycle_target_a
	melee_kill.target_defeated = true
	melee_kill.final_damage = 1
	melee_kill.packet = DamagePacket.new()
	melee_kill.packet.source = player
	melee_kill.packet.source_faction = CombatFaction.Id.PLAYER
	melee_kill.packet.weapon_id = baton_data.id
	melee_kill.packet.feedback_group_id = 9103
	melee_kill.packet.is_melee = true
	root.get_node("CombatEvents").damage_resolved.emit(melee_kill)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0 - baton_duration * 0.50), "direct melee kills trigger the 50 percent micro rotor refund")

	player.weapons.set_cooldown_remaining(1.0)
	var excluded_rotor := DamageResult.new()
	excluded_rotor.target = recycle_target_a
	excluded_rotor.final_damage = 1
	excluded_rotor.packet = DamagePacket.new()
	excluded_rotor.packet.source = player
	excluded_rotor.packet.source_faction = CombatFaction.Id.PLAYER
	excluded_rotor.packet.weapon_id = baton_data.id
	excluded_rotor.packet.feedback_group_id = 9104
	excluded_rotor.packet.is_area_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_rotor)
	excluded_rotor.packet.feedback_group_id = 9105
	excluded_rotor.packet.is_area_damage = false
	excluded_rotor.packet.is_projectile = true
	excluded_rotor.packet.is_continuous_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_rotor)
	excluded_rotor.packet.feedback_group_id = 9106
	excluded_rotor.packet.is_continuous_damage = false
	excluded_rotor.packet.source = world
	root.get_node("CombatEvents").damage_resolved.emit(excluded_rotor)
	check(is_equal_approx(player.weapons.get_cooldown_remaining(), 1.0), "secondary area, continuous, and environment damage cannot trigger micro rotor refunds")
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.MICRO_ROTOR_REFLEX_BUNDLE), 1.0), "micro rotor reflex bundle has no internal cooldown")

	var predatory_ring := ComponentRolls.create("predatory_vestibular_ring", 1, rng)
	player.cyberware.set_equipped_item(predatory_ring)
	player.dash.cooldown_remaining = 0.8
	var predatory_kill := DamageResult.new()
	predatory_kill.target = recycle_target_a
	predatory_kill.target_defeated = true
	predatory_kill.final_damage = 1
	predatory_kill.packet = DamagePacket.new()
	predatory_kill.packet.source = player
	predatory_kill.packet.source_faction = CombatFaction.Id.PLAYER
	predatory_kill.packet.weapon_id = pistol_data.id
	predatory_kill.packet.feedback_group_id = 9200
	predatory_kill.packet.is_projectile = true
	root.get_node("CombatEvents").damage_resolved.emit(predatory_kill)
	check(is_zero_approx(player.dash.cooldown_remaining), "direct weapon kill immediately refreshes dash cooldown")
	player.dash.cooldown_remaining = 0.7
	predatory_kill.target = recycle_target_b
	root.get_node("CombatEvents").damage_resolved.emit(predatory_kill)
	check(is_equal_approx(player.dash.cooldown_remaining, 0.7), "multiple kills from one attack group refresh dash only once")

	player.dash.reset_transient_state()
	check(player.dash.start_dash(player, Vector2.RIGHT), "predatory ring fixture starts an active dash")
	predatory_kill.packet.feedback_group_id = 9201
	predatory_kill.packet.is_projectile = false
	predatory_kill.packet.is_beam = true
	root.get_node("CombatEvents").damage_resolved.emit(predatory_kill)
	check(player.dash.is_dashing() and player.dash.cooldown_remaining > 0.0, "kill during a dash defers the refresh until that dash ends")
	player.dash.cancel_dash(false)
	check(not player.dash.is_dashing() and is_zero_approx(player.dash.cooldown_remaining), "deferred predatory refresh is applied when the active dash ends")

	player.dash.cooldown_remaining = 0.9
	var excluded_predatory := DamageResult.new()
	excluded_predatory.target = recycle_target_a
	excluded_predatory.target_defeated = true
	excluded_predatory.final_damage = 1
	excluded_predatory.packet = DamagePacket.new()
	excluded_predatory.packet.source = player
	excluded_predatory.packet.source_faction = CombatFaction.Id.PLAYER
	excluded_predatory.packet.weapon_id = baton_data.id
	excluded_predatory.packet.feedback_group_id = 9202
	excluded_predatory.packet.is_area_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_predatory)
	excluded_predatory.packet.feedback_group_id = 9203
	excluded_predatory.packet.is_area_damage = false
	excluded_predatory.packet.is_melee = true
	excluded_predatory.packet.is_continuous_damage = true
	root.get_node("CombatEvents").damage_resolved.emit(excluded_predatory)
	excluded_predatory.packet.feedback_group_id = 9204
	excluded_predatory.packet.is_continuous_damage = false
	excluded_predatory.packet.weapon_id = &""
	root.get_node("CombatEvents").damage_resolved.emit(excluded_predatory)
	excluded_predatory.packet.feedback_group_id = 9205
	excluded_predatory.packet.weapon_id = baton_data.id
	excluded_predatory.packet.source = world
	root.get_node("CombatEvents").damage_resolved.emit(excluded_predatory)
	check(is_equal_approx(player.dash.cooldown_remaining, 0.9), "secondary area, continuous, non-weapon, and environment kills cannot refresh dash")

	player.dash.reset_transient_state()
	check(player.dash.start_dash(player, Vector2.RIGHT), "pending refresh lifecycle fixture starts another dash")
	predatory_kill.packet.feedback_group_id = 9206
	predatory_kill.packet.is_beam = false
	predatory_kill.packet.is_melee = true
	predatory_kill.packet.weapon_id = baton_data.id
	root.get_node("CombatEvents").damage_resolved.emit(predatory_kill)
	player.cyberware.set_equipped_item(micro_rotor)
	player.dash.cancel_dash(false)
	check(player.dash.cooldown_remaining > 0.0, "unequipping predatory ring clears a deferred dash refresh")
	player.cyberware.set_equipped_item(predatory_ring)
	check(is_equal_approx(player.cyberware.get_module_readiness(CyberwareController.PREDATORY_VESTIBULAR_RING), 1.0), "predatory vestibular ring has no internal cooldown")
	player.cyberware.set_physics_process(true)

	player.inventory.cyberware_slot.equip(compound)
	player.inventory._apply_equipment()
	var run_state := player.inventory.export_run_state()
	check(not run_state.cyberware.is_empty(), "same-run snapshot retains equipped cyberware")
	var restored := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(restored)
	await process_frame
	restored.inventory.import_run_state(run_state)
	check(restored.cyberware.has_module(CyberwareController.SMART_FIRE) and restored.cyberware.has_module(CyberwareController.EXPLOSIVE_MAGAZINE), "serialized compound restores its complete module set")
	var bag_cyberware := ComponentRolls.create("optical_intruder", 1, rng)
	check(player.inventory.backpack.add_item(bag_cyberware), "settlement fixture includes backpack cyberware")
	var before_settlement := player.inventory.export_run_state()
	var settlement := player.export_settlement_state(true)
	check(settlement.inventory.cyberware.is_empty(), "successful settlement clears equipped cyberware")
	var expected_bag: Array = []
	for item in player.inventory.backpack.get_items():
		if item.get_property("slot", "") != "cyberware":
			expected_bag.append(item.serialize())
	check(settlement.inventory.backpack.get("items", []) == expected_bag, "successful settlement removes backpack cyberware and preserves ordinary items")
	check(settlement.inventory.primary == before_settlement.primary and settlement.inventory.defense == before_settlement.defense, "successful settlement retains ordinary equipped items")
	check(player.inventory.export_run_state() == before_settlement, "building settlement does not mutate the current run on save failure")
	var recovery := player.inventory.export_recovery_inventory()
	check(recovery.cyberware.is_empty(), "action recovery clears equipped cyberware")

	world.queue_free()
	await process_frame
	print("Cyberware failures: ", failures)
	quit(0 if failures == 0 else 1)
