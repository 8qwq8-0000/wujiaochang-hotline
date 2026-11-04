extends SceneTree

## Launch the actual second floor with its full HUD, scene flow and test tools.
## Inventory/save writes remain in the existing memory-only test session.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	await process_frame
	var settings := root.get_node("GameSettings")
	var tools: CanvasLayer = settings.test_tools
	if not tools.set_enabled(true):
		push_error("Cannot start memory-only herald playtest")
		quit(1)
		return
	var manager := root.get_node("RunManager")
	manager.begin_run(102902)
	manager.floor_index = 1
	manager.persistent_run = true
	manager.persona_authorization_floor = 1
	manager.persona_authorization_pending = false
	manager.persona_rest_refilled_floor = 1
	var packed := load("res://scenes/bootstrap/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main
	var flow := main.get_node("SceneFlow") as SceneContainerManager
	await flow.scene_swapped
	for frame in 120:
		await process_frame
		if not flow._is_loading and not get_nodes_in_group("signal_emitters").is_empty():
			break
	var sources := get_nodes_in_group("signal_emitters")
	var boosted := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy is EnemyController and enemy.has_signal_boost():
			boosted += 1
	if sources.size() != 1 or boosted == 0:
		push_error("Herald playtest did not spawn the expected active encounter")
		quit(1)
		return
	print("Herald live floor ready: floor=2, active sources=", sources.size(), ", boosted enemies=", boosted)
	if DisplayServer.get_name() == "headless":
		quit()
		return
	# Keep combat paused until the user closes the existing F8 test panel.
	tools.open_panel()
	tools.get("_message").text = "第二层传令兵试玩已就绪。F8 关闭面板开始；可自由领取装备或跳转楼层。测试数据不写入正式存档。"
