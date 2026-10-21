extends SceneTree
const SAVE := "user://start-menu-check.json"
var failures := 0
var checks := 0
var store: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func backups() -> Array[String]:
	var found: Array[String] = []
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("start-menu-check.json.backup-"):
			found.append("user://" + name)
	return found

func menu() -> Control:
	var instance: Control = load("res://scenes/ui/start_menu.tscn").instantiate()
	root.add_child(instance)
	current_scene = instance
	return instance

func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func click(instance: Node, text: String) -> void:
	for child in instance.get("_content").get_children():
		if child is Button and child.text == text:
			var point: Vector2 = child.get_global_rect().get_center()
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				root.push_input(event, true)
				await process_frame
			return
	check(false, "button exists: " + text)

func warehouse() -> Node:
	for frame in 500:
		await process_frame
		var rooms := get_nodes_in_group("warehouse")
		if not rooms.is_empty():
			return rooms[0]
	return null

func run() -> void:
	store = root.get_node("WarehouseStore")
	store.save_path = SAVE
	DirAccess.remove_absolute(SAVE)
	for path in backups():
		DirAccess.remove_absolute(path)
	var cutout := (load("res://assets/art/ui/standard_chassis_cutout.png") as Texture2D).get_image()
	check(cutout.detect_alpha() != Image.ALPHA_NONE, "portrait has true alpha transparency")
	check(cutout.get_pixel(0, 0).a == 0.0, "portrait background is transparent")
	var home := menu()
	await process_frame
	check(home.get("_home_art").visible and not home.get("_legacy_art").visible, "home uses the poster art layer")
	check(home.get("_continue").disabled, "no save disables continue")
	check(not FileAccess.file_exists(SAVE), "opening home never creates save")
	check(root.gui_get_focus_owner().text == "开始新存档", "first game keyboard focus selects new save")
	await screenshot("/tmp/hotline-start-home.png")
	await click(home, "开始新存档")
	check(home.page == "difficulty", "new game opens difficulty selection through mouse")
	check(not home.get("_home_art").visible and home.get("_legacy_art").visible, "difficulty restores the legacy menu art layer")
	check(not FileAccess.file_exists(SAVE), "difficulty selection never creates save")
	check(root.gui_get_focus_owner().text == "标准", "difficulty defaults to standard")
	await click(home, "低压")
	check(home.page == "character" and home.get("_difficulty") == "low_pressure", "low pressure is selectable before save creation")
	home.show_difficulty()
	await screenshot("/tmp/hotline-start-difficulty.png")
	await click(home, "高压")
	check(home.page == "character", "difficulty selection opens character confirmation")
	check(not FileAccess.file_exists(SAVE), "character selection never creates save")
	check(root.gui_get_focus_owner().text == "开始行动", "character confirmation receives keyboard focus")
	await screenshot("/tmp/hotline-start-character.png")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	check(home.page == "difficulty", "Escape from character returns to difficulty")
	root.push_input(escape, true)
	await process_frame
	check(home.page == "home", "Escape returns home without creating save")
	await click(home, "开始新存档")
	await click(home, "高压")
	await click(home, "开始行动")
	var room := await warehouse()
	check(room != null, "first game enters warehouse")
	if room == null:
		quit(1)
		return
	room.player.set_physics_process(false)
	check(root.get_node("GameSettings").high_pressure_alert, "new high-pressure save applies difficulty")
	check(store.get_profile().get("difficulty") == "high_pressure", "new save persists chosen difficulty")
	check(room.player.inventory.weapon_slot.get_item().get_prototype().get_prototype_id() == "pistol", "new save has ordinary issued pistol")
	check(room.chest.get_item_count() == 0, "new save has empty chest")
	check(room.save_loadout(), "warehouse persists new default loadout")
	var rng := RandomNumberGenerator.new()
	room.chest.add_item(ComponentRolls.create("wheel", 2, rng))
	check(room.save_loadout(), "existing save fixture is committed")
	check(store.get_profile().get("difficulty") == "high_pressure", "warehouse commits preserve difficulty")
	var original := FileAccess.get_file_as_string(SAVE)
	var previous_weapon: String = room.player.inventory.weapon_slot.get_item().get_property("instance_id")
	current_scene.queue_free()
	await process_frame
	await process_frame
	home = menu()
	await process_frame
	check(not home.get("_continue").disabled, "valid save enables continue")
	await click(home, "开始新存档")
	await click(home, "高压")
	await click(home, "开始行动")
	check(home.page == "confirm" and FileAccess.get_file_as_string(SAVE) == original, "existing save requires confirmation without mutation")
	await screenshot("/tmp/hotline-start-confirm.png")
	await click(home, "取消")
	check(FileAccess.get_file_as_string(SAVE) == original and backups().is_empty(), "cancel leaves file unchanged and no backup side effects")
	home.show_home()
	root.get_node("GameSettings").set_high_pressure_alert(false, false)
	await click(home, "继续游戏")
	room = await warehouse()
	check(room != null and room.chest.get_item_count() == 1, "continue restores chest")
	check(root.get_node("GameSettings").high_pressure_alert, "continue restores saved high-pressure difficulty")
	check(room.player.inventory.weapon_slot.get_item().get_property("instance_id") == previous_weapon, "continue retains same weapon instance")
	current_scene.queue_free()
	await process_frame
	await process_frame
	home = menu()
	await process_frame
	home.show_difficulty()
	await click(home, "标准")
	home.request_new_game()
	await click(home, "确认重开")
	room = await warehouse()
	check(room != null and room.chest.get_item_count() == 0, "confirmed new game clears old chest")
	check(not root.get_node("GameSettings").high_pressure_alert and store.get_profile().get("difficulty") == "standard", "standard new save resets previous difficulty")
	check(room.player.inventory.weapon_slot.get_item().get_property("instance_id") != previous_weapon, "new save grants a new ordinary pistol")
	check(backups().size() == 1 and FileAccess.get_file_as_string(backups()[0]) == original, "backup preserves exact old file before replacement")
	current_scene.queue_free()
	await process_frame
	await process_frame
	# Legacy profiles without a difficulty field inherit the migrated global setting.
	var legacy: Dictionary = store.get_profile()
	legacy.erase("difficulty")
	var legacy_file := FileAccess.open(SAVE, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	store.set("_loaded", false)
	home = menu()
	root.get_node("GameSettings").set_high_pressure_alert(true, false)
	await process_frame
	await click(home, "继续游戏")
	room = await warehouse()
	check(room != null and root.get_node("GameSettings").high_pressure_alert, "legacy save retains migrated high-pressure setting")
	current_scene.queue_free()
	await process_frame
	await process_frame
	# Corrupt profiles are recoverable only through explicit new-game confirmation.
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("corrupt original")
	file.close()
	store.set("_loaded", false)
	home = menu()
	await process_frame
	check(home.get("_continue").disabled and FileAccess.get_file_as_string(SAVE) == "corrupt original", "corrupt save disables continue and stays intact")
	check(store.create_new_profile(), "explicit new game recovers rejected profile")
	var corrupt_backup := false
	for path in backups():
		corrupt_backup = corrupt_backup or FileAccess.get_file_as_string(path) == "corrupt original"
	check(corrupt_backup, "corrupt raw file is backed up too")
	var before: Dictionary = store.get_profile()
	store.save_path = "user://start-menu-no-such-directory/save.json"
	check(not store.create_new_profile() and store.get_profile() == before, "failed new save preserves cached profile")
	store.save_path = SAVE
	home.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	for path in backups():
		DirAccess.remove_absolute(path)
	print("Start menu checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
