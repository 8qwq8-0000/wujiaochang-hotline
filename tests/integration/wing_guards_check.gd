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


func hit(amount: int) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = amount
	packet.source_faction = CombatFaction.Id.PLAYER
	return packet


func verify_animation(guard: WingGuard, clip: String) -> void:
	for index in 8:
		var path := "res://assets/art/characters/bosses/wing_guards/animations/%s/frame_%02d.png" % [clip, index]
		check(load(path) is Texture2D, "%s frame %d loads" % [clip, index])
	guard._play_attack_frames(clip)
	await create_timer(0.1).timeout
	check(guard.body.texture != guard._idle_texture and guard.body.scale.x > 0.1, "%s plays in runtime" % clip)
	await create_timer(0.95).timeout
	check(guard.body.texture == guard._idle_texture, "%s restores idle art" % clip)


func run() -> void:
	var arena: RooftopBossArena = load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate()
	arena.attack_loop_enabled = false
	root.add_child(arena)
	await process_frame
	var wings := arena.get_node("Enemies").get_children()
	check(wings.size() == 2, "opening has two wing guards")
	if wings.size() != 2:
		quit(1)
		return
	var rook := wings[0] as WingGuard
	var bishop := wings[1] as WingGuard
	rook.set_active(false)
	bishop.set_active(false)
	await verify_animation(rook, "rook_slash")
	await verify_animation(bishop, "bishop_laser")
	arena.player.set_physics_process(false)
	arena.player.global_position = rook.global_position + Vector2(42, 0)
	arena.player.hurt_box.clear_invulnerability()
	var health_before_slash := arena.player.health.current_health
	var slash := WingSlashProjectile.new()
	arena.add_child(slash)
	slash.launch(rook, arena.player, Vector2.RIGHT, 2)
	check(slash.get_child(0) is CollisionShape2D and (slash.get_child(0) as CollisionShape2D).shape is CircleShape2D, "rook slash has a physical melee hitbox")
	check((slash.get_child(1) as Sprite2D).texture.resource_path.ends_with("rook_slash_arc.png"), "rook slash uses generated artwork")
	await create_timer(0.5).timeout
	check(not is_instance_valid(slash), "slash projectile expires at short range")
	check(arena.player.health.current_health < health_before_slash, "slash collision damages player once")
	check(rook.kind == WingGuard.Kind.ROOK and rook.health.max_health == 20, "rook has 20 health")
	check(bishop.kind == WingGuard.Kind.BISHOP and bishop.health.max_health == 15, "bishop has 15 health")
	var diagonal := bishop._edge_ray(Vector2i(16, 5), Vector2(-1, 1))
	check(diagonal.size() == 2 and (is_equal_approx(diagonal[1].x, 256.0) or is_equal_approx(diagonal[1].y, 748.0)), "bishop diagonal laser reaches board edge")
	var radial := rook._edge_ray(Vector2i(11, 6), Vector2.RIGHT)
	check(is_equal_approx(radial[1].x, 1024.0), "queen cardinal laser can reach board edge")
	var summon_cells := arena._choose_summon_cells(2)
	check(summon_cells.size() == 2, "random summon chooses two valid board cells")
	arena._spawn_summoned_enemy(summon_cells[0])
	var summoned := arena.summoned_root.get_child(0) as EnemyController
	var base_health: int = (load("res://resources/enemies/melee_pressure.tres") as EnemyProfile).max_health if summoned.profile.role == EnemyProfile.Role.MELEE_PRESSURE else (load("res://resources/enemies/ranged_sightline.tres") as EnemyProfile).max_health
	check(summoned.profile.max_health == base_health + 1 and summoned.has_meta("boss_summoned_minion") and not summoned.mandatory, "first-phase summon uses second-floor strength without mandatory objective")
	check(arena.boss.health.current_health == 6 and not arena.boss.health.damage_enabled, "dormant boss is protected")
	rook.health.apply_damage(20, hit(20))
	await process_frame
	check(is_instance_valid(rook) and rook.body.texture.resource_path.ends_with("left_rook_guard_dead.png") and not rook.hurt_box.monitorable, "rook corpse persists without damage collision")
	check(arena.boss.opening_guards_remaining == 1 and arena.phase == RooftopBossArena.Phase.MINIONS, "one core remains")
	bishop.health.apply_damage(15, hit(15))
	check(is_instance_valid(bishop) and bishop.body.texture.resource_path.ends_with("right_bishop_guard_dead.png"), "bishop corpse appears before fusion flash")
	check(arena.phase == RooftopBossArena.Phase.AWAKENING, "both shattered wings awaken boss")
	await create_timer(2.8).timeout
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE, "awakening reaches second phase")
	check(not is_instance_valid(rook) and not is_instance_valid(bishop), "fusion flash clears both corpses")
	var second_cell := arena._choose_summon_cells(1)[0]
	arena._spawn_summoned_enemy(second_cell)
	var stronger := arena.summoned_root.get_child(0) as EnemyController
	var source_profile: EnemyProfile = load("res://resources/enemies/melee_pressure.tres") if stronger.profile.role == EnemyProfile.Role.MELEE_PRESSURE else (load("res://resources/enemies/ranged_sightline.tres") if stronger.profile.role == EnemyProfile.Role.RANGED_SIGHTLINE else load("res://resources/enemies/heavy_anchor.tres"))
	check(stronger.profile.max_health == source_profile.max_health + 2, "second-phase summon uses third-floor strength")
	var queen := arena.get_node("SupportEnemies").get_child(0) as WingGuard
	queen.set_active(false)
	await verify_animation(queen, "queen_laser")
	await verify_animation(queen, "queen_landing")
	queen._fire_queen_spread_projectile(Vector2.RIGHT)
	var spread_bullet := arena.get_children().filter(func(node: Node) -> bool: return node is CombatProjectile).back() as CombatProjectile
	var sniper_profile := load("res://resources/enemies/ranged_sightline.tres") as EnemyProfile
	check(spread_bullet.scene_file_path.ends_with("scenes/combat/projectile.tscn") and spread_bullet.speed == sniper_profile.projectile_speed and spread_bullet.faction == CombatFaction.Id.ENEMY, "queen landing uses sniper projectile scene and speed")
	arena._clear_hostile_projectiles()
	check(queen.kind == WingGuard.Kind.QUEEN and queen.health.max_health == 35, "fused queen has 35 health")
	check(arena.boss.health.guard_link_active, "queen protects boss")
	for threshold in 5:
		queen.health.apply_damage(6, hit(6))
		check(arena.boss.health.current_health == 6 - threshold, "partial segment damage leaves boss health")
		queen.health.apply_damage(1, hit(1))
		check(arena.boss.health.current_health == 5 - threshold, "every seven queen health removes one boss health")
	check(not arena.boss.health.guard_link_active and arena.boss.health.current_health == 1, "queen death leaves one direct boss hit")
	check(is_instance_valid(queen) and queen.body.texture.resource_path.ends_with("fused_queen_guard_dead.png"), "queen death texture remains until boss defeat")
	arena.boss.health.apply_damage(1, hit(1))
	check(arena.phase == RooftopBossArena.Phase.CLEARED, "final direct hit clears arena")
	arena.queue_free()
	await process_frame
	print("Wing guard checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
