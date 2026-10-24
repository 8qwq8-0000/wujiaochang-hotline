extends Node

const MAIN := preload("res://scenes/bootstrap/main.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var run := get_node("/root/RunManager")
	run.begin_run(20261021)
	run.persistent_run = true
	var main := MAIN.instantiate()
	add_child(main)
	main.get_node("SceneFlow").fade_duration = 0.0
	if "--capture-preview" in OS.get_cmdline_user_args():
		var rest: PersonaRestFlow = main.get_node("PersonaRestFlow")
		for _frame in 600:
			await get_tree().process_frame
			if rest.is_open:
				break
		rest.choose_persona(TalentCoreController.DEEP_NINJA)
		await get_tree().create_timer(0.1, true).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://art_sources/ai_drafts/ai_personalities/v1/persona_rest_ui_preview.png")
		var talent_buttons: Array[Node] = rest.get("_talent_column").find_children("*", "Button", true, false)
		await rest._show_talent_tooltip(talent_buttons[-1], &"ceaseless_hunt", 3, true)
		await get_tree().create_timer(0.1, true).timeout
		image = get_viewport().get_texture().get_image()
		image.save_png("res://art_sources/ai_drafts/ai_personalities/v1/persona_rest_ui_tooltip_preview.png")
		get_tree().quit()
