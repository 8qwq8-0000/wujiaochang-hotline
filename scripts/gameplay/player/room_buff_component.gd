class_name RoomBuffComponent
extends Node

signal changed(id: StringName)
const BUFFS: Array[StringName] = [&"attack_speed", &"cooling", &"guard_recovery"]
const TITLES := {&"attack_speed": "攻速提升 25%", &"cooling": "散热提升 50%", &"guard_recovery": "格挡后摇缩短 30%"}
var active_buff: StringName = &""
var source_room: Node

func _ready() -> void:
	get_parent().get_node("HealthComponent").died.connect(func(_packet: DamagePacket) -> void: clear())

func apply_buff(id: StringName, room: Node) -> bool:
	if id not in BUFFS or not is_instance_valid(room) or room.is_queued_for_deletion():
		return false
	if get_parent().get_node("HealthComponent").is_dead():
		return false
	clear()
	active_buff = id
	source_room = room
	if room.has_signal("room_cleared"):
		room.connect("room_cleared", clear)
	room.tree_exiting.connect(clear)
	get_parent().get_node("WeaponController").attack_speed_multiplier = 1.25 if id == &"attack_speed" else 1.0
	get_parent().get_node("HeatComponent").cooling_multiplier = 1.5 if id == &"cooling" else 1.0
	get_parent().get_node("GuardComponent").recovery_multiplier = 0.7 if id == &"guard_recovery" else 1.0
	changed.emit(id)

	return true

func clear() -> void:
	if is_instance_valid(source_room):
		if source_room.has_signal("room_cleared") and source_room.is_connected("room_cleared", clear):
			source_room.disconnect("room_cleared", clear)
		if source_room.tree_exiting.is_connected(clear):
			source_room.tree_exiting.disconnect(clear)
	source_room = null
	if active_buff.is_empty():
		return
	active_buff = &""
	get_parent().get_node("WeaponController").attack_speed_multiplier = 1.0
	get_parent().get_node("HeatComponent").cooling_multiplier = 1.0
	get_parent().get_node("GuardComponent").recovery_multiplier = 1.0
	changed.emit(active_buff)
