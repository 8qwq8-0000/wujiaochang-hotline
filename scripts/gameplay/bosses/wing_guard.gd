class_name WingGuard
extends Node2D

signal defeated(guard: WingGuard)
signal health_changed(current: int, maximum: int)
signal attack_started
signal attack_finished

enum Kind { ROOK, BISHOP, QUEEN }

const GRID_MAX := BossFloorGeometry.GRID_MAX
const SLASH_SCENE := preload("res://scripts/gameplay/bosses/wing_slash_projectile.gd")
const SNIPER_PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const SNIPER_PROFILE := preload("res://resources/enemies/ranged_sightline.tres")
const ART := [
	"res://assets/art/characters/bosses/wing_guards/left_rook_guard.png",
	"res://assets/art/characters/bosses/wing_guards/right_bishop_guard.png",
	"res://assets/art/characters/bosses/wing_guards/fused_queen_guard.png",
]
const DEATH_ART := [
	"res://assets/art/characters/bosses/wing_guards/left_rook_guard_dead.png",
	"res://assets/art/characters/bosses/wing_guards/right_bishop_guard_dead.png",
	"res://assets/art/characters/bosses/wing_guards/fused_queen_guard_dead.png",
]

@export var kind := Kind.ROOK
@export var active := true
@export var player_path: NodePath

@onready var body: Sprite2D = $BodySprite
@onready var health: HealthComponent = $HealthComponent
@onready var hurt_box: HurtBox2DComponent = $HurtBox

var player: PlayerController
var _generation := 0
var _dashing := false
var _warning_cells: Array[Vector2i] = []
var _warning_lines: Array[PackedVector2Array] = []
var _laser_warning := false
var _laser_active := false
var _idle_texture: Texture2D
var _visual_generation := 0
var _attacking := false
var _stagger_recovery := 0.0
var _warning_elapsed := 0.0
var _slash_warning := Vector2.INF


func _process(delta: float) -> void:
	if not _warning_cells.is_empty() or not _warning_lines.is_empty():
		_warning_elapsed += delta
		queue_redraw()


func _ready() -> void:
	player = get_node_or_null(player_path) as PlayerController
	_idle_texture = load(ART[kind])
	body.texture = _idle_texture
	health.health_changed.connect(func(current: int, maximum: int, _delta: int) -> void:
		health_changed.emit(current, maximum)
		queue_redraw())
	health.died.connect(_on_died)
	attack_started.connect(func() -> void: _attacking = true)
	attack_finished.connect(func() -> void: _attacking = false)
	if active:
		_run_loop(_generation)


func set_active(value: bool) -> void:
	active = value
	_generation += 1
	_clear_warning()
	if active and is_node_ready() and not health.is_dead():
		_run_loop(_generation)


func is_attacking() -> bool:
	return _attacking


func should_ignore_damage(_packet: DamagePacket) -> bool:
	return _dashing


func apply_stagger(seconds: float) -> void:
	_stagger_recovery = maxf(_stagger_recovery, seconds)


func _on_died(_packet: DamagePacket) -> void:
	active = false
	_attacking = false
	_generation += 1
	_visual_generation += 1
	_clear_warning()
	body.texture = load(DEATH_ART[kind])
	body.scale = Vector2(0.064, 0.064)
	hurt_box.set_deferred("monitorable", false)
	hurt_box.set_deferred("monitoring", false)
	($HurtBox/CollisionShape2D as CollisionShape2D).set_deferred("disabled", true)
	defeated.emit(self)
	queue_redraw()


func _run_loop(generation: int) -> void:
	while _current(generation):
		await get_tree().create_timer(0.45, false).timeout
		if not _current(generation): return
		match kind:
			Kind.ROOK: await _rook_turn(generation)
			Kind.BISHOP: await _bishop_turn(generation)
			Kind.QUEEN:
				if randi() % 2 == 0: await _queen_laser(generation)
				else: await _queen_jump(generation)


