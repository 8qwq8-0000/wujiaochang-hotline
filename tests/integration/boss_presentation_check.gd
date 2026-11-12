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

func frames(count := 4) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func packet(player: PlayerController, weapon: StringName = &"pistol") -> DamagePacket:
	var hit := DamagePacket.new()
	hit.source = player
	hit.source_faction = CombatFaction.Id.PLAYER
	hit.base_damage = 1
	hit.weapon_id = weapon
	return hit

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	# Freeze a rendered impact frame so background-window throttling cannot
	# expire the short feedback before a screenshot is written.
	paused = true
	var arena: RooftopBossArena = current_scene
	arena.presentation._process(0.06)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hotline-boss-feedback-" + name + ".png")
	paused = false

func run() -> void:
	var store := root.get_node("WarehouseStore")
	check(store.begin_test_session() and store.create_new_profile(), "feedback review uses an isolated profile")
	var arena: RooftopBossArena = load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate()
	arena.attack_loop_enabled = false
	root.add_child(arena)
	current_scene = arena
	await frames()
	arena._stop_summons()
	arena.player.set_physics_process(false)
	arena.player.global_position = Vector2(640, 490)
	arena.player.camera.position_smoothing_enabled = false
	arena.player.camera.zoom = Vector2.ONE * 0.65
	var review_camera := Camera2D.new()
	review_camera.position = Vector2(640, 390)
	review_camera.zoom = Vector2.ONE * 0.5
	arena.add_child(review_camera)
	review_camera.make_current()
	for guard in arena.get_node("Enemies").get_children():
		if guard is WingGuard:
			guard.set_active(false)
	var view := arena.presentation
	check(view.voices.size() == 6, "presentation owns a bounded six-voice pool")
	var guard: WingGuard = arena.get_node("Enemies").get_child(0)
	var guard_health := guard.health.current_health
	guard.hurt_box.receive_hit(packet(arena.player))
	check(guard.health.current_health == guard_health - 1 and view.event_counts.get(&"guard_hit", 0) == 1, "real guard hit produces its metallic feedback without changing damage")
	guard.hurt_box.receive_hit(packet(arena.player))
	check(view.event_counts.get(&"guard_hit", 0) == 1, "rapid hits merge feedback while gameplay damage continues")
	await frames(8)
	arena.boss.activate_immediately()
	arena._set_phase(arena.Phase.BOSS_ACTIVE)
	var before := arena.boss.health.current_health
	arena.boss.hurt_box.receive_hit(packet(arena.player, &"rail_cannon"))
	check(arena.boss.health.current_health == before - 1 and view.event_counts.get(&"body_hit", 0) == 1, "actual body damage has distinct feedback and preserves damage values")
	await capture("statue-hit")
	arena.boss.health.set_current_health(arena.boss.health.max_health)
	arena.boss.health.begin_guard_link()
	arena.boss.health.set_guard_damage_progress(1, 5)
	check(view.event_counts.get(&"break", 0) == 1, "guard-link segment loss triggers a dedicated break burst")
	view.moment(&"awakening")
	for index in 100:
		view.cast(&"halo", arena.boss.global_position - Vector2(0, 75), 0.96)
	check(view.pulses.size() == BossCombatPresentation.MAX_PULSES and view.voices.size() == 6, "feedback burst budgets remain bounded under sustained requests")
	check(view.voices[0].stream == BossCombatPresentation.WEIGHT and view.voices[1].stream == BossCombatPresentation.SONG, "normal hit/cast voices never replace critical break and awakening voices")
	view.pulses.clear()
	view.moment(&"phase")
	await capture("statue-break")
	await frames(4)
	paused = true
	var age: float = view.pulses[0].age
	for frame in 5:
		await process_frame
	check(float(view.pulses[0].age) == age, "paused game freezes feedback along with attack warnings")
	paused = false
	await frames(65)
	check(view.pulses.is_empty(), "transient feedback expires without leaving geometry behind")
	arena.boss.health.end_guard_link()
	arena.boss.channel_form = true
	arena.boss.global_position = Vector2(640, 350)
	arena.boss.body_sprite.hide()
	arena.boss.glow_sprite.hide()
	var animator := ChannelBossAnimator.new()
	arena.boss.add_child(animator)
	arena.boss.health.damaged.connect(animator.flash_hit)
	arena.boss.health.configure_max_health(60)
	await frames(6)
	arena.boss.hurt_box.receive_hit(packet(arena.player, &"rail_cannon"))
	check(animator.get("_impact_hold") > 0.0 and arena.boss.health.current_health == 59, "heavy channel hit holds the visual pose only and preserves combat damage")
	await capture("channel-hit")
	for skill: StringName in [&"echo", &"halo", &"protect", &"tail"]:
		var effect := ChannelBossEffect.new()
		effect.arena = arena
		effect.skill = skill
		arena.add_child(effect)
		effect.global_position = arena.player.global_position + Vector2(170, 0)
		view.cast(skill, arena.boss.global_position - Vector2(0, 75), effect._warning_time())
		await frames(64)
		check(view.event_counts.get(&"release_" + String(skill), 0) == 1, "actual %s effect emits one release cue at its gameplay release" % skill)
		check(view.pulses.size() <= BossCombatPresentation.MAX_PULSES, "actual effects stay within feedback budget")
	view.moment(&"phase")
	await capture("channel-phase")
	arena.boss.health.apply_damage(100, packet(arena.player))
	check(view.event_counts.get(&"defeat", 0) == 1 and view.get("_dead"), "boss death emits its finale exactly once")
	await capture("channel-defeat")
	view._on_player_died(packet(arena.player))
	check(view.pulses.is_empty(), "player death clears pending presentation")
	var sounds_stopped := true
	for voice in view.voices:
		sounds_stopped = sounds_stopped and not voice.playing and voice.stream == null
	check(sounds_stopped, "death cleanup stops and detaches every feedback voice")
	arena.queue_free()
	await frames()
	store.end_test_session()
	print("Boss presentation checks: ", checks, "; failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
