class_name ChannelMission
extends Node

# Shared route checkpoint support. Only the first-floor hidden room has a task;
# later floors keep this node solely to restore and save normal floor progress.
var room: ChannelTaskRoom
var dialogue: ChannelDialogue
var inside := false
var task_done := false
var choice_resolved := false
@onready var floor_scene: Node2D = get_parent()
@onready var player: PlayerController = floor_scene.get_node("Player")
@onready var assembler: FloorAssembler = floor_scene.get_node("FloorAssembler")
@onready var run: Node = get_node("/root/RunManager")
@onready var store: Node = get_node("/root/WarehouseStore")
@onready var floor_index: int = run.floor_index


func _ready() -> void:
	call_deferred("_restore_or_checkpoint")


func _restore_or_checkpoint() -> void:
	if not run.channel_resume.is_empty():
		var saved: Dictionary = run.channel_resume
		player.position = Vector2(float(saved.get("x", 111)), float(saved.get("y", 270)))
		# Old maintenance/isolation checkpoints may place the player in a removed room.
		if floor_index > 0 and (player.position.y < 0 or player.position.y > CombatRoom.ROOM_SIZE.y):
			player.position = Vector2(924, 270)
		var index: int = assembler.active_area_index
		assembler.generated_rooms[index]._configure_player_camera_if_inside()
		for pickup_data: Dictionary in saved.get("pickups", []):
			var item := InventoryItem.new()
			if not item.deserialize(pickup_data.item):
				item.free()
				continue
			var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
			pickup.rolled_item = item
			pickup.component_id = item.get_prototype().get_prototype_id()
			pickup.position = Vector2(float(pickup_data.x), float(pickup_data.y))
			if floor_index > 0 and (pickup.position.y < 0 or pickup.position.y > CombatRoom.ROOM_SIZE.y):
				pickup.position = Vector2(890, 270)
			if floor_index == 2:
				pickup.position.x = clampf(pickup.position.x, 60, 900)
			floor_scene.add_child(pickup)
		run.channel_resume.clear()
	elif run.channel_route_active:
		save_checkpoint()


func allows_next_area() -> bool:
	return not inside


# First-floor hidden mission supplies these interactions.
func offer_entry() -> void:
	pass


func enter_room() -> void:
	pass


func use_task_terminal() -> void:
	pass


func accept_route() -> void:
	pass


func decline_route() -> void:
	pass


func save_checkpoint() -> bool:
	if not run.channel_route_active or player.health.is_dead():
		return false
	var cleared: Array = []
	for area in assembler.generated_rooms:
		cleared.append(area.cleared)
	var pickups: Array = []
	for pickup in get_tree().get_nodes_in_group("component_pickups"):
		if floor_scene.is_ancestor_of(pickup) and not pickup._picked and not pickup.is_queued_for_deletion():
			pickups.append({"item": pickup.rolled_item.serialize(), "x": pickup.global_position.x, "y": pickup.global_position.y})
	var saved := {"scene": floor_scene.scene_file_path, "seed": run.run_seed, "floor": floor_index, "route": run.export_channel_state(),
		"player": player.export_run_state(), "cleared": cleared, "pickups": pickups,
		"x": player.position.x, "y": player.position.y,
		"elapsed": float(Time.get_ticks_msec() - run.run_started_msec) / 1000,
		"medical_used": run.codex_medical_supply_used,
		"persona_floor": run.persona_authorization_floor, "persona_pending": run.persona_authorization_pending,
		"persona_refilled": run.persona_rest_refilled_floor}
	saved.merge(checkpoint_details(), true)
	return store.save_channel_progress(saved, checkpoint_discoveries())


func _notice(text: String) -> void:
	get_node("/root/CombatEvents").publish_message(text, Color("75e8df"))


func checkpoint_details() -> Dictionary:
	return {}


func checkpoint_discoveries() -> Array:
	return []
