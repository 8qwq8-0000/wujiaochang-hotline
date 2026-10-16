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
	check(hud.find_children("*", "TerminalPanel", true, false).size() >= 4, "main game uses the cyber terminal HUD panels")
	check(hud.find_children("*", "SegmentMeter", true, false).size() >= 3, "main game uses live segmented instruments")
	check(hud.find_children("CRTOverlay", "CRTOverlay", true, false).size() == 1, "main game applies one shared CRT overlay")
	var queue_rect := queue.get_global_rect()
	check(queue_rect.end.y <= 360.0, "combat notices remain inside the 640 by 360 viewport")
	check(queue_rect.size.x <= 190.0 and queue_rect.size.y <= 108.0, "combat notices use the compact non-obstructive layout")
	var terminal_panels := hud.find_children("*", "TerminalPanel", true, false)
	check(terminal_panels.all(func(panel: TerminalPanel) -> bool: return panel.size.x <= 175.0 and panel.panel_color.a <= 0.681), "combat panels stay compact and translucent")

	# New notices can arrive while paused, while their lifetime remains frozen.
	root.get_node("CombatEvents").publish_notice(&"pause_a", "暂停前", Color.WHITE, CombatNotice.Priority.NORMAL, 0.0, 0.15)
	paused = true
	root.get_node("CombatEvents").publish_notice(&"pause_b", "暂停中", Color.WHITE, CombatNotice.Priority.HIGH, 0.0, 0.15)
	await create_timer(0.25, true).timeout
	check(queue.get_visible_notices().size() == 2, "pause freezes notice lifetime but accepts new inventory-time messages")
	paused = false
	await create_timer(0.3).timeout
	check(queue.get_visible_notices().is_empty(), "notices resume expiry after pause closes")

	# Walking emits nothing; an active mobility ability emits pooled body-only images.
	player.set_physics_process(false)
	player.unequip_mobility()
	player._tick_afterimages(0.1)
	check((vfx.get("_active_afterimages") as Array).is_empty(), "walking without a mobility kit emits no afterimage")
	player.equip_mobility(load("res://resources/mobility/wheel.tres"))
	check(player.mobility.activate_ability(player, Vector2.RIGHT), "wheel ability activates")
	for _index in 12:
		player._tick_afterimages(0.05)
	var active := vfx.get("_active_afterimages") as Array
	check(active.size() > 0 and active.size() <= vfx.afterimage_budget, "active mobility emits afterimages without exceeding the six-item pool")
	player.unequip_mobility()
	var count_after_switch := active.size()
	player._tick_afterimages(0.2)
	check((vfx.get("_active_afterimages") as Array).size() == count_after_switch, "switching to walking stops new emission without abruptly deleting existing images")
	root.get_node("CombatEvents").clear_afterimages(player)
	check((vfx.get("_active_afterimages") as Array).is_empty(), "death/restart/scene cleanup can clear all images for one source")

	scene.queue_free()
	await process_frame
	print("Presentation systems failures: ", failures)
	quit(0 if failures == 0 else 1)
