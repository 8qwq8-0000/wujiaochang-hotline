extends SceneTree

const ROOF := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
const OUTPUT := "res://docs/art/validation/channel_boss_duel_v1/"
var checks := 0
var failures := 0
var store: Node
var run_manager: Node
var main: Node
var flow: SceneContainerManager
var arena: RooftopBossArena
var duel: ChannelBossDuel


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func frames(count := 4) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func wait_scene() -> Node:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not flow._is_loading and main.get_node("SceneContainer").get_child_count() > 0:
			await frames()
			return main.get_node("SceneContainer").get_child(0)
	return null


func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")


func enter() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	run_manager = root.get_node("RunManager")
	var formal: Dictionary = store.get_profile()
	check(store.begin_test_session() and store.create_new_profile(), "test profile is isolated in memory")
	store.commit([], {}, "", {"id": "fixture-original", "ending": "core_destroyed", "personas": [], "semantic_leaks": []})
	store.acknowledge_channel_intro()
	run_manager.begin_run(90411)
	var temporary: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(temporary)
	temporary.set_physics_process(false)
	temporary.inventory.grant_channel_core()
	temporary.apply_channel_curse(true)
	var saved := {"scene": ROOF, "seed": 90411, "floor": 3, "elapsed": 0.0, "medical_used": false,
		"player": temporary.export_run_state(), "route": {"active": true, "record": true, "key": false, "isolated": false,
			"codex": {"joined": true, "health": 2, "arrived": true, "ambush_complete": true}}}
	temporary.queue_free()
	await frames()
	check(store.save_channel_progress(saved) and run_manager.restore_channel_checkpoint(saved), "eligible rooftop checkpoint restores")
	main = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	flow = main.get_node("SceneFlow")
	flow.fade_duration = 0
	arena = await wait_scene() as RooftopBossArena
	check(arena != null and arena.channel_duel != null, "production room selects second-ending duel")
	if arena == null or arena.channel_duel == null:
		quit(1)
		return
	duel = arena.channel_duel
	var player := arena.player
	check(paused and duel.dialogue.visible and not player.is_input_enabled(), "entry story pauses gameplay and input")
	check(duel.dialogue._speaker.text.contains("Codex") and duel.dialogue._text.text.contains("求救"), "entry explains restoring the calls")
	check(arena.get_node("Enemies").get_child_count() == 0 and arena.get_node("SupportEnemies").get_child_count() == 0, "second ending has no guards")
	check(run_manager.mandatory_enemies_remaining == 1 and not arena.exit_elevator.enabled, "duel holds a mandatory objective and closed exit")
	check(not run_manager.finish_victory(player), "intro cannot award victory")
	check(player.channel_curse_active and run_manager.carries_channel_core(player), "entry retains core until deliberate connection")
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	check(arena.boss.health.apply_damage(1, packet) == 0, "story cannot damage dormant boss")
	await capture("01-entry-story")
	for index in 12:
		if duel.stage != duel.Stage.INTRO:
			break
		await enter()
	check(duel.stage == duel.Stage.AWAKENING and not paused, "real Enter advances story into awakening")
	check(not player.channel_curse_active and not run_manager.carries_channel_core(player), "connection transfers core and lifts curse")
	check(player.health.current_health == player.health.max_health and player.health.max_health >= 3, "connection repairs normal player health")
	check(not player.is_input_enabled(), "awakening locks player until the reveal completes")
	check(store.get_channel_checkpoint().player.channel_curse and store.get_channel_checkpoint().player.current_health == 1, "safe checkpoint remains before core transfer")
	var before_clock := duel.stage_clock
	paused = true
	await create_timer(0.06).timeout
	check(is_equal_approx(before_clock, duel.stage_clock), "pause freezes awakening clock")
	paused = false
	for frame in 180:
		await frames(1)
		if duel.stage == duel.Stage.ACTIVE:
			break
	duel.auto_attacks = false
	check(duel.stage == duel.Stage.ACTIVE and arena.phase == arena.Phase.BOSS_ACTIVE, "reveal starts actual boss combat")
	check(player.is_input_enabled() and arena.boss.channel_form and duel.visual.visible, "player controls and front-facing animated form activate")
	check(arena.boss.health.damage_enabled and not arena.boss.health.guard_link_active, "boss is directly vulnerable throughout combat")
	check(arena.get_node_or_null("CodexCompanion") == null and run_manager.codex_companion.health == 2, "Codex is dialogue-only on the roof and retains escort health")
	check(arena.boss.get_node("PedestalCollision").disabled, "floating form removes old pedestal collision")
	var life := arena.boss.health.current_health
	var bullet: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	bullet.setup(player, CombatFaction.Id.PLAYER, Vector2.UP, 1, 600)
	bullet.position = arena.boss.position + Vector2(0, 65)
	arena.add_child(bullet)
	await frames(16)
	check(arena.boss.health.current_health == life - 1, "real player projectile damages floating boss")
	await capture("02-active-duel")
	# All three casts run their actual runtime scheduling, without automatic repeats.
	player.health.configure_max_health(100)
	player.set_physics_process(false)
	for index in 3:
		duel.clear_effects()
		await frames()
		duel.cast_attack(index)
		await create_timer([1.2, 1.0, 1.12][index]).timeout
		check(duel.attacks_started[index] > 0, "runtime cast starts: %d" % index)
		check(not get_nodes_in_group("channel_boss_effects").is_empty(), "cast creates active effect: %d" % index)
		await capture(["03-echo", "04-halo", "05-protect"][index])
	duel.set_physics_process(false)
	duel.clear_effects()
	await frames()
	player.position = Vector2(480, 430)
	var effect := duel.spawn_effect(&"echo", player.global_position)
	check(effect.contains_impact(player.global_position), "echo contains warned center")
	check(not effect.contains_impact(player.global_position + Vector2(0, 30)), "echo vertical boundary matches ground ellipse")
	check(not effect.contains_impact(player.global_position + Vector2(45, 0)), "echo horizontal boundary is bounded")
	var locked := effect.global_position
	player.position.x += 80
	check(effect.global_position == locked, "warned echo never follows player after placement")
	player.position = locked
	player.hurt_box.clear_invulnerability()
	player.health.set_current_health(100)
	effect.elapsed = 0.79
	effect._physics_process(0.02)
	check(player.health.current_health == 99, "echo deals real damage at release")
	player.hurt_box.clear_invulnerability()
	effect._physics_process(0.02)
	check(player.health.current_health == 99, "echo resolves once")
	duel.clear_effects()
	await frames()
	effect = duel.spawn_effect(&"halo", player.global_position)
	check(effect.halo_rects().size() == 3, "halo uses three parallel ground strips")
	check(effect.contains_impact(player.global_position), "halo center strip is dangerous")
	check(not effect.contains_impact(player.global_position + Vector2(39, 0)), "halo gaps remain safe")
	player.hurt_box.clear_invulnerability()
	var health_before := player.health.current_health
	effect.elapsed = 0.95
	effect._physics_process(0.02)
	check(player.health.current_health == health_before - 1, "halo damage follows warning release")
	var frozen := effect.elapsed
	paused = true
	await create_timer(0.06).timeout
	check(is_equal_approx(frozen, effect.elapsed), "pause freezes live hazard")
	paused = false
	duel.clear_effects()
	await frames()
	effect = duel.spawn_effect(&"protect", arena.boss.global_position)
	player.position = arena.boss.position + Vector2(120, 0)
	player.hurt_box.clear_invulnerability()
	health_before = player.health.current_health
	effect.previous_radius = 90
	effect.elapsed = 0.20
	effect._physics_process(0.15)
	check(player.health.current_health == health_before - 1, "swept wave cannot skip a crossing between frames")
	player.hurt_box.clear_invulnerability()
	effect._physics_process(0.01)
	check(player.health.current_health == health_before - 1, "wave hits once per crossing")
	duel.clear_effects()
	await frames()
	effect = duel.spawn_effect(&"protect", arena.boss.global_position)
	player.position = arena.boss.position + Vector2(120, 0)
	player.hurt_box.clear_invulnerability()
	player.dash.cooldown_remaining = 0
	check(player.dash.start_dash(player, Vector2.RIGHT), "actual dash starts for wave crossing")
	health_before = player.health.current_health
	effect.previous_radius = 90
	effect.elapsed = 0.20
	effect._physics_process(0.15)
	check(player.health.current_health == health_before, "actual dash invulnerability avoids wave damage")
	player.dash.cancel_dash()
	duel.clear_effects()
	await frames()
	effect = duel.spawn_effect(&"protect", arena.boss.global_position)
	player.position = arena.boss.position + Vector2(275, 0)
	player.hurt_box.clear_invulnerability()
	health_before = player.health.current_health
	effect.previous_radius = effect.wave_radius(0.73)
	effect.elapsed = 0.73
	effect._physics_process(0.05)
	check(player.health.current_health == health_before - 1, "extended wave damages beyond the old maximum")
	duel.clear_effects()
	await frames()
	var tail_origin := arena.boss.global_position - Vector2(0, 8)
	player.global_position = tail_origin + Vector2(0, 85)
	duel.cast_skill = &""
	duel.recovery = 1.0
	duel.tail_ready = true
	duel.auto_attacks = true
	duel._physics_process(1.0 / 60.0)
	check(duel.cast_skill == &"tail", "ordinary attack starts in a special skill's recovery window")
	duel.auto_attacks = false
	var tail := get_first_node_in_group("channel_boss_effects") as ChannelBossEffect
	if tail != null:
		var target := player.global_position
		player.global_position = tail_origin - Vector2(0, 85)
		check(tail.contains_impact(target) and not tail.contains_impact(player.global_position), "tail fan stays locked and leaves space behind the boss safe")
		player.global_position = target
		player.hurt_box.clear_invulnerability()
		health_before = player.health.current_health
		tail._physics_process(0.40)
		check(player.health.current_health == health_before, "tail telegraph does not damage the player")
		tail._physics_process(0.03)
		check(player.health.current_health == health_before - 1, "tail sweep lands once after its telegraph")
		player.hurt_box.clear_invulnerability()
		tail._physics_process(0.03)
		check(player.health.current_health == health_before - 1, "tail sweep cannot hit twice")
	else:
		check(false, "tail spawns a live fan")
	duel.clear_effects()
	await frames()
	# Death cancels queued attacks, then restore this fixture only for victory checks.
	duel.spawn_effect(&"echo", player.global_position)
	arena._on_player_died(DamagePacket.new())
	check(duel.stage == duel.Stage.STOPPED, "death stops duel scheduling")
	await frames()
	check(get_nodes_in_group("channel_boss_effects").is_empty(), "death clears all pending effects")
	duel.stage = duel.Stage.ACTIVE
	duel.set_physics_process(true)
	player.set_physics_process(true)
	player.health.configure_max_health(3)
	player.position = Vector2(480, 445)
	arena.boss.health.apply_damage(1000, packet)
	check(duel.stage == duel.Stage.ENDING and paused and duel.dialogue.visible, "defeating boss opens paused ending dialogue")
	check(not arena.exit_elevator.enabled and not run_manager.finish_victory(player), "exit and victory stay locked during ending")
	await capture("06-ending")
	for index in 12:
		if duel.stage != duel.Stage.ENDING:
			break
		await enter()
	check(duel.stage == duel.Stage.COMPLETE and run_manager.channel_takeover_complete, "ending confirms channel returned")
	check(arena.phase == arena.Phase.CLEARED and arena.exit_elevator.enabled and run_manager.mandatory_enemies_remaining == 0, "complete ending opens real settlement exit")
	var ui: Node = main.get_node("ExtractionFlow")
	ui.open_exit(arena.exit_elevator)
	ui.complete_victory()
	check(run_manager.run_finished and store.get_legacy_drinks().back().ending == "channel_returned", "actual settlement saves second-ending record")
	check(store.get_channel_checkpoint().is_empty(), "successful settlement clears safe checkpoint")
	var records: int = store.get_legacy_drinks().size()
	ui.complete_victory()
	check(store.get_legacy_drinks().size() == records, "repeat settlement cannot duplicate record")
	await capture("07-settlement")
	# Re-enter the real room from its safe checkpoint, then exercise actual death.
	paused = false
	check(store.save_channel_progress(saved) and run_manager.restore_channel_checkpoint(saved), "pre-connection checkpoint can restart a fresh duel")
	check(flow.request_scene(ROOF), "restart requests actual rooftop")
	arena = await wait_scene() as RooftopBossArena
	duel = arena.channel_duel
	check(duel.stage == duel.Stage.INTRO and arena.player.channel_curse_active, "resume replays entry with core and curse intact")
	for index in 12:
		if duel.stage != duel.Stage.INTRO:
			break
		await enter()
	for frame in 180:
		await frames(1)
		if duel.stage == duel.Stage.ACTIVE:
			break
	duel.auto_attacks = false
	arena.player.health.fatal_damage_interceptor = Callable()
	arena.player.health.apply_damage(1000, DamagePacket.new())
	await frames()
	check(duel.stage == duel.Stage.STOPPED and paused, "actual player death stops combat and opens failure UI")
	check(run_manager.run_finished and store.get_channel_checkpoint().is_empty(), "actual death atomically clears run checkpoint")
	check(store.get_legacy_drinks().size() == records, "death cannot mint an additional ending")
	main.queue_free()
	await frames()
	paused = false
	store.end_test_session()
	check(store.get_profile() == formal, "test restores formal profile without changes")
	print("Channel boss duel checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
