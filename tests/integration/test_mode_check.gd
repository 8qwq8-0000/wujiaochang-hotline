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
		root.get_node("GameSettings").quit_game(1)
		return
	var original: Dictionary = store.get_profile()
	var original_bytes := FileAccess.get_file_as_bytes(SAVE)
	var tools: CanvasLayer = root.get_node("GameSettings").test_tools
	check(not tools.enabled and not tools._badge.visible, "test mode defaults off")
	check(tools._launcher == null or not tools._launcher.visible, "desktop test tools do not show a touch launcher")
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
	var command_result: Dictionary = await tools.run_command("help jump")
	check(command_result.ok and String(command_result.message).contains("floor1"), "command help explains jump parameters")
	command_result = await tools.run_command("jump unknown")
	check(not command_result.ok and String(command_result.message).contains("jump"), "invalid command shows usage without mutating the game")
	await key(KEY_ESCAPE)
	check(tools.enabled and not tools._overlay.visible and not paused, "Esc resumes play while retaining the isolated test session")
	tools._badge.pressed.emit()
	check(tools._overlay.visible and paused, "badge reopens the paused test panel")
	var categories: OptionButton = tools._equipment_category
	var equipment: OptionButton = tools._items
	check(categories.get_selected_metadata() == "weapon", "equipment supply defaults to weapons")
	var listed_ids: Array[String] = []
	for category_index in categories.item_count:
		categories.select(category_index)
		categories.item_selected.emit(category_index)
		var slot: String = categories.get_selected_metadata()
		check(equipment.item_count > 0 and equipment.selected == 0, "equipment category selects its first item: %s" % slot)
		check(tools._quality.disabled == (slot not in ["weapon", "defense"]), "equipment category enables applicable quality selection: %s" % slot)
		for index in equipment.item_count:
			var id: String = equipment.get_item_metadata(index)
			check(ComponentInventory.PROTOTYPES.data[id].get("slot") == slot and id not in listed_ids, "equipment appears once in its own category: %s" % id)
			listed_ids.append(id)
	check(listed_ids.size() == tools._item_ids.size(), "equipment categories expose all grantable items")
	categories.select(0)
	categories.item_selected.emit(0)
	for index in equipment.item_count:
		if equipment.get_item_metadata(index) == "rail_cannon":
			equipment.select(index)
			break
	tools._quality.select(2)
	tools._grant_button.pressed.emit()
	check(tools._message.text.begins_with("已领取"), "equipment button grants the selected weapon")
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
	command_result = await tools.run_command("seed 77441")
	check(command_result.ok, "command accepts a deterministic next-jump seed")
	command_result = await tools.run_command("jump lab")
	check(command_result.ok and root.get_node("RunManager").run_seed == 77441, "command jump shares the real scene setup and seed")
	command_result = await tools.run_command("report")
	var report_path := String(command_result.message).trim_prefix("报告已保存：")
	var report_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path)) if command_result.ok else null
	check(command_result.ok and report_data is Dictionary and int(report_data.state.seed) == 77441 and report_data.commands.size() >= 3, "command report preserves reproducible scene state and history")
	if command_result.ok:
		var replay_result: Dictionary = await tools.run_command("replay " + report_path.get_file())
		check(replay_result.ok and root.get_node("RunManager").run_seed == 77441, "reported scenario commands can be replayed")
		DirAccess.remove_absolute(report_path)
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
		var assembler: FloorAssembler = floor.get_node("FloorAssembler")
		if index == 0:
			var packet := DamagePacket.new()
			packet.source_faction = CombatFaction.Id.PLAYER
			var waiting_for_explosion := false
			for enemy in assembler.generated_rooms[0].get_node("Enemies").get_children():
				if enemy is EnemyController and enemy.mandatory and enemy.profile.self_destruct_enabled:
					enemy.health.apply_damage(enemy.health.max_health, packet)
					waiting_for_explosion = enemy.state == EnemyController.State.SELF_DESTRUCT
					break
			check(waiting_for_explosion, "first area has a defeated heavy waiting to self-destruct")
		tools.open_panel()
		check(tools.clear_area(), "one-click clear accepts floor")
		check(assembler._rooms_remaining == 0, "clear includes inactive combat areas")
		check(root.get_node("RunManager").mandatory_enemies_remaining == 0, "floor objectives cleared normally")
		if index == 0:
			var corridor := assembler.passages[0]
			check(corridor.unlocked, "clear opens the passage even with a pending self-destruct")
			tools.close_panel()
			player.global_position = corridor.global_position - Vector2(12.0, 0.0)
			player.set_physics_process(true)
			Input.action_press("move_right")
			for frame in 120:
				await physics_frame
				if assembler.active_area_index == 1:
					break
			Input.action_release("move_right")
			check(assembler.active_area_index == 1 and corridor.return_sealed, "player can walk from area one into area two after F8 clear")
			var second_room: CombatRoom = assembler.generated_rooms[1]
			check(player.camera.limit_left == floori(second_room.global_position.x) and player.camera.limit_right == ceili(second_room.global_position.x + CombatRoom.ROOM_SIZE.x), "camera switches to area two even though F8 already activated and cleared it")
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
	var opening_guards := arena.get_node("Enemies")
	check(opening_guards.get_child_count() == 2, "both opening wings are present before the shortcut")
	var left_wing := opening_guards.get_child(0) as WingGuard
	left_wing._fire_slash(2)
	var wing_slash := opening_guards.get_child(2) as WingSlashProjectile
	check(is_instance_valid(wing_slash), "opening wing launches an actual slash")
	tools.open_panel()
	check(tools.defeat_boss(), "quick Boss win bypasses awakening immunity")
	check(arena.phase == RooftopBossArena.Phase.CLEARED and arena.boss.health.is_dead(), "Boss defeat updates actual state")
	check(root.get_node("RunManager").mandatory_enemies_remaining == 0, "Boss victory clears remaining guards")
	await process_frame
	check(opening_guards.get_child_count() == 0 and not is_instance_valid(wing_slash), "quick victory removes both opening wings and their lingering slash")
	check(await tools.jump_to(3), "Boss can be restarted after quick victory")
	arena = await wait_room() as RooftopBossArena
	arena.attack_loop_enabled = false
	arena.boss.activate_immediately()
	arena._set_phase(RooftopBossArena.Phase.BOSS_ACTIVE)
	arena._spawn_support_guards()
	check(arena.boss.health.guard_link_active, "second-phase shield is active")
	tools.open_panel()
	check(tools.defeat_boss() and arena.phase == RooftopBossArena.Phase.CLEARED, "quick victory also handles shielded second phase")
	await process_frame
	arena._spawn_support_guards()
	check(arena.get_node("SupportEnemies").get_child_count() == 0, "quick victory removes the fused wing and blocks delayed respawns")
	tools.close_panel()
	var record_count: int = store.get_legacy_drinks().size()
	var extraction := main.get_node("ExtractionFlow")
	arena.player.set_physics_process(false)
	var exit_point := arena.exit_elevator.global_position
	arena.player.global_position = exit_point - Vector2(0, 100)
	for frame in 4:
		await physics_frame
	arena.player.global_position = exit_point
	for frame in 4:
		await physics_frame
	check(extraction.get("_overlay").visible, "walking into the rooftop exit opens victory choices")
	arena.player.global_position = exit_point + Vector2(0, 24)
	for frame in 4:
		await physics_frame
	check(extraction.get("_overlay").visible, "the victory dialogue stays open below the rooftop exit")
	arena.player.global_position = exit_point + Vector2(100, 24)
	for frame in 4:
		await physics_frame
	check(not extraction.get("_overlay").visible, "leaving the enlarged rooftop exit closes the dialogue")
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
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
