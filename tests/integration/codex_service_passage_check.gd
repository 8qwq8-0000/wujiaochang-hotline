extends SceneTree

const SAVE_PATH := "user://codex-passage-check.json"
const PASSAGE_PATH := "res://scenes/levels/intermissions/codex_service_passage.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_scene(flow: SceneContainerManager) -> Node:
	for frame in 600:
		await process_frame
		var container := flow.get_node(flow.scene_container_path)
		if container.get_child_count() > 0 and not flow.get("_is_loading"):
			return container.get_child(0)
	return null

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/codex-passage-" + name + ".png")

func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	store.create_new_profile()
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow := main.get_node("SceneFlow") as SceneContainerManager
	flow.fade_duration = 0.0
	var floor := await wait_scene(flow)
	var run := root.get_node("RunManager")
	run.begin_run(53531)
	run.persistent_run = true
	run.floor_index = 1
	run.persona_authorization_floor = 1
	run.persona_authorization_pending = false
	run.persona_rest_refilled_floor = 1
	run.set_mandatory_enemy_count(0)
	var player := floor.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.health.set_current_health(2)
	player.cyberware.circuit.set_energy(27.0)
	player.consume_persona_drink(TalentCoreController.DEEP_NINJA)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	var inv := player.inventory
	inv.weapon_slot.clear()
	inv.weapon_slot.equip(ComponentRolls.create("pistol", 1, rng))
	inv.backpack.add_item(ComponentRolls.create("pistol", 1, rng))
	while inv.backpack.get_item_count() < 6:
		inv.backpack.add_item(ComponentRolls.create("armor", 1, rng))
	for item in inv.backpack.get_items():
		ComponentRolls.ensure(item)
	inv._apply_equipment()
	player.cyberware.store_circuit_modules(PackedStringArray(["combat_synapse_sensor_dash"]))
	var before := player.export_run_state()
	var energy_before: float = player.cyberware.circuit.current_energy
	var ui := main.get_node("ExtractionFlow")
	ui.continue_floor()
	ui.continue_floor()
	var passage := await wait_scene(flow)
	check(passage.scene_file_path == PASSAGE_PATH and run.floor_index == 1, "floor two continue enters service passage once without advancing floor")
	if passage.scene_file_path != PASSAGE_PATH:
		quit(1)
		return
	player = passage.player
	player.set_physics_process(false)
	var passage_after: Dictionary = player.export_run_state()
	(passage_after.cyberware_circuit as Dictionary).erase("current_energy")
	(before.cyberware_circuit as Dictionary).erase("current_energy")
	check(passage_after == before, "passage keeps health, inventory identities and persona state")
	check(player.cyberware.circuit.current_energy >= energy_before and player.cyberware.circuit.current_energy < energy_before + 20.0, "passage preserves current circuit energy while regeneration continues")
	check(not paused and not main.get_node("PersonaRestFlow").is_open, "passage does not open persona rest or refill another floor")
	check(run.persona_rest_refilled_floor == 1 and not run.persona_authorization_pending, "passage grants no extra persona authorization")
	await capture("room")
	check(not passage.depart(), "third-floor exit requires Codex conversation first")
	inv = player.inventory
	var material: InventoryItem
	for candidate: InventoryItem in inv.backpack.get_items():
		if candidate.get_prototype().get_prototype_id() == "pistol":
			material = candidate
			break
	check(not passage.synthesize(inv.weapon_slot.get_item(), material), "workshop is locked before conversation")
	var disk_before := FileAccess.get_file_as_string(SAVE_PATH)
	player.position = passage.get_node("SynthesisNPC").position + Vector2(0, 47)
	for frame in 3:
		await physics_frame
	await key(KEY_E)
	check(passage.panel.is_open and paused and not player.is_input_enabled(), "real E near existing Codex opens dialogue and stops player input")
	await capture("dialogue")
	await key(KEY_ESCAPE)
	check(not passage.panel.is_open and not paused and not passage.dialogue_completed, "interrupted dialogue restores movement without unlocking workshop")
	await key(KEY_E)
	for page in 4:
		await key(KEY_E)
	check(passage.dialogue_completed and passage.upgrade_panel.is_open and paused, "finishing conversation opens the reusable synthesis workshop")
	await capture("workshop")
	var subject := inv.weapon_slot.get_item()
	passage.upgrade_panel.select_material(0, subject)
	passage.upgrade_panel.select_material(1, material)
	passage.upgrade_panel.get("_synthesis_button").pressed.emit()
	check(passage.upgrade_panel.get("_target") == 0, "successful synthesis resets selection to subject")
	check(passage.upgrade_panel.get("_materials") == [null, null], "successful synthesis clears both consumed inputs")
	check(root.gui_get_focus_owner() == passage.upgrade_panel.get("_material_buttons")[0], "successful synthesis returns keyboard focus to subject")
	check(ComponentRolls.quality(inv.weapon_slot.get_item()) == 2 and inv.backpack.get_item_count() == 5, "workshop upgrades equipped gun while consuming its material from a full bag")
	check(not passage.owns_synthesis_item(subject) and not passage.owns_synthesis_item(material), "consumed input instances cannot be reused")
	check(not passage.synthesize(subject, material), "duplicate synthesis request cannot duplicate equipment")
	check((passage.upgrade_panel.get("_event_subject") as OptionButton).item_count > 0 and (passage.upgrade_panel.get("_event_material") as OptionButton).item_count > 0, "forge lists owned event starters")
	check(passage.synthesize_event_starters(&"combat_synapse_sensor", &"combat_synapse_sensor_dash"), "forge merges installed fire and stored dash starters")
	check(player.cyberware.circuit.get_slots()[0] == String(CyberwareController.event_starter_id(3)), "merged event starter replaces the installed slot")
	var before_duplicate := player.export_run_state()
	check(not passage.synthesize_event_starters(CyberwareController.event_starter_id(3), &"combat_synapse_sensor"), "overlapping event effects cannot be merged twice")
	check(player.export_run_state() == before_duplicate, "rejected event merge consumes nothing")
	check(FileAccess.get_file_as_string(SAVE_PATH) == disk_before, "in-run synthesis never writes carried gear or cyberware to permanent warehouse storage")
	await key(KEY_ESCAPE)
	check(not paused and player.is_input_enabled(), "closing workshop resumes passage movement")
	passage.talk_to_codex()
	check(passage.upgrade_panel.is_open and not passage.panel.is_open, "Codex reopens workshop after completed conversation")
	passage.upgrade_panel.close()
	var after := player.export_run_state()
	player.position = Vector2(535, 244)
	for frame in 3:
		await physics_frame
	await capture("exit")
	await key(KEY_E)
	var third := await wait_scene(flow)
	check(third.scene_file_path == "res://scenes/levels/floors/combat_prototype.tscn" and run.floor_index == 2, "real exit interaction advances to floor three exactly once")
	var third_player := third.get_node("Player") as PlayerController
	check(third_player.inventory.export_run_state() == after.inventory and third_player.health.current_health == 2, "floor three keeps upgraded weapon, compound cyberware and health")
	check(third_player.talent_core.get_persona_level(TalentCoreController.DEEP_NINJA) == 1, "existing persona level survives service stop")
	check(main.get_node("PersonaRestFlow").is_open and run.persona_rest_refilled_floor == 2, "third floor still opens its own normal persona rest")
	main.get_node("PersonaRestFlow").close(true)
	main.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(SAVE_PATH)
	print("Codex passage checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
