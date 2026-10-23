extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var room := Node2D.new()
	root.add_child(room)
	current_scene = room
	for filename in RefinedEnvironmentArt.REGIONS:
		var source: Texture2D = load(RefinedEnvironmentArt.ROOT + filename)
		var texture := RefinedEnvironmentArt.art_texture(filename) as AtlasTexture
		check(source.get_image().detect_alpha() != Image.ALPHA_NONE, filename + " has real transparency")
		check(texture.region == RefinedEnvironmentArt.REGIONS[filename] and Rect2(Vector2.ZERO, source.get_size()).encloses(texture.region), filename + " has valid silhouette bounds")
	var power: PowerBox = load("res://scenes/environment/power_box.tscn").instantiate()
	room.add_child(power)
	power.set_process(false)
	var art := power.get_node("RefinedArt")
	check(power.self_modulate.a == 0.0 and art.self_modulate.a == 1.0 and power.prompt.self_modulate.a == 1.0, "hide legacy body while retaining art and interaction prompt")
	power.state = PowerBox.State.CLAIMED
	art._process(0.0)
	check(art.get("_state") == 1, "claimed power state updates art")
	power.state = PowerBox.State.BROKEN
	art._process(0.0)
	check(art.get("_state") == 2, "broken power state updates art")
	var barrel: FuelBarrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate()
	room.add_child(barrel)
	barrel.broken = true
	barrel.get_node("RefinedArt")._process(0.0)
	check(barrel.get_node("RefinedArt").get("_state") == 1, "exploded crate hides intact sprite state")
	var door: AutomaticDoor = load("res://scenes/environment/automatic_door.tscn").instantiate()
	room.add_child(door)
	door.opened = true
	door.get_node("RefinedArt")._process(0.0)
	check(door.get_node("RefinedArt").get("_state") == 1, "sliding door swaps open art")
	door.hinged_visual = true
	door.set("_swing", PI / 2)
	door.get_node("RefinedArt")._process(0.0)
	check(is_equal_approx(door.get_node("RefinedArt").get("_pose"), PI / 2), "hinged door art follows actual swing angle")
	var exit := ExitElevator.new()
	room.add_child(exit)
	exit.set_enabled(true)
	check(exit.get_node("DoorArt").modulate == Color.WHITE and exit.get_node("DoorSigil").texture.resource_path.ends_with("deploy_complete.png"), "unlocked exit uses illuminated warehouse door and orange sigil")
	exit.set_enabled(false)
	check(exit.get_node("DoorArt").modulate.r < 1.0 and not exit.can_interact(power), "locked exit dims warehouse door and prevents interaction")
	room.queue_free()
	await process_frame
	print("Refined art checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
