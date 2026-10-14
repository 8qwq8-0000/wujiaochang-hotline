extends Node2D


func _ready() -> void:
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null and run_manager.run_seed == 0:
		run_manager.begin_run()
	var player := get_node_or_null("Player") as PlayerController
	if run_manager != null and is_instance_valid(player):
		player.import_run_state(run_manager.get_player_state())
	queue_redraw()


func receive_scene_payload(payload: Dictionary) -> void:
	var player := get_node_or_null("Player") as PlayerController
	if not is_instance_valid(player):
		return
	if payload.has("player_state") and payload["player_state"] is Dictionary:
		player.import_run_state(payload["player_state"])


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color("101722"), true)
	for x in range(0, 641, 32):
		draw_line(Vector2(x, 0), Vector2(x, 360), Color(0.14, 0.2, 0.28, 0.35), 1.0)
	for y in range(0, 361, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.14, 0.2, 0.28, 0.35), 1.0)
