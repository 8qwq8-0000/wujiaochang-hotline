class_name CombatRoom
extends Node2D

@export var layout: CombatLayoutData

signal room_cleared
var cleared := false
var sequence_managed := false
var area_index := 0
var area_total := 1
var active := true
var reward_count := 0

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var exit_elevator: Area2D = $ExitElevator


func _enter_tree() -> void:
	add_to_group("environment_areas")


func contains_world_point(point: Vector2) -> bool:
	return Rect2(0, 0, 640, 360).has_point(to_local(point))


func _ready() -> void:
	if layout != null:
		_apply_layout()
	spawner.all_required_defeated.connect(_on_all_required_defeated)
	exit_elevator.set_enabled(false)


func _on_all_required_defeated() -> void:
	if cleared:
		return
	cleared = true
	if not sequence_managed:
		exit_elevator.set_enabled(true)
	room_cleared.emit()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_room_cleared(self)
		var detail := "通道已开放，掉落请在敌人倒下处拾取" if area_index + 1 < area_total else "最终出口已开放"
		var message := "区域 %d/%d 清场 · %s" % [area_index + 1, area_total, detail] if sequence_managed else "区域清理完成，出口电梯已启用"
		events.publish_notice(&"room_cleared", message, Color(0.35, 1.0, 0.55), CombatNotice.Priority.NORMAL, 0.0, 2.0)


func configure_stage(index: int, total: int) -> void:
	sequence_managed = true
	area_index = index
	area_total = total
	active = false
	get_node("EnemySpawner").auto_spawn = false
	get_node("EnemySpawner").report_to_run_manager = false
	get_node("EnemySpawner").seed_offset = index * 97


func activate() -> void:
	if active or cleared:
		return
	active = true
	spawner.spawn_all()


func open_side(side: String) -> void:
	var wall := get_node(side + "Wall") as StaticBody2D
	wall.get_node("CollisionShape2D").set_deferred("disabled", true)
	wall.get_node("Visual").hide()
	for center in [-114.0, 114.0]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(16, 132)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position.y = center
		wall.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([Vector2(-8, center - 66), Vector2(8, center - 66), Vector2(8, center + 66), Vector2(-8, center + 66)])
		visual.color = Color(0.22, 0.28, 0.36)
		wall.add_child(visual)


func _apply_layout() -> void:
	for old_name in ["CoverA", "CoverB"]:
		var old := get_node_or_null(old_name)
		if old != null:
			remove_child(old)
			old.free()
	var geometry := Node2D.new()
	geometry.name = "LayoutGeometry"
	add_child(geometry)
	for rect in layout.covers:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = CombatLayoutData._outline(Rect2(-rect.size * 0.5, rect.size))
		visual.color = layout.cover_color
		body.add_child(visual)
		geometry.add_child(body)
	$Floor.color = layout.floor_color
	var markers := $EnemySpawnPoints.get_children()
	for index in mini(markers.size(), layout.enemy_positions.size()):
		markers[index].position = layout.enemy_positions[index]
	$PowerBox.position = layout.power_position
	$FuelBarrel.position = layout.bomb_position
	$NavigationRegion2D.navigation_polygon = layout.navigation_polygon()
