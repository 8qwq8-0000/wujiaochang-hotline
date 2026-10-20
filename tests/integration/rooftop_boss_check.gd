extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func hit(damage: int = 99) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = damage
	packet.source_faction = CombatFaction.Id.PLAYER
	return packet

func run() -> void:
	var arena: RooftopBossArena = load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate()
	arena.attack_loop_enabled = false
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.player.health.configure_max_health(100)
	check(arena.spawner.required_remaining == 3, "opening wave has three guards")
	check(arena.boss.opening_guards_remaining == 3 and arena.boss.opening_guards_total == 3, "three guards have an independent counter")
	check(arena.boss.health.max_health == 6, "boss phase two has exactly six health")
	check(arena.boss.health.apply_damage(99, hit()) == 0, "opening guards protect dormant statue")
	check(arena.get_node("SupportEnemies").get_child_count() == 0, "support wave is not spawned early")
	# Exercise the real viewport/FOV checks at opposite sides of the arena.
	var scout: EnemyController = arena.get_node("Enemies").get_child(0)
	var scout_position := scout.global_position
	var player_position := arena.player.global_position
	var facing := scout.facing
	scout.set_physics_process(false)
	scout.global_position = Vector2(200,270)
	scout.facing = Vector2.LEFT
	scout._target = arena.player
	arena.player.global_position = Vector2(780,480)
	await physics_frame
	await physics_frame
	check(scout.can_see_target(), "boss guard sees across arena even behind its initial facing")
	scout.profile.full_room_awareness = false
	check(not scout.can_see_target(), "ordinary viewport cap would reject the same distant target")
	scout.profile.full_room_awareness = true
	scout.global_position = scout_position
	scout.facing = facing
	scout.set_physics_process(true)
	arena.player.global_position = player_position
	for path in ["melee_pressure", "ranged_sightline", "heavy_anchor"]:
		var normal: EnemyProfile = load("res://resources/enemies/" + path + ".tres")
		check(not normal.full_room_awareness and normal.vision_angle_degrees == 120, "boss awareness override leaves shared normal profiles unchanged")
	var heavy: EnemyController
	var remaining := 3
	for enemy: EnemyController in arena.get_node("Enemies").get_children():
		check(enemy.profile.full_room_awareness and enemy.profile.awareness_range == 1000 and enemy.profile.vision_angle_degrees == 360, "opening guard has full arena awareness")
	var total_opening_health := 0
	for enemy: EnemyController in arena.get_node("Enemies").get_children():
		total_opening_health += enemy.health.max_health
	check(total_opening_health == 3, "opening guards have exactly three health in total")
	for enemy: EnemyController in arena.get_node("Enemies").get_children():
		if enemy.profile.self_destruct_enabled:
			heavy = enemy
			continue
		enemy.health.apply_damage(99, hit())
		remaining -= 1
		check(arena.boss.opening_guards_remaining == remaining, "each opening defeat updates independent guard counter")
		check(arena.boss.get_halo_segments_remaining() == 5, "guard defeats do not change statue halo or boss health")
		check(arena.boss.health.current_health == 6, "guard kills do not consume phase two boss health")
		check(arena.phase == RooftopBossArena.Phase.MINIONS, "boss stays dormant while last guard remains")
	heavy.health.apply_damage(99, hit())
	check(arena.boss.opening_guards_remaining == 1, "heavy self-destruct must finish before guard wave clears")
	await create_timer(0.6).timeout
	check(arena.phase == RooftopBossArena.Phase.AWAKENING, "last guard starts original awakening cinematic")
	check(arena.boss.opening_guards_remaining == 0 and arena.boss.health.get_precise_health() == 6, "clearing opening guards leaves boss health unchanged")
	check(not arena.player.is_physics_processing(), "cinematic freezes player movement")
	await create_timer(0.8).timeout
	check(arena.player.camera.zoom.is_equal_approx(Vector2.ONE), "cinematic keeps teammate camera scale")
	check(arena.player.camera.position.length() > 1, "cinematic moves camera toward altar")
	check(arena.boss.glow_sprite.visible and arena.room_lighting.phase_light > 0, "cinematic retains statue glow and room lighting")
	await create_timer(1.8).timeout
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE, "cinematic ends in phase two")
	check(arena.player.is_physics_processing(), "cinematic restores player movement")
	check(arena.player.camera.zoom.is_equal_approx(Vector2.ONE * 0.8) and arena.player.camera.position.length() < 40, "phase two opens a wider view after original cinematic")
	check(not arena.boss.hurt_box.monitorable and arena.boss.health.guard_link_active, "supports protect active boss from direct hits")
	check(arena.get_node("SupportEnemies").get_child_count() == 3, "phase two spawns three supports")
	arena._spawn_support_guards()
	check(arena.get_node("SupportEnemies").get_child_count() == 3, "support wave cannot be duplicated")
	check(root.get_node("RunManager").mandatory_enemies_remaining == 1, "boss remains mandatory during support wave")
	var supports: Array[EnemyController] = []
	var support_heavy: EnemyController
	for enemy: EnemyController in arena.get_node("SupportEnemies").get_children():
		check(enemy.profile.full_room_awareness and enemy.profile.awareness_range == 1000 and enemy.profile.vision_angle_degrees == 360, "second phase guard has full arena awareness")
		check(enemy.is_physics_processing() and not enemy.health.is_dead(), "support fights alongside boss")
		check(enemy.health.max_health == 3 and enemy.health.current_health == 3, "each second phase guard has three health")
		if enemy.profile.self_destruct_enabled:
			support_heavy = enemy
		else:
			supports.append(enemy)
	supports.append(support_heavy)
	check(arena.boss.health.apply_damage(99, hit()) == 0, "even direct health damage cannot bypass support shield")
	var shot: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	arena.add_child(shot)
	shot.global_position = arena.boss.global_position + Vector2(0, 165)
	shot.setup(arena.player, CombatFaction.Id.PLAYER, Vector2.UP, 99, 180)
	await create_timer(0.4).timeout
	check(arena.boss.health.get_precise_health() == 6, "real weapon shot cannot harm shielded boss")
	var lost := 0
	for enemy in supports:
		for index in 3:
			enemy.health.apply_damage(1, hit(1))
			lost += 1
			var expected := 6.0 * (1.0 - float(lost) / 9.0 * 0.5)
			check(absf(arena.boss.health.get_precise_health() - expected) < 0.00001, "every lost guard health point proportionally reduces boss health")
			check(arena.boss.health.apply_damage(99, hit()) == 0, "boss stays immune until final support death completes")
		check(enemy.health.apply_damage(99, hit()) == 0, "overkill on a dead guard cannot repeat linked damage")
	check(arena.boss.health.guard_link_active, "heavy death animation keeps boss shield active")
	check(absf(arena.boss.health.get_health_ratio() - 0.5) < 0.00001, "nine lost guard health points leave exactly half boss health")
	await create_timer(0.6).timeout
	check(not arena.boss.health.guard_link_active and arena.boss.hurt_box.monitorable, "clearing supports opens boss hurtbox")
	check(absf(arena.boss.health.get_precise_health() - 3.0) < 0.00001, "shield removal preserves exactly 3 of 6 health")
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE and not arena.exit_elevator.enabled, "player must still defeat remaining half health boss")
	shot = load("res://scenes/combat/projectile.tscn").instantiate()
	arena.add_child(shot)
	shot.global_position = arena.boss.global_position + Vector2(0, 165)
	shot.setup(arena.player, CombatFaction.Id.PLAYER, Vector2.UP, 1, 180)
	await create_timer(0.4).timeout
	check(absf(arena.boss.health.get_precise_health() - 2.0) < 0.00001, "real bullet damages vulnerable remaining boss without refilling health")
	arena.boss.health.apply_damage(1, hit(1))
	check(absf(arena.boss.health.get_precise_health() - 1.0) < 0.00001, "last boss health point stays accurate")
	arena.boss.hurt_box.receive_hit(hit(1))
	await process_frame
	check(arena.phase == RooftopBossArena.Phase.CLEARED and arena.exit_elevator.enabled, "remaining boss health must be depleted before exit opens")
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.NONE, "victory clears pending hazards")
	arena.queue_free()
	await process_frame
	print("Rooftop boss checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
