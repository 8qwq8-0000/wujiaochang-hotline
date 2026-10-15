extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	var movement := player.get_node("AudioSockets/MovementLoop") as AudioStreamPlayer2D

	player.mobility.equip_mode(load("res://resources/mobility/flight.tres"))
	player.velocity = Vector2.RIGHT * 120.0
	player._update_movement_audio()
	check(movement.stream != null, "flight movement selects a loop")
	check(movement.stream.resource_path.ends_with("flight_loop.wav"), "flight uses the flight loop")
	check(movement.playing, "moving with flight starts the loop")

	player.mobility.equip_mode(load("res://resources/mobility/walk.tres"))
	player._update_movement_audio()
	check(movement.stream == null, "walking has no player movement sound")
	check(not movement.playing, "switching to walking stops the flight loop")

	player.queue_free()
	await process_frame
	print("Combat audio failures: ", failures)
	quit(0 if failures == 0 else 1)
