extends SceneTree

var save_path := "user://prologue-check-%d.json" % OS.get_process_id()
const PROLOGUE := "res://scenes/levels/prologue/hotline_prologue.tscn"
const WAREHOUSE := "res://scenes/levels/base/warehouse.tscn"
var checks := 0
var failures := 0
var store: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func click_at(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)


func frames(count := 3) -> void:
	for index in count:
		await physics_frame
		await process_frame
		# Combat feedback uses wall-clock hit-stop deadlines, even with fixed game delta.
		OS.delay_msec(2)


func wait_transition(room: HotlinePrologue) -> void:
	for index in 300:
		if room.get("_pending_step") < 0:
			break
		await frames(1)


func drain_dialogue(room: HotlinePrologue) -> void:
	await wait_transition(room)
	for index in 24:
		if room.get("_dialogue_remaining") <= 0.0 and room.get("_dialogue_queue").is_empty():
			break
		key(KEY_ENTER)
		key(KEY_ENTER, false)
		await frames(1)
	await frames()


func wait_room(path: String) -> Node:
	for index in 700:
		await process_frame
		# Give threaded resource loading wall-clock time under uncapped headless rendering.
		OS.delay_msec(2)
		var main := current_scene
		if main == null:
			continue
		var flow := main.get_node_or_null("SceneFlow")
		var container := main.get_node_or_null("SceneContainer")
		if flow != null and not flow.get("_is_loading") and container.get_child_count() > 0:
			var room: Node = container.get_child(0)
			if room.scene_file_path == path:
				return room
	return null


func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture" in OS.get_cmdline_user_args():
		return
	await frames(120 if path.ends_with("opening.png") or path.ends_with("operator.png") else 16)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func shoot_at(room: HotlinePrologue, enemy: Node2D) -> void:
	var player := room.player
	player.set_physics_process(false)
	player.position = enemy.position - Vector2(60, 0)
	player.visuals.weapon_pivot.cancel_feedback()
	player.visuals.update_visual(Vector2.RIGHT, Vector2.ZERO, GuardComponent.State.IDLE, 120, 0, enemy.position)
	player.weapons.reset_transient_state()
	player.heat.reduce_heat(1000)
	await frames()
	var attack := player._get_attack_transform()
	check(player.weapons.try_attack(attack.origin, attack.x, player), "issued pistol submits fire: energy %.1f cooldown %.2f slots %s" % [player.cyberware.circuit.current_energy, player.weapons.get_cooldown_remaining(), str(player.cyberware.circuit.get_slots())])
	await frames(48)
	player.set_physics_process(true)


func aim_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)


func close_arrival() -> void:
	key(KEY_ENTER)
	key(KEY_ENTER, false)
	await frames()


func check_native_profile(enemy: EnemyController, path: String) -> void:
	var expected := load(path) as EnemyProfile
	check(is_equal_approx(enemy.profile.attack_windup, expected.attack_windup) and is_equal_approx(enemy.profile.attack_cooldown, expected.attack_cooldown), "tutorial attack windup and cooldown match production")
	check(is_equal_approx(enemy.profile.move_speed, expected.move_speed * 0.8), "tutorial movement is 20 percent slower than production")
	check(is_equal_approx(enemy.profile.projectile_speed, expected.projectile_speed * 0.85) and is_equal_approx(expected.projectile_speed, 310), "tutorial projectiles are 15 percent slower without modifying production profile")
	check(enemy.profile.tactical_enabled == expected.tactical_enabled and enemy.profile.patrol_enabled == expected.patrol_enabled and not enemy.stationary_test_target, "tutorial uses production tactical AI and patrol instead of a fixed target")
	check(enemy.profile.full_room_awareness == expected.full_room_awareness and is_equal_approx(enemy.profile.vision_angle_degrees, expected.vision_angle_degrees), "tutorial perception matches production")


