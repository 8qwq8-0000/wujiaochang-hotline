extends SceneTree

var failures := 0
var checks := 0
var rng := RandomNumberGenerator.new()

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

func move_mouse(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)
	await process_frame

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func drag(source: Control, destination: Vector2) -> void:
	var start := source.get_global_rect().get_center()
	await move_mouse(start, Vector2.ZERO, false)
	await mouse_button(start, true)
	await move_mouse(start + Vector2(20, 0), Vector2(20, 0), true)
	check(root.gui_is_dragging(), "native synthesis drag starts")
	await move_mouse(destination, destination - start - Vector2(20, 0), true)
	await mouse_button(destination, false)
	await process_frame

func run() -> void:
	rng.seed = 913
	var store := root.get_node("WarehouseStore")
	store.save_path = "user://component_progression_test.json"
	DirAccess.remove_absolute(store.save_path)
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await settle()
	var player: PlayerController = room.player
	player.set_physics_process(false)
	player.heat.set_physics_process(false)
	var inv := player.inventory
	check(ComponentRolls.affixes(inv.weapon_slot.get_item()).is_empty(), "bound starter has no affixes")
	for tier in range(1, 4):
		for index in 30:
			var item := ComponentRolls.create("pistol", tier, rng)
			check(ComponentRolls.quality(item) == tier and ComponentRolls.affixes(item).size() >= 1 and ComponentRolls.affixes(item).size() <= tier, "generated quality and affix cap")
	var legacy := InventoryItem.new(ComponentInventory.PROTOTYPES, "wheel")
	ComponentRolls.ensure(legacy)
	var legacy_data := legacy.serialize()
	ComponentRolls.ensure(legacy)
	check(legacy.serialize() == legacy_data, "legacy migration stable on repeated load")
	var a := ComponentRolls.create("pistol", 1, rng)
	var b := ComponentRolls.create("scattergun", 1, rng)
	a.set_property("affixes", {"attack": 20})
	b.set_property("affixes", {"attack": 40})
	check(not ComponentRolls.compatible(a, a) and not ComponentRolls.compatible(a, legacy) and ComponentRolls.compatible(a, inv.weapon_slot.get_item()), "same item and wrong slot rejected; starter accepts standard weapon")
	check(not ComponentRolls.compatible(a, inv.blackbox_slot.get_item()), "insurance cannot synthesize")
	check(inv.pickup("pistol", a), "rolled item pickup equips free reserve")
	check(inv.secondary_weapon_slot.get_item() == a, "pickup retains same instance")
	player.weapons.select_weapon(1)
	check(player.weapons.get_current_weapon().damage > load("res://resources/weapons/service_pistol.tres").damage, "attack affix changes actual weapon damage")
	check(load("res://resources/weapons/service_pistol.tres").damage == 1, "shared weapon resource is untouched")
	var before := player.export_run_state()
	for index in 3:
		player.import_run_state(before)
	check(player.export_run_state() == before, "repeated snapshots preserve exact instances and rolled values")
	check(player.weapons.get_current_weapon().damage == ComponentRolls.weapon(a).damage, "repeated imports never stack attack")
	a = inv.secondary_weapon_slot.get_item()
	check(room.transfer(a, true), "rolled equipped item deposits into warehouse")
	room.chest.add_item(b)
	check(room.save_loadout(), "persist second material")
	room.panel.open()
	await settle()
	var rows: Array = room.panel.get("_chest_list").get_children()
	var targets: Array = room.panel.get("_material_buttons")
	await drag(rows[0], targets[0].get_global_rect().get_center())
	await drag(rows[1], targets[1].get_global_rect().get_center())
	check(room.panel.get("_materials") == [a, b] and not room.panel.get("_synthesis_button").disabled, "native warehouse drag selects subject and material without moving ownership")
	room.panel.close()
	for index in 6:
		inv.backpack.add_item(ComponentRolls.create("wheel", 1, rng))
	check(inv.backpack.get_item_count() == 6, "synthesis setup uses full backpack")
	var chest_before: Dictionary = room.chest.serialize()
	var bag_before: Dictionary = inv.export_run_state()
	var valid_path: String = store.save_path
	store.save_path = "user://missing_component_directory/save.json"
	check(not room.synthesize(a, b), "write failure rejects synthesis")
	check(room.chest.has_item(a) and room.chest.has_item(b) and room.chest.serialize() == chest_before and inv.export_run_state() == bag_before, "failed synthesis retains both original instances and full bag")
	store.save_path = valid_path
	check(room.synthesize(a, b), "full bag synthesis succeeds into chest")
	check(not room.chest.has_item(a) and not room.chest.has_item(b) and room.chest.get_item_count() == 1, "exactly two materials consumed and one result created")
	var result: InventoryItem = room.chest.get_items()[0]
	check(result.get_prototype().get_prototype_id() == "pistol" and ComponentRolls.quality(result) == 2 and ComponentRolls.affixes(result) == {"attack": 40.0}, "subject shape and stronger shared affix inherited")
	check(not room.synthesize(a, b), "stale material references cannot duplicate synthesis")
	var persisted := result.serialize()
	check(not room.transfer(result, false) and room.chest.has_item(result), "full bag withdrawal retains synthesized item")
	inv.backpack.remove_item(inv.backpack.get_items()[0])
	check(room.transfer(result, false), "synthesized item withdraws after freeing one cell")
	result = inv.backpack.get_items().back()
	check(result.serialize() == persisted, "synthesis values survive warehouse withdrawal")
	check(room.transfer(result, true), "result returns to chest")
	var c := ComponentRolls.create("wheel", 3, rng)
	var d := ComponentRolls.create("wheel", 3, rng)
	c.set_property("affixes", {"cooling": 10, "guard": 20, "mobility": 10})
	d.set_property("affixes", {"cooling": 30, "capacity": 20, "mobility": 25})
	var fused := ComponentRolls.fuse(c, d, rng)
	check(ComponentRolls.quality(fused) == 3 and ComponentRolls.affixes(fused).size() == 3, "prototype adjusts merged pool while retaining cap")
	for key in ComponentRolls.affixes(fused):
		check(ComponentRolls.affixes(fused)[key] == maxf(float(ComponentRolls.affixes(c).get(key, 0)), float(ComponentRolls.affixes(d).get(key, 0))), "selected affix keeps max parent value")
	inv.backpack.clear()
	inv.pickup("wheel", c)
	inv.equip(0)
	check(player.mobility.get_current_mode().max_speed > load("res://resources/mobility/wheel.tres").max_speed and player.guard.equipment_window_bonus > 0 and player.heat.equipment_cooling_bonus > 0, "mobility cooling and guard affixes affect runtime")
	var speed := player.mobility.get_current_mode().max_speed
	inv._apply_equipment()
	check(player.mobility.get_current_mode().max_speed == speed, "reapplying equipment never stacks mobility")
	inv.unequip("mobility")
	check(player.guard.equipment_window_bonus == 0 and player.heat.equipment_cooling_bonus == 0, "unequip removes bonuses")
	var protective := inv.backpack.get_items()[0]
	protective.set_property("affixes", {"status": 25, "capacity": 20})
	inv.equip(0)
	var statuses: StatusComponent = player.get_node("StatusComponent")
	statuses.add_status(&"conductive", 6.0, ["negative", "electric"])
	check(is_equal_approx(statuses.remaining_seconds(&"conductive"), 4.5), "status affix shortens actual negative status")
	check(is_equal_approx(player.heat.effective_max(), player.heat.max_heat * 1.2), "capacity changes actual heat limit")
	inv.unequip("mobility")
	statuses.clear_all()
	statuses.add_status(&"conductive", 6.0, ["negative", "electric"])
	check(is_equal_approx(statuses.remaining_seconds(&"conductive"), 6.0), "unequip removes status duration reduction")
	statuses.clear_all()
	var reloaded: Node = load("res://scripts/core/warehouse_store.gd").new()
	reloaded.save_path = valid_path
	root.add_child(reloaded)
	check(reloaded.load_profile(), "fresh service loads synthesized profile")
	var disk_item := InventoryItem.new()
	check(disk_item.deserialize(reloaded.get_profile().chest[0]) and ComponentRolls.quality(disk_item) == ComponentRolls.quality(result) and ComponentRolls.affixes(disk_item) == ComponentRolls.affixes(result) and disk_item.get_property("instance_id") == result.get_property("instance_id"), "fresh disk read preserves synthesized quality values and ID")
	reloaded.queue_free()
	var profile: Dictionary = store.get_profile()
	check(not profile.chest.is_empty() and profile.chest[0] == persisted, "atomic saved profile contains exact result")
	room.panel.open()
	await settle()
	if OS.get_cmdline_user_args().has("--capture"):
		root.get_texture().get_image().save_png("/tmp/hotline-synthesis.png")
	room.panel.close()
	room.queue_free()
	await settle()
	DirAccess.remove_absolute(valid_path)
	print("Component progression checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
