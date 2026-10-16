class_name CombatRoom
extends Node2D

signal room_cleared
var cleared := false

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var exit_elevator: Area2D = $ExitElevator


func _enter_tree() -> void:
	add_to_group("environment_areas")

func contains_world_point(point: Vector2) -> bool:
	return Rect2(0,0,640,360).has_point(to_local(point))

func _ready() -> void:
	spawner.all_required_defeated.connect(_on_all_required_defeated)
	exit_elevator.set_enabled(false)


func _on_all_required_defeated() -> void:
	cleared = true
	exit_elevator.set_enabled(true)
	room_cleared.emit()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_room_cleared(self)
		events.publish_notice(&"room_cleared", "区域清理完成，出口电梯已启用", Color(0.35, 1.0, 0.55), CombatNotice.Priority.NORMAL, 0.0, 2.0)
