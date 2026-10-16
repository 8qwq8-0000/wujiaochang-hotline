extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var showcase: CyberUIShowcase = load("res://scenes/ui/showcase/cyber_ui_showcase.tscn").instantiate()
	root.add_child(showcase)
	await process_frame
	var descendants := showcase.find_children("*", "", true, false)
	var panel_count := descendants.filter(func(node: Node) -> bool: return node is TerminalPanel).size()
	var meter_count := descendants.filter(func(node: Node) -> bool: return node is SegmentMeter).size()
	var notice_count := descendants.filter(func(node: Node) -> bool: return node is TerminalNotice).size()
	check(showcase.get_workspace_name() == &"combat", "showcase opens on the combat operation panel")
	check(panel_count >= 9, "showcase composes the reusable terminal panels")
	check(meter_count >= 6, "showcase demonstrates segmented combat instruments")
	check(notice_count == 3, "showcase demonstrates the three-message budget")
	showcase.show_workspace(CyberUIShowcase.Workspace.SETTINGS)
	check(showcase.get_workspace_name() == &"settings", "showcase includes the shared settings workspace")
	var initial_strength := showcase.get_crt_strength()
	showcase.cycle_crt_strength()
	check(showcase.get_crt_strength() != initial_strength, "CRT accessibility level can be changed")
	showcase.trigger_demo_glitch()
	var overlay := showcase.get_node("CRTOverlay") as CRTOverlay
	check(float(overlay.get("_glitch_remaining")) > 0.0, "event glitch can be previewed without affecting gameplay")
	showcase.queue_free()
	await process_frame
	print("Cyber UI showcase failures: ", failures)
	quit(0 if failures == 0 else 1)