func run() -> void:
	store = root.get_node("WarehouseStore")
	store.save_path = save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var menu: Control = load("res://scenes/ui/start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames()
	menu.set("_difficulty", "high_pressure")
	menu.start_new_game()
	var room := await wait_room(PROLOGUE) as HotlinePrologue
	check(room != null, "new save enters independent prologue")
	if room == null:
		root.get_node("GameSettings").quit_game(1)
		return
	var original := FileAccess.get_file_as_string(save_path)
	var combat_hud := current_scene.get_node("CombatHUD")
	check(not combat_hud.get("overlay").is_visible_in_tree(), "story opening hides the production combat HUD")
	check(room.step == HotlinePrologue.Step.BRIEFING, "opening starts in story dialogue")
	check(room.player.weapons.get_current_weapon() == null and room.player.inventory.weapon_slot.get_item() == null and room.player.inventory.secondary_weapon_slot.get_item() == null, "opening really starts without any gun")
	check(not room.player.visible and not room.get_node("Art").visible, "opening hides actors and scenery")
	check(not room.player.is_input_enabled() and room.targets.is_empty(), "opening locks movement and spawns no enemies")
	check(root.get_node("GameSettings").high_pressure_alert, "difficulty is preserved")
	await capture("/tmp/hotline-prologue-opening.png")
	var start := room.player.position
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	check(room.player.position.distance_to(start) < 1, "movement input cannot advance before accepting task")
	for index in 12:
		if room.step != HotlinePrologue.Step.BRIEFING:
			break
		for wait_index in 240:
			if room.get("_line_age") >= 1.0:
				break
			await frames(1)
		key(KEY_ENTER)
		key(KEY_ENTER, false)
		await frames()
		if index == 0:
			await capture("/tmp/hotline-prologue-operator.png")
	check(room.step == HotlinePrologue.Step.DODGE and room.player.visible and paused and not room.player.is_input_enabled(), "dash instruction pauses play after accepting briefing")
	check(combat_hud.get("overlay").is_visible_in_tree() and combat_hud.get("_player") == room.player, "paused tutorial uses production HUD bound to the practice player")
	check(combat_hud.get("_health_meter").value == room.player.health.current_health and combat_hud.find_child("CurrentWeaponPreview", true, false) == null, "production HUD shows real health without a gun thumbnail")
	var frozen_player := room.player.position
	var frozen_enemy := room.targets[0].position
	Input.action_press("move_right")
	key(KEY_E)
	key(KEY_E, false)
	key(KEY_TAB)
	key(KEY_TAB, false)
	await frames(180)
	Input.action_release("move_right")
	check(paused and room.player.position == frozen_player and room.targets[0].position == frozen_enemy, "instruction freezes both player and native enemy until dismissed")
	check(not room.player.inventory.is_open and room.step == HotlinePrologue.Step.DODGE, "E and Tab cannot bypass a radio instruction")
	var dialogue_point: Vector2 = room.get("_dialogue").get_global_rect().get_center()
	click_at(dialogue_point, true)
	click_at(dialogue_point, false)
	await frames()
	check(not paused and room.player.is_input_enabled(), "left click on finished dialogue text restores play")
	if paused:
		root.get_node("GameSettings").quit_game(1)
		return
	check(room.targets.size() == 1, "dash lesson starts with one native melee enemy")
	var dodge_target := room.targets[0]
	check_native_profile(dodge_target, "res://resources/enemies/melee_pressure.tres")
	room.player.position = dodge_target.position - Vector2(70, 0)
	await frames()
	await capture("/tmp/hotline-prologue-dash.png")
	Input.action_press("move_right")
	key(KEY_SPACE)
	key(KEY_SPACE, false)
	await frames(35)
	Input.action_release("move_right")
	check(room.step == HotlinePrologue.Step.DODGE and room.get("_pending_step") == HotlinePrologue.Step.PARRY and not paused, "dash kill leaves time for movement and death animation before next lesson")
	await frames(25)
	check(room.step == HotlinePrologue.Step.DODGE and room.get("_gates")[0].collision_layer != 0, "next gate and dialogue do not switch within the first second")
	await wait_transition(room)
	check(room.step == HotlinePrologue.Step.PARRY and room.get("_gates")[0].collision_layer == 0, "next gate opens automatically after the transition delay")
	dialogue_point = Vector2(320, 200) # Outside the radio panel, in the game scene.
	click_at(dialogue_point, true)
	click_at(dialogue_point, false)
	await frames(1)
	check(paused and room.get("_dialogue").visible_characters == room.get("_dialogue").get_total_character_count(), "first scene click reveals unfinished dialogue without resuming combat")
	var panel_rect: Rect2 = room.get("_dialogue_panel").get_global_rect()
	click_at(panel_rect.position + Vector2(24, 12), true)
	click_at(panel_rect.position + Vector2(24, 12), false)
	await frames()
	check(not paused and room.player.is_input_enabled(), "second click on dialogue frame resumes play")
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.PARRY, "actual dash kill unlocks second lesson: parry")
	check(room.player.weapons.get_current_weapon() == null, "first dash kill grants no early gun")
	if room.step != HotlinePrologue.Step.PARRY:
		root.get_node("GameSettings").quit_game(1)
		return
	# The immediately preceding kill can pause the lesson mid-dash. Let that
	# real dash finish before freezing only player movement for deterministic aim.
	for index in 120:
		if not room.player.dash.is_dashing():
			break
		await frames(1)
	check(not room.player.dash.is_dashing(), "previous dash finishes before the stationary parry probe")
	var shooter := room.targets[0]
	check_native_profile(shooter, "res://resources/enemies/ranged_sightline.tres")
	var attacks := [0]
	root.get_node("CombatEvents").enemy_attack_performed.connect(func(source: Node, _damage: StringName, _melee: bool) -> void:
		if is_instance_valid(shooter) and source == shooter:
			attacks[0] += 1
	)
	room.player.position = shooter.position - Vector2(50, 0)
	# Headless viewports cannot warp the OS pointer; only the player aim is fixed.
	# The enemy keeps its real movement, windup, AI and projectile callbacks.
	room.player.set_physics_process(false)
	await frames()
	await capture("/tmp/hotline-prologue-parry.png")
	var defended: Dictionary = {}
	var native_speed := false
	for index in 2400:
		await frames(1)
		if room.get("_pending_step") == HotlinePrologue.Step.GUN_PICKUP or room.step == HotlinePrologue.Step.GUN_PICKUP:
			break
		for child in room.get_children():
			if not child is CombatProjectile or child.faction != CombatFaction.Id.ENEMY or defended.has(child.get_instance_id()):
				continue
			if child.global_position.distance_to(room.player.hurt_box.global_position) < 45 and room.player.guard.state == GuardComponent.State.IDLE:
				native_speed = is_equal_approx(child.speed, 310.0 * 0.85)
				room.player.aim_direction = -child.direction
				room.player.guard.update_direction(-child.direction)
				click_at(Vector2(300, 200), true, MOUSE_BUTTON_RIGHT)
				click_at(Vector2(300, 200), false, MOUSE_BUTTON_RIGHT)
				room.player._consume_buffered_defense_actions()
				defended[child.get_instance_id()] = true
	room.player.set_physics_process(true)
	await drain_dialogue(room)
	check(attacks[0] > 0, "enemy controller itself emits native attack events")
	check(native_speed, "native controller fires tutorial projectiles at speed 263.5")
	check(room.step == HotlinePrologue.Step.GUN_PICKUP, "real reflection kills second enemy and unlocks pistol pickup")
	if room.step != HotlinePrologue.Step.GUN_PICKUP:
		root.get_node("GameSettings").quit_game(1)
		return
	check(is_instance_valid(room.gun_pickup) and room.gun_pickup.component_id == "pistol", "second enemy drops the first pistol")
	await capture("/tmp/hotline-prologue-pistol-drop.png")
	room.player.position = room.gun_pickup.position
	await frames()
	key(KEY_E)
	key(KEY_E, false)
	await frames()
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.EQUIP, "picking up pistol advances to explicit equipment lesson")
	check(room.player.inventory.backpack.get_item_count() == 1 and room.player.weapons.get_current_weapon() == null, "pistol stays in backpack instead of auto-equipping")
	key(KEY_TAB)
	key(KEY_TAB, false)
	await frames(6)
	check(paused and room.player.inventory.is_open, "real Tab opens the normal inventory")
	key(KEY_TAB)
	key(KEY_TAB, false)
	await frames()
	check(not room.player.inventory.is_open and room.step == HotlinePrologue.Step.EQUIP, "closing an empty equipment attempt keeps the gate locked")
	key(KEY_TAB)
	key(KEY_TAB, false)
	await frames()
	check(room.player.inventory.is_open, "Tab reopens the backpack after an unfinished equipment attempt")
	var item_button: Button = room.player.inventory.panel.get("_buttons")[0]
	click_at(item_button.get_global_rect().get_center(), true)
	click_at(item_button.get_global_rect().get_center(), false)
	await frames()
	check(room.player.weapons.get_current_weapon() != null and room.player.weapons.get_current_weapon().id == &"service_pistol", "clicking the real backpack slot equips pistol")
	await capture("/tmp/hotline-prologue-inventory.png")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames()
	check(not room.player.inventory.is_open, "Escape closes the equipped backpack without skipping the tutorial")
	await drain_dialogue(room)
	check(combat_hud.find_child("CurrentWeaponPreview", true, false) == null, "equipped tutorial pistol does not add a bottom-right thumbnail")
	check(room.step == HotlinePrologue.Step.WAVE and room.targets.size() == 3 and room.get("_gates")[1].collision_layer == 0, "equipping the pistol opens the gate and starts the wave without using the buff crate")
	check(room.player.cyberware.circuit.current_energy > 0.0, "the first battle begins with circuit energy")
	check(room.find_children("*", "FuelBarrel", true, false).is_empty() and room.find_children("*", "PowerBox", true, false).is_empty(), "wave has no explosive or charging crate lesson")
	for enemy in room.targets:
		enemy.set_physics_process(false)
	var attack := room.player._get_attack_transform()
	check(room.player.weapons.try_attack(attack.origin, Vector2.LEFT, room.player), "combat fire submits a circuit attack")
	await frames(48)
	check(not paused and room.player.is_input_enabled() and room.step == HotlinePrologue.Step.WAVE and room.get("_pending_step") < 0, "circuit attack never blocks the lesson")
	check(not combat_hud.get("_heat_meter").visible and combat_hud.get("_circuit_energy_fill").is_visible_in_tree(), "production HUD shows energy without a heat meter")
	await capture("/tmp/hotline-prologue-wave.png")
	var enemies: Array = room.targets.duplicate()
	for enemy in enemies:
		for attempt in 4:
			if not is_instance_valid(enemy) or enemy.health.is_dead():
				break
			await shoot_at(room, enemy)
	await frames(15)
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.RECOVER and room.recovery_pickups.size() == 5, "wave deaths drop five unique rewards")
	var ids: Array = []
	for pickup in room.recovery_pickups.duplicate():
		ids.append(pickup.component_id)
		for attempt in 12:
			if not is_instance_valid(pickup) or pickup.get("_picked"):
				break
			room.player.position = pickup.position
			await frames(4)
			key(KEY_E)
			key(KEY_E, false)
			await frames(8)
	ids.sort()
	check(ids == ["armor", "explosive_magazine", "pistol", "smart_fire", "tactical_coprocessor"], "wave rewards include three distinct cyberware modules and synthesis equipment")
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.CODEX and room.get_node_or_null("Codex") != null and room.get_node_or_null("SynthesisTable") != null, "Codex and table appear after all loot is collected")
	check(room.player.inventory.backpack.get_item_count() == 2 and int(room.player.cyberware.circuit.get_library_counts().get(CyberwareController.SMART_FIRE, 0)) > 0, "equipment enters the backpack and cyberware enters the circuit library")
	if room.step != HotlinePrologue.Step.CODEX:
		print("Recovery diagnostic: ", room.player.inventory.backpack.get_item_count(), "; player=", room.player.position)
		for item in room.recovery_pickups:
			if is_instance_valid(item):
				print("Remaining pickup: ", item.component_id, " ", item.position)
		root.get_node("GameSettings").quit_game(1)
		return
	check(not room.get("_circuit_lesson_button").visible, "circuit lesson waits for the Codex conversation")
	var circuit_editor: CyberwareCircuitPanel = combat_hud.get_circuit_editor()
	var editor_hint: Label = circuit_editor.get("_tutorial_hint")
	for module_id in [&"smart_fire", &"explosive_magazine", &"tactical_coprocessor"]:
		check(int(room.player.cyberware.circuit.get_library_counts().get(module_id, 0)) == 1, "each tutorial cyberware enters the circuit library once")
	room.player.position = HotlinePrologue.FORGE_POINT + Vector2(0, 35)
	await frames()
	key(KEY_E)
	key(KEY_E, false)
	await frames()
	check(not room.upgrade_panel.is_open and not room.dialogue_completed, "table is locked before Codex conversation")
	room.player.position = HotlinePrologue.CODEX_POINT + Vector2(0, 35)
	await frames()
	key(KEY_E)
	key(KEY_E, false)
	await frames()
	check(room.panel.is_open and paused, "real E near Codex opens her dialogue")
	await capture("/tmp/hotline-prologue-codex.png")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames()
	check(not room.panel.is_open and not room.dialogue_completed and room.step == HotlinePrologue.Step.CODEX, "interrupted conversation cannot unlock synthesis")
	key(KEY_E)
	key(KEY_E, false)
	await frames()
	for index in room.panel.lines.size():
		key(KEY_E)
		key(KEY_E, false)
		await frames()
	check(room.step == HotlinePrologue.Step.CIRCUIT and circuit_editor.is_open and not room.upgrade_panel.is_open, "Codex first opens actual cyberware arrangement instead of the forge")
	check(editor_hint.is_visible_in_tree() and "槽 2" in editor_hint.text and "智能火控" in editor_hint.text, "Codex points to the module and target slot")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames(100)
	check(not circuit_editor.is_open and room.step == HotlinePrologue.Step.CIRCUIT, "Escape closes the editor without skipping an unfinished arrangement")
	room.get("_circuit_lesson_button").pressed.emit()
	check(circuit_editor.is_open, "Codex lesson can reopen the editor")
	circuit_editor.select_slot(1)
	for child in circuit_editor.get("_library_grid").get_children():
		if "智能火控" in child.text:
			child.pressed.emit()
			break
	await frames()
	check(room.player.cyberware.circuit.get_slots()[1] == "smart_fire", "actual UI installs smart fire after the starter")
	check("接好了" in editor_hint.text, "the editor confirms the correct arrangement")
	circuit_editor.set_open(false)
	await frames(100)
	check(room.step == HotlinePrologue.Step.SYNTHESIZE and room.panel.is_open and not room.upgrade_panel.is_open, "after arranging Codex explains synthesis before opening the forge")
	await capture("/tmp/hotline-prologue-codex-synthesis.png")
	for index in room.panel.lines.size():
		key(KEY_E)
		key(KEY_E, false)
		await frames()
	check(room.dialogue_completed and room.upgrade_panel.is_open, "finishing the second Codex lesson opens the actual forge")
	var subject := room.player.inventory.weapon_slot.get_item()
	var material: InventoryItem
	for item in room.player.inventory.backpack.get_items():
		if item.get_prototype().get_prototype_id() == "pistol":
			material = item
	check(material != null and not room.synthesize(subject, null), "forge requires two actual compatible pistols")
	room.upgrade_panel.select_material(0, subject)
	room.upgrade_panel.select_material(1, material)
	room.upgrade_panel.get("_synthesis_button").pressed.emit()
	check(room.last_synthesis_result != null and ComponentRolls.quality(room.last_synthesis_result) == 2, "real forge upgrades the two pistols")
	check(room.player.inventory.weapon_slot.get_item() == room.last_synthesis_result and room.player.inventory.backpack.get_item_count() == 1, "result stays equipped while armor remains in the bag")
	check(not room.synthesize(subject, material), "consumed pistols cannot be reused")
	await capture("/tmp/hotline-prologue-synthesis.png")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames()
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.MINI_BOSS and is_instance_valid(room.mini_boss), "synthesis unlocks the final mini boss")
	check(room.mini_boss.health.max_health == 12 and room.mini_boss.profile.barrier_enabled, "mini boss has real health, shield and attack behavior")
	var boss := room.mini_boss
	boss.set_physics_process(false)
	check(room.find_children("*", "FuelBarrel", true, false).is_empty() and room.find_children("*", "PowerBox", true, false).is_empty(), "boss arena skips explosive and charging crate lessons")
	key(KEY_C)
	key(KEY_C, false)
	await frames()
	check(circuit_editor.is_open, "C reopens the configured circuit for combat practice")
	circuit_editor.select_slot(1)
	for child in circuit_editor.get("_library_grid").get_children():
		if "智能火控" in child.text:
			child.pressed.emit()
			break
	var circuit_slots := room.player.cyberware.circuit.get_slots()
	check(circuit_slots[0] == "combat_synapse_sensor" and circuit_slots[1] == "smart_fire", "smart fire follows the default fire starter")
	await frames()
	check("接好了" in editor_hint.text, "the editor confirms the exact starter and effect combination")
	circuit_editor.set_open(false)
	await frames()
	check("瞄准守卫" in room.get("_circuit_lesson_hint").text and "点击左键射击" in room.get("_circuit_lesson_hint").text, "the combat prompt explains how to trigger the equipped module")
	room.player.position = boss.position - Vector2(100, 0)
	await capture("/tmp/hotline-prologue-miniboss.png")
	for attempt in 20:
		if not is_instance_valid(boss) or boss.health.is_dead():
			break
		await shoot_at(room, boss)
	check(room.get("_circuit_lesson_complete"), "a real circuit shot completes the smart fire practice")
	check(not editor_hint.visible, "the editor tutorial hint clears after practice")
	check(not is_instance_valid(boss) or boss.health.is_dead(), "upgraded pistol can defeat mini boss")
	if is_instance_valid(boss):
		boss.set_physics_process(true)
	await frames(100)
	var original_profile: Dictionary = JSON.parse_string(original)
	var current_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(current_profile.chest == original_profile.chest and current_profile.loadout == original_profile.loadout, "complete revised tutorial never writes practice gear to formal save")
	check("melee_pressure" in current_profile.get("codex", {}).get("enemies", []), "tutorial permanently records actual enemy encounters")
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.TRANSFER and not room.get("_leaving"), "closing final radio does not immediately transfer to warehouse")
	await frames(35)
	check(not room.get("_leaving") and room.get("_transfer_remaining") > 0.0, "final transfer also leaves a breathing interval")
	var warehouse := await wait_room(WAREHOUSE)
	check(warehouse != null, "finishing lessons automatically teleports to warehouse")
	if warehouse == null:
		root.get_node("GameSettings").quit_game(1)
		return
	check(get_first_node_in_group("prologue_arrival") == null, "warehouse does not reopen the old full-screen arrival confirmation")
	var storage_guide: CanvasLayer = warehouse.get("_storage_guide")
	check(warehouse.get("_storage_guide_active") and storage_guide.get("_panel").is_visible_in_tree() and paused, "warehouse guide uses a real paused bottom dialogue panel")
	check(storage_guide.get("_text").text.contains("保险箱"), "arrival dialogue introduces the safe")
	await capture("/tmp/hotline-warehouse-guide-intro.png")
	key(KEY_ENTER)
	key(KEY_ENTER, false)
	await frames()
	check(not paused and warehouse.player.is_input_enabled() and not storage_guide.get("_panel").visible, "closing arrival radio lets the player walk to storage")
	warehouse.player.position = warehouse.get_node("Chest").position + Vector2(0, 56)
	await frames()
	check(not paused and not storage_guide.get("_panel").visible, "storage explanation does not trigger while still approaching from a distance")
	warehouse.player.position = warehouse.get_node("Chest").position + Vector2(0, 24)
	await frames()
	check(paused and storage_guide.get("_panel").visible and storage_guide.get("_text").text.contains("死了会掉落") and storage_guide.get("_text").text.contains("一直保留"), "approaching storage opens the loss and preservation explanation in the same dialogue panel")
	await capture("/tmp/hotline-prologue-arrival.png")
	click_at(Vector2(320, 300), true)
	click_at(Vector2(320, 300), false)
	await frames()
	check(not paused and not storage_guide.get("_panel").visible, "mouse click closes storage explanation and resumes warehouse play")
	key(KEY_E)
	key(KEY_E, false)
	await frames()
	check(warehouse.panel.is_open and not warehouse.get("_storage_guide_active"), "opening actual storage completes and hides the first-visit guide")
	warehouse.panel.close()
	await frames()
	check(warehouse.player.inventory.backpack.get_item_count() == 0, "practice loot does not enter formal warehouse")
	check(warehouse.player.get_node("RoomBuffComponent").active_buff == &"", "practice buffs expire on transfer")
	var normal_loadout: Dictionary = store.get_profile().loadout
	var flow: SceneContainerManager = current_scene.get_node("SceneFlow")
	check(flow.request_scene(PROLOGUE), "prologue reloads for the already-equipped regression")
	room = await wait_room(PROLOGUE)
	room.player.inventory.pickup("pistol")
	room.player.inventory.equip(0)
	room.get("_dialogue_queue").clear()
	room.set("_dialogue_remaining", 0.0)
	room._end_radio()
	room._set_step(HotlinePrologue.Step.EQUIP)
	await drain_dialogue(room)
	await wait_transition(room)
	await drain_dialogue(room)
	check(room.step == HotlinePrologue.Step.WAVE and room.get("_gates")[1].collision_layer == 0, "an already equipped pistol opens the gate without relying on inventory-open history")
	check(flow.request_scene(PROLOGUE), "prologue reloads for skip verification")
	room = await wait_room(PROLOGUE)
	key(KEY_ESCAPE)
	await frames(3)
	check(room.step == HotlinePrologue.Step.DODGE and paused, "Escape skips only the opening story, not the whole prologue")
	await frames(100)
	check(room.step == HotlinePrologue.Step.DODGE, "holding Escape cannot repeatedly skip stages")
	key(KEY_ESCAPE, false)
	for expected in [HotlinePrologue.Step.PARRY, HotlinePrologue.Step.GUN_PICKUP, HotlinePrologue.Step.EQUIP, HotlinePrologue.Step.WAVE, HotlinePrologue.Step.RECOVER, HotlinePrologue.Step.CODEX, HotlinePrologue.Step.CIRCUIT]:
		key(KEY_ESCAPE)
		key(KEY_ESCAPE, false)
		await frames(3)
		check(room.step == expected, "Escape advances to exactly one next tutorial stage")
	check(room.player.weapons.get_current_weapon() != null and room.player.inventory.backpack.get_item_count() == 2 and int(room.player.cyberware.circuit.get_library_counts().get(CyberwareController.SMART_FIRE, 0)) > 0, "stage skips preserve the equipment needed by subsequent lessons")
	room.get("_hud").get_circuit_editor().set_open(false)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames()
	check(room.step == HotlinePrologue.Step.SYNTHESIZE and room.panel.is_open, "skipping arrangement continues to the Codex synthesis lesson")
	room.panel.close()
	for expected in [HotlinePrologue.Step.MINI_BOSS, HotlinePrologue.Step.TRANSFER]:
		key(KEY_ESCAPE)
		key(KEY_ESCAPE, false)
		await frames(3)
		check(room.step == expected, "later combat stages can also be skipped individually")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	warehouse = await wait_room(WAREHOUSE)
	check(warehouse != null and store.get_profile().loadout == normal_loadout, "stage skips keep all practice gear out of the formal save")
	key(KEY_ENTER)
	key(KEY_ENTER, false)
	await frames()
	check(flow.request_scene(PROLOGUE), "prologue reloads for mouse skip")
	room = await wait_room(PROLOGUE)
	await frames(4)
	var point: Vector2 = room.get("_skip_button").get_global_rect().get_center()
	click_at(point, true)
	await frames(15)
	click_at(point, false)
	await frames()
	check(not room.get("_leaving") and room.get("_skip_elapsed") == 0, "short mouse hold cancels")
	click_at(point, true)
	check(room.get("_skip_mouse"), "visible dialogue skip button receives mouse press")
	warehouse = await wait_room(WAREHOUSE)
	click_at(point, false)
	check(warehouse != null and store.get_profile().loadout == normal_loadout, "mouse hold skips with identical formal loadout")
	key(KEY_ENTER)
	key(KEY_ENTER, false)
	await frames()
	current_scene.queue_free()
	await frames()
	menu = load("res://scenes/ui/start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames()
	menu.continue_game()
	warehouse = await wait_room(WAREHOUSE)
	check(not warehouse.get("_storage_guide_active"), "continuing a save does not repeat the storage guide")
	check(warehouse != null and get_nodes_in_group("prologue").is_empty() and get_nodes_in_group("prologue_arrival").is_empty(), "continue bypasses both prologue and arrival briefing")
	current_scene.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("Prologue checks: ", checks, "; failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
