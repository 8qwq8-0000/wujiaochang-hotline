extends SceneTree

const SAVE := "res://.godot/test-mode-check.json"
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_room() -> Node:
	for frame in 600:
		await process_frame
		var main := current_scene
		var flow := main.get_node_or_null("SceneFlow") if main != null else null
		if flow != null and not flow._is_loading and flow._scene_container.get_child_count() > 0:
			return flow._scene_container.get_child(0)
	return null

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	check(store.create_new_profile(), "isolated formal fixture is writable")
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.0
	root.add_child(main)
	current_scene = main
	var warehouse := await wait_room()
	check(warehouse != null, "warehouse loads")
	if warehouse == null:
		quit(1)
		return
	var original: Dictionary = store.get_profile()
	var original_bytes := FileAccess.get_file_as_bytes(SAVE)
	var tools: CanvasLayer = root.get_node("GameSettings").test_tools
	check(not tools.enabled and not tools._badge.visible, "test mode defaults off")
	check(not tools.grant_item("rail_cannon", 3), "equipment command rejects normal mode")
	check(not tools.apply_talents(&"deep_ninja", 1, [&"read_opening"]), "talent command rejects normal mode")
	check(not await tools.jump_to(3), "jump rejects normal mode")
	var menu := main.get_node("PauseSettingsMenu")
	menu.open_settings_only()
	var obsolete_switch := false
	for button in menu.find_children("*", "BaseButton", true, false):
		obsolete_switch = obsolete_switch or "测试模式" in button.text or "打开测试面板" in button.text
	check(not obsolete_switch, "settings no longer contains the test mode switch or entry")
	menu.close_menu()
	await key(KEY_F8)
	check(tools.enabled and store.test_session_active and tools._badge.visible, "F8 enables the isolated session directly")
	check(tools._overlay.visible and paused, "F8 immediately opens the paused test panel")
	await key(KEY_F8)
	check(tools.enabled and not tools._overlay.visible and not paused and current_scene == main, "F8 closes only panel and keeps current game instead of returning to menu")
	await key(KEY_F8)
	check(tools.enabled and tools._overlay.visible and paused, "F8 reopens panel without restarting test session")
	await key(KEY_ESCAPE)
	check(tools.enabled and not tools._overlay.visible and not paused, "Esc resumes play while retaining the isolated test session")
	tools._badge.pressed.emit()
	check(tools._overlay.visible and paused, "badge reopens the paused test panel")
	check(tools.grant_item("rail_cannon", 3), "prototype weapon can be granted")
	check(ComponentRolls.quality(warehouse.player.inventory.secondary_weapon_slot.get_item()) == 3, "granted weapon retains requested quality")
	# The merged control panel must expose the main branch's advanced modules,
	# and granting them must still use the real inventory with isolated saves.
	for advanced_id in ["momentum_recovery_tendon", "trajectory_echo_processor", "ballistic_takeover_protocol", "arc_ballistic_cortex", "inertial_inversion_vertebra", "axon_recycler", "micro_rotor_reflex_bundle", "predatory_vestibular_ring"]:
		var module_id := StringName(advanced_id)
		var circuit: CyberwareCircuitState = warehouse.player.cyberware.circuit
		var previous_count := int(circuit.get_library_counts().get(module_id, 0))
		check(advanced_id in tools._item_ids and tools.grant_item(advanced_id), "F8 grants advanced cyberware %s" % advanced_id)
		var prototype := ComponentRolls.make_item(advanced_id)
		check(prototype != null and prototype.get_texture() != null and int(circuit.get_library_counts().get(module_id, 0)) == previous_count + 1, "advanced module retains image and enters circuit library %s" % advanced_id)
	check(not tools.grant_item("unknown", 1), "unknown item rejected")
	check(not tools.grant_item("circuit_breaker", 1), "duplicate insurance core rejected")
	for index in 6:
		check(tools.grant_item("armor", 2), "backpack accepts equipment %d" % index)
	check(not tools.grant_item("armor", 3), "full backpack fails without deleting existing equipment")
	for id in TalentCoreController.PERSONA_IDS:
		for branch in 2:
			var choices: Array[StringName] = []
			for tier in range(1, 4):
				choices.append(TalentCoreController.TALENT_OPTIONS[id][tier][branch])
			check(tools.apply_talents(id, 3, choices), "all tiers can be selected for %s branch %d" % [id, branch])
			check(warehouse.player.talent_core.get_active_talents() == choices, "selected talents are active")
	var before_bad: Dictionary = warehouse.player.talent_core.export_state()
	check(not tools.apply_talents(&"deep_ninja", 3, [&"read_opening", &"blood_step", &"invalid"]), "invalid build rejected")
	check(before_bad == warehouse.player.talent_core.export_state(), "invalid build has no partial mutations")
	check(warehouse.save_loadout(), "test warehouse autosave succeeds in memory")
	check(FileAccess.get_file_as_bytes(SAVE) == original_bytes, "test equipment and talents do not touch disk")
	check(await tools.jump_to(-2), "dedicated cyberware circuit lab jump works")
	var circuit_lab := await wait_room()
	check(circuit_lab != null and circuit_lab.scene_file_path == "res://scenes/debug/cyberware_circuit_lab.tscn", "test flow loads the circuit lab inside the persistent gameplay host")
	check(circuit_lab.get_node("Player").cyberware.circuit.get_library_counts().size() == 9, "real test-mode jump grants the first-playable circuit library")
	check(await tools.jump_to(-1), "circuit lab can return to the test warehouse")
	warehouse = await wait_room()
	for index in 3:
		check(await tools.jump_to(index), "direct jump reaches floor %d" % (index + 1))
		var floor := await wait_room()
		var player: PlayerController = floor.get_node("Player")
		player.set_physics_process(false)
		check(root.get_node("RunManager").floor_index == index, "floor scaling index matches jump")
		check(not paused, "jump bypasses mandatory persona rest without leaving pause stuck")
		check(player.talent_core.core_level == 3 and player.inventory.secondary_weapon_slot.get_item() != null, "jump preserves testing build")
		tools.open_panel()
		check(tools.clear_area(), "one-click clear accepts floor")
		check(floor.get_node("FloorAssembler")._rooms_remaining == 0, "clear includes inactive combat areas")
		check(root.get_node("RunManager").mandatory_enemies_remaining == 0, "floor objectives cleared normally")
	check(await tools.jump_to(-1), "test warehouse jump works")
	warehouse = await wait_room()
	check(warehouse.player.talent_core.core_level == 3 and warehouse.player.inventory.secondary_weapon_slot.get_item() != null, "warehouse jump preserves test build")
	check(await tools.jump_to_codex(), "direct Codex passage preserves current test build")
	var passage := await wait_room()
	check(passage.is_in_group("intermission") and root.get_node("RunManager").floor_index == 1, "passage jump uses the second-floor intermission")
	passage.talk_to_codex()
	check(not passage.get("_escort_dialogue"), "ordinary passage keeps ordinary Codex conversation")
	passage.panel.close()
	check(not await tools.jump_to_codex(true), "core passage refuses a full backpack without discarding equipment")
	var material = passage.player.inventory.backpack.get_items()[0]
	passage.player.inventory.backpack.remove_item(material)
	check(await tools.jump_to_codex(true), "core passage jump grants actual core in isolated session")
	passage = await wait_room()
	check(root.get_node("RunManager").carries_channel_core(passage.player), "core passage contains real prerequisite collectible")
	check(passage.player.talent_core.core_level == 3 and passage.player.inventory.secondary_weapon_slot.get_item() != null, "passage jump preserves equipment and selected talents")
	passage.talk_to_codex()
	check(passage.get("_escort_dialogue") and passage.panel.lines[0].contains("残损频道核心"), "core passage jump triggers new escort conversation")
	while passage.panel.is_open:
		passage.panel.advance()
	for _frame in 4:
		await process_frame
	passage.upgrade_panel.close()
	check(root.get_node("RunManager").codex_is_alive() and passage.get_node("CodexCompanion").health.current_health == 3, "test passage can recruit three-health Codex")
	check(FileAccess.get_file_as_bytes(SAVE) == original_bytes, "core unlock, pickup and escort never modify formal file")
	check(await tools.jump_to_channel_boss(), "direct second-ending Boss jump prepares actual route")
	var channel_arena := await wait_room() as RooftopBossArena
	check(channel_arena != null and channel_arena.channel_duel != null, "test jump reaches production duel controller")
	check(paused and channel_arena.route_dialogue.visible, "test jump preserves paused entry story")
	check(root.get_node("RunManager").channel_boss_ready() and root.get_node("RunManager").carries_channel_core(channel_arena.player), "test jump supplies core and completed ambush")
	check(FileAccess.get_file_as_bytes(SAVE) == original_bytes, "second-ending test jump cannot modify formal file")
	channel_arena.route_dialogue.close()
	check(await tools.jump_to(3), "direct Boss jump works")
	var arena := await wait_room() as RooftopBossArena
	check(arena != null and arena.phase == RooftopBossArena.Phase.MINIONS, "Boss starts in its normal opening phase")
	arena.player.set_physics_process(false)
	tools.open_panel()
	check(tools.defeat_boss(), "quick Boss win bypasses awakening immunity")
	check(arena.phase == RooftopBossArena.Phase.CLEARED and arena.boss.health.is_dead(), "Boss defeat updates actual state")
	check(root.get_node("RunManager").mandatory_enemies_remaining == 0, "Boss victory clears remaining guards")
	check(await tools.jump_to(3), "Boss can be restarted after quick victory")
	arena = await wait_room() as RooftopBossArena
	arena.attack_loop_enabled = false
	arena.boss.activate_immediately()
	arena._set_phase(RooftopBossArena.Phase.BOSS_ACTIVE)
	arena._spawn_support_guards()
	check(arena.boss.health.guard_link_active, "second-phase shield is active")
	tools.open_panel()
	check(tools.defeat_boss() and arena.phase == RooftopBossArena.Phase.CLEARED, "quick victory also handles shielded second phase")
	tools.close_panel()
	var record_count: int = store.get_legacy_drinks().size()
	var extraction := main.get_node("ExtractionFlow")
	extraction.complete_victory()
	check(extraction._settled and store.get_legacy_drinks().size() == record_count + 1, "test victory can exercise settlement and records")
	check(FileAccess.get_file_as_bytes(SAVE) == original_bytes, "test victory cannot write a formal record")
	check(store.create_new_profile("low_pressure"), "new profile can be tried in test mode")
	check(FileAccess.get_file_as_bytes(SAVE) == original_bytes, "test new profile does not replace formal save")
	tools.set_enabled(false)
	for frame in 600:
		await process_frame
		if not tools.enabled:
			break
	check(not tools.enabled and not store.test_session_active and not paused, "exit restores normal mode without a stuck pause")
	check(current_scene.scene_file_path == "res://scenes/ui/start_menu.tscn", "exit returns to the main menu")
	check(store.get_profile() == original, "formal inventory, codex and records restored exactly")
	check(FileAccess.get_file_as_bytes(SAVE) == original_bytes, "formal save is byte-identical after the whole session")
	check(not tools.defeat_boss() and not tools.clear_area(), "combat commands disabled after exit")
	check(not tools._badge.visible and not tools._overlay.visible, "test UI is hidden after exit")
	await key(KEY_F8)
	check(tools.enabled and tools._overlay.visible, "F8 re-enables test mode directly from main menu")
	check(await tools.jump_to_codex(true), "main menu can jump directly to core passage")
	var menu_passage := await wait_room()
	check(menu_passage.is_in_group("intermission") and root.get_node("RunManager").carries_channel_core(menu_passage.player), "main menu route prepares playable core passage")
	check(await tools.jump_to(3), "main menu jump creates a gameplay host")
	var second_arena := await wait_room() as RooftopBossArena
	check(second_arena != null, "main menu direct Boss reaches arena")
	second_arena.player.health.set_current_health(0)
	check(await tools.jump_to(0), "jump can recover a dead test player")
	var recovered := await wait_room()
	check(not recovered.get_node("Player").health.is_dead(), "jump refills test player health")
	var second_menu := current_scene.get_node("PauseSettingsMenu")
	second_menu.open_settings_only()
	tools.set_enabled(false)
	for frame in 600:
		await process_frame
		if not tools.enabled:
			break
	check(store.get_profile() == original and FileAccess.get_file_as_bytes(SAVE) == original_bytes, "repeated test sessions still preserve formal profile")
	check(store.commit(original.chest, original.loadout), "normal saving still works after test session")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Test mode checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
