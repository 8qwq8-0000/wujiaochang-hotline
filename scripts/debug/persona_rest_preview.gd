extends Node

const MAIN := preload("res://scenes/bootstrap/main.tscn")
const OUTPUT := "res://docs/art/validation/persona_os_card_v1/"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	var run := get_node("/root/RunManager")
	run.begin_run(20261021)
	run.persistent_run = true
	var main := MAIN.instantiate()
	add_child(main)
	main.get_node("SceneFlow").fade_duration = 0.0
	if "--capture-preview" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(OUTPUT)
		var rest: PersonaRestFlow = main.get_node("PersonaRestFlow")
		for _frame in 600:
			await get_tree().process_frame
			if rest.is_open:
				break
		rest.choose_persona(TalentCoreController.DEEP_NINJA)
		await get_tree().create_timer(0.1, true).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png(OUTPUT + "runtime_persona_rest_1920_1080.png")
		var talent_buttons: Array[Node] = rest.get("_talent_column").find_children("*", "Button", true, false)
		await rest._show_talent_tooltip(talent_buttons[-1], &"ceaseless_hunt", 3, true)
		await get_tree().create_timer(0.1, true).timeout
		image = get_viewport().get_texture().get_image()
		image.save_png(OUTPUT + "runtime_persona_rest_tooltip_1920_1080.png")
		get_tree().quit()