func _current(generation: int) -> bool:
	return active and generation == _generation and is_instance_valid(player) and not player.health.is_dead() and not health.is_dead()


func _cell(point: Vector2) -> Vector2i:
	return BossFloorGeometry.nearest_cell(point)


func _point(cell: Vector2i) -> Vector2:
	return BossFloorGeometry.cell_point(cell)


func _move_to(cell: Vector2i, seconds: float) -> void:
	var start := _cell(global_position)
	var steps := maxi(absi(cell.x - start.x), absi(cell.y - start.y))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if steps <= 1 or kind == Kind.QUEEN:
		tween.tween_property(self, "global_position", _point(cell), seconds)
	else:
		for step in range(1, steps + 1):
			var next := Vector2i(
				start.x + roundi(float(cell.x - start.x) * float(step) / float(steps)),
				start.y + roundi(float(cell.y - start.y) * float(step) / float(steps))
			)
			tween.tween_property(self, "global_position", _point(next), seconds / float(steps))
	await tween.finished


func _rook_turn(generation: int) -> void:
	var here := _cell(global_position)
	var target := _cell(player.global_position)
	if here.x != target.x and here.y != target.y:
		var align := Vector2i(target.x, here.y) if absi(target.x - here.x) < absi(target.y - here.y) else Vector2i(here.x, target.y)
		await _move_to(align, 0.34)
		return
	_warning_cells.clear()
	var end := Vector2i(target.x, here.y) if here.y == target.y else Vector2i(here.x, target.y)
	var distance := maxi(absi(end.x - here.x), absi(end.y - here.y))
	for index in range(distance + 1):
		_warning_cells.append(here + Vector2i(signi(end.x - here.x), signi(end.y - here.y)) * index)
	_slash_warning = _point(end)
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(0.7, false).timeout
	if not _current(generation): return
	_dashing = true
	_play_attack_frames("rook_slash")
	await get_tree().create_timer(0.36, false).timeout
	if not _current(generation): return
	await _move_to(end, 0.18)
	_dashing = false
	_clear_warning()
	if not _current(generation): return
	_fire_slash(2)
	await get_tree().create_timer(0.6 + _stagger_recovery, false).timeout
	_stagger_recovery = 0.0
	attack_finished.emit()


func _bishop_turn(generation: int) -> void:
	var here := _cell(global_position)
	var target := _cell(player.global_position)
	var dx := target.x - here.x
	var dy := target.y - here.y
	if dx == 0 and dy == 0:
		var sidestep := Vector2i(clampi(here.x + 1, 0, GRID_MAX.x), clampi(here.y + 1, 0, GRID_MAX.y))
		if sidestep != here:
			await _move_to(sidestep, 0.14)
		return
	if absi(absi(dx) - absi(dy)) > 1:
		var best := here
		var best_score := INF
		for xdir in [-1, 1]:
			for ydir in [-1, 1]:
				for step in range(1, 4):
					var candidate := here + Vector2i(xdir, ydir) * step
					if candidate.x < 0 or candidate.y < 0 or candidate.x > GRID_MAX.x or candidate.y > GRID_MAX.y:
						continue
					var score := float(absi(absi(target.x - candidate.x) - absi(target.y - candidate.y)) * 10 + candidate.distance_squared_to(target))
					if score < best_score:
						best_score = score
						best = candidate
		if best != here:
			await _move_to(best, 0.14)
		return
	_warning_lines = [_edge_ray(here, Vector2(signi(dx), signi(dy)))]
	_laser_warning = true
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(0.7, false).timeout
	if not _current(generation): return
	_play_attack_frames("bishop_laser")
	await get_tree().create_timer(0.36, false).timeout
	if not _current(generation): return
	_laser_active = true
	queue_redraw()
	if _distance_to_polyline(player.global_position, _warning_lines[0]) <= 7.0:
		_hit_player(false, &"energy")
	await get_tree().create_timer(0.22, false).timeout
	_clear_warning()
	attack_finished.emit()


