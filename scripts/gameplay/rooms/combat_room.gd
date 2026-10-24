class_name CombatRoom
extends Node2D

const BASE_ROOM_SIZE := Vector2(640.0, 360.0)
const ROOM_SCALE := 1.5
const ROOM_SIZE := BASE_ROOM_SIZE * ROOM_SCALE
const BOMB_BOX_COUNT := 3
const SMALL_OBSTACLE_COUNT := 6
var small_obstacles: Array[Rect2] = []

@export var layout: CombatLayoutData
@export_range(0.0, 256.0, 1.0) var camera_north_extension := 0.0

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
	return Rect2(Vector2.ZERO, ROOM_SIZE).has_point(to_local(point))


func _ready() -> void:
	_expand_room_shell()
	if layout != null:
		layout = layout.scaled_for_room(ROOM_SCALE, BASE_ROOM_SIZE)
		_place_sentries()
		var run := get_node_or_null("/root/RunManager")
		var seed_value: int = (run.run_seed if run != null else 1) + 104729 * (run.floor_index + 1 if run != null else 1) + area_index * 97 + hash(layout.id)
		layout.power_position = EncounterPropPlacement.choose_power_position(layout, seed_value)
		_add_small_obstacles()
		_apply_layout()
	_place_barrel()
	if layout != null:
		_apply_workshop_art()
	spawner.all_required_defeated.connect(_on_all_required_defeated)
	exit_elevator.set_enabled(false)
	call_deferred("_configure_player_camera_if_inside")


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
		var message := "区域 %d/%d 已清理。%s" % [area_index + 1, area_total, detail] if sequence_managed else "区域清理完成，出口电梯已启用"
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
	_configure_player_camera_if_inside()


func open_side(side: String) -> void:
	var art := get_node_or_null("WorkshopForeground") as WorkshopArt
	if art != null:
		if side == "Left":
			art.left_open = true
		else:
			art.right_open = true
		art.rebuild_scenery()
		art.queue_redraw()
	var wall := get_node(side + "Wall") as StaticBody2D
	wall.get_node("CollisionShape2D").set_deferred("disabled", true)
	wall.get_node("Visual").hide()
	var opening_size := 96.0
	var segment_size := (ROOM_SIZE.y - opening_size) * 0.5
	var center_offset := opening_size * 0.5 + segment_size * 0.5
	for center in [-center_offset, center_offset]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(16, segment_size)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position.y = center
		wall.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([Vector2(-8, center - segment_size * 0.5), Vector2(8, center - segment_size * 0.5), Vector2(8, center + segment_size * 0.5), Vector2(-8, center + segment_size * 0.5)])
		visual.color = Color(0.22, 0.28, 0.36)
		visual.visible = art == null
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
		# Keep the door leaf at its authored aspect ratio. The door owns a
		# variable-length collider and draws matching wall infill at both ends.
		door.configure_opening_width(definition.w)
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


func _expand_room_shell() -> void:
	var horizontal_shape := RectangleShape2D.new()
	horizontal_shape.size = Vector2(ROOM_SIZE.x, 16.0)
	var vertical_shape := RectangleShape2D.new()
	vertical_shape.size = Vector2(16.0, ROOM_SIZE.y)
	$Floor.polygon = CombatLayoutData._outline(Rect2(Vector2(8, 8), ROOM_SIZE - Vector2(16, 16)))
	for definition in [
		[$TopWall, Vector2(ROOM_SIZE.x * 0.5, 8), horizontal_shape, Vector2(ROOM_SIZE.x, 16)],
		[$BottomWall, Vector2(ROOM_SIZE.x * 0.5, ROOM_SIZE.y - 8), horizontal_shape, Vector2(ROOM_SIZE.x, 16)],
		[$LeftWall, Vector2(8, ROOM_SIZE.y * 0.5), vertical_shape, Vector2(16, ROOM_SIZE.y)],
		[$RightWall, Vector2(ROOM_SIZE.x - 8, ROOM_SIZE.y * 0.5), vertical_shape, Vector2(16, ROOM_SIZE.y)],
	]:
		var wall: StaticBody2D = definition[0]
		wall.position = definition[1]
		wall.get_node("CollisionShape2D").shape = definition[2]
		var size: Vector2 = definition[3]
		wall.get_node("Visual").polygon = CombatLayoutData._outline(Rect2(-size * 0.5, size))
	exit_elevator.position = CombatLayoutData._scaled_point(exit_elevator.position, ROOM_SCALE, BASE_ROOM_SIZE)
	if layout == null:
		for node in [$CoverA, $CoverB, $PowerBox, $FuelBarrel]:
			node.position = CombatLayoutData._scaled_point(node.position, ROOM_SCALE, BASE_ROOM_SIZE)
		for marker in $EnemySpawnPoints.get_children():
			marker.position = CombatLayoutData._scaled_point(marker.position, ROOM_SCALE, BASE_ROOM_SIZE)
		var fallback_navigation := CombatLayoutData.new()
		fallback_navigation.room_size = ROOM_SIZE
		for cover in [$CoverA, $CoverB]:
			var cover_shape := cover.get_node("CollisionShape2D").shape as RectangleShape2D
			fallback_navigation.covers.append(Rect2(cover.position - cover_shape.size * 0.5, cover_shape.size))
		$NavigationRegion2D.navigation_polygon = fallback_navigation.navigation_polygon()


func _configure_player_camera_if_inside() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or not active or not contains_world_point(player.global_position):
		return
	var origin := global_position
	player.camera.limit_left = floori(origin.x)
	player.camera.limit_top = floori(origin.y - camera_north_extension)
	player.camera.limit_right = ceili(origin.x + ROOM_SIZE.x)
	player.camera.limit_bottom = ceili(origin.y + ROOM_SIZE.y)
	_try_operator_low_pressure_notice(player)


