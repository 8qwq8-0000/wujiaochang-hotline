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
	var rack := room.get_node("PartsRack") as Node2D
	check(chest.position.x > rack.position.x and is_equal_approx(chest.position.y, rack.position.y), "chest sits along the north wall to the right of the parts rack")
	check(room.get_node("Chest/Art").global_position == room.get_node("Chest/Shape").global_position, "interaction area follows the moved chest artwork")
	player.position = chest.position + Vector2(0, 38)
	await physics_frame
	var front := player.move_and_collide(Vector2(0, -80))
	check(front != null and front.get_collider() == chest_body, "approaching from front stops at chest base")
	check(player.position.y >= chest.position.y + 9.9, "front player stays outside solid base and draws in front")
	player.position = chest.position + Vector2(58, -6)
	await physics_frame
	var side := player.move_and_collide(Vector2(-100, 0))
	check(side != null and side.get_collider() == chest_body, "chest cannot be crossed from the side")
	player.position = Vector2(330, 112)
	await physics_frame
	var crossing := player.move_and_collide(Vector2(-180, 0))
	check(crossing == null and player.position.x <= 150, "walks right to left in front of rack and chest")
	crossing = player.move_and_collide(Vector2(180, 0))
	check(crossing == null and player.position.x >= 330, "walks left to right in front of rack and chest")
	# Every warehouse prop has a solid floor footprint, including interactable art.
	var cases := [
		["PartsRack", Vector2(194, 114), Vector2(0, -60)],
		["SynthesisNPC/Workbench", Vector2(92, 114), Vector2(0, -60)],
		["SynthesisNPC", Vector2(110, 164), Vector2(0, -60)],
		["ArchiveTerminal", Vector2(61, 248), Vector2(0, -60)],
		["CratesLeft", Vector2(190, 222), Vector2(0, 60)],
		["CratesRight", Vector2(407, 222), Vector2(0, 60)],
		["ParryTraining", Vector2(418, 122), Vector2(0, -60)],
		["Deploy", Vector2(392, 162), Vector2(80, 0)],
	]
	for entry in cases:
		player.position = entry[1]
		await physics_frame
		var impact := player.move_and_collide(entry[2])
		check(impact != null and impact.get_collider() == room.get_node(entry[0] + "/Body"), "%s blocks entry into its floor footprint" % entry[0])
		if room.get_node(entry[0]) is Area2D:
			check(room.get_node(entry[0]).can_interact(player), "%s is usable without walking into solid artwork" % entry[0])
	for boundary in [[Vector2(420, 110), Vector2(80, 0), "Right"], [Vector2(280, 225), Vector2(0, 80), "Bottom"]]:
		player.position = boundary[0]
		await physics_frame
		var wall_hit := player.move_and_collide(boundary[1])
		check(wall_hit != null and wall_hit.get_collider() == room.get_node("Walls"), "%s boundary blocks movement" % boundary[2])
		check(player.position.x < 444.0 and player.position.y < 252.0, "player remains inside compact room")
	var aisles := [
		[Vector2(142, 112), Vector2(-90, 0), "workbench-synthesist gap"],
		[Vector2(244, 112), Vector2(-102, 0), "rack and chest front aisle"],
		[Vector2(44, 248), Vector2(80, 0), "terminal-front aisle"],
		[Vector2(250, 110), Vector2(130, 0), "north-door approach aisle"],
		[Vector2(370, 118), Vector2(0, 120), "east-elevator approach aisle"],
	]
	for aisle in aisles:
		player.position = aisle[0]
		await physics_frame
		check(player.move_and_collide(aisle[1]) == null, "%s is traversable forward" % aisle[2])
		check(player.move_and_collide(-aisle[1]) == null, "%s is traversable backward" % aisle[2])
	check(room.get_node("SynthesisNPC").y_sort_enabled, "workbench and synthesist sort independently")
	for entry in [["PartsRack", 92.0], ["CratesLeft", 252.0], ["CratesRight", 252.0], ["ArchiveTerminal", 237.0], ["ParryTraining", 92.0], ["Deploy", 200.0], ["SynthesisNPC/Workbench", 92.0], ["SynthesisNPC/RefinedArt", 140.0]]:
		check(is_equal_approx(room.get_node(entry[0]).global_position.y, entry[1]), "%s sorts at floor anchor" % entry[0])
	player.position = chest.position + Vector2(0, 24)
	await physics_frame
	check(chest.can_interact(player), "chest remains usable from front")
	check(player.interactor.get_best_target(player) == chest, "E detector still selects chest at front")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		for entry in [[chest.position + Vector2(0, 24), "front"], [Vector2(194, 103), "rack_front"], [Vector2(92, 103), "workbench_front"], [Vector2(110, 151), "synthesist_front"], [Vector2(61, 248), "terminal_front"], [Vector2(190, 239), "crates_behind"], [Vector2(418, 103), "door_front"], [Vector2(412, 162), "elevator_front"]]:
			player.position = entry[0]
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/warehouse_chest_%s.png" % entry[1])
	room.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("Warehouse collision checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
