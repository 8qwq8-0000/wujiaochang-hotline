extends SceneTree

var failures := 0
const SAVE := "user://inventory-trash-drop-check.json"


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = SAVE
	DirAccess.remove_absolute(SAVE)
	var room: Node = load("res://scenes/levels/base/warehouse.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame

	var player: PlayerController = room.player
	var inventory := player.inventory
	var item := ComponentRolls.create("armor", 2, RandomNumberGenerator.new())
	check(inventory.backpack.add_item(item), "trash-drop fixture enters backpack")
	inventory.set_open(true)
	await process_frame
	var drop_zone := inventory.panel.get("_trash_zone") as InventoryTrashDropZone
	var payload := {"inventory": inventory, "item": item}
	check(drop_zone != null and drop_zone._can_drop_data(Vector2.ZERO, payload), "trash zone accepts a backpack drag")
	drop_zone._drop_data(Vector2.ZERO, payload)
	await process_frame

	check(not inventory.is_open and not paused, "successful touch drop closes the backpack and resumes play")
	check(not inventory.backpack.has_item(item), "successful touch drop removes the backpack item")
	var pickup := get_first_node_in_group("component_pickups") as ComponentPickup
	check(pickup != null and pickup.rolled_item == item, "trash zone creates recoverable ground loot with the same item instance")
	check(not drop_zone._can_drop_data(Vector2.ZERO, payload), "stale payload cannot duplicate discarded loot")

	room.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	print("Inventory trash-drop failures: ", failures)
	quit(0 if failures == 0 else 1)
