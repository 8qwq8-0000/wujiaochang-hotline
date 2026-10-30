extends Node

# Explicit developer invocation only; never participates in normal gameplay.
@onready var root: Window = get_tree().root

func _ready() -> void:
	if not OS.is_debug_build() or not bool(get_meta("requested", false)):
		queue_free()
		return
	call_deferred("run")

func run() -> void:
	var store := root.get_node("WarehouseStore")
	if not store.begin_test_session():
		print("MOBILE_UI_PROBE unable to isolate profile")
		get_tree().quit(1)
		return
	store.create_new_profile()
	var previous := get_tree().current_scene
	if previous != null:
		previous.queue_free()
		await get_tree().process_frame
	var mobile := root.get_node("MobileInput")
	mobile.set_process(false)
	mobile.get("_root").hide()
	mobile.get("_tutorial").hide()
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	get_tree().current_scene = room
	for frame in 30:
		await get_tree().process_frame
	var inv: ComponentInventory = room.player.inventory
	inv.backpack.add_item(ComponentRolls.create("rail_cannon", 2, RandomNumberGenerator.new()))
	inv.set_open(true)
	for frame in 120:
		await get_tree().process_frame
	var ui: Node = inv.panel
	var viewport := root.get_visible_rect()
	var safe: Rect2 = root.get_node("MobileInput")._safe_rect()
	var panel: Rect2 = ui.get("_panel").get_global_rect()
	var close: Rect2 = ui.get("_close_button").get_global_rect()
	var trash: Rect2 = ui.get("_trash_zone").get_global_rect()
	var leaks: Array[String] = []
	for node in root.find_children("*", "Label", true, false) + root.find_children("*", "Button", true, false):
		if not node.is_visible_in_tree():
			continue
		for key in ["Tab", "Esc", "Enter", "WASD", "Space", "按 E", "[E]"]:
			if node.text.contains(key):
				leaks.append(node.text)
				break
	var report := {
		"mobile": OS.has_feature("mobile"), "ios": OS.has_feature("ios"),
		"window": str(DisplayServer.window_get_size()), "display_safe": str(DisplayServer.get_display_safe_area()),
		"viewport": str(viewport), "safe": str(safe), "panel": str(panel),
		"panel_minimum": str(ui.get("_panel").get_combined_minimum_size()),
		"close": str(close), "trash": str(trash),
		"fits": viewport.encloses(safe) and safe.encloses(panel) and safe.encloses(close) and safe.encloses(trash),
		"desktop_prompt_leaks": leaks,
		"control_examples": [ControlPrompts.adapt("按 E 拾取"), ControlPrompts.adapt("按 Tab 打开背包"), ControlPrompts.adapt("鼠标瞄准，点左键开火")],
	}
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://mobile_ui_probe.png")
	for pressed in [true, false]:
		var tap := InputEventScreenTouch.new()
		tap.index = 0
		tap.position = close.get_center()
		tap.pressed = pressed
		root.push_input(tap, true)
	report["touch_close_works"] = not inv.is_open
	var file := FileAccess.open("user://mobile_ui_probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOBILE_UI_PROBE ", JSON.stringify(report))
	print("MOBILE_UI_PROBE files: ", OS.get_user_data_dir())
	inv.set_open(false)
	room.queue_free()
	await get_tree().process_frame
	store.end_test_session()
	get_tree().quit(0 if report.fits and leaks.is_empty() and report.touch_close_works else 1)
