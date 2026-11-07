extends SceneTree

const OUTPUT := "res://docs/art/validation/ui_graphite_amber_v4/"


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var world := Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	var backdrop := CanvasLayer.new()
	backdrop.layer = -10
	world.add_child(backdrop)
	var room := TextureRect.new()
	room.texture = load("res://docs/art/validation/combat_architecture_v1/loading_workshop.png")
	room.size = Vector2(640, 360)
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.add_child(room)
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(player)
	var hud := load("res://scenes/ui/combat_hud.tscn").instantiate() as CanvasLayer
	world.add_child(hud)
	await process_frame
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await process_frame
	var ids := PackedStringArray(["active_neural_switch", "smart_fire", "explosive_magazine", "tactical_coprocessor"])
	var counts := {"active_neural_switch": 1, "smart_fire": 1, "explosive_magazine": 1, "tactical_coprocessor": 1}
	player.cyberware.set_circuit_library_counts(counts)
	player.cyberware.set_circuit_slots(ids)
	player.health.set_current_health(2)
	player.heat.set_heat(player.heat.effective_max() * 0.6)
	await _save("runtime_combat_card_a_1280_720.png")
	hud._show_circuit_tooltip(0)
	await _save("runtime_circuit_tooltip_1280_720.png")
	hud._hide_circuit_tooltip()
	var menu := load("res://scenes/ui/pause_settings_menu.tscn").instantiate() as PauseSettingsMenu
	world.add_child(menu)
	menu.open_settings_only()
	await _save("runtime_settings_card_a_1280_720.png")
	menu.close_menu()
	var editor := hud.get_circuit_editor() as CyberwareCircuitPanel
	editor.set_open(true)
	await _save("runtime_circuit_editor_card_a_1280_720.png")
	editor.set_open(false)
	editor.select_slot(1)
	editor.remove_selected()
	for frame in 8:
		hud._advance_circuit_reflow(1.0 / 60.0)
	await _save("runtime_circuit_reflow_card_a_1280_720.png")
	quit()


func _save(filename: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + filename)
