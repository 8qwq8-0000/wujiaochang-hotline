extends SceneTree

const SAVE := "user://codex-escort-check.json"
const PASSAGE := "res://scenes/levels/intermissions/codex_service_passage.tscn"
const FLOOR := "res://scenes/levels/floors/combat_prototype.tscn"
const ROOF := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
var checks := 0
var failures := 0
var run: Node
var store: Node
var main: Node
var flow: SceneContainerManager

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 4) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func scene() -> Node:
	for _i in 600:
		await process_frame
		if not flow._is_loading and main.get_node("SceneContainer").get_child_count() > 0:
			await frames()
			main.get_node("PersonaRestFlow").close(true)
			return main.get_node("SceneContainer").get_child(0)
	return null

func freeze_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for turret in get_nodes_in_group("sentry_turrets"):
		turret.set_physics_process(false)
		turret.stop_firing()

func kill(enemies: Array) -> void:
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			enemy.profile = enemy.profile.duplicate()
			enemy.profile.self_destruct_enabled = false
			enemy.health.apply_damage(100, packet)
	await create_timer(0.6).timeout

func finish_dialogue(room: Node) -> void:
	while room.panel.is_open:
		room.panel.advance()
	await frames()
	room.upgrade_panel.close()

func clear_floor(room: Node) -> void:
	var assembler: FloorAssembler = room.get_node("FloorAssembler")
	for area: CombatRoom in assembler.generated_rooms:
		area.activate()
		freeze_enemies()
		await kill(area.get_node("Enemies").get_children())


func wait_for_station(ambush: CodexAmbush) -> void:
	ambush.set_physics_process(true)
	for _frame in 360:
		await frames(1)
		if ambush.station_ready:
			break
	ambush.set_physics_process(false)


func capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/codex-escort-" + name + ".png")

