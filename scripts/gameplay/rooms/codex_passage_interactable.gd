extends Area2D

@export_enum("codex", "exit", "storage") var action := "codex"
@onready var room: Node2D = get_parent()

func can_interact(actor: Node2D) -> bool:
	return actor == room.player and actor.is_input_enabled() and not get_tree().paused and not room.departing and actor.global_position.distance_to(global_position) <= 68.0

func interact(actor: Node2D) -> void:
	if not can_interact(actor):
		return
	if action == "codex":
		room.talk_to_codex()
	elif action == "storage":
		room.safe_storage.open()
	else:
		room.depart()

func _process(_delta: float) -> void:
	$Prompt.visible = is_instance_valid(room.player) and can_interact(room.player)
