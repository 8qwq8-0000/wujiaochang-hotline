extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func press_key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func stock(scene: Node,id: String) -> InventoryItem:
	for item in scene.chest.get_items():
		if item.get_prototype().get_prototype_id() == id:
			return item
	return null
func right_titles(scene: Node) -> Array:
	var titles := []
	for button in scene.panel.get("_chest_list").get_children():
		titles.append(button.text)
	return titles
func run_checks() -> void:
	var before: Dictionary = root.get_node("WarehouseStore").get_profile()
	var scene = load("res://scenes/debug/fuel_reaction_sandbox.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player: PlayerController = scene.player
	player.set_physics_process(false)
	var expected := 0
	for id in ComponentInventory.PROTOTYPES.data:
		var data: Dictionary = ComponentInventory.PROTOTYPES.data[id]
		if data.get("debug_only",false) or data.get("bound",false):
			check(stock(scene,id) == null,"test and bound gear excluded from chest")
		else:
			expected += 1
			check(stock(scene,id) != null,"all ordinary items available")
	check(scene.chest.get_item_count() == expected,"one stock instance per ordinary item")
	player.position = Vector2(100,170)
	for frame in 4:
		await physics_frame
	await press_key(KEY_E)
	check(scene.panel.is_open and paused and not player.is_input_enabled(),"real E opens chest and pauses")
	var initial_order := right_titles(scene)
	var pistol := stock(scene,"pistol")
	var original_id: String = pistol.get_property("instance_id")
	var list: VBoxContainer = scene.panel.get("_chest_list")
	var clicked := false
	for button in list.get_children():
		if button is Button and button.text == ComponentRolls.title(pistol):
			var point: Vector2 = button.get_global_transform_with_canvas()*(button.size/2)
			for pressed in [true,false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				event.position = point
				root.push_input(event,true)
				await process_frame
			clicked = true
			break
	check(clicked and player.inventory.backpack.has_item(pistol),"real mouse click withdraws item")
	check(right_titles(scene) == initial_order,"restocked item keeps original row")
	check(stock(scene,"pistol") != pistol and stock(scene,"pistol").get_property("instance_id") != original_id,"restock creates a distinct instance")
	for index in 5:
		scene.transfer(stock(scene,"pistol"),false)
	check(right_titles(scene) == initial_order,"repeated withdrawals preserve catalog order")
	check(player.inventory.backpack.get_item_count() == 6,"bag capacity remains six")
	var count: int = scene.chest.get_item_count()
	check(not scene.transfer(stock(scene,"pistol"),false) and scene.chest.get_item_count() == count,"full bag refuses without losing stock")
	await press_key(KEY_E)
	check(not scene.panel.is_open and not paused and player.is_input_enabled(),"E closes chest and resumes")
	await press_key(KEY_TAB)
	check(player.inventory.is_open and player.inventory.can_drop_item(pistol,"weapon_secondary"),"trial allows drag equipment with living targets")
	check(player.inventory.drop_item(pistol,"weapon_secondary") and player.weapons.get_current_weapon() != null,"withdrawn gear equips through drag/drop operation")
	await press_key(KEY_TAB)
	await press_key(KEY_E)
	check(scene.transfer(pistol,true) and player.inventory.secondary_weapon_slot.get_item() == null,"equipped item can be stored back")
	check(right_titles(scene) == initial_order,"returned duplicate does not insert extra row")
	check(not scene.transfer(stock(scene,"circuit_breaker"),false),"insurance uniqueness still enforced")
	var core := player.inventory.blackbox_slot.get_item()
	check(scene.transfer(core,true),"current insurance can be deposited")
	check(right_titles(scene) == initial_order,"returned insurance preserves every catalog row")
	# Make bag space before taking a replacement insurance instance.
	scene.transfer(player.inventory.backpack.get_items()[0],true)
	check(scene.transfer(stock(scene,"circuit_breaker"),false),"insurance can be withdrawn once existing one is stored")
	check(not scene.transfer(player.inventory.weapon_slot.get_item(),true),"bound initial weapon cannot be stored")
	await press_key(KEY_ESCAPE)
	check(not paused and not scene.panel.is_open,"Esc closes chest")
	check(root.get_node("WarehouseStore").get_profile() == before,"test stock never writes profile")
	await press_key(KEY_R)
	for frame in 8:
		await process_frame
	scene = current_scene
	check(scene.chest.get_item_count() == expected and scene.player.inventory.backpack.get_item_count() == 0,"R recreates initial stock and clears test bag")
	scene.queue_free()
	await process_frame
	var normal: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(normal)
	root.get_node("RunManager").set_mandatory_enemy_count(1)
	check(not normal.inventory.can_change_equipment(),"normal combat retains equipment lock")
	normal.queue_free()
	await process_frame
	print("Trial chest checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