func run_checks() -> void:
	run = root.get_node("RunManager")
	store = root.get_node("WarehouseStore")
	store.save_path = SAVE
	DirAccess.remove_absolute(SAVE)
	check(store.create_new_profile(), "isolated escort profile created")
	check(store.commit([], {}, "", {"id": "original", "personas": [], "semantic_leaks": []}), "first ending fixture unlocks core")
	run.begin_run(77131)
	main = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	flow = main.get_node("SceneFlow")
	flow.fade_duration = 0
	var room := await scene()
	var player: PlayerController = room.get_node("Player")
	var ordinary := player.export_run_state()
	run.floor_index = 1
	run.persistent_run = true
	check(flow.request_scene(PASSAGE, {"player_state": ordinary}), "ordinary passage loads")
	room = await scene()
	room.talk_to_codex()
	check(not room.get("_escort_dialogue") and room.panel.lines[0].contains("下面"), "without actual core ordinary conversation remains")
	await finish_dialogue(room)
	check(run.codex_companion.is_empty() and room.get_node_or_null("CodexCompanion") == null, "ordinary conversation cannot recruit")
	player = room.player
	check(player.inventory.grant_channel_core(), "actual prerequisite collectible added")
	var carrying := player.export_run_state()
	run.begin_run(77132)
	run.floor_index = 1
	run.persistent_run = true
	run.channel_route_active = true
	run.channel_record_found = true
	run.set_player_state(carrying)
	flow.request_scene(PASSAGE, {"player_state": carrying})
	room = await scene()
	room.talk_to_codex()
	check(paused and room.panel.lines[0].contains("残损频道核心"), "core switches to new paused conversation")
	await capture("01-dialogue")
	room.panel.close()
	check(run.codex_companion.is_empty(), "interrupted conversation does not recruit")
	room.talk_to_codex()
	store.save_path = "user://missing-escort-directory/checkpoint.json"
	await finish_dialogue(room)
	check(run.codex_companion.is_empty() and not room.dialogue_completed and room.get_node_or_null("CodexCompanion") == null, "save failure rolls back recruitment without duplicate actor")
	store.save_path = SAVE
	room.talk_to_codex()
	await finish_dialogue(room)
	var escort := room.get_node_or_null("CodexCompanion") as CodexCompanion
	check(escort != null and escort.health.current_health == 3 and run.codex_is_alive(), "completed conversation recruits three-health Codex")
	if escort == null:
		quit(1)
		return
	check(escort.global_position.is_equal_approx(room.get_node("SynthesisNPC/RefinedArt").global_position + Vector2(-32, 0)), "Codex spawns 32 pixels left of her original anchor")
	check(not room.get_node("SynthesisNPC/RefinedArt").visible, "stationary double is hidden after recruitment")
	check(store.get_channel_checkpoint().route.codex.health == 3, "recruitment is durable")
	player = room.player
	player.set_physics_process(false)
	var before := escort.position
	player.position = escort.position + Vector2(200, 0)
	await create_timer(0.4).timeout
	check(escort.follow_player and escort.position.distance_to(before) > 8, "after dialogue Codex follows the player through the service passage")
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.base_damage = 1
	escort.hurt_box.receive_hit(packet)
	check(escort.health.current_health == 2 and store.get_channel_checkpoint().route.codex.health == 2, "enemy damage immediately persists remaining health")
	escort.hurt_box.receive_hit(packet)
	check(escort.health.current_health == 2, "post-hit protection prevents same-frame damage stacking")
	await create_timer(0.8).timeout
	check(escort.hurt_box.is_invulnerable(), "damage protection still active after 0.8 seconds")
	await create_timer(0.45).timeout
	check(not escort.hurt_box.is_invulnerable(), "damage protection ends after 1.2 seconds")
	var friendly: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	friendly.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 200)
	room.add_child(friendly)
	friendly._on_area_entered(escort.hurt_box)
	check(not friendly.get("_resolved") and escort.health.current_health == 2, "player projectile passes escort without friendly fire or consumption")
	friendly.queue_free()
	room.talk_to_codex()
	await frames()
	room.upgrade_panel.close()
	check(escort.health.current_health == 2 and room.get_children().filter(func(n: Node) -> bool: return n is CodexCompanion).size() == 1, "repeat interaction neither heals nor duplicates Codex")
	await capture("02-following")
	check(room.depart(), "service departure has no escort distance or arrival restriction")
	room = await scene()
	var control := room.get_node_or_null("CodexAmbush")
	if control != null:
		control.set_physics_process(false)
	freeze_enemies()
	escort = room.get_node_or_null("CodexCompanion") as CodexCompanion
	check(run.floor_index == 2 and escort != null and escort.health.current_health == 2, "third floor recreates escort with carried damage")
	if escort == null:
		quit(1)
		return
	var checkpoint: Dictionary = store.get_channel_checkpoint()
	var malformed := checkpoint.duplicate(true)
	malformed.route.codex.health = 4
	check(not store.save_channel_progress(malformed), "invalid escort health rejected")
	# The altar owns three health, while Codex is protected during repair.
	check(control.health.current_health == 3 and escort.protected_by_altar, "altar starts with three health and Codex is protected")
	control.started = true
	escort.hurt_box.receive_hit(packet)
	check(escort.health.current_health == 2, "enemy hits do not hurt Codex during altar defense")
	var enemy_shot: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
	enemy_shot.setup(null, CombatFaction.Id.ENEMY, Vector2.RIGHT, 1, 120)
	enemy_shot.position = control.global_position + Vector2(-50, 3)
	room.add_child(enemy_shot)
	await create_timer(0.4).timeout
	check(control.health.current_health == 2 and store.get_channel_checkpoint().route.codex.altar_health == 2, "actual hostile projectile damages and persists altar health")
	control.started = false
	checkpoint = store.get_channel_checkpoint()
	check(run.restore_channel_checkpoint(checkpoint), "injured escort checkpoint restores")
	flow.request_scene(FLOOR)
	room = await scene()
	control = room.get_node_or_null("CodexAmbush")
	if control != null:
		control.set_physics_process(false)
	freeze_enemies()
	escort = room.get_node("CodexCompanion")
	check(control.health.current_health == 2, "resume never refills altar health")
	# Enemy targeting stays on the player even with a closer living escort.
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	enemy.profile.full_room_awareness = true
	enemy.mandatory = false
	enemy.position = Vector2(150, 270)
	escort.position = Vector2(175, 270)
	room.get_node("Player").position = Vector2(310, 270)
	room.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._physics_process(0.01)
	check(enemy.get("_target") == room.get_node("Player"), "enemy locks player even when Codex is closer")
	enemy.queue_free()
	var assembler: FloorAssembler = room.get_node("FloorAssembler")
	var ambush := room.get_node("CodexAmbush") as CodexAmbush
	var area: CombatRoom = assembler.generated_rooms[0]
	check(assembler.generated_rooms.size() == 1 and assembler.passages.is_empty(), "third floor contains only one area")
	check(not run.channel_floor_ready() and not area.exit_elevator.enabled and area.get_node("Enemies").get_child_count() == 0, "no enemies spawn and ascent is locked before consent")
	await wait_for_station(ambush)
	check(ambush.station_ready and not paused and not ambush.dialogue.visible, "Codex arrival alone does not interrupt a distant player")
	player = room.get_node("Player")
	player.global_position = ambush.global_position + Vector2(-50, 54)
	ambush._physics_process(0)
	check(paused and ambush.dialogue.visible, "approaching the ready altar automatically opens dialogue")
	check(escort.global_position.distance_to(ambush.global_position + Vector2(0, 54)) <= 9, "Codex reaches device without player-distance escort checks")
	while ambush.dialogue.get("_page_index") < ambush.dialogue.get("_pages").size() - 1:
		ambush.dialogue._advance_page()
	check(ambush.dialogue.get("_buttons").visible, "arrival dialogue exposes start and preparation choices after reading")
	check(ambush.dialogue.get("_buttons").get_child(1).text == "接受挑战", "accept challenge is the right-hand choice")
	await capture("03-ready")
	ambush.dialogue._choose(Callable())
	check(not paused and not ambush.started and area.get_node("Enemies").get_child_count() == 0, "prepare-first choice restores play without spawning enemies")
	player = room.get_node("Player")
	player.global_position = ambush.global_position + Vector2(-50, 54)
	check(ambush.can_interact(player), "device remains interactable after prepare-first")
	player.set_physics_process(false)
	await frames()
	check(player.interactor.get_best_target(player) == ambush, "existing interaction detector finds the device at its displayed range")
	check(player.interactor.request_interaction(player), "normal interaction action opens the device")
	check(paused and ambush.dialogue.visible, "returning to device reopens the real start choice")
	ambush.dialogue._choose(ambush.start)
	check(not paused and ambush.started and area.spawner.required_remaining == 3 and ambush.wave_number == 1, "acceptance immediately starts first of three waves")
	check(not store.get_channel_checkpoint().route.codex.ambush_complete and store.get_channel_checkpoint().cleared == [false], "active assault checkpoint cannot fabricate success")
	before = escort.position
	var held_wave := ambush.wave_number
	ambush.set_physics_process(true)
	paused = true
	await frames()
	check(ambush.wave_number == held_wave and escort.position == before, "pause freezes assault actors and wave progression")
	paused = false
	ambush.set_physics_process(false)
	ambush._physics_process(2.01)
	freeze_enemies()
	check(area.spawner.required_remaining == 3, "first wave uses three existing enemies")
	var first_wave := area.get_node("Enemies").get_children()
	var baseline_ids: Array[StringName] = []
	var baseline_health: Array[int] = []
	for unit: EnemyController in first_wave:
		baseline_ids.append(unit.profile.id)
		baseline_health.append(unit.health.max_health)
	check(first_wave.all(func(unit: EnemyController) -> bool: return unit.profile.full_room_awareness and unit.pursue_player), "ambush enemies actively seek the player")
	check(first_wave.all(func(unit: EnemyController) -> bool: return unit.global_position.distance_to(ambush.global_position) <= 265 and unit.global_position.distance_to(player.global_position) >= 90), "enemies spawn near altar with safe distance from player")
	check(ambush.find_children("ChallengeTimeBar", "", true, false).is_empty(), "no countdown bar remains")
	for unit: EnemyController in first_wave:
		unit._physics_process(0.01)
		check(unit.get("_target") == player and unit.get("_last_known_position").distance_to(player.global_position) < 1, "ambush unit actively tracks the player's location through the room")
	await capture("04-ambush")
	check(ambush.wave_number == 1, "second wave does not spawn while first wave remains alive")
	await kill(first_wave)
	freeze_enemies()
	check(not area.cleared and not area.exit_elevator.enabled and run.mandatory_enemies_remaining > 0, "clearing first wave does not unlock exit or complete the floor")
	check(ambush.wave_number == 2 and area.spawner.required_remaining == 3, "clearing first wave immediately spawns exactly three second-wave enemies")
	var second_wave := area.get_node("Enemies").get_children().filter(func(unit: EnemyController) -> bool: return not unit.health.is_dead())
	for index in second_wave.size():
		var unit: EnemyController = second_wave[index]
		check(unit.profile.id == baseline_ids[index] and unit.health.max_health == baseline_health[index] + 1, "second wave now uses former third-wave composition with second-wave health scaling")
	ambush._physics_process(120.0)
	check(ambush.wave_number == 2 and not ambush.resolved, "second wave has no time limit and cannot finish without clearing enemies")
	await kill(area.get_node("Enemies").get_children())
	freeze_enemies()
	check(ambush.wave_number == 3 and area.spawner.required_remaining == 3 and not area.cleared, "clearing second wave spawns the final third wave")
	var third_wave := area.get_node("Enemies").get_children().filter(func(unit: EnemyController) -> bool: return not unit.health.is_dead())
	for index in third_wave.size():
		var unit: EnemyController = third_wave[index]
		var source: EnemyProfile = area.spawner._spawn_plan[index + 3].profile
		check(unit.profile.id == source.id and unit.health.max_health == source.max_health + area.spawner.health_bonus + 2 and unit.health.current_health == unit.health.max_health, "third wave uses former second-wave composition with third-wave health scaling")
		var expected_speed := source.move_speed * area.spawner.melee_speed_multiplier * 1.16 if unit.profile.role == EnemyProfile.Role.MELEE_PRESSURE else source.move_speed
		check(is_equal_approx(unit.profile.move_speed, expected_speed) and is_equal_approx(unit.profile.attack_windup, source.attack_windup), "swapped final wave keeps third-wave speed scaling and readable attack windup")
	before = escort.global_position
	player.global_position = Vector2(820, 400)
	await frames()
	check(escort.global_position == before, "Codex stays at device during assault instead of following the player")
	ambush._physics_process(120.0)
	check(not ambush.resolved and ambush.wave_number == 3, "third wave remains active after long waits without any time limit")
	await kill(area.get_node("Enemies").get_children())
	check(ambush.wave_number == 3, "third-wave last kill never spawns a fourth wave")
	check(ambush.resolved and area.cleared and area.exit_elevator.enabled and run.channel_floor_ready(), "clearing exactly three waves completes repair and unlocks the rooftop")
	check(ambush.health.current_health == 2, "completion does not invent altar healing")
	checkpoint = store.get_channel_checkpoint()
	check(checkpoint.route.codex.ambush_complete and checkpoint.cleared == [true], "completed ambush and single-area progress are durable")
	check(run.restore_channel_checkpoint(checkpoint), "completed ambush checkpoint restores")
	flow.request_scene(FLOOR)
	room = await scene()
	check(room.get_node_or_null("CodexAmbush") == null and run.mandatory_enemies_remaining == 0, "completed ambush resume does not restart waves or leave a held objective")
	main.get_node("ExtractionFlow").continue_floor()
	var arena := await scene() as RooftopBossArena
	check(arena != null and arena.phase == RooftopBossArena.Phase.SECOND_ENDING_PENDING, "living Codex entering rooftop triggers second-ending branch immediately")
	if arena == null:
		quit(1)
		return
	check(run.channel_boss_ready() and run.codex_companion.arrived, "arrival commits the living escort prerequisite")
	check(arena.get_node_or_null("ChannelTakeover") == null and not arena.boss.health.damage_enabled, "pending branch does not run abandoned takeover or original boss")
	check(not run.finish_victory(arena.player) and not arena.exit_elevator.enabled, "placeholder never awards a fabricated second ending")
	await capture("03-second-route")
	arena.route_dialogue.close()
	var roof_checkpoint: Dictionary = store.get_channel_checkpoint()
	check(roof_checkpoint.route.codex.health == 2 and roof_checkpoint.route.codex.arrived, "rooftop saves living escort without healing")
	check(run.restore_channel_checkpoint(roof_checkpoint), "pending route restores")
	flow.request_scene(ROOF)
	arena = await scene() as RooftopBossArena
	check(arena.phase == RooftopBossArena.Phase.SECOND_ENDING_PENDING and run.codex_companion.health == 2 and arena.get_node_or_null("CodexCompanion") == null, "rooftop resume preserves escort state without spawning Codex")
	arena.route_dialogue.close()
	# Replay an unfinished assault and fail during its first wave.
	checkpoint = checkpoint.duplicate(true)
	checkpoint.route.codex.ambush_complete = false
	checkpoint.cleared = [false]
	check(run.restore_channel_checkpoint(checkpoint), "unfinished assault fixture restores")
	flow.request_scene(FLOOR)
	room = await scene()
	ambush = room.get_node("CodexAmbush")
	ambush.set_physics_process(false)
	escort = room.get_node("CodexCompanion")
	check(ambush.health.current_health == 2 and not ambush.started, "unfinished resume preserves altar damage and waits for consent again")
	ambush.offered = true
	ambush.start()
	ambush._physics_process(2.01)
	freeze_enemies()
	ambush.hurt_box.clear_invulnerability()
	var fatal := DamagePacket.new()
	fatal.source_faction = CombatFaction.Id.ENEMY
	fatal.base_damage = 3
	ambush.hurt_box.receive_hit(fatal)
	check(ambush.health.is_dead() and run.codex_is_alive() and not run.channel_boss_ready(), "destroyed altar fails defense while Codex stays alive")
	check(ambush.resolved and ambush.wave_number == 1 and not room.get_node("FloorAssembler").generated_rooms[0].cleared, "death cancels pending reinforcements but requires clearing present enemies")
	ambush._physics_process(40)
	check(ambush.wave_number == 1, "failed assault never spawns the second wave")
	await clear_floor(room)
	check(ambush.health.is_dead() and run.channel_floor_ready(), "clearing failed assault never repairs altar and allows first-ending ascent")
	var dead_checkpoint: Dictionary = store.get_channel_checkpoint()
	check(dead_checkpoint.route.codex.altar_health == 0 and dead_checkpoint.route.codex.ambush_failed, "altar destruction remains durable")
	check(run.restore_channel_checkpoint(dead_checkpoint), "dead escort checkpoint restores")
	flow.request_scene(FLOOR)
	room = await scene()
	freeze_enemies()
	check(room.get_node_or_null("CodexAmbush") == null and room.get_node_or_null("CodexCompanion") != null, "destroyed altar does not restart defense or remove Codex on resume")
	await clear_floor(room)
	main.get_node("ExtractionFlow").continue_floor()
	arena = await scene() as RooftopBossArena
	check(arena.phase == RooftopBossArena.Phase.MINIONS and arena.route_dialogue == null, "dead escort falls back to original first ending")
	arena.attack_loop_enabled = false
	arena.player.health.configure_max_health(100, true)
	await kill(arena.get_node("Enemies").get_children())
	await create_timer(2.4).timeout
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE and arena.get_node("SupportEnemies").get_child_count() == 5, "fallback retains awakening and all five second-phase guards")
	await kill(arena.get_node("SupportEnemies").get_children())
	check(arena.boss.health.current_health == 1 and arena.boss.health.damage_enabled, "fallback exposes original final hit after guards")
	var final_hit := DamagePacket.new()
	final_hit.source_faction = CombatFaction.Id.PLAYER
	arena.boss.health.apply_damage(100, final_hit)
	check(arena.phase == RooftopBossArena.Phase.CLEARED, "fallback boss can be defeated")
	var ui: Node = main.get_node("ExtractionFlow")
	ui.open_exit(arena.exit_elevator)
	ui.complete_victory()
	check(run.run_finished and store.get_legacy_drinks().back().ending == "core_destroyed", "dead escort route settles as first ending despite carrying core")
	paused = false
	main.queue_free()
	await frames()
	DirAccess.remove_absolute(SAVE)
	print("Codex escort checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
