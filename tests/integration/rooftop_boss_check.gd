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

func run() -> void:
	var store := root.get_node("WarehouseStore")
	check(store.begin_test_session() and store.create_new_profile(), "encounters use an isolated test profile")
	root.get_node("RunManager").persistent_run = true
	var arena: RooftopBossArena = load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate()
	arena.attack_loop_enabled = false
	root.add_child(arena)
	await process_frame
	for frame in 20:
		await physics_frame
	var opening_entries: Array = store.get_codex().enemies
	check("rooftop_whale_goddess" in opening_entries and "wing_guard_rook" in opening_entries and "wing_guard_bishop" in opening_entries, "ordinary route records the statue and both opening wings")
	check(not "rooftop_whale_goddess_channel" in opening_entries and not "wing_guard_queen" in opening_entries, "undiscovered forms remain locked")
	var room_art := arena.get_node("RoomArt") as Sprite2D
	check(room_art.texture.resource_path.ends_with("rooftop_server_chapel_base.png") and room_art.position == Vector2(640, 450) and room_art.scale.is_equal_approx(Vector2(1.333333, 1.666667)), "original chapel architecture remains beneath separate floor")
	check(room_art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "chapel art uses smooth filtering")
	check((arena.get_node("ChessFloor") as Sprite2D).texture.resource_path.ends_with("rooftop_chess_floor_v1.png") and (arena.get_node("ChessFloor") as Sprite2D).position == Vector2(640, 524), "generated 24x14 floor sits at revised grid origin")
	check((arena.get_node("RoomForeground") as Sprite2D).z_index > (arena.get_node("ChessFloor") as Sprite2D).z_index, "altar steps and railing cover floor layer")
	var foreground_image := (arena.get_node("RoomForeground") as Sprite2D).texture.get_image()
	check(foreground_image.get_pixel(290, 350).a > 0.99 and foreground_image.get_pixel(990, 350).a > 0.99, "both side steps remain opaque above the floor")
	check(foreground_image.get_pixel(640, 380).a < 0.01, "playable center stays transparent in foreground mask")
	check(BossFloorGeometry.ORIGIN == Vector2(256, 300), "floor gameplay coordinates match standalone art")
	await physics_frame
	var space := arena.get_world_2d().direct_space_state
	var foot_query := PhysicsPointQueryParameters2D.new()
	foot_query.position = Vector2(640, 350)
	foot_query.collision_mask = 1
	check(not space.intersect_point(foot_query).is_empty(), "expanded pedestal blocks the statue feet")
	var side_query := PhysicsPointQueryParameters2D.new()
	side_query.position = Vector2(205, 550)
	side_query.collision_mask = 1
	check(not space.intersect_point(side_query).is_empty(), "floor-edge collision blocks side rack art")
	var rail_query := PhysicsPointQueryParameters2D.new()
	rail_query.position = Vector2(400, 760)
	rail_query.collision_mask = 1
	check(not space.intersect_point(rail_query).is_empty(), "lower railing blocks floor escape")
	rail_query.position = Vector2(640, 760)
	check(space.intersect_point(rail_query).is_empty(), "central elevator path remains open")
	check(arena.boss.body_sprite.texture.resource_path.ends_with("rooftop_boss_dormant_large.png") and arena.boss.body_sprite.scale == Vector2.ONE and arena.boss.position == Vector2(640, 170), "boss uses aligned enlarged AI source")
	check(arena.boss.body_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "boss art uses smooth filtering")
	arena.player.health.configure_max_health(100)
	var wings := arena.get_node("Enemies").get_children()
	check(wings.size() == 2 and arena.spawner.required_remaining == 0, "two dedicated wings replace ordinary opening wave")
	check(arena.boss.opening_guards_total == 2 and arena.boss.health.current_health == 6, "opening counter and dormant boss health")
	check(arena.boss.health.apply_damage(99, hit(99)) == 0, "dormant boss is protected")
	var rook := wings[0] as WingGuard
	var bishop := wings[1] as WingGuard
	rook.set_active(false)
	bishop.set_active(false)
	check(rook.kind == WingGuard.Kind.ROOK and rook.health.max_health == 20, "rook has 20 health")
	check(bishop.kind == WingGuard.Kind.BISHOP and bishop.health.max_health == 15, "bishop has 15 health")
	var bishop_cell := BossFloorGeometry.nearest_cell(bishop.global_position)
	var diagonal_target := BossFloorGeometry.cell_point(bishop_cell + Vector2i(2, 2))
	arena.player.global_position = diagonal_target
	check(not bishop._bishop_target_ray(bishop_cell).is_empty(), "bishop detects a distant player along a corner ray before repositioning")
	arena.player.global_position = diagonal_target + Vector2(0, -64)
	check(bishop._bishop_target_ray(bishop_cell).is_empty(), "bishop keeps diagonal targeting rather than scanning every angle")
	bishop._warning_lines = [PackedVector2Array([Vector2(500, 300), Vector2(500, 700)])]
	bishop._laser_active = true
	arena.player.position = Vector2(530, 500)
	arena.player.hurt_box.clear_invulnerability()
	var laser_health := arena.player.health.current_health
	bishop._physics_process(0.02)
	arena.player.position = Vector2(505, 500)
	bishop._physics_process(0.02)
	check(arena.player.health.current_health == laser_health - 1, "entering an active bishop laser causes contact damage")
	arena.player.hurt_box.clear_invulnerability()
	bishop._physics_process(0.02)
	check(arena.player.health.current_health == laser_health - 1, "one bishop laser damages at most once")
	bishop._clear_warning()
	var distant_bishop_cell := bishop._bishop_destination(Vector2i(2, 2), Vector2i(12, 12))
	check(absi(distant_bishop_cell.x - 2) == absi(distant_bishop_cell.y - 2) and absi(absi(12 - distant_bishop_cell.x) - absi(12 - distant_bishop_cell.y)) <= 1 and distant_bishop_cell.distance_to(Vector2i(12, 12)) >= 6.0, "bishop can find a distant diagonal firing lane without approaching the player")
	check(arena.get_node("SupportEnemies").get_child_count() == 0, "queen is absent before fusion")
	rook.health.apply_damage(20, hit(20))
	check(arena.boss.opening_guards_remaining == 1 and arena.phase == RooftopBossArena.Phase.MINIONS, "first shattered core does not awaken boss")
	bishop.health.apply_damage(15, hit(15))
	check(arena.phase == RooftopBossArena.Phase.AWAKENING, "both cores trigger awakening")
	check(not arena.player.is_physics_processing(), "cinematic freezes player")
	await create_timer(0.8).timeout
	check(arena.player.camera.zoom.is_equal_approx(Vector2.ONE) and arena.player.camera.position.length() > 1, "cinematic retains altar camera move")
	await create_timer(2.0).timeout
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE and arena.player.is_physics_processing(), "awakening restores combat")
	check(arena.player.camera.zoom.is_equal_approx(Vector2.ONE * 0.8), "second phase opens wider view")
	var queen := arena.get_node("SupportEnemies").get_child(0) as WingGuard
	queen.set_active(false)
	for frame in 20:
		await physics_frame
	check("wing_guard_queen" in store.get_codex().enemies, "the fused wing unlocks after appearing")
	check(queen.kind == WingGuard.Kind.QUEEN and queen.health.max_health == 35, "fused queen has 35 health")
	var landing := queen._queen_landing_cell(Vector2i(2, 3), Vector2i(17, 10))
	check(landing.x == 2 or landing.y == 3 or absi(landing.x - 2) == absi(landing.y - 3), "queen landing follows a legal rook or bishop line")
	check(arena.boss.health.guard_link_active and arena.boss.health.apply_damage(99, hit(99)) == 0, "queen protects boss")
	for segment in 5:
		queen.health.apply_damage(6, hit(6))
		check(arena.boss.health.current_health == 6 - segment, "partial queen damage does not reduce boss health")
		queen.health.apply_damage(1, hit(1))
		check(arena.boss.health.current_health == 5 - segment, "each seven queen damage removes one boss health")
	check(not arena.boss.health.guard_link_active and arena.boss.health.current_health == 1, "queen defeat exposes final boss health")
	arena.boss.health.apply_damage(1, hit(1))
	check(arena.phase == RooftopBossArena.Phase.CLEARED and arena.exit_elevator.enabled, "final direct hit clears room")
	arena.queue_free()
	await process_frame
	print("Rooftop boss checks: ", checks, "; failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
