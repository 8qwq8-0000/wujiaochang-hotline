extends SceneTree

const SAVE_PATH := "user://warehouse-layout-check.json"
const SCENE_PATH := "user://warehouse-layout-roundtrip.tscn"
const MOVABLE := {
	"Chest": ["Art", "Body/Shape", "Shape"],
	"Deploy": ["Art", "Shape", "DoorSigil"],
	"Trial": ["Art", "Shape", "DoorSigil"],
	"BossTest": ["Art", "Shape", "DoorSigil"],
	"ParryTraining": ["Art", "Shape", "DoorSigil"],
	"ArchiveTerminal": ["Art", "Shape"],
	"SynthesisNPC": ["RefinedArt", "Workbench/Art", "Workbench/Body/Shape", "Shape"],
	"PartsRack": ["Art", "Body/Shape"],
	"CratesLeft": ["Art", "Body/Shape"],
	"CratesRight": ["Art", "Body/Shape"],
}
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
	var source: PackedScene = load("res://scenes/levels/base/warehouse.tscn")
	var room: Node2D = source.instantiate()
	root.add_child(room)
	room.get_node("Player").set_physics_process(false)
	await process_frame
	var positions: Dictionary = {}
	var delta := Vector2(16, 8)
	for node_name in MOVABLE:
		var item: Node2D = room.get_node(node_name)
		var before: Dictionary = {}
		for path in MOVABLE[node_name]:
			var child: Node2D = item.get_node(path)
			before[path] = child.global_position
			check(child.owner == room, str(node_name, "/", path, " is saved in scene"))
		item.position += delta
		positions[node_name] = item.position
		for path in before:
			var child: Node2D = item.get_node(path)
			check(child.global_position.is_equal_approx(before[path] + delta), str(node_name, "/", path, " follows parent"))
	var packed := PackedScene.new()
	check(packed.pack(room) == OK, "pack moved warehouse")
	check(ResourceSaver.save(packed, SCENE_PATH) == OK, "save moved warehouse")
	room.queue_free()
	await process_frame
	var reloaded := ResourceLoader.load(SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var restored: Node2D = reloaded.instantiate()
	root.add_child(restored)
	restored.get_node("Player").set_physics_process(false)
	await process_frame
	for node_name in positions:
		var item: Node2D = restored.get_node(node_name)
		check(item.position.is_equal_approx(positions[node_name]), str(node_name, " placement survives save and ready"))
	check(restored.get_node("WarehouseArt").get_child_count() == 8, "ready does not duplicate saved props or foreground")
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SCENE_PATH)
	print("Warehouse layout checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
