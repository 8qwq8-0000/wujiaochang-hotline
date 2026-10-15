extends SceneTree

var failures := 0
var checks := 0
var store: Node
const SAVE_PATH := "user://blackbox-integration-test.json"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_scene(main: Node) -> Node:
	for frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
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

func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	var room := await wait_scene(main)
	var player: PlayerController = room.player
	player.set_physics_process(false)
	var inv: ComponentInventory = player.inventory
	check(inv.backpack.get_item_count() == 0, "default insurance takes no ordinary backpack cell")
	var insurance := inv.blackbox_slot.get_item()
	var insurance_id: String = insurance.get_property("instance_id")
	check(insurance.get_property("slot") == "insurance" and player.circuit_breaker.equipped, "default blackbox contains actual insurance item")
	check(not inv.pickup("circuit_breaker"), "duplicate insurance is refused")
	check(room.transfer(insurance, true), "insurance can be stored safely in warehouse chest")
	check(not inv.pickup("circuit_breaker"), "insurance in warehouse also prevents duplicate grants")
	check(room.transfer(insurance, false) and inv.put_in_blackbox(0), "same stored insurance can return to blackbox")
	await key(KEY_TAB)
	check(inv.is_open and paused, "real Tab opens paused backpack")
	var panel: CanvasLayer = inv.panel
	await process_frame
	var box_button: Button = panel.get("_blackbox")
	check(box_button.is_visible_in_tree() and box_button.text.contains("保险就绪"), "blackbox slot is visible with insurance status")
	box_button.pressed.emit()
	check(inv.blackbox_slot.get_item() == null and inv.backpack.has_item(insurance), "blackbox button takes insurance into bag")
	check(not player.circuit_breaker.equipped, "taking insurance immediately disables it")
	check(inv.pickup("wheel"), "ordinary item fixture")
	check(inv.drop_item(inv.backpack.get_items()[1], "blackbox"), "backpack item drops onto blackbox")
	check(inv.blackbox_slot.get_item().get_property("slot") == "mobility", "target selection places ordinary item in blackbox")
	check(not player.circuit_breaker.equipped, "ordinary protection provides no fatal-hit insurance")
	check(inv.put_in_blackbox(0), "insurance can swap with protected item")
	check(inv.blackbox_slot.get_item() == insurance and inv.backpack.get_item_count() == 1, "exchange keeps original insurance instance")
	inv.set_open(false)
	player.health.apply_damage(100, DamagePacket.new())
	check(player.health.current_health == 1 and player.circuit_breaker.circuit_breaker_used, "blackbox insurance prevents first fatal hit")
	check(insurance.get_property("circuit_breaker_used"), "used state belongs to insurance item")
	check(inv.put_in_blackbox(0), "ordinary item can replace spent insurance")
	check(inv.put_in_blackbox(0), "spent insurance can return to blackbox")
	check(player.circuit_breaker.circuit_breaker_used and not player.circuit_breaker.try_prevent_fatal_damage(), "taking out and replacing insurance does not refresh it")
	var snapshot := player.export_run_state()
	player.import_run_state(snapshot)
	check(player.circuit_breaker.circuit_breaker_used and inv.blackbox_slot.get_item().get_property("instance_id") == insurance_id, "state round trip preserves insurance identity and spent flag")
	# Existing saves gain one physical core, carrying their former used flag.
	var legacy := snapshot.duplicate(true)
	legacy.inventory.erase("blackbox")
	player.import_run_state(legacy)
	check(player.circuit_breaker.circuit_breaker_used, "legacy migration preserves spent insurance")
	legacy.circuit_breaker.equipped = false
	player.import_run_state(legacy)
	check(inv.get_insurance_item() == null and not player.circuit_breaker.equipped, "legacy disabled insurance does not gain a new core")
	player.import_run_state(snapshot)
	player.health.set_current_health(3)
	var changed_during_damage: Array[bool] = []
	var callback := func(_amount: int, _packet: DamagePacket) -> void:
		changed_during_damage.append(inv.put_in_blackbox(0))
	player.health.damaged.connect(callback)
	player.health.apply_damage(1, DamagePacket.new())
	player.health.damaged.disconnect(callback)
	check(changed_during_damage == [false], "blackbox cannot change during an in-progress damage event")
	for index in 5:
		inv.pickup("wheel")
	check(inv.backpack.get_item_count() == 6, "full backpack fixture")
	check(not inv.take_from_blackbox() and inv.blackbox_slot.get_item() != null, "full bag refuses direct removal")
	check(inv.put_in_blackbox(0) and inv.backpack.get_item_count() == 6, "full bag still permits atomic exchange")
	var before := player.export_run_state()
	store.save_path = "user://blackbox-missing-directory/test.json"
	check(not inv.put_in_blackbox(0), "save failure refuses protection change")
	check(player.export_run_state() == before, "failed protection save rolls back both slot and bag")
	store.save_path = SAVE_PATH
	check(room.save_loadout(), "save path restored")
	# Carrying a core equips it by default for the next action.
	check(room.depart(), "departure accepted")
	var battle := await wait_scene(main)
	player = battle.get_node("Player")
	inv = player.inventory
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	check(player.circuit_breaker.equipped and not player.circuit_breaker.circuit_breaker_used, "new action equips held insurance and resets its per-run usage")
	check(not inv.put_in_blackbox(0), "combat blackbox edits require paused backpack")
	await key(KEY_TAB)
	check(inv.put_in_blackbox(0), "paused combat permits blackbox exchange")
	var protected_id: String = inv.blackbox_slot.get_item().get_property("instance_id")
	check(not player.circuit_breaker.equipped, "ordinary protected item disables combat insurance")
	check(store.get_profile().loadout.inventory.blackbox.item.properties.instance_id.value == var_to_str(protected_id), "protection checkpoint updates before death")
	check(store.get_profile().loadout.inventory.backpack.get("items", []).is_empty(), "unprotected gear has no safe duplicate")
	await key(KEY_TAB)
	store.save_path = "user://blackbox-missing-directory/test.json"
	player.health.apply_damage(100, DamagePacket.new())
	await process_frame
	await process_frame
	var settlement: Node = main.get_node("ExtractionFlow")
	check(not root.get_node("RunManager").run_finished and paused and settlement.get("_death_pending"), "failed death save remains pending and offers retry")
	await key(KEY_ESCAPE)
	check(paused and settlement.get("_overlay").visible, "Escape cannot dismiss unsaved death settlement")
	store.save_path = SAVE_PATH
	settlement.settle_death()
	check(player.health.is_dead() and paused and root.get_node("RunManager").run_finished, "death shows completed settlement and pauses the world")
	check(not inv.is_open, "death closes backpack")
	var saved: Dictionary = store.get_profile()
	check(saved.loadout.inventory.backpack.get("items", []).is_empty() and saved.loadout.inventory.secondary.is_empty(), "death discards unprotected bag and equipment")
	check(saved.loadout.inventory.blackbox.item.properties.instance_id.value == var_to_str(protected_id), "only blackbox instance is protected")
	settlement.settle_death()
	check(store.get_profile() == saved, "repeat death settlement cannot duplicate items")
	settlement.return_to_warehouse()
	room = await wait_scene(main)
	player = room.player
	inv = player.inventory
	player.set_physics_process(false)
	check(not paused and inv.backpack.get_item_count() == 0, "return to warehouse restores playable state without lost bag items")
	check(inv.blackbox_slot.get_item().get_property("instance_id") == protected_id, "same protected item is recovered")
	check(inv.get_insurance_item() == null and not player.circuit_breaker.equipped, "core lost outside blackbox is not silently regenerated")
	check(inv.weapon_slot.get_item().get_property("bound"), "bound starter remains available")
	# A fresh service reads the same death result, including an absent core.
	var fresh: Node = load("res://scripts/core/warehouse_store.gd").new()
	fresh.save_path = SAVE_PATH
	root.add_child(fresh)
	check(fresh.load_profile() and fresh.get_profile().loadout.inventory.blackbox.item.prototype_id == "wheel", "death protection persists across fresh disk read")
	fresh.queue_free()
	# Grant a replacement as a test fixture; a spent core in blackbox also survives death.
	check(inv.pickup("circuit_breaker") and inv.put_in_blackbox(0), "replacement insurance fixture")
	check(room.depart(), "second action starts")
	battle = await wait_scene(main)
	player = battle.get_node("Player")
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	player.health.apply_damage(100, DamagePacket.new())
	check(not player.health.is_dead() and player.inventory.blackbox_slot.get_item().get_property("circuit_breaker_used"), "insurance protects once and marks actual item spent")
	player.health.apply_damage(1, DamagePacket.new())
	await process_frame
	await process_frame
	check(player.health.is_dead(), "spent core cannot prevent second fatal hit")
	check(store.get_profile().loadout.inventory.blackbox.item.prototype_id == "circuit_breaker", "spent core in blackbox survives death")
	settlement.return_to_warehouse()
	room = await wait_scene(main)
	check(room.depart(), "third action starts for abandon-path check")
	battle = await wait_scene(main)
	player = battle.get_node("Player")
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await key(KEY_R)
	room = await wait_scene(main)
	check(room.is_in_group("warehouse") and not paused, "R on a persistent action abandons it and returns to warehouse")
	check(room.player.inventory.blackbox_slot.get_item().get_property("slot") == "insurance", "abandon path preserves blackbox instead of spawning duplicate equipment")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("Blackbox checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
