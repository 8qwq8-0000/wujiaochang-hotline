extends SceneTree
var failures := 0
var checks := 0
const SAVE_PATH := "user://ordinary-baton-check.json"
const LEGACY_PATH := "user://ordinary-baton-legacy-check.json"

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

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(LEGACY_PATH)
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await settle()
	var player: PlayerController = room.player
	player.set_physics_process(false)
	var inv := player.inventory
	var baton := inv.weapon_slot.get_item()
	check(baton.get_prototype().get_prototype_id() == "pistol" and baton.get_title() == "制式手枪", "new save starts with an ordinary service pistol")
	check(not ComponentInventory.PROTOTYPES.data.has("initial_baton") and not baton.get_property("bound", false), "catalog has no separate initial or bound baton")
	check(ComponentRolls.quality(baton) == 1 and ComponentRolls.affixes(baton).is_empty(), "issued pistol starts at quality one without affixes")
	check(player.weapons.get_current_weapon().id == &"service_pistol" and player.weapons.get_current_weapon().display_name == "制式手枪", "starting weapon uses service pistol runtime data and HUD name")
	var id: String = baton.get_property("instance_id")
	check(room.transfer(baton, true), "starting pistol stores like any ordinary item")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item() == baton and room.chest.get_item_count() == 0, "unarmed profile equips same stored pistol without duplicating it")
	check(inv.unequip("weapon"), "ordinary starting pistol may be carried in backpack")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item().get_property("instance_id") == id and inv.backpack.get_item_count() == 0, "unarmed profile prioritizes existing backpack weapon")
	check(player.export_recovery_state().inventory.primary.is_empty(), "ordinary pistol has no hidden permanent death protection")
	var rng := RandomNumberGenerator.new()
	var material := ComponentRolls.create("pistol", 1, rng)
	check(inv.pickup("pistol", material), "ordinary pistol can be acquired as material")
	# First acquired weapon may auto-fill the reserve. Either source is valid.
	check(room.synthesize(baton, material), "issued and looted pistols synthesize under the same rules")
	var upgraded := inv.weapon_slot.get_item()
	check(upgraded.get_prototype().get_prototype_id() == "pistol" and upgraded.get_title() == "制式手枪" and ComponentRolls.quality(upgraded) == 2, "upgrade remains the service pistol with quality distinction")
	var upgrade_id: String = upgraded.get_property("instance_id")
	room.transfer(upgraded, true)
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item().get_property("instance_id") == upgrade_id and room.chest.get_item_count() == 0, "existing improved weapon is equipped rather than replaced by new basic baton")
	inv.weapon_slot.clear()
	inv.secondary_weapon_slot.clear()
	inv.backpack.clear()
	room.chest.clear()
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item().get_prototype().get_prototype_id() == "pistol" and ComponentRolls.affixes(inv.weapon_slot.get_item()).is_empty(), "profile losing all weapons receives one no-affix service pistol")
	var fallback_id: String = inv.weapon_slot.get_item().get_property("instance_id")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item().get_property("instance_id") == fallback_id, "repeated recovery never grants extra weapons")
	var old_item := ComponentRolls.create("baton", 3, rng)
	old_item.set_property("affixes", {"guard": 55})
	var old_serialized := old_item.serialize()
	old_serialized.prototype_id = "initial_baton"
	old_serialized.properties.bound = {"type": TYPE_BOOL, "value": "true"}
	var legacy_profile: Dictionary = store.get_profile()
	legacy_profile.chest = [old_serialized]
	legacy_profile.loadout = player.export_run_state()
	legacy_profile.loadout.inventory.primary = {}
	legacy_profile.loadout.inventory.secondary = {}
	legacy_profile.loadout.inventory.backpack.erase("items")
	var file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_profile))
	file.close()
	var reader: Node = load("res://scripts/core/warehouse_store.gd").new()
	reader.save_path = LEGACY_PATH
	root.add_child(reader)
	check(reader.load_profile(), "legacy initial-baton save loads despite removed catalog prototype")
	var migrated: Dictionary = reader.get_profile()
	var migrated_item := InventoryItem.new()
	check(migrated_item.deserialize(migrated.chest[0]), "migrated item deserializes as normal GLoot item")
	check(migrated_item.get_prototype().get_prototype_id() == "baton" and migrated_item.get_title() == "警棍" and not migrated_item.get_property("bound", false), "legacy initial baton becomes ordinary unified baton")
	check(migrated_item.get_property("instance_id") == old_item.get_property("instance_id") and ComponentRolls.quality(migrated_item) == 3 and ComponentRolls.affixes(migrated_item) == {"guard": 55}, "migration preserves original instance quality and affixes")
	check(ComponentRolls.migrate_snapshot(migrated) == migrated, "migration is idempotent and does not reroll items")
	check(reader.commit(migrated.chest, migrated.loadout), "legacy migration can save atomically under v1 format")
	var prior_state := player.export_run_state()
	prior_state.inventory.primary = {"item": old_serialized}
	player.import_run_state(prior_state)
	check(inv.weapon_slot.get_item().get_prototype().get_prototype_id() == "baton" and ComponentRolls.quality(inv.weapon_slot.get_item()) == 3, "older in-memory run snapshot migrates before GLoot loading")
	var protected_baton := inv.weapon_slot.get_item()
	check(inv.move_to_storage(inv.blackbox_slot.get_item(), room.chest) and inv.unequip("weapon") and inv.put_in_blackbox(inv.backpack.get_item_index(protected_baton)), "ordinary baton can be protected in blackbox without a bound exception")
	check(player.export_recovery_state().inventory.blackbox.item.properties.instance_id.value == var_to_str(protected_baton.get_property("instance_id")), "blackbox preserves the actual ordinary baton rather than a special starter")
	reader.queue_free()
	room.queue_free()
	await settle()
	# Actual departure failure must roll back the automatic chest-to-hand selection.
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		if main.get_node("SceneContainer").get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	room = main.get_node("SceneContainer").get_child(0)
	player = room.player
	player.set_physics_process(false)
	inv = player.inventory
	var carried_id: String = inv.weapon_slot.get_item().get_property("instance_id")
	check(room.transfer(inv.weapon_slot.get_item(), true), "save ordinary weapon into chest before unarmed departure")
	var loadout_before := player.export_run_state()
	var chest_before: Dictionary = room.chest.serialize()
	store.save_path = "user://missing-ordinary-baton-directory/save.json"
	check(not room.depart() and player.export_run_state() == loadout_before and room.chest.serialize() == chest_before, "failed departure restores ownership before automatic weapon equip")
	store.save_path = SAVE_PATH
	check(room.depart(), "unarmed departure can equip an existing stored weapon")
	for frame in 600:
		await process_frame
		if get_nodes_in_group("enemies").size() == 3 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	player = get_first_node_in_group("player") as PlayerController
	check(player.inventory.weapon_slot.get_item().get_property("instance_id") == carried_id, "formal action carries same stored weapon without minting duplicate")
	main.queue_free()
	await settle()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(LEGACY_PATH)
	print("Ordinary baton checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
