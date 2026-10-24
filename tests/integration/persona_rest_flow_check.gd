extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func wait_for_rest(main: Node) -> Node:
	for _frame in 600:
		await process_frame
		var rest: Node = main.get_node("PersonaRestFlow")
		if rest.is_open:
			return rest
	return null


func wait_for_floor(flow: SceneContainerManager) -> PlayerController:
	for _frame in 600:
		await process_frame
		var player := get_first_node_in_group("player") as PlayerController
		if player != null and not flow.get("_is_loading"):
			return player
	return null


func run_checks() -> void:
	var run: Node = root.get_node("RunManager")
	run.begin_run(20261021)
	run.persistent_run = true
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow := main.get_node("SceneFlow") as SceneContainerManager
	flow.fade_duration = 0.0
	var combat_hud := main.get_node("CombatHUD")
	check(not combat_hud.get_node("Overlay").visible, "combat HUD stays hidden while the initial scene is loading")
	var rest: Node = await wait_for_rest(main)
	check(rest != null, "first-floor persistent run opens mandatory persona rest")
	if rest == null:
		main.queue_free()
		await process_frame
		quit(1)
		return
	var player := get_first_node_in_group("player") as PlayerController
	check(paused and not player.is_input_enabled(), "rest pauses combat and disables player input")
	check(run.has_persona_authorization(0), "first floor grants one pending authorization")
	check(player.talent_core.get_persona_level(TalentCoreController.LEGENDARY_MASTER) == 0, "fresh run has no preinstalled persona")
	check(rest.choose_persona(TalentCoreController.DEEP_NINJA), "drink consumes first-floor authorization")
	check(player.talent_core.current_persona_id == TalentCoreController.DEEP_NINJA, "drink activates selected persona")
	check(player.talent_core.get_persona_level(TalentCoreController.DEEP_NINJA) == 1, "first drink installs level one")
	check(not run.has_persona_authorization(0), "authorization cannot be reused on same floor")
	check(not rest.choose_persona(TalentCoreController.ROCK_VIGILANTE), "second drink is rejected on same floor")
	var talent_buttons: Array[Node] = rest.get("_talent_column").find_children("*", "Button", true, false)
	check(talent_buttons.size() == 6, "rest screen shows all three talent tiers")
	check(talent_buttons.filter(func(button: Button) -> bool: return bool(button.get_meta("talent_locked", false))).size() == 4, "future talent tiers remain visible, focusable, and locked")
	await rest._show_talent_tooltip(talent_buttons[0], &"read_opening", 1, false)
	check(rest.get("_talent_tooltip_label").get_parsed_text().contains("猎痕") and rest.get("_talent_tooltip_label").get_parsed_text().contains("失衡"), "talent hover exposes exact effect and glossary terms")
	rest._hide_talent_tooltip()
	check(rest.choose_talent(1, &"read_opening"), "unlocked talent can be selected at rest")
	check(rest.close(), "rest can close after authorization is consumed")
	check(not paused and player.is_input_enabled(), "closing rest returns control")
	player.talent_core.takeover_charges = 0
	var snapshot := player.export_run_state()
	run.set_player_state(snapshot)
	run.floor_index = 1
	check(flow.request_scene("res://scenes/levels/floors/combat_prototype.tscn", {"player_state": snapshot}), "next floor scene request succeeds")
	check(not combat_hud.get_node("Overlay").visible, "combat HUD hides immediately when a scene transition starts")
	player = await wait_for_floor(flow)
	rest = await wait_for_rest(main)
	check(rest != null and run.has_persona_authorization(1), "next floor grants exactly one new authorization")
	check(player.talent_core.takeover_charges == player.talent_core.takeover_charge_max, "new-floor rest refills shared takeover once")
	check(rest.choose_persona(TalentCoreController.ROCK_VIGILANTE), "next-floor authorization can switch persona")
	check(player.talent_core.get_persona_level(TalentCoreController.DEEP_NINJA) == 1, "switch preserves inactive persona level")
	check(player.talent_core.get_talent_choice(TalentCoreController.DEEP_NINJA, 1) == &"read_opening", "switch preserves inactive persona build")
	check(player.talent_core.get_persona_level(TalentCoreController.ROCK_VIGILANTE) == 1, "new persona installs at level one")
	rest.close()
	main.queue_free()
	await process_frame
	print("Persona rest flow failures: ", failures)
	quit(0 if failures == 0 else 1)
