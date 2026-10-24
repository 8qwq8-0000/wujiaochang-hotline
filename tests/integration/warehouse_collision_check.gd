extends SceneTree

const SAVE_PATH := "user://warehouse-collision-check.json"
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
	root.get_node("WarehouseStore").save_path = SAVE_PATH
	DirAccess.remove_absolute(SAVE_PATH)
	var room := load("res://scenes/levels/base/warehouse.tscn").instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	var player: PlayerController = room.player
	player.set_physics_process(false)
	await physics_frame
	var chest := room.get_node("Chest") as Node2D
	var chest_body := room.get_node("Chest/Body")
	check(room.y_sort_enabled, "warehouse sorts actors and props by floor position")
	check(chest.global_position.y == 136, "chest sorting origin sits at bottom of artwork")
	check(room.get_node("Chest/Art").global_position == Vector2(193, 120), "chest artwork remains at original placement")
	check(room.get_node("Chest/Shape").global_position == Vector2(193, 120), "interaction area remains aligned with original chest")
	player.position = Vector2(193, 170)
	await physics_frame
	var front := player.move_and_collide(Vector2(0, -80))
	check(front != null and front.get_collider() == chest_body, "approaching from front stops at chest base")
	check(player.position.y >= 145.9 and player.position.y > chest.position.y, "front player stays outside solid base and draws in front")
	player.position = Vector2(193, 112)
	await physics_frame
	var back := player.move_and_collide(Vector2(0, 60))
	check(back != null and back.get_collider() == chest_body, "approaching from behind stops at chest base")
	check(player.position.y <= 124.1 and player.position.y < chest.position.y, "rear player remains behind chest sorting origin")
	player.position = Vector2(145, 130)
	await physics_frame
	var side := player.move_and_collide(Vector2(100, 0))
	check(side != null and side.get_collider() == chest_body, "chest cannot be crossed from the side")
	player.position = Vector2(244, 112)
	await physics_frame
	var crossing := player.move_and_collide(Vector2(-102, 0))
	check(crossing == null and player.position.x < 143, "walks right to left through rack-chest corridor")
	crossing = player.move_and_collide(Vector2(102, 0))
	check(crossing == null and player.position.x > 243, "walks left to right through rack-chest corridor")
	# Every warehouse prop has a solid floor footprint, including interactable art.
	var cases := [
		["PartsRack", Vector2(194, 114), Vector2(0, -60)],
		["SynthesisNPC/Workbench", Vector2(92, 114), Vector2(0, -60)],
		["SynthesisNPC", Vector2(110, 164), Vector2(0, -60)],
		["ArchiveTerminal", Vector2(61, 312), Vector2(0, -60)],
		["CratesLeft", Vector2(190, 286), Vector2(0, 60)],
		["CratesRight", Vector2(567, 286), Vector2(0, 60)],
		["ParryTraining", Vector2(288, 122), Vector2(0, -60)],
		["Trial", Vector2(386, 122), Vector2(0, -60)],
		["BossTest", Vector2(485, 122), Vector2(0, -60)],
		["Deploy", Vector2(552, 194), Vector2(80, 0)],
	]
	for entry in cases:
		player.position = entry[1]
		await physics_frame
		var impact := player.move_and_collide(entry[2])
		check(impact != null and impact.get_collider() == room.get_node(entry[0] + "/Body"), "%s blocks entry into its floor footprint" % entry[0])
		if room.get_node(entry[0]) is Area2D:
			check(room.get_node(entry[0]).can_interact(player), "%s is usable without walking into solid artwork" % entry[0])
	var aisles := [
		[Vector2(142, 112), Vector2(-90, 0), "workbench-synthesist gap"],
		[Vector2(244, 112), Vector2(-102, 0), "rack-chest gap"],
		[Vector2(44, 312), Vector2(80, 0), "terminal-front aisle"],
		[Vector2(250, 110), Vector2(290, 0), "north-door approach aisle"],
		[Vector2(530, 150), Vector2(0, 120), "east-elevator approach aisle"],
	]
	for aisle in aisles:
		player.position = aisle[0]
		await physics_frame
		check(player.move_and_collide(aisle[1]) == null, "%s is traversable forward" % aisle[2])
		check(player.move_and_collide(-aisle[1]) == null, "%s is traversable backward" % aisle[2])
	check(room.get_node("SynthesisNPC").y_sort_enabled, "workbench and synthesist sort independently")
	for entry in [["PartsRack", 92.0], ["CratesLeft", 316.0], ["CratesRight", 316.0], ["ArchiveTerminal", 301.0], ["ParryTraining", 92.0], ["Trial", 92.0], ["BossTest", 92.0], ["Deploy", 232.0], ["SynthesisNPC/Workbench", 92.0], ["SynthesisNPC/RefinedArt", 140.0]]:
		check(is_equal_approx(room.get_node(entry[0]).global_position.y, entry[1]), "%s sorts at floor anchor" % entry[0])
	player.position = Vector2(193, 148)
	await physics_frame
	check(chest.can_interact(player), "chest remains usable from front")
	check(player.interactor.get_best_target(player) == chest, "E detector still selects chest at front")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		for entry in [[Vector2(193, 148), "front"], [Vector2(193, 112), "behind"], [Vector2(194, 103), "rack_front"], [Vector2(92, 103), "workbench_front"], [Vector2(110, 151), "synthesist_front"], [Vector2(61, 312), "terminal_front"], [Vector2(190, 303), "crates_behind"], [Vector2(288, 103), "door_front"], [Vector2(572, 194), "elevator_front"]]:
			player.position = entry[0]
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/warehouse_chest_%s.png" % entry[1])
	room.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("Warehouse collision checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
