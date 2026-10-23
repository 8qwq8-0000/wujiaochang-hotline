extends SceneTree
class TestRoom extends Node2D:
	signal room_cleared
	var cleared := false
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var room := TestRoom.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var box: PowerBox = load("res://scenes/environment/power_box.tscn").instantiate()
	box.position = Vector2(320,180)
	room.add_child(box)
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = box.position + Vector2(40,0)
	room.add_child(player)
	player.set_physics_process(false)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(260,12)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	wall.add_child(collider)
	room.add_child(wall)
	for state in [PowerBox.State.READY, PowerBox.State.CLAIMED]:
		box.state = state
		for wall_y in [220,130]:
			wall.position = Vector2(320,wall_y)
			await physics_frame
			await physics_frame
			box._process(0)
			var bounds := Rect2(wall.position - shape.size * 0.5, shape.size)
			check(box.prompt.visible and not box.prompt.get_global_rect().intersects(bounds), "ready and claimed prompts avoid a nearby wall")
			check(box.prompt.position.y < 0 if wall_y == 220 else box.prompt.position.y > 0, "prompt changes side when the upper position is obstructed")
	check(not box.prompt.z_as_relative and box.prompt.z_index > 0, "walls cannot obscure the text layer")
	room.queue_free()
	await process_frame
	print("Power-box prompt checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
