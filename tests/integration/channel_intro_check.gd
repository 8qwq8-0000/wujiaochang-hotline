extends SceneTree

const TEST_PATH := "user://channel-intro-integration-test.json"
var checks := 0
var failures := 0
var store: Node
var main: Node
var flow: SceneContainerManager


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func wait_warehouse() -> Node:
	for _frame in 600:
		await process_frame
		if not flow._is_loading and flow.get_node(flow.scene_container_path).get_child_count() > 0:
			for _settle in 8:
				await process_frame
			return flow.get_node(flow.scene_container_path).get_child(0)
	return null


func reload_warehouse() -> Node:
	check(flow.request_scene("res://scenes/levels/base/warehouse.tscn"), "warehouse reload accepted")
	return await wait_warehouse()


func run_checks() -> void:
	store = root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "isolated profile created")
	main = load("res://scenes/bootstrap/warehouse_main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	flow = main.get_node("SceneFlow")
	flow.fade_duration = 0
	var warehouse := await wait_warehouse()
	check(not paused and not warehouse.has_node("ChannelHotline"), "no unlock dialogue before first victory")
	var profile: Dictionary = store.get_profile()
	check(store.commit(profile.chest, profile.loadout, "", {"id": "old-original-clear", "personas": [], "semantic_leaks": []}), "legacy original-ending fixture saved")
	warehouse = await reload_warehouse()
	var hotline: Node = warehouse.get_node("ChannelHotline")
	check(warehouse.get_node_or_null("HotlineTerminal") == null, "unlocked warehouse has no standalone phone terminal")
	check(paused and hotline.dialogue.visible, "old completed save receives automatic first notice")
	check(not warehouse.player.is_input_enabled(), "notice blocks player input")
	check(hotline.dialogue.get("_panel") is CyberDialoguePanel and hotline.dialogue.get("_panel").compact, "notice reuses compact bottom radio panel")
	check(not hotline.dialogue.get("_buttons").visible, "bottom radio has no large action buttons")
	check(hotline.dialogue.get("_text").text.contains("有人能听见吗"), "first page delivers short incoming call")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hotline-channel-intro-call.png")
	var advance := InputEventKey.new()
	advance.keycode = KEY_ENTER
	advance.pressed = true
	root.push_input(advance, true)
	await process_frame
	var text: String = hotline.dialogue.get("_text").text
	check(paused and text.contains("第二结局「频道归还」已解锁") and text.contains("第一层"), "second page explains unlock and next destination")
	check(not text.contains("无法撤离"), "commitment details remain at first-floor decision")
	check(not store.has_seen_channel_intro(), "opening alone does not acknowledge notice")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hotline-channel-intro.png")
	store.save_path = "user://channel-intro-missing-directory/save.json"
	hotline.dialogue._choose(hotline.acknowledge_intro)
	check(paused and hotline.dialogue.visible and not store.has_seen_channel_intro(), "failed save leaves modal open for retry")
	check("".join(hotline.dialogue.get("_pages")).contains("请重试"), "failed acknowledgement explains retry")
	store.save_path = TEST_PATH
	while hotline.dialogue.get("_page_index") < hotline.dialogue.get("_pages").size() - 1:
		hotline.dialogue._advance_page()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(320, 310)
	root.push_input(click, true)
	await process_frame
	check(not paused and warehouse.player.is_input_enabled() and store.has_seen_channel_intro(), "acknowledgement saves and resumes gameplay")
	var fresh: Node = load("res://scripts/core/warehouse_store.gd").new()
	fresh.save_path = TEST_PATH
	root.add_child(fresh)
	check(fresh.load_profile() and fresh.has_seen_channel_intro(), "acknowledgement survives fresh disk read")
	fresh.queue_free()
	warehouse = await reload_warehouse()
	check(not paused and not warehouse.get_node("ChannelHotline").dialogue.visible, "warehouse revisits do not repeat acknowledged notice")
	var formal: Dictionary = store.get_profile()
	check(store.begin_test_session(), "test session begins")
	profile = store.get_profile()
	check(store.commit(profile.chest, profile.loadout, "", {}, {"intro_seen": false}), "test-only reset of notice")
	warehouse = await reload_warehouse()
	hotline = warehouse.get_node("ChannelHotline")
	check(paused and hotline.dialogue.visible, "notice can be previewed inside isolated test mode")
	hotline.dialogue._choose(hotline.acknowledge_intro)
	store.end_test_session()
	check(store.get_profile() == formal, "test preview preserves formal story progress")
	profile = store.get_profile()
	check(store.commit(profile.chest, profile.loadout, "", {"id": "second-clear", "ending": "channel_returned", "personas": [], "semantic_leaks": []}, {"intro_seen": false}), "already-completed second-ending fixture")
	warehouse = await reload_warehouse()
	check(not paused and not warehouse.get_node("ChannelHotline").dialogue.visible, "second-ending completion suppresses obsolete unlock notice")
	main.queue_free()
	for _frame in 4:
		await process_frame
	paused = false
	DirAccess.remove_absolute(TEST_PATH)
	print("Channel intro checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