func _queen_laser(generation: int) -> void:
	var here := _cell(global_position)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	_warning_lines.clear()
	for dir in dirs:
		_warning_lines.append(_edge_ray(here, Vector2(dir)))
	_laser_warning = true
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(0.7, false).timeout
	if not _current(generation): return
	_play_attack_frames("queen_laser")
	await get_tree().create_timer(0.36, false).timeout
	if not _current(generation): return
	_laser_active = true
	queue_redraw()
	for line in _warning_lines:
		if _distance_to_polyline(player.global_position, line) <= 7.0:
			_hit_player(false, &"energy")
			break
	await get_tree().create_timer(0.22, false).timeout
	_clear_warning()
	attack_finished.emit()


func _queen_jump(generation: int) -> void:
	var target := _cell(player.global_position)
	_warning_cells = [target]
	_slash_warning = _point(target)
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(0.7, false).timeout
	if not _current(generation): return
	_play_attack_frames("queen_landing")
	await get_tree().create_timer(0.36, false).timeout
	if not _current(generation): return
	await _move_to(target, 0.22)
	if not _current(generation): return
	_fire_slash(3)
	# Four tight cardinal fans leave diagonal corridors.
	_warning_lines.clear()
	for quarter in 4:
		for offset in [-22.5, -7.5, 7.5, 22.5]:
			var dir := Vector2.RIGHT.rotated(deg_to_rad(float(quarter) * 90.0 + float(offset)))
			_warning_lines.append(_edge_line_from(global_position, dir))
	queue_redraw()
	await get_tree().create_timer(0.4, false).timeout
	if not _current(generation): return
	for line in _warning_lines:
		_fire_queen_spread_projectile((line[1] - line[0]).normalized())
	_clear_warning()
	attack_finished.emit()


func _hit_player(blockable: bool, damage_type: StringName) -> void:
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source = self
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = global_position
	packet.travel_direction = global_position.direction_to(player.global_position)
	packet.damage_type = damage_type
	packet.blockable = blockable
	packet.is_melee = blockable and kind == Kind.ROOK
	packet.stagger_seconds = 0.8 if packet.is_melee else 0.0
	packet.is_beam = kind != Kind.ROOK
	player.receive_damage(packet)


func _fire_slash(cells: int) -> void:
	var slash := SLASH_SCENE.new() as WingSlashProjectile
	get_parent().add_child(slash)
	slash.launch(self, player, global_position.direction_to(player.global_position), cells)


func _fire_queen_spread_projectile(direction: Vector2) -> void:
	var projectile := SNIPER_PROJECTILE_SCENE.instantiate() as CombatProjectile
	get_parent().get_parent().add_child(projectile)
	projectile.global_position = global_position + direction * 16.0
	projectile.setup(self, CombatFaction.Id.ENEMY, direction, SNIPER_PROFILE.damage, SNIPER_PROFILE.projectile_speed)


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(point, start, end).distance_to(point)


func _distance_to_polyline(point: Vector2, line: PackedVector2Array) -> float:
	var distance := INF
	for index in range(line.size() - 1):
		distance = minf(distance, _distance_to_segment(point, line[index], line[index + 1]))
	return distance


func _grid_line(start: Vector2i, end: Vector2i) -> PackedVector2Array:
	var line := PackedVector2Array([_point(start)])
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y))
	for step in range(1, steps + 1):
		var cell := Vector2i(
			start.x + roundi(float(end.x - start.x) * float(step) / float(steps)),
			start.y + roundi(float(end.y - start.y) * float(step) / float(steps))
		)
		line.append(_point(cell))
	return line


func _edge_ray(start: Vector2i, direction: Vector2) -> PackedVector2Array:
	return _edge_line_from(_point(start), direction)