func _try_operator_low_pressure_notice(player: PlayerController) -> void:
	if not sequence_managed:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var run := get_node_or_null("/root/RunManager")
	var events := get_node_or_null("/root/CombatEvents")
	if settings == null or run == null or events == null or not settings.is_low_pressure() or run.operator_hack_announced:
		return
	run.operator_hack_announced = true
	var lines := {
		TalentCoreController.DEEP_NINJA: [
			"猎痕已锁定。别让目标离开我的视野。",
			"猎痕已锁定。你选猎物，我替你封死退路。",
			"猎痕已锁定。我们都知道下一具躯壳会倒在哪里。",
		],
		TalentCoreController.LEGENDARY_MASTER: [
			"招式样本已收录。先观察，再拆解。",
			"样本交给我。你只需决定何时验证。",
			"无需提示。你的判断已经与模型重合。",
		],
		TalentCoreController.ROCK_VIGILANTE: [
			"线路已经热场。让整栋楼听见返场。",
			"拍子归你，失真归我。把这一层叫醒。",
			"线路归我们。接线员只是还没承认。",
		],
	}
	var persona_id := player.talent_core.current_persona_id
	var persona_lines: Array = lines.get(persona_id, lines[TalentCoreController.LEGENDARY_MASTER])
	var relationship_stage := clampi(player.talent_core.get_relationship_stage(persona_id), 0, persona_lines.size() - 1)
	events.publish_operator_communication(String(persona_lines[relationship_stage]))


func _add_small_obstacles() -> void:
	var blockers: Array[Rect2] = []
	for rect in layout.covers:
		# Extra clearance keeps a full dodge lane alongside the new crates.
		blockers.append(rect.grow(24))
	blockers.append_array(layout.windows)
	for rect in layout.navigation_obstacles:
		blockers.append(rect.grow(24))
	var candidates: Array[Vector2] = []
	# Maps with protected routes need a finer search around authored machinery.
	var protected_routes := not layout.clear_lanes.is_empty()
	var spacing := 24 if protected_routes else 48
	var padding := 40 if protected_routes else 80
	var end_padding := 38 if protected_routes else 64
	for y in range(padding, int(ROOM_SIZE.y) - end_padding, spacing):
		for x in range(padding, int(ROOM_SIZE.x) - end_padding, spacing):
			candidates.append(Vector2(x, y))
	var random := RandomNumberGenerator.new()
	var run := get_node_or_null("/root/RunManager")
	random.seed = (run.run_seed if run != null else 1) + hash(layout.id) + area_index * 97
	while small_obstacles.size() < SMALL_OBSTACLE_COUNT and not candidates.is_empty():
		var index := random.randi_range(0, candidates.size() - 1)
		var point := candidates[index]
		candidates.remove_at(index)
		if not EncounterPropPlacement.is_safe(point, layout.enemy_positions, blockers, layout.doors, layout.power_position, ROOM_SIZE):
			continue
		var near_door := false
		for door in layout.doors:
			near_door = near_door or EncounterPropPlacement.door_bounds(door, 40, 32).has_point(point)
		if near_door or layout.enemy_positions.any(func(enemy: Vector2) -> bool: return point.distance_to(enemy) < 60):
			continue
		var sizes := [Vector2(32, 32), Vector2(48, 28), Vector2(28, 44), Vector2(56, 28), Vector2(36, 40), Vector2(44, 32)]
		var size: Vector2 = sizes[small_obstacles.size()]
		var footprint := Rect2(point - size * 0.5, size)
		if layout.clear_lanes.any(func(lane: Rect2) -> bool: return lane.intersects(footprint.grow(20))):
			continue
		small_obstacles.append(footprint)
		layout.covers.append(footprint)
		blockers.append(footprint.grow(20))


func _place_barrel() -> void:
	var blockers: Array[Rect2] = []
	var doors: Array[Vector4] = []
	var windows: Array[Rect2] = []
	if layout != null:
		blockers.append_array(layout.covers)
		blockers.append_array(layout.windows)
		blockers.append_array(layout.navigation_obstacles)
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
	for index in BOMB_BOX_COUNT:
		var barrel := $FuelBarrel as FuelBarrel
		if index > 0:
			barrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate() as FuelBarrel
			barrel.name = "FuelBarrel%d" % (index + 1)
			add_child(barrel)
		barrel.position = EncounterPropPlacement.choose_barrel_position(spawner.planned_positions(self), blockers, doors, $PowerBox.position, seed_value + index * 7919, $FuelBarrel.position, windows, ROOM_SIZE)
		# Keep separate boxes apart and leave a walking lane around each one.
		blockers.append(Rect2(barrel.position - Vector2(32, 32), Vector2(64, 64)))


func _place_sentries() -> void:
	for point in layout.sentry_positions:
		var turret := load("res://scenes/environment/sentry_turret.tscn").instantiate() as Node2D
		turret.position = point
		layout.navigation_obstacles.append(Rect2(point - Vector2(48, 48), Vector2(96, 96)))
		add_child(turret)


func remove_sentry_obstacle(turret: Node2D) -> void:
	layout.navigation_obstacles.erase(Rect2(turret.position - Vector2(48, 48), Vector2(96, 96)))
	layout._navigation = null
	$NavigationRegion2D.navigation_polygon = layout.navigation_polygon()


func _apply_workshop_art() -> void:
	y_sort_enabled = true
	$LayoutGeometry.y_sort_enabled = true
	$Enemies.y_sort_enabled = true
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
	var blood_decals := preload("res://scripts/presentation/floor_blood_decals.gd").new()
	blood_decals.name = "FloorBloodDecals"
	add_child(blood_decals)
