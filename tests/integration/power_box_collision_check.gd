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

func settle() -> void:
	await physics_frame
	await physics_frame

func run_checks() -> void:
	var room := TestRoom.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var box: PowerBox = load("res://scenes/environment/power_box.tscn").instantiate()
	box.position = Vector2(320, 180)
	room.add_child(box)
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	var target := box.global_position + Vector2(0, 12)
	for claimed in [false, true]:
		if claimed:
			player.global_position = box.global_position + Vector2(40, 0)
			await settle()
			box.interact(player)
			check(box.state == PowerBox.State.CLAIMED, "solid station still grants its buff")
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for dashing in [false, true]:
				player.global_position = target - direction * 60
				player.velocity = Vector2.ZERO
				player.dash.reset_transient_state()
				await settle()
				if dashing:
					player.dash.start_dash(player, direction, direction)
				for frame in 40:
					await physics_frame
					if dashing:
						player.dash.tick(player, direction, direction, 1.0 / 60.0)
					else:
						player.velocity = direction * 180
						player.move_and_slide()
				check((player.global_position - target).dot(direction) < -3, "station blocks %s from %s after_claim=%s" % ["dash" if dashing else "walking", direction, claimed])
	player.dash.reset_transient_state()
	room.queue_free()
	await process_frame
	print("Power-box collision checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
