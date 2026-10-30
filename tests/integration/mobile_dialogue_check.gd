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

func touch(point: Vector2, pressed: bool, finger := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = finger
	root.push_input(event, true)

func emulated_mouse(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var store := root.get_node("WarehouseStore")
	store.save_path = "user://mobile-dialogue-isolated.json"
	store.begin_test_session()
	store.create_new_profile()
	var prologue: HotlinePrologue = load("res://scenes/levels/prologue/hotline_prologue.tscn").instantiate()
	var main := Node2D.new()
	var container := Node2D.new()
	main.add_child(container)
	root.add_child(main)
	current_scene = main
	container.add_child(prologue)
	await process_frame
	var point := Vector2(40, 90)
	prologue.set("_line_age", 2.0)
	var before: int = prologue.get("_dialogue_queue").size()
	touch(point, true)
	touch(point, false)
	emulated_mouse(point)
	check(prologue.get("_dialogue_queue").size() == before - 1, "opening accepts native touch exactly once including emulated mouse and release")
	prologue.set("_line_age", 2.0)
	before = prologue.get("_dialogue_queue").size()
	touch(point, true, 1)
	touch(point, false, 1)
	check(prologue.get("_dialogue_queue").size() == before, "second finger does not skip another opening line")
	var skip_rect: Rect2 = prologue.get("_skip_button").get_global_rect()
	touch(skip_rect.get_center(), true)
	touch(skip_rect.get_center(), false)
	check(prologue.get("_dialogue_queue").size() == before, "skip button region is excluded from dialogue taps")
	for index in 12:
		if prologue.step != HotlinePrologue.Step.BRIEFING:
			break
		prologue.set("_line_age", 2.0)
		touch(point, true)
		touch(point, false)
	check(prologue.step == HotlinePrologue.Step.DODGE and paused, "native taps finish opening and reach paused movement instruction")
	prologue.get("_dialogue_queue").clear()
	var dialogue: Label = prologue.get("_dialogue")
	dialogue.visible_characters = 0
	touch(point, true)
	touch(point, false)
	emulated_mouse(point)
	check(paused and dialogue.visible_characters == dialogue.get_total_character_count(), "first tutorial touch only reveals the current line")
	touch(point, true)
	touch(point, false)
	check(not paused and prologue.player.is_input_enabled(), "second tutorial touch continues and resumes gameplay")
	main.queue_free()
	await process_frame
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var codex: Node = load("res://scripts/ui/codex_dialogue_panel.gd").new()
	codex.player = player
	codex.lines.assign(["第一句", "第二句", "第三句"])
	root.add_child(codex)
	codex.open()
	touch(point, true)
	touch(point, false)
	emulated_mouse(point)
	check(codex.get("_page") == 1 and codex.is_open, "Codex native tap advances exactly one page")
	touch(point, true, 1)
	touch(point, false, 1)
	check(codex.get("_page") == 1, "Codex ignores secondary fingers")
	codex.set("_page", 0)
	codex._refresh()
	await process_frame
	await process_frame
	var next_point: Vector2 = codex.get("_next").get_global_rect().get_center()
	touch(next_point, true)
	touch(next_point, false)
	check(codex.get("_page") == 1 and codex.is_open, "native touch on the visible continue button also advances only once")
	codex.close()
	codex.queue_free()
	await process_frame
	var arrival: Node = load("res://scripts/ui/prologue_arrival_notice.gd").new()
	arrival.player = player
	root.add_child(arrival)
	check(paused and not player.is_input_enabled(), "arrival notice pauses the player")
	touch(point, true)
	touch(point, false)
	check(not paused and player.is_input_enabled(), "arrival notice closes with native tap")
	await process_frame
	player.queue_free()
	await process_frame
	var warehouse: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(warehouse)
	current_scene = warehouse
	warehouse.receive_scene_payload({"guide_storage": true})
	var guide: Node = warehouse.get("_storage_guide")
	check(guide.get("_talking") and paused, "storage guide starts paused")
	touch(point, true)
	touch(point, false)
	check(not guide.get("_talking") and not paused and warehouse.player.is_input_enabled(), "storage guide accepts native touch without a mouse event")
	warehouse.queue_free()
	await process_frame
	store.end_test_session()
	print("Mobile dialogue checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
