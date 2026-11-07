extends SceneTree

const TEST_PATH := "user://channel-dialogue-test.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count := 5) -> void:
	for _index in count:
		await process_frame

func click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "isolated UI profile")
	var main: Node = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var flow: SceneContainerManager = main.get_node("SceneFlow")
	flow.fade_duration = 0
	for _frame in 600:
		await process_frame
		if not flow._is_loading and main.get_node("SceneContainer").get_child_count():
			break
	await frames()
	var player := get_first_node_in_group("player") as PlayerController
	var dialogue := ChannelDialogue.new()
	main.add_child(dialogue)
	var result := [0]
	var accept := func() -> void: result[0] = 1
	var decline := func() -> void: result[0] = 2
	dialogue.open("异常呼叫 / 是否建立直连", "频道里还有求救信号。\n\n建立直连将关闭本局撤离，需要连续完成三层任务和楼顶接管。\n\n死亡沿用装备损失与黑匣规则，Codex 补给仍保留。", [["建立直连 / 本局无法撤离", accept], ["保持普通行动", decline]], decline)
	await frames()
	check(paused and not player.is_input_enabled(), "radio pauses combat and input")
	check(dialogue._panel.compact and dialogue._panel.size.x == 612, "radio shares compact warehouse geometry")
	check(dialogue._panel.position.y + dialogue._panel.size.y == 350, "radio remains anchored to bottom")
	check(dialogue._pages.size() == 3 and not dialogue._buttons.visible, "long choice explanation paginates before options")
	await click(Vector2(320, 100))
	check(dialogue._page_index == 1 and result[0] == 0 and paused, "background click advances narration without committing")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter, true)
	await frames()
	check(dialogue._buttons.visible and result[0] == 0, "Enter reveals final choices without executing one")
	check(dialogue._buttons.get_child(1).has_focus(), "safe alternative receives focus")
	await click(Vector2(320, 100))
	check(result[0] == 0 and dialogue.visible, "background click cannot accept irreversible choice")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/channel-unified-choice.png")
	await click(dialogue._buttons.get_child(1).get_global_rect().get_center())
	check(result[0] == 2 and not paused and player.is_input_enabled(), "actual option click chooses safe action and resumes")
	dialogue.open("接线员 / 签名有效", "我们取得了频道管理权限。\n\n前往第三层隔离控制回写，再到楼顶解除护罩。", [["返回整备走廊", accept]])
	await frames()
	check(not dialogue._buttons.visible and dialogue._pages.size() == 2, "task feedback uses button-free radio pages")
	await click(Vector2(320, 100))
	check(result[0] == 2 and paused, "first feedback page does not execute return callback")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/channel-unified-feedback.png")
	root.push_input(enter, true)
	await frames()
	check(result[0] == 1 and not paused, "last feedback page executes callback once")
	dialogue.open("第二结局 / 频道归还", "公共路由恢复。\n\n求救信号重新传出。", [["继续", accept]], decline)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await frames()
	check(result[0] == 2 and not paused, "ending escape retains skip callback")
	# Native touch advances one page, ignoring release, extra fingers and its
	# synthesized mouse event. Desktop click and Enter remain covered above.
	dialogue.open("移动通信", "第一段。\n\n第二段。\n\n第三段。", [["继续", accept]])
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(320, 100)
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	await frames()
	check(dialogue._page_index == 1 and paused, "native touch advances channel radio exactly one page")
	touch.pressed = false
	root.push_input(touch, true)
	touch.index = 1
	touch.pressed = true
	root.push_input(touch, true)
	var emulated := InputEventMouseButton.new()
	emulated.position = touch.position
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(emulated, true)
	await frames()
	check(dialogue._page_index == 1 and paused, "touch release, second finger and emulated mouse cannot skip radio pages")
	touch.index = 0
	root.push_input(touch, true)
	await frames()
	check(dialogue._page_index == 2 and paused, "next primary touch reaches final radio page without committing early")
	root.push_input(touch, true)
	await frames()
	check(not dialogue.visible and not paused and result[0] == 1 and player.is_input_enabled(), "last touch completes callback and restores gameplay")
	main.queue_free()
	await frames()
	DirAccess.remove_absolute(TEST_PATH)
	print("Channel dialogue checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
