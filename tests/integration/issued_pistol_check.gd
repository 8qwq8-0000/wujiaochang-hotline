extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func run() -> void:
	for retired in ["baton", "initial_baton"]:
		var raw := {"protoset": "res://resources/items/components.json", "prototype_id": retired, "properties": {"instance_id": {"type": TYPE_STRING, "value": var_to_str("legacy-" + retired)}, "bound": {"type": TYPE_BOOL, "value": "true"}, "effect": {"type": TYPE_STRING, "value": var_to_str("res://resources/weapons/baton.tres")}}}
		var snapshot := {"chest": [raw], "loadout": {"inventory": {"primary": {"item": raw}, "backpack": {"items": [raw]}, "blackbox": {"item": raw}}}}
		var migrated: Dictionary = ComponentRolls.migrate_snapshot(snapshot)
		for entry in [migrated.chest[0], migrated.loadout.inventory.primary.item, migrated.loadout.inventory.backpack.items[0], migrated.loadout.inventory.blackbox.item]:
			var item := InventoryItem.new()
			check(item.deserialize(entry) and item.get_prototype().get_prototype_id() == "pistol", "retired weapon migrates in every storage location")
			check(ComponentRolls.quality(item) == 1 and ComponentRolls.affixes(item).is_empty() and not item.get_property("bound", false), "migration yields ordinary plain standard pistol")
			check(item.get_property("instance_id") == "legacy-" + retired and item.get_property("effect") == "res://resources/weapons/service_pistol.tres", "migration preserves identity and removes old melee effect")
		check(ComponentRolls.migrate_snapshot(migrated) == migrated, "migration is idempotent")
		check(ComponentRolls.create(retired, 3, RandomNumberGenerator.new()).get_prototype().get_prototype_id() == "pistol", "legacy generation request cannot recreate baton")
	var store = root.get_node("WarehouseStore")
	store.save_path="user://issued-pistol-check.json"
	DirAccess.remove_absolute(store.save_path)
	check(store.create_new_profile(),"create isolated fresh profile")
	var room=load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene=room
	room.player.set_physics_process(false)
	room.set("_mutating",true)
	var inv:ComponentInventory=room.player.inventory
	var issued=inv.weapon_slot.get_item()
	check(issued.get_prototype().get_prototype_id()=="pistol","new save starts with service pistol")
	check(ComponentRolls.quality(issued)==1 and ComponentRolls.affixes(issued).is_empty(),"issued pistol is standard without affixes")
	check(not issued.get_property("bound",false) and ComponentRolls.synthesizable(issued),"issued pistol is unbound and synthesizable")
	var legacy=ComponentRolls.create("scattergun",2,RandomNumberGenerator.new())
	inv.weapon_slot.equip(legacy)
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item()==legacy,"existing old-save weapon is not replaced")
	inv.weapon_slot.clear()
	inv.secondary_weapon_slot.clear()
	for item in inv.backpack.get_items(): inv.backpack.remove_item(item)
	for item in room.chest.get_items(): room.chest.remove_item(item)
	room._ensure_fallback_weapon()
	var replacement=inv.weapon_slot.get_item()
	check(replacement.get_prototype().get_prototype_id()=="pistol" and ComponentRolls.affixes(replacement).is_empty(),"no weapons grants the same plain pistol")
	room._ensure_fallback_weapon()
	check(inv.weapon_slot.get_item()==replacement,"repeated fallback does not duplicate pistol")
	var rng:=RandomNumberGenerator.new()
	rng.seed=42
	var old_drop_found:=false
	for i in 100:
		var item:=ComponentRolls.floor_drop(1,rng)
		old_drop_found=old_drop_found or item.get_prototype().get_prototype_id()=="baton"
	check(not old_drop_found,"new loot does not generate removed baton")
	room.queue_free()
	await process_frame
	await process_frame
	var trial=load("res://scenes/debug/fuel_reaction_sandbox.tscn").instantiate()
	root.add_child(trial)
	current_scene=trial
	var has_baton:=false
	for item in trial.chest.get_items():
		has_baton=has_baton or item.get_prototype().get_prototype_id() in ["baton","initial_baton"]
	check(not has_baton and trial.player.inventory.weapon_slot.get_item().get_prototype().get_prototype_id()=="pistol","trial supplies and loadout have no new baton")
	trial.queue_free()
	await process_frame
	DirAccess.remove_absolute(store.save_path)
	print("Issued pistol checks: ",checks,"; failures: ",failures)
	quit(0 if failures==0 else 1)
