extends SceneTree

var failures := 0
var checks := 0
var store: Node
const TEST_PATH := "user://warehouse-integration-test.json"

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

func press_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func click_button(button: Button) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size/2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event,true)
		await process_frame
func wait_path(path: String) -> Node:
	for frame in 600:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return current_scene
	return null
func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	store.save_path = "user://trial-entry-check.json"
	DirAccess.remove_absolute(store.save_path)
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	var warehouse := await wait_scene(main)
	var player: PlayerController = warehouse.player
	player.set_physics_process(false)
	player.inventory.pickup("pistol")
	await process_frame
	warehouse.save_loadout()
	var before: Dictionary = store.get_profile()
	var save_path: String = store.save_path
	store.save_path = "user://missing-trial-folder/profile.json"
	check(not warehouse.enter_trial() and player.is_input_enabled(),"failed save keeps player safely in warehouse")
	store.save_path = save_path
	player.position = Vector2(420,150)
	for frame in 4:
		await physics_frame
	await press_key(KEY_E)
	var trial := await wait_path("res://scenes/debug/fuel_reaction_sandbox.tscn")
	check(trial != null,"real E at warehouse portal opens trial")
	if trial == null:
		quit(1)
		return
	check(not root.get_node("RunManager").persistent_run,"trial is isolated from persistent action")
	check(trial.player.inventory.secondary_weapon_slot.get_item() == null,"trial does not import stored weapon")
	check(trial.get_node("PowerBox") != null and trial.get_node("FuelBarrel") != null,"both environment props available")
	trial.panel.open()
	for item in trial.chest.get_items():
		if item.get_prototype().get_prototype_id() == "pistol":
			check(trial.transfer(item,false),"trial supply chest withdraws test gear")
			break
	trial.panel.close()
	trial.player.statuses.add_status(&"oiled",6,["negative","oil"])
	check(store.get_profile() == before,"trial equipment and status do not mutate saved profile")
	await press_key(KEY_R)
	for frame in 10:
		await process_frame
	trial = current_scene
	check(trial.scene_file_path == "res://scenes/debug/fuel_reaction_sandbox.tscn" and trial.player.inventory.secondary_weapon_slot.get_item() == null,"R resets trial rather than discarding stored gear")
	trial.player.set_circuit_breaker_equipped(false)
	trial.player.health.apply_damage(100,DamagePacket.new())
	await click_button(trial.get_node("UI/ReturnWarehouse"))
	main = await wait_path("res://scenes/bootstrap/warehouse_main.tscn")
	check(main != null,"return button works after death")
	if main != null:
		main.get_node("SceneFlow").fade_duration = 0
		warehouse = await wait_scene(main)
		check(warehouse != null and warehouse.is_in_group("warehouse"),"return loads warehouse")
		check(store.get_profile() == before,"original warehouse gear restored without trial rewards")
		check(not warehouse.player.statuses.has_status(&"oiled") and warehouse.player.health.current_health == 3,"trial statuses and damage do not leak back")
		main.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("Trial entry checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
