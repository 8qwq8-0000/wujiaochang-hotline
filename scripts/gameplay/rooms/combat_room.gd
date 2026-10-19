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
	_place_barrel()
	if layout != null and layout.id in [&"interlinked_apartment", &"loading_workshop"]:
		_apply_workshop_art()
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
	var art := get_node_or_null("WorkshopForeground") as WorkshopArt
	if art != null:
		if side == "Left":
			art.left_open = true
		else:
			art.right_open = true
		art.queue_redraw()
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
	var palette := [Color("20343d"), Color("283844"), Color("263b3b"), Color("303440"), Color("293d43"), Color("35333d")]
	for index in layout.zones.size():
		var zone := Polygon2D.new()
		zone.polygon = CombatLayoutData._outline(layout.zones[index])
		zone.color = palette[index % palette.size()]
		zone.z_index = -1
		geometry.add_child(zone)
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
	for rect in layout.windows:
		var window := StaticBody2D.new()
		window.name = "ObservationWindow"
		window.position = rect.get_center()
		# Actors collide with glass; vision/projectile rays use world layer 1.
		window.collision_layer = 128
		window.collision_mask = 0
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		window.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = CombatLayoutData._outline(Rect2(-rect.size * 0.5, rect.size))
		visual.color = Color("72c7e4")
		window.add_child(visual)
		geometry.add_child(window)
	for definition in layout.doors:
		var door: AutomaticDoor = load("res://scenes/environment/automatic_door.tscn").instantiate()
		door.position = Vector2(definition.x, definition.y)
		door.rotation = definition.z
		door.scale.y = definition.w / 64.0
		door.hinged_visual = true
		geometry.add_child(door)
	$Floor.color = layout.floor_color
	$Floor.z_index = -2
	if not layout.enemy_profiles.is_empty():
		for old in $EnemySpawnPoints.get_children():
			$EnemySpawnPoints.remove_child(old)
			old.free()
		for index in layout.enemy_positions.size():
			var marker := EnemySpawnMarker.new()
			marker.position = layout.enemy_positions[index]
			marker.profile = layout.enemy_profiles[index] as EnemyProfile
			$EnemySpawnPoints.add_child(marker)
	else:
		var markers := $EnemySpawnPoints.get_children()
		for index in mini(markers.size(), layout.enemy_positions.size()):
			markers[index].position = layout.enemy_positions[index]
	$PowerBox.position = layout.power_position
	$FuelBarrel.position = layout.bomb_position
	$NavigationRegion2D.navigation_polygon = layout.navigation_polygon()


func _place_barrel() -> void:
	var blockers: Array[Rect2] = []
	var doors: Array[Vector4] = []
	var windows: Array[Rect2] = []
	if layout != null:
		blockers.append_array(layout.covers)
		blockers.append_array(layout.windows)
		windows.assign(layout.windows)
		doors.assign(layout.doors)
	else:
		# Original standalone room has two rectangular cover bodies.
		for name in ["CoverA", "CoverB"]:
			var cover := get_node_or_null(name) as StaticBody2D
			if cover != null:
				var shape := cover.get_node("CollisionShape2D").shape as RectangleShape2D
				blockers.append(Rect2(cover.position - shape.size * 0.5, shape.size))
	var run := get_node_or_null("/root/RunManager")
	var seed_value: int = (run.run_seed if run != null else 1) + 104729 * (run.floor_index + 1 if run != null else 1) + area_index * 97
	$FuelBarrel.position = EncounterPropPlacement.choose_barrel_position(spawner.planned_positions(self), blockers, doors, $PowerBox.position, seed_value, $FuelBarrel.position, windows)


func _apply_workshop_art() -> void:
	$Floor.hide()
	for side in ["Top", "Bottom", "Left", "Right"]:
		get_node(side + "Wall/Visual").hide()
	for child in $LayoutGeometry.get_children():
		if child is Polygon2D:
			child.hide()
		elif child is StaticBody2D:
			for visual in child.get_children():
				if visual is Polygon2D:
					visual.hide()
	var floor_art := WorkshopArt.new()
	floor_art.name = "WorkshopFloor"
	floor_art.layout = layout
	floor_art.floor_pass = true
	floor_art.z_index = -2
	add_child(floor_art)
	var foreground := WorkshopArt.new()
	foreground.name = "WorkshopForeground"
	foreground.layout = layout
	add_child(foreground)
	for prop in [$PowerBox, $FuelBarrel]:
		var label := prop.get_node_or_null("Label") as Label
		if label != null:
			label.hide()
	$ExitElevator/Label.hide()
