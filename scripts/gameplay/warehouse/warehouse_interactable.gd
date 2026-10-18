extends Area2D

@export_enum("chest", "deploy", "trial", "boss_test") var kind := "chest"
@onready var room: Node2D = get_parent()

func can_interact(actor: Node2D) -> bool:
	return actor == room.player and actor.is_input_enabled() and not get_tree().paused and actor.global_position.distance_to(global_position) <= 64

func interact(actor: Node2D) -> void:
	if not can_interact(actor):
		return
	if kind == "chest":
		room.panel.open()
	elif kind == "trial":
		room.enter_trial()
	elif kind == "boss_test":
		room.enter_boss_test()
	else:
		room.depart()

func _process(_delta: float) -> void:
	var near := is_instance_valid(room.player) and can_interact(room.player)
	$Prompt.visible = near
	queue_redraw()

func _draw() -> void:
	if kind == "chest":
		draw_rect(Rect2(-32, -20, 64, 40), Color("506761"))
		draw_rect(Rect2(-32, -20, 64, 40), Color("a6c0a4"), false, 2)
		draw_line(Vector2(-30, -6), Vector2(30, -6), Color("a6c0a4"), 2)
		draw_rect(Rect2(-4, -10, 8, 14), Color("e3c681"))
	else:
		var color := Color("60513b") if kind == "trial" else Color("385b61")
		if kind == "boss_test":
			color = Color("59405f")
		draw_rect(Rect2(-24, -32, 48, 64), color)
		draw_line(Vector2(-15, 0), Vector2(15, 0), Color("d6d299"), 3)
		draw_line(Vector2(15, 0), Vector2(6, -9), Color("d6d299"), 3)
		draw_line(Vector2(15, 0), Vector2(6, 9), Color("d6d299"), 3)
