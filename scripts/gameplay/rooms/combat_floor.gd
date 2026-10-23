extends Node2D


func _ready() -> void:
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null and run_manager.run_seed == 0:
		run_manager.begin_run()
	var player := get_node_or_null("Player") as PlayerController
	if run_manager != null and is_instance_valid(player):
		player.import_run_state(run_manager.get_player_state())
	y_sort_enabled = true
	var backdrop := Node2D.new()
	backdrop.name = "CombatBackdrop"
	backdrop.z_index = -10
	add_child(backdrop)
	backdrop.draw.connect(_draw_background.bind(backdrop))
	backdrop.queue_redraw()


func receive_scene_payload(payload: Dictionary) -> void:
	var player := get_node_or_null("Player") as PlayerController
	if not is_instance_valid(player):
		return
	if payload.has("player_state") and payload["player_state"] is Dictionary:
		player.import_run_state(payload["player_state"])
	if payload.has("transit_heat"):
		player.heat.set_heat(float(payload.transit_heat.get("current", 0.0)))
		player.heat.is_overheated = bool(payload.transit_heat.get("overheated", false))


func _draw_background(canvas: Node2D) -> void:
	var assembler := get_node_or_null("FloorAssembler") as FloorAssembler
	var count := assembler.room_count if assembler != null else 1
	var spacing := assembler.room_spacing.x if assembler != null else CombatRoom.ROOM_SIZE.x
	var floor_size := Vector2(CombatRoom.ROOM_SIZE.x + spacing * maxi(count - 1, 0), CombatRoom.ROOM_SIZE.y)
	canvas.draw_rect(Rect2(Vector2.ZERO, floor_size), Color("101722"), true)
	for x in range(0, int(floor_size.x) + 1, 32):
		canvas.draw_line(Vector2(x, 0), Vector2(x, floor_size.y), Color(0.14, 0.2, 0.28, 0.35), 1.0)
	for y in range(0, int(floor_size.y) + 1, 32):
		canvas.draw_line(Vector2(0, y), Vector2(floor_size.x, y), Color(0.14, 0.2, 0.28, 0.35), 1.0)
