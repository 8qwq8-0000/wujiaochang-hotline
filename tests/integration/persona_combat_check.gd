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
	player.talent_core.set_persona_level(TalentCoreController.ROCK_VIGILANTE, 3)
	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 3, &"encore_autopilot")
	player.persona_combat.rock_feedback = 99.0
	player.weapons.reset_transient_state()
	player.heat.set_heat(0.0)
	check(player.perform_persona_attack(Vector2.RIGHT) and player.persona_combat.is_nuclear_frenzy_active(), "full feedback enters the two-second nuclear frenzy")
	player.heat.set_heat(player.heat.effective_max())
	player.heat.is_overheated = true
	player.weapons.set_cooldown_remaining(99.0)
	var movement_input := InputEventAction.new()
	movement_input.action = "move_right"
	movement_input.pressed = true
	player.persona_combat.notify_player_input(movement_input)
	check(player.persona_combat.is_nuclear_frenzy_active(), "nuclear frenzy is not an AI soft takeover and player input does not cancel it")
	check(player.perform_persona_attack(Vector2.RIGHT), "nuclear frenzy attacks through both cooldown and overheat")
	check(player.heat.current_heat > player.heat.effective_max(), "nuclear frenzy stores doubled heat in the darker overflow channel")
	player.persona_combat._tick_rock_vigilante(2.1)
	check(not player.persona_combat.is_nuclear_frenzy_active() and player.heat.current_heat > player.heat.effective_max(), "overflow remains after frenzy until normal cooling removes it")

	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 1, &"calibrated_window")
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 3, &"open_model")
	player.talent_core.set_persona(TalentCoreController.LEGENDARY_MASTER)
	var calibration_hit := DamagePacket.new()
	calibration_hit.source = enemy
	calibration_hit.source_faction = CombatFaction.Id.ENEMY
	calibration_hit.source_position = enemy.global_position
	calibration_hit.travel_direction = Vector2.LEFT
	calibration_hit.is_melee = true
	for _sample in 2:
		player.persona_combat._on_enemy_attack_performed(enemy, &"kinetic", true)
	check(int(player.persona_combat.get_runtime_snapshot().analyzed_attack_count) == 1, "master analyzes a repeated attack pattern")
	check(int(player.persona_combat.get_runtime_snapshot().prediction_source_count) == 1, "open model retains a prediction source for analyzed attacks")
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
