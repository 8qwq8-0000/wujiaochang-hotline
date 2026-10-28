extends Area2D

var action := "codex"


func can_interact(actor: Node2D) -> bool:
	return actor == get_parent().player and actor.is_input_enabled() and not get_tree().paused and actor.global_position.distance_to(global_position) <= 62.0


func interact(actor: Node2D) -> void:
	if can_interact(actor):
		get_parent().use_service(action)
