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

	# A level-one emergency takeover must create distance, regardless of facing.
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		player.global_position = Vector2(400, 300)
		enemy.global_position = player.global_position + direction * 80.0
		enemy.facing = direction
		await physics_frame
		var landing := player.persona_combat._find_safe_takeover_landing(enemy)
		check(not landing.is_empty(), "emergency retreat finds an open landing in every direction")
		if not landing.is_empty():
			var motion: Vector2 = landing.position - player.global_position
			check(motion.dot(-direction) > 0.0, "retreat moves away from enemy instead of behind its back")
			check(landing.position.distance_to(enemy.global_position) > 80.0, "retreat increases enemy separation")
	player.global_position = Vector2(400, 300)
	enemy.global_position = Vector2(480, 300)
	var retreat_wall := make_wall(arena, Vector2(350, 300), Vector2(12, 50))
	await physics_frame
	var side_landing := player.persona_combat._find_safe_takeover_landing(enemy)
	check(not side_landing.is_empty(), "blocked retreat can find a safe diagonal alternative")
	if not side_landing.is_empty():
		check(not player.test_move(player.global_transform, side_landing.position - player.global_position), "retreat never crosses the blocking wall")
		check(side_landing.position.distance_to(enemy.global_position) > 80.0, "diagonal retreat still increases separation")
	retreat_wall.queue_free()
	await physics_frame
	var second_enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	second_enemy.stationary_test_target = true
	second_enemy.position = Vector2(300, 300)
	arena.add_child(second_enemy)
	await physics_frame
	var crowd_landing := player.persona_combat._find_safe_takeover_landing(enemy)
	check(not crowd_landing.is_empty(), "retreat finds an escape between multiple threats")
	if not crowd_landing.is_empty():
		check(crowd_landing.position.distance_to(enemy.global_position) > 80 and crowd_landing.position.distance_to(second_enemy.global_position) > 80, "retreat does not escape one enemy into another")
	second_enemy.queue_free()
	await physics_frame
	var retreat_origin := player.global_position
	player.talent_core.refill_takeover_charges()
	player.health.set_current_health(1)
	await process_frame
	await process_frame
	check(player.global_position.distance_to(enemy.global_position) > retreat_origin.distance_to(enemy.global_position), "actual one-HP level-one takeover retreats from enemy")
	check(player.talent_core.takeover_charges == 0 and player.hurt_box.is_invulnerable(), "successful retreat consumes one charge and grants invulnerability")
	player.health.configure_max_health(3)
	player.hurt_box.clear_invulnerability()
	player.global_position = Vector2(100, 100)
	enemy.global_position = Vector2(150, 100)
	await physics_frame

	player.talent_core.consume_persona_drink(TalentCoreController.ROCK_VIGILANTE)
	player.talent_core.set_talent_choice(TalentCoreController.ROCK_VIGILANTE, 1, &"steady_beat")
	player.talent_core.set_persona(TalentCoreController.ROCK_VIGILANTE)
	var test_baton := (load("res://resources/weapons/baton.tres") as WeaponComponentData).duplicate(true) as WeaponComponentData
	test_baton.heat_per_attack = 10.0
	player.equip_weapon(test_baton)
	player.weapons.reset_transient_state()
	player.heat.set_heat(0.0)
	check(player.perform_persona_attack(Vector2.RIGHT), "rock persona can use ordinary weapon path")
	check(player.persona_combat.rock_feedback > 0.0, "rock attack builds stage feedback")
	check(player.heat.current_heat < player.weapons.get_current_weapon().heat_per_attack, "steady beat refunds part of attack heat")

	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER)
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 1, &"calibrated_window")
	player.talent_core.set_talent_choice(TalentCoreController.LEGENDARY_MASTER, 3, &"open_model")
	player.talent_core.set_persona(TalentCoreController.LEGENDARY_MASTER)
	check(player.guard.equipment_window_bonus >= 0.039, "calibrated window extends perfect guard timing")
	for _sample in 2:
		var incoming := DamagePacket.new()
		incoming.base_damage = 0
		incoming.source = enemy
		incoming.source_faction = CombatFaction.Id.ENEMY
		incoming.source_position = enemy.global_position
		incoming.travel_direction = Vector2.LEFT
		incoming.is_melee = true
		player.receive_damage(incoming)
	check(int(player.persona_combat.get_runtime_snapshot().analyzed_attack_count) == 1, "master analyzes a repeated attack pattern")
	check(int(player.persona_combat.get_runtime_snapshot().prediction_source_count) == 1, "open model retains a prediction source for analyzed attacks")
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
