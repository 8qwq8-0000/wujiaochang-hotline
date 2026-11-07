extends SceneTree
var checks := 0
var failures := 0

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
	root.add_child(arena)
	await process_frame
	for wing in arena.get_node("Enemies").get_children():
		wing.set_active(false)
	arena.player.set_physics_process(false)
	arena.player.health.configure_max_health(100)
	arena.player.hurt_box.damage_invulnerability_seconds = 0
	arena.player.hurt_box.clear_invulnerability()
	arena.boss.activate_immediately()
	arena._set_phase(RooftopBossArena.Phase.BOSS_ACTIVE)
	arena._spawn_support_guards()
	arena.get_node("SupportEnemies").get_child(0).set_active(false)
	check(arena._attack_counts(6) == Vector2i(1, 1), "six health uses one point and one lane")
	check(arena._attack_counts(5) == Vector2i(2, 1), "five health uses two points")
	check(arena._attack_counts(4) == Vector2i(2, 2), "four health adds a second lane")
	check(arena._attack_counts(3) == Vector2i(3, 2), "three health adds a third point")
	check(arena._attack_counts(2) == Vector2i(3, 3), "two health adds a third lane")
	check(arena._attack_counts(1) == Vector2i(4, 4), "last health uses four points and lanes")
	var lane := arena._thunder_lane(Vector2(480, 400), true, 0)
	check(lane.size() == 24 and lane[0].y == lane[-1].y and lane[0].x < lane[-1].x, "horizontal thunder lane follows orthographic 32px floor cells")
	arena._show_lightning_at(Vector2(480, 335))
	check(arena.get_node_or_null("WhaleLightningStrike") is Sprite2D, "generated lightning texture enters runtime effect layer")
	await create_timer(0.3).timeout
	check(arena.get_node_or_null("WhaleLightningStrike") == null, "lightning sprite frees after brief strike")
	arena.player.global_position = Vector2(480, 400)
	arena._attack_generation = 1
	arena._run_attack_loop(1)
	await create_timer(0.15).timeout
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.ECHO, "visible sonar begins attack")
	await create_timer(0.55).timeout
	check(arena.telegraph.mode == BossAttackTelegraph.Mode.THUNDER_WARNING, "locked cell warns before lightning")
	var elapsed := arena.telegraph.elapsed
	var life := arena.player.health.current_health
	paused = true
	await create_timer(1.0).timeout
	check(arena.telegraph.elapsed == elapsed and arena.player.health.current_health == life, "pause freezes warning and damage")
	paused = false
	await create_timer(0.65).timeout
	check(arena.player.health.current_health == life - 1, "point lightning hits locked cell once")
	arena._attack_generation += 1
	arena.telegraph.clear()
	arena.queue_free()
	await process_frame
	print("Boss pattern checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
