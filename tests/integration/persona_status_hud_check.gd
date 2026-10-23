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
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(350, 220)
	room.add_child(player)
	player.set_physics_process(false)
	player.persona_combat.set_physics_process(false)
	var hud: CanvasLayer = load("res://scenes/ui/combat_hud.tscn").instantiate()
	room.add_child(hud)
	await process_frame
	var panel: PersonaStatusPanel = hud.get("_persona_status")
	var comms: HoloCommsPanel = hud.get("_operator_panel")
	check(hud.get_node_or_null("Overlay/PauseButton") == null, "persona cluster replaces top-right pause button")
	check(panel.get_parent().name == "TopRightPersona" and comms.get_parent() == panel.get_parent(), "portrait and status share top-right anchor")
	var core := player.talent_core
	var combat := player.persona_combat
	hud._process(0)
	check(panel._title.text == "人格尚未装载" and not panel._meter.visible, "locked default persona does not claim active buffs")
	core.set_persona_level(TalentCoreController.DEEP_NINJA, 3)
	core.set_persona(TalentCoreController.DEEP_NINJA)
	core.set_talent_choice(core.current_persona_id, 1, &"read_opening")
	core.set_talent_choice(core.current_persona_id, 2, &"blood_step")
	core.set_talent_choice(core.current_persona_id, 3, &"shared_hunt_resonance")
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.position = Vector2(440,220)
	room.add_child(enemy)
	enemy.set_physics_process(false)
	combat._set_mark(enemy)
	combat.set("_blood_step_remaining", 1.25)
	combat.set("_resonance_remaining", 4.0)
	hud._process(0)
	check(panel._title.text == "深渊忍者 · Lv.3", "HUD shows actual current persona and level")
	check(panel._detail.text.contains("已锁定"), "live marked target appears locked")
	check(panel._effects.get_parsed_text().contains("●踏血") and panel._effects.get_parsed_text().contains("●共猎共振"), "running ninja effects light up")
	combat._tick_temporary_bonuses(5)
	hud._process(0)
	check(not panel._effects.get_parsed_text().contains("●踏血"), "expired talent remains selected but no longer active")
	await capture("ninja", hud)
	core.set_persona_level(TalentCoreController.ROCK_VIGILANTE, 3)
	core.set_persona(TalentCoreController.ROCK_VIGILANTE)
	core.set_talent_choice(core.current_persona_id, 1, &"distortion_gain")
	core.set_talent_choice(core.current_persona_id, 2, &"seamless_switch")
	core.set_talent_choice(core.current_persona_id, 3, &"encore_autopilot")
	combat.rock_feedback = 75
	combat.set("_seamless_free_attack", true)
	combat.set("_encore_remaining", 0.8)
	hud._process(0)
	check(panel._meter.value == 75 and panel._detail.text.contains("战斗反馈 · 75%"), "feedback meter uses live rock feedback")
	check(panel._effects.get_parsed_text().contains("●无缝换台") and panel._effects.get_parsed_text().contains("●安可托管"), "rock effects use runtime flags")
	check(panel._effects.mouse_filter == Control.MOUSE_FILTER_PASS, "talent text receives hover while allowing input propagation")
	check(panel._effects.text.contains("[hint=无缝换台：") and panel._effects.text.contains("[hint=安可托管："), "each talent has an individual hover description")
	check(PersonaStatusPanel.talent_tooltip(&"encore_autopilot").contains("0.8秒"), "encore hover explains actual duration")
	await process_frame
	check(panel._effects.get_tooltip(Vector2(20, 8)).contains("下一次攻击"), "hovering first talent resolves its own effect tooltip")
	check(panel._effects.get_tooltip(Vector2(90, 8)).contains("100%"), "hovering encore resolves its distinct trigger description")
	for hud_scale in [1.0, 1.25, 1.5]:
		hud.set_hud_scale(hud_scale)
		var bounds := panel.get_global_rect()
		check(bounds.end.x <= root.get_visible_rect().size.x and bounds.position.x > 0, "right anchored status stays inside viewport at %s scale" % hud_scale)
	hud.set_hud_scale(1.0)
	await capture("rock", hud)
	core.set_persona_level(TalentCoreController.LEGENDARY_MASTER, 3)
	core.set_persona(TalentCoreController.LEGENDARY_MASTER)
	core.set_talent_choice(core.current_persona_id, 1, &"calibrated_window")
	core.set_talent_choice(core.current_persona_id, 2, &"refutation_reward")
	core.set_talent_choice(core.current_persona_id, 3, &"master_loop")
	combat._record_attack_sample(enemy, "hud-test-attack")
	hud._process(0)
	check(panel._meter.value == 1 and panel._detail.text.contains("1/2"), "first observed attack shows partial analysis")
	combat._record_attack_sample(enemy, "hud-test-attack")
	hud._process(0)
	check(panel._meter.value == 2 and panel._detail.text.contains("已解析"), "repeated attack completes threat analysis")
	check(panel._effects.get_parsed_text().contains("●闭环震慑"), "master loop shows its actual stagger effect")
	await capture("master", hud)
	comms.set_message("先处理护卫链路，再攻击本体。")
	comms.set_expanded(true, false)
	hud._process(0)
	check(panel.position.y >= comms.position.y + comms.size.y, "expanded communications move status below the portrait")
	await capture("comms_expanded", hud)
	comms.set_expanded(false, false)
	hud._process(0)
	check(panel.position.x >= comms.position.x + comms.size.x, "collapsed communications restore adjacent status")
	comms.set_expanded(true, false)
	comms.set_expanded(false, true)
	hud._process(0)
	check(panel.position.y >= comms.position.y + comms.size.y, "status stays below communications during collapse animation")
	await comms._size_tween.finished
	hud._process(0)
	check(panel.position.x >= comms.position.x + comms.size.x, "animated collapse restores compact status without stale minimum width")
	enemy.queue_free()
	await process_frame
	hud._process(0)
	check(panel._detail.text.contains("等待交锋") and panel._meter.value == 0, "freed threat clears analysis display safely")
	player.health.set_current_health(0)
	hud._process(0)
	check(not panel._meter.visible and panel._effects.text.is_empty(), "death clears active effect presentation")
	room.queue_free()
	await process_frame
	print("Persona status HUD checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)

func capture(label: String, hud: Node) -> void:
	if not "--capture-persona-status" in OS.get_cmdline_user_args():
		return
	hud.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/art/validation/persona_status_v1")
	root.get_texture().get_image().save_png("res://docs/art/validation/persona_status_v1/%s.png" % label)
	hud.set_process(true)
