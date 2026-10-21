extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var scene: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in 600:
		if get_first_node_in_group("player") != null and not scene.get_node("SceneFlow").get("_is_loading"):
			break
		await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	var vfx := scene.get_node("VFXManager") as VFXManager
	var queue := scene.get_node("CombatHUD/Overlay/NoticeQueue") as CombatNoticeQueue
	check(player != null and vfx != null and queue != null, "main scene exposes player, VFX manager and notice queue")
	if player == null or vfx == null or queue == null:
		quit(1)
		return
	var hud := scene.get_node("CombatHUD")
	check(hud.find_children("*", "TerminalPanel", true, false).is_empty(), "combat removes the four large terminal panels")
	check(hud.find_children("*", "SegmentMeter", true, false).size() == 2, "combat exposes only health and heat instruments")
	check(hud.find_children("*", "HoloCommsPanel", true, false).size() == 1, "AI communications use one collapsible holographic panel")
	check(hud.find_children("CRTOverlay", "CRTOverlay", true, false).is_empty(), "CRT treatment no longer covers the whole combat screen")
	check(hud.get("_pause_button") != null and hud.get("_weapon_preview") != null, "minimal HUD includes pause and current-weapon affordances")
	hud.set_hud_scale(1.5)
	await process_frame
	var viewport_rect := (hud.get("overlay") as Control).get_global_rect()
	check(viewport_rect.encloses((hud.get("_pause_button") as Button).get_global_rect()), "150 percent pause control stays inside the viewport")
	check(viewport_rect.encloses((hud.get("_weapon_preview") as TextureRect).get_global_rect()), "150 percent weapon preview stays inside the viewport")
	hud.set_hud_scale(1.0)
	var queue_rect := queue.get_global_rect()
	check(queue_rect.end.y <= 360.0, "combat notices remain inside the 640 by 360 viewport")
	check(not queue.visible and queue.get_visible_notices().is_empty(), "legacy notice queue stays non-rendering")

	check((vfx.get("_active_numbers") as Array).is_empty(), "damage-number pool stays unused in the minimal presentation")

	scene.queue_free()
	await process_frame
	print("Presentation systems failures: ", failures)
	quit(0 if failures == 0 else 1)
