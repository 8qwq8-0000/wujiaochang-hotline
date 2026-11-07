extends SceneTree

func _initialize() -> void:
	call_deferred("start_preview")

func start_preview() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = "user://f8-test-tools-preview-%d.json" % OS.get_process_id()
	if not store.create_new_profile():
		push_error("Cannot create isolated test-tools preview")
		quit(1)
		return
	var menu: Node = load("res://scenes/ui/start_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var tools: CanvasLayer = root.get_node("GameSettings").test_tools
	if not tools.set_enabled(true):
		quit(1)
		return
	tools.open_panel()
	DisplayServer.window_set_title("五角场热线 · F8 测试工具体验（独立存档）")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hotline-f8-test-panel.png")
	print("F8 test tools ready; F8 or Esc hides panel without leaving the current game.")
