extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var menu: PauseSettingsMenu = load("res://scenes/ui/pause_settings_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(not menu.visible, "pause menu starts hidden")
	menu.open_menu()
	check(menu.visible and paused, "pause menu owns and pauses the scene tree")
	check(menu.get("_resolution").item_count == 4, "settings expose the four confirmed resolutions")
	check(menu.find_children("*", "HSlider", true, false).size() == 4, "settings expose Master, Music, SFX and combat-cue sliders")
	check(menu.get("_mute") != null, "settings expose global mute")
	check(menu.get("_continuous_precharge") != null, "AI test switch remains available")
	check(menu.get("_hud_scale") != null and (menu.get("_hud_scale") as OptionButton).item_count == 3, "settings expose 100, 125 and 150 percent HUD scales")
	check(menu.get("_reduced_flashes") != null, "settings expose reduced-flashes accessibility toggle")
	check(menu.get("_feedback_quality") != null and (menu.get("_feedback_quality") as OptionButton).item_count == 2, "settings expose low and standard combat effect quality")
	menu._show_settings_page()
	await process_frame
	var settings_page := menu.get("_settings_page") as VBoxContainer
	var scroll_nodes := settings_page.find_children("*", "ScrollContainer", true, false)
	var settings_scroll := scroll_nodes[0] as ScrollContainer if not scroll_nodes.is_empty() else null
	check(settings_page.size.y > 200.0 and settings_scroll != null and settings_scroll.size.y > 100.0, "settings page receives usable height instead of clipping its options")
	check(menu.get("_resolution").is_visible_in_tree(), "resolution control is actually visible after opening settings")
	check((menu.get("_crt_strength") as OptionButton).item_count == 3, "settings expose Off, Low and Standard CRT levels")
	menu._show_history_page()
	await process_frame
	check((menu.get("_history_page") as VBoxContainer).visible, "pause menu exposes the recent communication page")
	check((menu.get("_history_label") as Label).text == "暂无通讯记录", "communication history has a clear empty state")
	menu._show_settings_page()
	for button in menu.find_children("*", "CheckButton", true, false):
		check(button.text != "高压难度", "pause menu no longer changes save difficulty")
	var game_settings := root.get_node("GameSettings")
	game_settings.set_high_pressure_alert(true, false)
	menu._on_continuous_precharge_toggled(true)
	check(game_settings.high_pressure_alert and game_settings.continuous_precharge, "AI test switch preserves saved difficulty")
	game_settings.set_high_pressure_alert(false, false)
	game_settings.set_continuous_precharge(false, false)
	menu.close_menu()
	check(not menu.visible and not paused, "continue closes the menu and resumes play")
	menu.queue_free()
	await process_frame
	print("Settings menu failures: ", failures)
	quit(0 if failures == 0 else 1)
