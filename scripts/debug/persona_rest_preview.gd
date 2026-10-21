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
		await get_tree().create_timer(1.0, true).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://art_sources/ai_drafts/ai_personalities/v1/persona_rest_ui_preview.png")
		get_tree().quit()
