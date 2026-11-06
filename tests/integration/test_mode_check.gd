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
	menu._test_mode.set_pressed(true)
	check(tools.enabled and store.test_session_active and tools._badge.visible, "settings switch enables the isolated session")
	menu._open_test_tools()
	check(tools._overlay.visible and paused, "settings opens a paused test panel")
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_F8
	shortcut.pressed = true
	root.push_input(shortcut, true)
	await process_frame
	check(not tools._overlay.visible and not paused, "F8 closes and resumes a test panel")
	root.push_input(shortcut, true)
	await process_frame
	check(tools._overlay.visible and paused, "F8 opens and pauses a test panel")
	check(tools.grant_item("rail_cannon", 3), "prototype weapon can be granted")
	check(ComponentRolls.quality(warehouse.player.inventory.secondary_weapon_slot.get_item()) == 3, "granted weapon retains requested quality")
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
	var extraction := main.get_node("ExtractionFlow")
	extraction.complete_victory()
	check(extraction._settled and not store.get_legacy_drinks().is_empty(), "test victory can exercise settlement and records")
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
	check(tools.set_enabled(true), "test mode can be re-enabled from main menu")
	check(await tools.jump_to(3), "main menu jump creates a gameplay host")
	var second_arena := await wait_room() as RooftopBossArena
	check(second_arena != null, "main menu direct Boss reaches arena")
	second_arena.player.health.set_current_health(0)
	check(await tools.jump_to(0), "jump can recover a dead test player")
	var recovered := await wait_room()
	check(not recovered.get_node("Player").health.is_dead(), "jump refills test player health")
	var second_menu := current_scene.get_node("PauseSettingsMenu")
	second_menu.open_settings_only()
	second_menu._test_mode.set_pressed(false)
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
