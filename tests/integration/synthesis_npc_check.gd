extends SceneTree
var failures := 0
var checks := 0
const SAVE_PATH := "user://synthesis-npc-test.json"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await settle()
	var player: PlayerController = room.player
	player.set_physics_process(false)
	var inv := player.inventory
	var npc: Area2D = room.get_node("SynthesisNPC")
	check(not npc.can_interact(player), "upgrade NPC cannot interact across warehouse")
	player.global_position = npc.global_position + Vector2(0, 35)
	await settle()
	check(player.interactor.get_best_target(player) == npc, "real physics overlaps select upgrade NPC")
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		root.get_texture().get_image().save_png("/tmp/hotline-npc-room.png")
	await key(KEY_E)
	check(room.panel.is_open and paused and not player.is_input_enabled(), "E opens NPC upgrade service and pauses world")
	check(room.panel.get("_title").text == "合成师 · 武器升级", "NPC opens dedicated upgrade heading and instructions")
	var starter := inv.weapon_slot.get_item()
	var original_id: String = starter.get_property("instance_id")
	check(room.transfer(starter, true), "starter deposits directly from equipped slot")
	check(player.export_recovery_state().inventory.primary.is_empty(), "stored starter is not recreated in death recovery")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item() == null and room.chest.get_item_count() == 1, "stored starter suppresses fallback generation")
	check(room.transfer(starter, false), "starter withdraws into backpack")
	check(inv.backpack.has_item(starter) and starter.get_property("instance_id") == original_id, "starter bag transfer preserves identity")
	check(room.transfer(starter, true), "starter redeposits for upgrade")
	var material := ComponentRolls.create("pistol", 1, RandomNumberGenerator.new())
	material.set_property("affixes", {"attack": 40})
	room.chest.add_item(material)
	check(room.save_loadout(), "save upgrade material")
	check(ComponentRolls.compatible(starter, material), "starter combines with standard weapon")
	var reversed := ComponentRolls.fuse(material, starter, RandomNumberGenerator.new())
	check(reversed.get_prototype().get_prototype_id() == "pistol" and ComponentRolls.quality(reversed) == 2, "starter as material preserves selected pistol subject")
	room.panel.refresh()
	room.panel.select_material(0, starter)
	room.panel.select_material(1, material)
	check(not room.panel.get("_synthesis_button").disabled, "starter enables actual upgrade button")
	store.save_path = "user://missing-npc-directory/save.json"
	check(not room.synthesize(starter, material) and room.chest.has_item(starter) and room.chest.has_item(material), "failed save retains starter and upgrade material")
	store.save_path = SAVE_PATH
	room.panel.show_message("初始警棍 + 制式武器 → 改良警棍 · 保留主体形态")
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		root.get_texture().get_image().save_png("/tmp/hotline-npc-upgrade.png")
	room.panel.get("_synthesis_button").pressed.emit()
	check(room.chest.get_item_count() == 1 and not room.chest.has_item(starter), "upgrade button consumes both originals")
	var upgraded: InventoryItem = room.chest.get_items()[0]
	check(upgraded.get_prototype().get_prototype_id() == "baton" and ComponentRolls.quality(upgraded) == 2 and ComponentRolls.affixes(upgraded) == {"attack": 40.0}, "starter subject becomes improved baton with inherited affix")
	check(not upgraded.get_property("bound", false), "upgraded baton is ordinary loot")
	check(player.export_recovery_state().inventory.primary.is_empty(), "consumed starter never respawns on death")
	check(room.transfer(upgraded, false) and inv.equip(0), "upgraded weapon can be withdrawn and equipped")
	check(player.weapons.get_current_weapon().id == &"baton", "upgraded baton works in weapon controller")
	check(player.export_recovery_state().inventory.primary.is_empty(), "upgraded weapon does not gain starter death protection")
	await key(KEY_ESCAPE)
	check(not paused and player.is_input_enabled(), "closing NPC restores control")
	var state := player.export_run_state()
	player.import_run_state(state)
	check(inv.export_run_state() == state.inventory and player.export_recovery_state().inventory.primary.is_empty(), "reload preserves upgrade without respawning consumed starter")
	check(room.transfer(inv.weapon_slot.get_item(), true), "upgraded weapon can remain in warehouse")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item() == null, "stored upgrade suppresses fallback generation")
	room.chest.clear()
	room._ensure_fallback_weapon()
	check(ComponentRolls.starter(inv.weapon_slot.get_item()), "losing all available weapons restores playable fallback")
	var fallback_id: String = inv.weapon_slot.get_item().get_property("instance_id")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item().get_property("instance_id") == fallback_id, "fallback generation is idempotent")
	room.queue_free()
	await settle()
	DirAccess.remove_absolute(SAVE_PATH)
	print("Synthesis NPC checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
