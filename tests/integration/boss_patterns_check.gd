extends SceneTree

var checks := 0
var failures := 0
var hits := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var arena: RooftopBossArena = load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate()
	arena.attack_loop_enabled = false
	arena.get_node("EnemySpawner").auto_spawn = false
	root.add_child(arena)
	await process_frame
	arena.player.set_physics_process(false)
	arena.player.health.configure_max_health(100)
	arena.player.hurt_box.damage_invulnerability_seconds = 0
	arena.player.hurt_box.clear_invulnerability()
	arena.player.hurt_box.hit_resolved.connect(func(_result): hits += 1)
	arena.boss.activate_immediately()
	arena._set_phase(RooftopBossArena.Phase.BOSS_ACTIVE)
	arena._spawn_support_guards()
	for enemy in arena.get_node("SupportEnemies").get_children():
		enemy.set_physics_process(false)
	arena.player.global_position = Vector2(480, 400)
	var lasers := arena._make_cross_lasers(arena.player.global_position)
	check(lasers.size() == 2 and lasers[0].size.x == 14 and lasers[1].size.y == 14, "cross contains vertical and horizontal beams")
	arena.telegraph.show_cross(lasers, 0.78)
	check(arena.telegraph.cross_lasers.size() == 2, "both beams have matching telegraphs")
	var before := hits
	arena._damage_player_in_cross(lasers)
	check(hits == before + 1, "cross intersection deals one hit, not two")
	arena.player.global_position = Vector2(530, 450)
	before = hits
	arena._damage_player_in_cross(lasers)
	check(hits == before, "outside cross remains safe")

	# Pause during a real coroutine timer, then resume into the delayed strike.
	arena.player.global_position = Vector2(480,400)
	arena._attack_generation = 1
	arena._run_attack_loop(1)
	await create_timer(0.45).timeout
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.ORACLE_WARNING, "real loop reaches oracle warning")
	check(arena.boss.health.guard_link_active, "shielded boss continues its original attacks alongside living supports")
	var elapsed := arena.telegraph.elapsed
	var life := arena.player.health.current_health
	paused = true
	await create_timer(1.2).timeout
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.ORACLE_WARNING and arena.telegraph.elapsed == elapsed, "pause freezes warning and coroutine timer")
	arena._damage_player(arena.player.global_position)
	check(arena.player.health.current_health == life, "pause blocks direct hazard damage too")
	paused = false
	await create_timer(0.8).timeout
	check(arena.player.health.current_health == life - 1, "pending strike resumes after unpause")
	arena._attack_generation += 1
	arena.telegraph.clear()
	arena.telegraph.show_cross(lasers, 0.78)
	arena.player.health.fatal_damage_interceptor = Callable()
	arena.player.health.apply_damage(999, DamagePacket.new())
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.NONE, "player death cancels pending hazards")
	arena.queue_free()
	await process_frame
	print("Boss pattern checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
