extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func make_wall(parent: Node2D, center: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = center
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	parent.add_child(wall)
	return wall


func run_checks() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	player.global_position = Vector2(100.0, 100.0)
	arena.add_child(player)
	var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	enemy.stationary_test_target = true
	enemy.profile = load("res://resources/enemies/heavy_anchor.tres")
	enemy.global_position = Vector2(150.0, 100.0)
	arena.add_child(enemy)
	await process_frame

	check(player.persona_combat != null, "player mounts persona combat runtime")
	player.persona_combat.set_physics_process(false)
	player.talent_core.consume_persona_drink(TalentCoreController.DEEP_NINJA)
	player.talent_core.set_talent_choice(TalentCoreController.DEEP_NINJA, 1, &"gaze")
	player.equip_weapon(load("res://resources/weapons/service_pistol.tres"))
	player.weapons.reset_transient_state()
	var ai_attacks := [0]
	player.weapons.attack_performed.connect(func(_data: WeaponComponentData) -> void: ai_attacks[0] += 1)
	player.persona_combat._physics_process(0.3)
	player.persona_combat._physics_process(0.3)
	check(player.persona_combat.marked_target == enemy, "new scene establishes an initial hunt mark")
	check(ai_attacks[0] == 0, "initial scene mark never triggers an automatic shot")
	var next_enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	next_enemy.stationary_test_target = true
	next_enemy.profile = load("res://resources/enemies/heavy_anchor.tres")
	next_enemy.global_position = Vector2(210.0, 100.0)
	arena.add_child(next_enemy)
	await process_frame
	var marked_defeat := DamageResult.new()
	marked_defeat.packet = DamagePacket.new()
	marked_defeat.packet.source = player
	marked_defeat.final_damage = 1
	marked_defeat.target_defeated = true
	player.persona_combat._on_deep_ninja_hit(enemy, marked_defeat)
	player.persona_combat._physics_process(0.2)
	check(player.persona_combat.marked_target == next_enemy and ai_attacks[0] == 1, "defeating a marked enemy still lets Gaze fire once at the next mark")
	player.persona_combat._set_mark(enemy)
	var player_hit := DamagePacket.new()
	player_hit.base_damage = 0
	player_hit.source = player
	player_hit.source_faction = CombatFaction.Id.PLAYER
	player_hit.source_position = player.global_position
	player_hit.travel_direction = Vector2.RIGHT
	enemy.hurt_box.receive_hit(player_hit)
	check(player.persona_combat.marked_target == enemy, "deep ninja moves execution mark to damaged enemy")

	# Reproduce the reported narrow-lane lock: the preferred behind-target point
	# has no meaningful vertical escape room. The takeover must choose another
	# candidate and cancel any dash that would keep forcing its old direction.
	enemy.facing = Vector2.RIGHT
	var upper_wall := make_wall(arena, Vector2(122.0, 88.0), Vector2(34.0, 8.0))
	var lower_wall := make_wall(arena, Vector2(122.0, 112.0), Vector2(34.0, 8.0))
	await physics_frame
	check(player.dash.start_dash(player, Vector2.RIGHT, Vector2.RIGHT), "fixture starts a locked-direction dash before emergency relocation")
	player.persona_combat._execute_deep_takeover()
	var landing_transform := player.global_transform
	var up_blocked := player.test_move(landing_transform, Vector2.UP * 14.0, null, 0.08, true)
	var down_blocked := player.test_move(landing_transform, Vector2.DOWN * 14.0, null, 0.08, true)
	check(not player.dash.is_dashing() and player.velocity.is_zero_approx(), "emergency relocation releases the previous dash and movement velocity")
	check(not (up_blocked and down_blocked), "emergency relocation avoids a landing that traps vertical movement")
	upper_wall.queue_free()
	lower_wall.queue_free()
	player.global_position = Vector2(100.0, 100.0)
	player.aim_direction = Vector2.RIGHT
	player.hurt_box.clear_invulnerability()
	player.dash.reset_transient_state()
	await physics_frame
	player.talent_core.set_persona_level(TalentCoreController.DEEP_NINJA, 3)
	player.talent_core.set_talent_choice(TalentCoreController.DEEP_NINJA, 3, &"shared_hunt_resonance")
	player.persona_combat.set("_resonance_remaining", 6.0)
	player.hurt_box.clear_invulnerability()
	var terrain_hit := DamagePacket.new()
	terrain_hit.base_damage = 1
	terrain_hit.source_faction = CombatFaction.Id.ENVIRONMENT
	terrain_hit.is_area_damage = true
	check(player.receive_damage(terrain_hit).final_damage == 0, "wind-fire buff ignores environmental and barrel-style terrain damage")
	var enemy_explosion := terrain_hit.duplicate_packet()
	enemy_explosion.source = enemy
	enemy_explosion.source_faction = CombatFaction.Id.ENEMY
	enemy_explosion.damage_type = &"explosive"
	check(player.receive_damage(enemy_explosion).final_damage == 1, "enemy explosive attacks are not classified as terrain damage")
	player.health.set_current_health(player.health.max_health)
	player.hurt_box.clear_invulnerability()
	var enemy_rock_safe_position := enemy.global_position
	var next_enemy_rock_safe_position := next_enemy.global_position
	enemy.global_position = Vector2(5000.0, 5000.0)
	next_enemy.global_position = Vector2(5100.0, 5000.0)

	player.talent_core.consume_persona_drink(TalentCoreController.ROCK_VIGILANTE)
	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 1, &"steady_beat")
	player.talent_core.set_persona(TalentCoreController.ROCK_VIGILANTE)
	var test_baton := (load("res://resources/weapons/baton.tres") as WeaponComponentData).duplicate(true) as WeaponComponentData
	test_baton.heat_per_attack = 10.0
	player.equip_weapon(test_baton)
	player.weapons.reset_transient_state()
	player.heat.set_heat(0.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "rock persona can use ordinary weapon path")
	check(is_equal_approx(player.persona_combat.rock_feedback, 10.0 / player.heat.effective_max() * 100.0), "rock firing feedback follows base heat divided by effective heat capacity")
	check(is_equal_approx(player.heat.current_heat, 7.5), "steady beat reduces attack heat by 25 percent before accumulation")
	player.persona_combat._set_rock_feedback(50.0)
	check(is_equal_approx(player.dash.persona_walk_speed_bonus, 0.10), "half feedback grants half of the movement bonus")
	check(is_equal_approx(player.heat.persona_cooling_bonus, 0.25), "half feedback grants half of the cooling bonus")
	check(is_equal_approx(player.weapons.persona_attack_speed_bonus, 0.15), "half feedback grants half of the attack-speed bonus")
	check(is_zero_approx(player.dash.equipment_speed_bonus), "rock feedback does not increase dash speed")

	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 1, &"distortion_gain")
	var pistol := load("res://resources/weapons/service_pistol.tres") as WeaponComponentData
	player.equip_weapon(pistol)
	player.persona_combat._set_rock_feedback(60.0)
	var burst_primary := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	burst_primary.stationary_test_target = true
	burst_primary.profile = load("res://resources/enemies/heavy_anchor.tres")
	burst_primary.global_position = Vector2(150.0, 100.0)
	arena.add_child(burst_primary)
	var burst_neighbor := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	burst_neighbor.stationary_test_target = true
	burst_neighbor.profile = load("res://resources/enemies/heavy_anchor.tres")
	burst_neighbor.global_position = Vector2(180.0, 100.0)
	arena.add_child(burst_neighbor)
	await physics_frame
	var distortion_context := player.persona_combat.get_attack_context(pistol)
	check(bool(distortion_context.get("distortion_burst", false)), "distortion is stamped when a projectile is fired at sixty percent feedback")
	player.persona_combat.prepare_attack_group(9001, distortion_context)
	var distortion_hit := DamageResult.new()
	distortion_hit.packet = DamagePacket.new()
	distortion_hit.packet.source = player
	distortion_hit.packet.source_faction = CombatFaction.Id.PLAYER
	distortion_hit.packet.weapon_id = pistol.id
	distortion_hit.packet.feedback_group_id = 9001
	distortion_hit.target = burst_primary
	distortion_hit.final_damage = 1
	var neighbor_health := burst_neighbor.health.current_health
	var primary_health := burst_primary.health.current_health
	player.persona_combat._on_damage_resolved(distortion_hit)
	player.persona_combat._on_damage_resolved(distortion_hit)
	check(burst_neighbor.health.current_health == neighbor_health - 1, "one firing group produces only one distortion burst")
	check(burst_primary.health.current_health == primary_health, "distortion burst does not damage the direct-hit target again")
	burst_neighbor.global_position = Vector2(240.0, 100.0)
	var blocked_neighbor := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	blocked_neighbor.stationary_test_target = true
	blocked_neighbor.profile = load("res://resources/enemies/heavy_anchor.tres")
	blocked_neighbor.global_position = Vector2(190.0, 100.0)
	arena.add_child(blocked_neighbor)
	var burst_wall := make_wall(arena, Vector2(170.0, 100.0), Vector2(6.0, 34.0))
	await physics_frame
	player.persona_combat.prepare_attack_group(9002, distortion_context)
	distortion_hit.packet.feedback_group_id = 9002
	var blocked_health := blocked_neighbor.health.current_health
	player.persona_combat._on_damage_resolved(distortion_hit)
	check(blocked_neighbor.health.current_health == blocked_health, "distortion burst cannot damage an enemy through a wall")
	burst_wall.queue_free()
	burst_primary.queue_free()
	burst_neighbor.queue_free()
	blocked_neighbor.queue_free()
	await physics_frame

	player.talent_core.set_persona_level(TalentCoreController.ROCK_VIGILANTE, 2)
	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 2, &"overload_scream")
	var wave_target := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	wave_target.stationary_test_target = true
	wave_target.profile = load("res://resources/enemies/heavy_anchor.tres")
	wave_target.global_position = Vector2(170.0, 100.0)
	arena.add_child(wave_target)
	var wave_wall := make_wall(arena, Vector2(135.0, 100.0), Vector2(6.0, 34.0))
	await physics_frame
	var wave_health := wave_target.health.current_health
	player.heat.set_heat(player.heat.effective_max())
	player.heat.is_overheated = true
	player.persona_combat._on_overheated()
	check(wave_target.health.current_health == wave_health - 1, "overload scream pulses immediately and passes through walls")
	player.persona_combat._tick_rock_vigilante(1.0)
	check(wave_target.health.current_health == wave_health - 2, "overload scream repeats once per overheated second")
	player.heat.is_overheated = false
	player.persona_combat._on_heat_recovered()
	wave_wall.queue_free()
	wave_target.queue_free()
	await physics_frame

	player.talent_core.set_persona_level(TalentCoreController.ROCK_VIGILANTE, 3)
	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 3, &"encore_autopilot")
	player.persona_combat.rock_feedback = 99.0
	player.weapons.reset_transient_state()
	player.heat.set_heat(0.0)
	check(player.perform_persona_attack(Vector2.RIGHT) and player.persona_combat.is_nuclear_frenzy_active(), "full feedback enters the four-second nuclear frenzy")
	check(is_equal_approx(float(player.persona_combat.get("_encore_remaining")), 4.0), "nuclear frenzy starts with four full seconds")
	player.heat.set_heat(player.heat.effective_max())
	player.heat.is_overheated = true
	var encore_before_overheat := float(player.persona_combat.get("_encore_remaining"))
	var feedback_before_overheat := player.persona_combat.rock_feedback
	player.persona_combat._on_overheated()
	check(is_equal_approx(float(player.persona_combat.get("_encore_remaining")), encore_before_overheat) and is_equal_approx(player.persona_combat.rock_feedback, feedback_before_overheat), "overheating does not shorten frenzy or cut its feedback")
	player.weapons.set_cooldown_remaining(99.0)
	var movement_input := InputEventAction.new()
	movement_input.action = "move_right"
	movement_input.pressed = true
	player.persona_combat.notify_player_input(movement_input)
	check(player.persona_combat.is_nuclear_frenzy_active(), "nuclear frenzy is not an AI soft takeover and player input does not cancel it")
	check(player.perform_persona_attack(Vector2.RIGHT), "nuclear frenzy attacks through both cooldown and overheat")
	check(player.heat.current_heat > player.heat.effective_max(), "nuclear frenzy stores doubled heat in the darker overflow channel")
	player.persona_combat._tick_rock_vigilante(2.1)
	check(player.persona_combat.is_nuclear_frenzy_active() and is_equal_approx(player.persona_combat.rock_feedback, 47.5), "frenzy remains active after two seconds and feedback falls linearly")
	player.persona_combat._tick_rock_vigilante(2.0)
	check(not player.persona_combat.is_nuclear_frenzy_active() and player.heat.current_heat > player.heat.effective_max(), "overflow remains after the four-second frenzy until normal cooling removes it")

	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 1, &"calibrated_window")
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 3, &"master_loop")
	player.talent_core.set_persona(TalentCoreController.LEGENDARY_MASTER)
	enemy.global_position = enemy_rock_safe_position
	next_enemy.global_position = next_enemy_rock_safe_position
	enemy.health.set_current_health(enemy.health.max_health)
	next_enemy.health.set_current_health(next_enemy.health.max_health)
	await physics_frame
	var calibration_hit := DamagePacket.new()
	calibration_hit.source = enemy
	calibration_hit.source_faction = CombatFaction.Id.ENEMY
	calibration_hit.source_position = enemy.global_position
	calibration_hit.travel_direction = Vector2.LEFT
	calibration_hit.is_melee = true
	player.persona_combat._tick_master_analysis(1.0)
	check(int(player.persona_combat.get_runtime_snapshot().analysis_samples) == 1, "master shows partial progress after one visible second")
	var enemy_analysis_position := enemy.global_position
	var next_enemy_analysis_position := next_enemy.global_position
	enemy.global_position = Vector2(5000.0, 5000.0)
	next_enemy.global_position = Vector2(5100.0, 5000.0)
	player.persona_combat._tick_master_analysis(0.1)
	enemy.global_position = enemy_analysis_position
	next_enemy.global_position = next_enemy_analysis_position
	player.persona_combat._tick_master_analysis(1.0)
	check(int(player.persona_combat.get_runtime_snapshot().analysis_samples) == 1, "los interruption resets unfinished analysis progress")
	player.persona_combat._tick_master_analysis(1.0)
	check(int(player.persona_combat.get_runtime_snapshot().analyzed_attack_count) == 2, "master analyzes all visible enemies in parallel after two continuous seconds")
	check(int(player.persona_combat.get_runtime_snapshot().prediction_source_count) == 2, "master retains every visible analyzed source")
	check(is_equal_approx(float(player.persona_combat.get_runtime_snapshot().master_loop_remaining), 6.0), "master loop starts with the full six-second duration")
	var master_input := InputEventAction.new()
	master_input.action = &"move_right"
	master_input.pressed = true
	player.persona_combat.notify_player_input(master_input)
	check(is_equal_approx(float(player.persona_combat.get_runtime_snapshot().master_loop_remaining), 3.0), "player combat input caps master loop at three seconds without cancelling it")
	player.persona_combat._tick_temporary_bonuses(1.0)
	player.persona_combat.notify_player_input(master_input)
	check(is_equal_approx(float(player.persona_combat.get_runtime_snapshot().master_loop_remaining), 2.0), "repeated input neither cancels nor extends the reduced master loop")
	player.persona_combat._trigger_master_loop_once()
	check(is_equal_approx(float(player.persona_combat.get_runtime_snapshot().master_loop_remaining), 6.0), "a new analysis trigger refreshes the full master loop")
	Input.action_press(&"move_right")
	player.persona_combat._trigger_master_loop_once()
	Input.action_release(&"move_right")
	check(is_equal_approx(float(player.persona_combat.get_runtime_snapshot().master_loop_remaining), 3.0), "master loop starts reduced when player control is already held")
	player.guard.begin_guard(Vector2.RIGHT)
	player.guard.advance_timing(player.guard.startup_seconds)
	player.try_persona_guard(calibration_hit)
	check(float(player.guard.get("_state_duration")) >= player.guard.perfect_seconds + 0.19, "calibrated window adds 0.2 seconds only for an analyzed attack")
	player.guard.reset_to_idle()
	for _validation in 3:
		player.guard.reset_to_idle()
		player.guard.begin_guard(Vector2.RIGHT)
		player.guard.advance_timing(player.guard.startup_seconds)
		var validation_hit := DamagePacket.new()
		validation_hit.base_damage = 1
		validation_hit.source = enemy
		validation_hit.source_faction = CombatFaction.Id.ENEMY
		validation_hit.source_position = enemy.global_position
		validation_hit.travel_direction = Vector2.LEFT
		validation_hit.is_melee = true
		var validation_result := player.receive_damage(validation_hit)
		check(validation_result.perfect, "manual validation resolves inside the perfect window")
	check(player.talent_core.get_relationship_stage(TalentCoreController.LEGENDARY_MASTER) == 1, "three manual validations advance hidden master rapport")
	player.talent_core.respec_persona(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 1, &"proxy_stance")
	player.guard.reset_to_idle()
	player.weapons.reset_transient_state()
	var analyzed_incoming := DamagePacket.new()
	analyzed_incoming.base_damage = 1
	analyzed_incoming.source = enemy
	analyzed_incoming.source_faction = CombatFaction.Id.ENEMY
	analyzed_incoming.source_position = enemy.global_position
	analyzed_incoming.travel_direction = Vector2.LEFT
	analyzed_incoming.is_melee = true
	var proxy_result := player.receive_damage(analyzed_incoming)
	check(proxy_result.blocked and proxy_result.final_damage == 0, "proxy stance performs a normal guard against analyzed attacks")

	player.talent_core.set_persona(TalentCoreController.ROCK_VIGILANTE)
	player.guard.reset_to_idle()
	player.health.set_current_health(1)
	await process_frame
	await process_frame
	check(player.talent_core.takeover_charges == 0, "rock emergency takeover consumes its charge only after launching a valid attack")

	arena.queue_free()
	await process_frame
	print("Persona combat failures: ", failures)
	quit(0 if failures == 0 else 1)
