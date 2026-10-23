extends SceneTree
var failures := 0
var checks := 0
const SAVE_PATH := "user://defense-component-check.json"

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

func hit(player: PlayerController, amount: int = 1) -> DamageResult:
	player.hurt_box.clear_invulnerability()
	var packet := DamagePacket.new()
	packet.base_damage = amount
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = player.global_position + Vector2.RIGHT * 20
	return player.hurt_box.receive_hit(packet)

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
	player.health.configure_max_health(100)
	var inv := player.inventory
	var defense: DefenseComponent = player.get_node("DefenseComponent")
	defense.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 551
	var armor := ComponentRolls.create("armor", 1, rng)
	check(inv.defense_slot.get_item() == null, "defense starts empty and does not grant free armor")
	check(inv.pickup("armor", armor) and inv.backpack.get_item_count() == 1, "armor pickup uses ordinary backpack")
	inv.set_open(true)
	var payload := {"inventory": inv, "item": armor}
	check(inv.panel.get("_defense")._can_drop_data(Vector2.ZERO, payload), "native defense slot accepts armor")
	inv.panel.get("_defense")._drop_data(Vector2.ZERO, payload)
	check(inv.defense_slot.get_item() == armor and inv.backpack.get_item_count() == 0, "equipped armor lives outside six bag cells")
	check(not inv.can_drop_item(inv.weapon_slot.get_item(), "defense"), "weapon cannot enter defense slot")
	inv.set_open(false)
	var friendly := DamagePacket.new()
	friendly.source_faction = CombatFaction.Id.PLAYER
	player.hurt_box.receive_hit(friendly)
	check(defense.remaining_seconds() == 0.0, "friendly fire never consumes armor charge")
	var health := player.health.current_health
	var absorbed := hit(player)
	check(absorbed.final_damage == 0 and absorbed.absorbed_damage == 1 and player.health.current_health == health, "ready armor absorbs actual one-point enemy hit")
	check(is_equal_approx(defense.remaining_seconds(), 12.0) and player.hurt_box.is_invulnerable(), "armor enters quality cooldown and grants normal hit invulnerability")
	var damaged := hit(player)
	check(damaged.final_damage == 1 and player.health.current_health == health - 1, "depleted armor allows next hit to damage health")
	check(inv.unequip("defense") and inv.equip(0), "armor can be removed and re-equipped safely")
	check(is_equal_approx(defense.remaining_seconds(), 12.0), "re-equipping does not refill armor")
	var snapshot := player.export_run_state()
	for index in 3:
		player.import_run_state(snapshot)
	check(is_equal_approx(defense.remaining_seconds(), 12.0), "repeated import preserves depleted armor cooldown")
	armor = inv.defense_slot.get_item()
	check(room.transfer(armor, true) and room.transfer(armor, false) and inv.equip(0), "armor round-trips through storage and equipment")
	check(is_equal_approx(defense.remaining_seconds(), 12.0), "storage never resets armor cooldown")
	defense.set_physics_process(true)
	await settle()
	check(defense.remaining_seconds() < 12.0 and defense.remaining_seconds() > 11.0, "real physics frames recover equipped armor")
	defense.set_physics_process(false)
	armor.set_property("armor_cooldown_remaining", 0.0)
	player.guard.begin_guard(Vector2.RIGHT)
	player.guard.advance_timing(player.guard.startup_seconds + 0.001)
	var guarded := hit(player)
	check(guarded.perfect and defense.remaining_seconds() == 0, "successful guard resolves before armor and never consumes it")
	player.guard.reset_to_idle()
	player.health.set_current_health(100)
	var heavy_hit := hit(player, 3)
	check(heavy_hit.absorbed_damage == 1 and heavy_hit.final_damage == 2, "armor absorbs one point rather than an entire heavy hit")
	armor.set_property("armor_cooldown_remaining", 0.0)
	player.hurt_box.clear_invulnerability()
	var electric := DamagePacket.new()
	electric.base_damage = 1
	electric.source_faction = CombatFaction.Id.ENEMY
	electric.damage_type = &"electric"
	electric.status_tags = ["conductive"]
	var first_electric := player.hurt_box.receive_hit(electric)
	player.hurt_box.clear_invulnerability()
	var duplicate_electric := player.hurt_box.receive_hit(electric)
	check(first_electric.absorbed_damage == 1 and duplicate_electric.final_damage == 0 and not player.statuses.has_status(&"conductive"), "absorbed electric hit cannot rehit within event or apply conductivity")
	armor.set_property("armor_cooldown_remaining", 0.0)
	player.health.set_current_health(1)
	hit(player)
	check(not player.circuit_breaker.circuit_breaker_used and player.health.current_health == 1, "armor absorbs lethal one-point hit before insurance is spent")
	hit(player)
	check(player.circuit_breaker.circuit_breaker_used and player.health.current_health == 1, "depleted armor still allows insurance to intercept next lethal hit")
	inv.get_insurance_item().set_property("circuit_breaker_used", false)
	inv.sync_insurance()
	player.health.set_current_health(100)
	check(room.save_loadout(), "save equipped armor including cooldown")
	var reloaded: Node = load("res://scripts/core/warehouse_store.gd").new()
	reloaded.save_path = SAVE_PATH
	root.add_child(reloaded)
	check(reloaded.load_profile() and reloaded.get_profile().loadout.inventory.defense.has("item"), "fresh disk service loads defense slot")
	var disk_item := InventoryItem.new()
	disk_item.deserialize(reloaded.get_profile().loadout.inventory.defense.item)
	check(disk_item.get_property("instance_id") == armor.get_property("instance_id") and float(disk_item.get_property("armor_cooldown_remaining")) == 12.0, "disk round-trip retains armor instance and cooldown")
	reloaded.queue_free()
	var bad_profile: Dictionary = store.get_profile()
	bad_profile.chest.append(armor.serialize())
	check(not store.commit(bad_profile.chest, bad_profile.loadout), "save validator rejects duplicated defense instance across slot and chest")
	check(player.export_recovery_state().inventory.defense.is_empty(), "unprotected defense equipment is lost on death")
	check(inv.unequip("defense") and inv.put_in_blackbox(0), "armor may use existing blackbox protection")
	check(player.export_recovery_state().inventory.blackbox.item.prototype_id == "armor", "protected armor survives in recovery snapshot")
	check(inv.take_from_blackbox() and inv.equip(inv.backpack.get_item_count() - 1), "protected armor can return to defense slot")
	armor = inv.defense_slot.get_item()
	var material := ComponentRolls.create("armor", 1, rng)
	check(inv.pickup("armor", material), "second armor becomes upgrade material")
	var before := player.export_run_state()
	store.save_path = "user://missing-defense-directory/save.json"
	check(not room.synthesize(armor, material) and inv.defense_slot.get_item() == armor and player.export_run_state() == before, "failed armor upgrade keeps equipped item and bag material")
	store.save_path = SAVE_PATH
	check(room.synthesize(armor, material), "equipped armor upgrades with bag material")
	armor = inv.defense_slot.get_item()
	check(ComponentRolls.quality(armor) == 2 and defense.cooldown_seconds(armor) == 10.0, "improved armor has actual shorter recovery")
	check(not ComponentRolls.affixes(armor).has("attack") and ComponentRolls.affixes(armor).size() >= 1, "armor rolls only effective general affixes")
	check(not ComponentRolls.compatible(armor, ComponentRolls.create("wheel", 2, rng)), "armor cannot synthesize with mobility despite matching quality")
	var old := player.export_run_state()
	old.inventory.erase("defense")
	player.import_run_state(old)
	check(inv.defense_slot.get_item() == null, "old save without defense migrates to empty slot without granting armor")
	player.import_run_state(before)
	armor = inv.defense_slot.get_item()
	check(inv.unequip("defense"), "armor can be carried for full-bag fixture")
	while inv.backpack.get_item_count() < 6:
		inv.pickup("pistol")
	check(inv.equip(inv.backpack.get_item_index(armor)) and inv.backpack.get_item_count() == 5, "equipping armor frees one full-bag cell")
	inv.pickup("pistol")
	check(not inv.unequip("defense") and inv.defense_slot.get_item() == armor, "full bag cannot swallow equipped armor on unequip")
	var pool_has_armor := false
	for index in 100:
		pool_has_armor = pool_has_armor or ComponentRolls.floor_drop(1, rng).get_prototype().get_prototype_id() == "armor"
	check(pool_has_armor, "formal enemy loot pool includes defense component")
	room.upgrade_panel.open()
	room.upgrade_panel.select_material(0, armor)
	check(room.upgrade_panel.get("_preview").text.contains("缓冲装甲"), "workshop previews defense upgrades")
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		root.get_texture().get_image().save_png("/tmp/hotline-defense-workshop.png")
	room.upgrade_panel.close()
	inv.set_open(true)
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		root.get_texture().get_image().save_png("/tmp/hotline-defense-inventory.png")
	inv.set_open(false)
	room.queue_free()
	await settle()
	DirAccess.remove_absolute(SAVE_PATH)
	print("Defense component checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