func _edge_line_from(origin: Vector2, direction: Vector2) -> PackedVector2Array:
	var board := Rect2(BossFloorGeometry.ORIGIN, Vector2(24, 14) * BossFloorGeometry.CELL_SIZE)
	var distance := INF
	if direction.x > 0.0: distance = minf(distance, (board.end.x - origin.x) / direction.x)
	elif direction.x < 0.0: distance = minf(distance, (board.position.x - origin.x) / direction.x)
	if direction.y > 0.0: distance = minf(distance, (board.end.y - origin.y) / direction.y)
	elif direction.y < 0.0: distance = minf(distance, (board.position.y - origin.y) / direction.y)
	return PackedVector2Array([origin, origin + direction * distance])


func _clear_warning() -> void:
	_warning_cells.clear()
	_warning_lines.clear()
	_warning_elapsed = 0.0
	_slash_warning = Vector2.INF
	_laser_warning = false
	_laser_active = false
	queue_redraw()


func _play_attack_frames(animation_name: String) -> void:
	_visual_generation += 1
	var generation := _visual_generation
	var original_scale := Vector2(0.064, 0.064)
	for index in 8:
		if generation != _visual_generation or not is_instance_valid(body): return
		var path := "res://assets/art/characters/bosses/wing_guards/animations/%s/frame_%02d.png" % [animation_name, index]
		body.texture = load(path)
		body.scale = original_scale * 2.0
		await get_tree().create_timer(0.12, false).timeout
	if generation == _visual_generation and is_instance_valid(body):
		body.texture = _idle_texture
		body.scale = original_scale


func _draw() -> void:
	if is_instance_valid(health) and health.max_health > 0 and not health.is_dead():
		var base := Rect2(-27, -86, 54, 5)
		draw_rect(base, Color(0.03, 0.06, 0.11, 0.88), true)
		draw_rect(Rect2(base.position, Vector2(base.size.x * float(health.current_health) / float(health.max_health), base.size.y)), Color(0.38, 0.83, 0.94) if kind != Kind.QUEEN else Color(0.96, 0.71, 0.28), true)
	for cell in _warning_cells:
		var polygon := BossFloorGeometry.cell_polygon(cell)
		for index in polygon.size():
			polygon[index] = to_local(polygon[index])
		var pulse := 0.48 + 0.24 * sin(_warning_elapsed * 13.0)
		for index in polygon.size():
			draw_line(polygon[index], polygon[(index + 1) % polygon.size()], Color(1.0, 0.78, 0.32, pulse), 1.5)
		var center := (polygon[0] + polygon[2]) * 0.5
		var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)])
		for index in 4:
			draw_line(diamond[index], diamond[(index + 1) % 4], Color(0.88, 0.91, 1.0, pulse * 0.75), 1.0)
	if _slash_warning != Vector2.INF:
		var slash_center := to_local(_slash_warning)
		var arc_phase := minf(_warning_elapsed / 0.7, 1.0)
		draw_arc(slash_center, 22.0, -PI * 0.72, -PI * 0.72 + PI * 1.44 * arc_phase, 24, Color(1.0, 0.94, 0.7, 0.85), 2.0)
	for line in _warning_lines:
		var local_line := PackedVector2Array()
		for point in line:
			local_line.append(to_local(point))
		if _laser_warning:
			draw_polyline(local_line, Color(1.0, 0.16, 0.06, 0.52) if _laser_active else Color(1.0, 0.65, 0.24, 0.26), 14.0 if _laser_active else 1.5)
			draw_polyline(local_line, Color(1.0, 0.88, 0.58, 0.94) if _laser_active else Color(1.0, 0.32, 0.12, 0.34), 4.0 if _laser_active else 2.0)
			if not _laser_active and local_line.size() > 1:
				var t := fmod(_warning_elapsed / 0.7, 1.0)
				var start: Vector2 = local_line[0]
				var end: Vector2 = local_line[local_line.size() - 1]
				draw_circle(start.lerp(end, t), 3.0, Color(1.0, 0.95, 0.72, 0.95))
		else:
			draw_polyline(local_line, Color(0.25, 0.85, 1.0, 0.7), 8.0)
