extends SceneTree

var failures := 0
var checks := 0
var native_drags := 0
const SAVE_PATH := "user://inventory-drag-test.json"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

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
	if root.gui_is_dragging():
		native_drags += 1
	await move_mouse(destination, destination - start - Vector2(20, 0), true)
	await mouse_button(destination, false)
	await process_frame

func run_checks() -> void:
	var store: Node = root.get_node("WarehouseStore")
	store.save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	var room: Node
	for frame in 600:
		await process_frame
		if main.get_node("SceneContainer").get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			room = main.get_node("SceneContainer").get_child(0)
			break
	if room == null:
		check(false, "warehouse loads")
		quit(1)
		return
	var player: PlayerController = room.player
	player.set_physics_process(false)
	var inv: ComponentInventory = player.inventory
	inv.pickup("pistol")
	inv.pickup("scattergun")
	inv.pickup("wheel")
	inv.pickup("baton")
	inv.set_open(true)
	await process_frame
	await process_frame
	var panel: CanvasLayer = inv.panel
	var cells: Array = panel.get("_buttons")
	var primary: Button = panel.get("_weapon")
	var reserve: Button = panel.get("_secondary")
	var mobility: Button = panel.get("_mobility")
	var blackbox: Button = panel.get("_blackbox")
	check(panel.find_children("*", "OptionButton", true, false).is_empty(), "no dropdown remains")
	check(not mobility.disabled and not cells[5].disabled, "empty slots accept drops")
	var scatter := inv.item_at("backpack", 0)
	var pistol := inv.secondary_weapon_slot.get_item()
	var bound := inv.weapon_slot.get_item()
	await drag(cells[0], reserve.get_global_rect().get_center())
	check(inv.secondary_weapon_slot.get_item() == scatter and inv.item_at("backpack", 0) == pistol, "native drag exchanges backpack weapon with chosen reserve")
	check(inv.weapon_slot.get_item() == bound, "explicit reserve drag preserves primary")
	var wheel := inv.item_at("backpack", 1)
	var insurance := inv.blackbox_slot.get_item()
	await drag(cells[1], blackbox.get_global_rect().get_center())
	check(inv.blackbox_slot.get_item() == wheel and inv.item_at("backpack", 1) == insurance, "native drag swaps ordinary item into occupied blackbox")
	check(not player.circuit_breaker.equipped, "dragging core out disables insurance")
	await drag(blackbox, mobility.get_global_rect().get_center())
	check(inv.mobility_slot.get_item() == wheel and inv.blackbox_slot.get_item() == null, "protected mobility item can move to empty matching equipment slot")
	check(player.mobility.get_current_mode().id == &"wheel", "drag updates actual mobility controller")
	await drag(cells[1], blackbox.get_global_rect().get_center())
	check(inv.blackbox_slot.get_item() == insurance and player.circuit_breaker.equipped, "dragging insurance back to blackbox re-enables it")
	var before := player.export_run_state()
	await drag(primary, blackbox.get_global_rect().get_center())
	check(player.export_run_state() == before, "occupied insurance cannot swap into weapon slot; both items unchanged")
	await drag(blackbox, primary.get_global_rect().get_center())
	check(player.export_run_state() == before, "insurance cannot be dropped into weapon slot")
	await drag(mobility, cells[5].get_global_rect().get_center())
	check(inv.mobility_slot.get_item() == null and inv.backpack.has_item(wheel), "equipment can be dragged back into available backpack capacity")
	check(player.mobility.get_current_mode().id == &"walk", "dragging mobility off restores walking")
	var first := inv.item_at("backpack", 0)
	var second := inv.item_at("backpack", 1)
	player.heat.current_heat = 27
	player.weapons.set("_cooldown_remaining", 0.75)
	player.heat.set_physics_process(false)
	player.weapons.set_physics_process(false)
	await drag(cells[0], cells[1].get_global_rect().get_center())
	check(inv.item_at("backpack", 0) == second and inv.item_at("backpack", 1) == first, "native drag exchanges backpack positions")
	check(player.heat.current_heat == 27 and player.weapons.get("_cooldown_remaining") == 0.75, "bag reordering preserves heat and cooldown")
	before = player.export_run_state()
	await drag(cells[0], Vector2(2, 2))
	check(player.export_run_state() == before, "drop outside inventory cancels without mutation")
	var invalid: Variant = {"inventory": null, "item": first}
	check(not blackbox.call("_can_drop_data", Vector2.ZERO, invalid), "foreign inventory drag payload rejected")
	# The initial weapon cannot be swapped into blackbox as the outgoing item either.
	check(not inv.can_drop_item(insurance, "weapon"), "incompatible reverse exchange is rejected")
	while inv.backpack.get_item_count() < 6:
		inv.pickup("wheel")
	before = player.export_run_state()
	player.mobility.ability_cooldown_remaining = 0.6
	player.mobility.set("_ability_active_remaining", 0.2)
	player.mobility.set("_ram_direction", Vector2.LEFT)
	player.mobility.set("_ram_hits", {123: true})
	await drag(blackbox, cells[5].get_global_rect().get_center())
	check(inv.blackbox_slot.get_item() != insurance and inv.backpack.has_item(insurance), "full backpack accepts compatible atomic exchange from blackbox")
	check(player.mobility.ability_cooldown_remaining == 0.6 and player.mobility.get("_ability_active_remaining") == 0.2, "blackbox exchange does not reset mobility cooldown or active ability")
	var protected_before := inv.blackbox_slot.get_item()
	# All six cells are occupied; no additional slot is manufactured.
	check(inv.backpack.get_item_count() == 6, "full-bag exchange keeps exact capacity")
	check(not inv.take_from_blackbox() and inv.blackbox_slot.get_item() == protected_before, "full-bag direct removal still refused")
	var core_index := inv.backpack.get_item_index(insurance)
	before = player.export_run_state()
	store.save_path = "user://inventory-drag-missing-directory/save.json"
	await drag(cells[core_index], blackbox.get_global_rect().get_center())
	check(player.export_run_state() == before, "failed drag checkpoint restores both original inventories")
	check(player.heat.current_heat == 27 and player.weapons.get("_cooldown_remaining") == 0.75 and player.mobility.ability_cooldown_remaining == 0.6, "failed drag keeps heat and cooldowns unchanged")
	check(player.mobility.get("_ram_direction") == Vector2.LEFT and player.mobility.get("_ram_hits").has(123), "failed checkpoint preserves charge heading and hit deduplication")
	store.save_path = SAVE_PATH
	room.save_loadout()
	# A drag carries the instance itself, not a mutable list index.
	var stale := inv.item_at("backpack", 0)
	inv.backpack.remove_item(stale)
	check(not inv.can_drop_item(stale, "blackbox"), "stale dragged item cannot be moved after ownership changes")
	check(native_drags >= 11, "mouse input exercised Godot native drag threshold and drop pipeline")
	before = player.export_run_state()
	var start: Vector2 = cells[0].get_global_rect().get_center()
	await move_mouse(start, Vector2.ZERO, false)
	await mouse_button(start, true)
	await move_mouse(start + Vector2(20, 0), Vector2(20, 0), true)
	check(root.gui_is_dragging(), "begin pending drag before inventory closes")
	inv.set_open(false)
	await mouse_button(Vector2(2, 2), false)
	check(player.export_run_state() == before, "closing during drag cancels without losing the item")
	check(not paused and not root.gui_is_dragging(), "closing inventory leaves no drag or pause behind")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("Inventory drag checks: ", checks, "; native drags: ", native_drags, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
