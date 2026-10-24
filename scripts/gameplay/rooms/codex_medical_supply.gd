extends Area2D

@onready var room: Node2D = get_parent().get_parent()
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	if run.codex_medical_supply_used:
		queue_free()
	queue_redraw()


func can_interact(actor: Node2D) -> bool:
	return actor == room.player and actor.is_input_enabled() and not get_tree().paused and not room.departing and not actor.health.is_dead() and not run.codex_medical_supply_used and actor.global_position.distance_to(global_position) <= 56.0


func interact(actor: Node2D) -> void:
	if not can_interact(actor):
		return
	if actor.health.repair(1) == 0:
		room.get_node("Status").text = "耐久已满，小血瓶留在货箱上。"
		return
	run.codex_medical_supply_used = true
	run.set_player_state(actor.export_run_state())
	room.get_node("Status").text = "已使用小血瓶 · 恢复 1 格耐久"
	hide()
	queue_free()


func _process(_delta: float) -> void:
	$Prompt.visible = is_instance_valid(room.player) and can_interact(room.player)


func _draw() -> void:
	# A small glass vial drawn in logical pixels, resting on the green supply crate.
	draw_rect(Rect2(-5, -10, 10, 13), Color("0a171c"))
	draw_rect(Rect2(-3, -14, 6, 4), Color("a3bab4"))
	draw_rect(Rect2(-4, -10, 8, 12), Color("9dbeb5"))
	draw_rect(Rect2(-3, -6, 6, 7), Color("d84153"))
	draw_rect(Rect2(-3, -9, 1, 6), Color("e5fff0"))
	draw_rect(Rect2(-1, -5, 2, 5), Color("fff1e5"))
	draw_rect(Rect2(-2, -4, 4, 2), Color("fff1e5"))
