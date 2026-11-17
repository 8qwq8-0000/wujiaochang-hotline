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


func press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


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
		root.get_node("GameSettings").quit_game(1)
		return
	var player := get_first_node_in_group("player") as PlayerController
	check(paused and not player.is_input_enabled(), "rest pauses combat and disables player input")
	check(run.has_persona_authorization(0), "first floor grants one pending authorization")
	check(player.talent_core.get_persona_level(TalentCoreController.LEGENDARY_MASTER) == 0, "fresh run has no preinstalled persona")
	var persona_button: Button = rest.get("_persona_buttons")[TalentCoreController.DEEP_NINJA]
	check(persona_button.get_theme_stylebox("normal") is StyleBoxTexture and (persona_button.get_node("BottleIcon") as TextureRect).texture != null, "persona option combines the graphite card art with its existing bottle")
	await press_escape()
	check(rest.is_open and paused and not player.is_input_enabled(), "Esc before drinking cannot skip mandatory rest")
	check(run.has_persona_authorization(0) and not main.get_node("PauseSettingsMenu").visible, "Esc preserves authorization and does not open pause menu")
	check(rest.choose_persona(TalentCoreController.DEEP_NINJA), "drink stages first-floor persona choice")
	check(player.cyberware.circuit.slot_capacity == 4 and is_equal_approx(player.cyberware.circuit.maximum_energy, 80.0), "first drink opens a fourth slot and adds twenty energy capacity")
	check(player.talent_core.current_persona_id == TalentCoreController.DEEP_NINJA, "drink activates selected persona")
	check(player.talent_core.get_persona_level(TalentCoreController.DEEP_NINJA) == 1, "first drink installs level one")
	check((persona_button.get_node("SelectionLine") as ColorRect).visible, "staged persona keeps a visible amber selection line")
	check(run.has_persona_authorization(0), "authorization remains pending until explicit leave")
	check(not rest.choose_persona(TalentCoreController.ROCK_VIGILANTE), "second drink is rejected on same floor")
	check(rest.choose_talent(1, &"read_opening"), "staged persona allows talent preview")
	check(rest.undo_choice(), "staged persona choice can be withdrawn")
	check(player.cyberware.circuit.slot_capacity == 3 and is_equal_approx(player.cyberware.circuit.maximum_energy, 60.0), "undo restores initial circuit capacity and energy")
	check(player.talent_core.get_persona_level(TalentCoreController.DEEP_NINJA) == 0 and player.talent_core.get_talent_choice(TalentCoreController.DEEP_NINJA, 1).is_empty(), "undo restores level and talents")
	check(run.has_persona_authorization(0) and rest.choose_persona(TalentCoreController.DEEP_NINJA), "withdrawn choice can be selected again")
	check(rest.has_unselected_active_talents(), "newly installed persona reports its unlocked empty talent tier")
	await press_escape()
	check(rest.is_open and paused and not player.is_input_enabled(), "Esc after drinking cannot skip talent selection")
	check(not main.get_node("PauseSettingsMenu").visible, "handled Esc cannot reach the global pause menu")
	var talent_buttons: Array[Node] = rest.get("_talent_column").find_children("*", "Button", true, false)
	check(talent_buttons.size() == 6, "rest screen shows all three talent tiers")
	for layout_frame in 3:
		await process_frame
	var viewport_bounds: Rect2 = rest.get("_overlay").get_global_rect()
	check(viewport_bounds.encloses(rest.get("_close_button").get_global_rect()), "leave confirmation remains fully inside the talent screen")
	var talent_scroll := rest.get("_talent_column").get_parent() as ScrollContainer
	check(talent_scroll != null, "talent descriptions have a scrollable reading area")
	for button: Button in talent_buttons:
		check(button.get_global_rect().position.x >= talent_scroll.get_global_rect().position.x and button.get_global_rect().end.x <= talent_scroll.get_global_rect().end.x, "long talent text cannot push either choice off the right edge")
	talent_scroll.ensure_control_visible(talent_buttons[-1])
	await process_frame
	check(talent_scroll.get_global_rect().encloses(talent_buttons[-1].get_global_rect()), "scrolling reaches the complete final talent choice")
	talent_scroll.ensure_control_visible(talent_buttons[0])
	await process_frame

	check(talent_buttons.filter(func(button: Button) -> bool: return bool(button.get_meta("talent_locked", false))).size() == 4, "future talent tiers remain visible, focusable, and locked")
	var viewport_size: Vector2 = (rest.get("_overlay") as Control).get_viewport_rect().size
	for button: Button in talent_buttons:
		var button_rect := button.get_global_rect()
		check(button_rect.position.x >= 0.0 and button_rect.position.y >= 0.0 and button_rect.end.x <= viewport_size.x + 0.5 and button_rect.end.y <= viewport_size.y + 0.5, "talent button stays inside the 640x360 viewport")
	await rest._show_talent_tooltip(talent_buttons[0], &"read_opening", 1, false)
	check(rest.get("_talent_tooltip_label").get_parsed_text().contains("猎痕") and rest.get("_talent_tooltip_label").get_parsed_text().contains("失衡"), "talent hover exposes exact effect and glossary terms")
	var tooltip: Control = rest.get("_talent_tooltip")
	var tooltip_rect := tooltip.get_global_rect()
	check(tooltip.visible, "talent hover opens the explanation")
	check(tooltip_rect.position.x >= 7.5 and tooltip_rect.position.y >= 7.5 and tooltip_rect.end.x <= viewport_size.x - 7.5 and tooltip_rect.end.y <= viewport_size.y - 7.5, "talent explanation is clamped to every viewport edge")
	check(tooltip.size.x <= 250.5 and tooltip.size.y <= 236.5, "talent explanation uses the compact bounded size")
	check(rest.get("_talent_tooltip_label").scroll_active, "long talent explanations can scroll instead of leaving the screen")
	check(viewport_bounds.encloses(rest.get("_talent_tooltip").get_global_rect()), "talent effect tooltip stays inside the viewport")
	await press_escape()
	check(not rest.get("_talent_tooltip").visible and rest.is_open, "Esc dismisses explanation while keeping talent selection open")
	rest._hide_talent_tooltip()
	check(rest.close(), "rest may close while an unlocked talent is still empty")
	check(not run.has_persona_authorization(0), "leaving commits the staged choice exactly once")
	var hint_tray := main.get_node("ControlHintTray") as ControlHintTray
	check(hint_tray._expanded and paused, "control hint pauses combat when it opens after the drink")
	hint_tray._set_expanded(false)
	check(not paused and player.is_input_enabled(), "closing an incomplete rest screen returns control")
	var escape := InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	rest._input(escape)
	check(rest.is_open and paused and not player.is_input_enabled(), "escape reopens persona rest before the pause menu while the active talent is empty")
	check(rest.choose_talent(1, &"read_opening"), "unlocked talent can be selected at rest")
	check(not rest.has_unselected_active_talents(), "selecting every unlocked tier restores normal pause behavior")
	await press_escape()
	check(rest.is_open and paused and player.talent_core.get_talent_choice(TalentCoreController.DEEP_NINJA, 1) == &"read_opening", "Esc after configuring keeps rest open and preserves selected talent")
	check(rest.close(), "rest can close after authorization is consumed")
	check(not paused and player.is_input_enabled(), "closing rest returns control")
	check(not rest._can_reopen_from_pause(), "completed active build no longer intercepts escape")
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
	await press_escape()
	check(rest.is_open and paused and player.talent_core.current_persona_id == TalentCoreController.ROCK_VIGILANTE, "Esc cannot skip talent selection on subsequent floors")
	rest.get("_close_button").pressed.emit()
	check(hint_tray._expanded and paused, "control hint pauses the next floor after a drink")
	hint_tray._set_expanded(false)
	check(not rest.is_open and not paused and player.is_input_enabled(), "explicit leave button still returns control")
	main.queue_free()
	await process_frame
	print("Persona rest flow failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
