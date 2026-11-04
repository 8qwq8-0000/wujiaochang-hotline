extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count := 4) -> void:
	for index in count:
		await process_frame

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = "user://mobile-inventory-panel-isolated.json"
	store.begin_test_session()
	store.create_new_profile()
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await frames()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 590)
	await frames()
	var inv: ComponentInventory = room.player.inventory
	inv.backpack.add_item(ComponentRolls.create("rail_cannon", 2, RandomNumberGenerator.new()))
	inv.set_open(true)
	await frames()
	var panel: Node = inv.panel
	var bounds: Rect2 = panel.get("_panel").get_global_rect()
	var safe: Rect2 = root.get_node("MobileInput")._safe_rect()
	check(safe.encloses(bounds), "landscape backpack stays within the visible safe area")
	var close: Button = panel.get("_close_button")
	var trash: Control = panel.get("_trash_zone")
	check(bounds.encloses(close.get_global_rect()), "close button is fully visible")
	check(bounds.encloses(trash.get_global_rect()), "entire bottom discard zone is visible")
	check(close.get_global_rect().size.y >= 36, "close target retains a usable touch height")
	var message: Label = panel.get("_message")
	var original_message := message.text
	message.text = "很长的装备说明与换装反馈\n".repeat(30)
	await frames(12)
	check(safe.encloses(panel.get("_panel").get_global_rect()) and safe.encloses(close.get_global_rect()) and safe.encloses(trash.get_global_rect()), "multiline feedback cannot expand the panel or push the close/footer offscreen")
	message.text = original_message
	await frames()
	var scroll: ScrollContainer = panel.get("_scroll")
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "equipment body can scroll instead of pushing the footer offscreen")
	var slot: Control = panel.get("_weapon")
	var weapon_before := inv.weapon_slot.get_item()
	var origin := slot.get_global_rect().get_center()
	touch(origin, true)
	for index in 5:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = origin + Vector2(0, -12 * (index + 1))
		drag.relative = Vector2(0, -12)
		root.push_input(drag, true)
		await process_frame
	touch(origin + Vector2(0, -60), false)
	await frames()
	check(scroll.scroll_vertical > 0, "swiping a slot scrolls the equipment body")
	check(inv.weapon_slot.get_item() == weapon_before, "swiping does not accidentally unequip the touched slot")
	check(bounds.encloses(trash.get_global_rect()), "discard zone remains fixed while equipment scrolls")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hotline-mobile-inventory.png")
	var cell: Control = panel.get("_buttons")[0]
	scroll.ensure_control_visible(cell)
	await frames()
	var cell_point := cell.get_global_rect().get_center()
	touch(cell_point, true)
	await create_timer(0.45).timeout
	await frames()
	check(root.gui_is_dragging(), "stationary long press still starts an equipment drag")
	var drop_point := trash.get_global_rect().get_center()
	var drop_drag := InputEventScreenDrag.new()
	drop_drag.index = 0
	drop_drag.position = drop_point
	drop_drag.relative = drop_point - cell_point
	root.push_input(drop_drag, true)
	await frames()
	touch(drop_point, false)
	await frames()
	check(not inv.is_open and not paused and inv.backpack.get_item_count() == 0, "native long-press drop reaches the fixed discard zone and closes safely")
	inv.set_open(false)
	inv.set_open(true)
	await frames()
	touch(close.get_global_rect().get_center(), true)
	touch(close.get_global_rect().get_center(), false)
	await frames()
	check(not inv.is_open and not paused, "native touch on close dismisses the backpack and resumes gameplay")
	root.size = Vector2i(960, 540)
	await frames()
	inv.set_open(true)
	await frames()
	safe = root.get_node("MobileInput")._safe_rect()
	check(safe.encloses(panel.get("_panel").get_global_rect()) and safe.encloses(trash.get_global_rect()), "resizing also keeps the panel and footer fully inside the viewport")
	var cancel := InputEventAction.new()
	cancel.action = &"inventory_toggle"
	cancel.pressed = true
	root.push_input(cancel, true)
	await frames()
	check(not inv.is_open and not paused, "desktop inventory toggle still closes the panel")
	room.queue_free()
	await frames()
	store.end_test_session()
	print("Mobile inventory panel checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
