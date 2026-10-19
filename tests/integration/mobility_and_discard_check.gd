extends SceneTree
var checks := 0
var failures := 0
const SAVE := "user://mobility-discard-check.json"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE
	DirAccess.remove_absolute(SAVE)
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	var player: PlayerController = room.player
	player.set_physics_process(false)
	var inv := player.inventory
	var rng := RandomNumberGenerator.new()
	for tier in [1, 2, 3]:
		var item := ComponentRolls.create("wheel", tier, rng)
		item.set_property("affixes", {"guard": 20})
		inv.mobility_slot.clear()
		inv.mobility_slot.equip(item)
		inv._apply_equipment()
		var mode := player.mobility.get_current_mode() as WheelMobilityMode
		check(mode.max_speed == 150.0, "wheel keeps modest constant move speed across quality")
		check(mode.ram_damage == tier + 1, "quality increases real ram damage")
		check(is_equal_approx(mode.ability_cooldown, ComponentRolls.WHEEL_RAM_COOLDOWNS[tier - 1]), "quality reduces real cooldown")
		check(ComponentRolls.describe(item).contains("冲撞 %d 点伤害" % (tier + 1)), "tooltip reports effective charge stats")
		inv._apply_equipment()
		check(player.mobility.get_current_mode().ram_damage == tier + 1, "reapplying equipment does not stack quality")
	check(load("res://resources/mobility/wheel.tres").ram_damage == 2, "quality never mutates shared wheel resource")
	var a := ComponentRolls.create("wheel", 1, rng)
	var b := ComponentRolls.create("wheel", 1, rng)
	room.chest.add_item(a)
	room.chest.add_item(b)
	room.upgrade_panel.select_material(0, a)
	room.upgrade_panel.select_material(1, b)
	check(room.upgrade_panel.get("_preview").text.contains("冲撞伤害 2 → 3"), "workshop previews quality damage gain")
	check(room.upgrade_panel.get("_preview").text.contains("冷却 1.2 → 1.0"), "workshop previews reduced cooldown")
	var discard := ComponentRolls.create("armor", 3, rng)
	discard.set_property("armor_cooldown_remaining", 4.5)
	inv.pickup("armor", discard)
	var id: String = discard.get_property("instance_id")
	inv.set_open(true)
	await process_frame
	var button: Button = inv.panel.get("_buttons")[0]
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	check(inv.panel.get("_discard_menu").visible, "real right click opens discard action")
	inv.panel.get("_discard_menu").id_pressed.emit(0)
	inv.panel.get("_discard_menu").hide()
	check(not inv.backpack.has_item(discard), "discard removes backpack item")
	var pickup: ComponentPickup = get_first_node_in_group("component_pickups")
	check(pickup != null and pickup.rolled_item == discard, "drop owns same instance without reroll")
	check(not inv.discard_backpack_item(discard), "repeated stale discard cannot duplicate ground loot")
	check(not inv.discard_backpack_item(inv.weapon_slot.get_item()) and not inv.discard_backpack_item(inv.blackbox_slot.get_item()), "equipped and blackbox items require moving to backpack first")
	check(store.get_profile().loadout.inventory.backpack.get("items", []).is_empty(), "warehouse snapshot commits removal before ground spawn")
	inv.set_open(false)
	await physics_frame
	check(pickup.try_pickup(inv), "dropped item can be picked back up")
	check(inv.backpack.get_items()[0].get_property("instance_id") == id and inv.backpack.get_items()[0].get_property("armor_cooldown_remaining") == 4.5, "pickup preserves ID quality affixes and armor cooldown")
	await process_frame
	inv.set_open(true)
	var before: Dictionary = player.export_run_state()
	store.save_path = "user://discard-no-such-folder/save.json"
	check(not inv.discard_backpack_item(discard), "save failure rejects discard")
	check(inv.backpack.get_items()[0] == discard and player.export_run_state() == before, "failed discard restores same item and ordering")
	check(get_nodes_in_group("component_pickups").is_empty(), "failed discard creates no ground duplicate")
	store.save_path = SAVE
	inv.set_open(false)
	check(not inv.discard_backpack_item(discard), "discard requires open backpack")
	room.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	print("Mobility and discard checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
