class_name WingGuard
extends Node2D

signal defeated(guard: WingGuard)
signal health_changed(current: int, maximum: int)
signal attack_started
signal attack_finished

enum Kind { ROOK, BISHOP, QUEEN }

const ENCOUNTER_IDS := ["wing_guard_rook", "wing_guard_bishop", "wing_guard_queen"]
const GRID_MAX := BossFloorGeometry.GRID_MAX
const SLASH_SCENE := preload("res://scripts/gameplay/bosses/wing_slash_projectile.gd")
const ATTACK_WARNING := 0.55
const BISHOP_LASER_WARNING := 0.35
const LASER_LINGER := 0.6
const LASER_RADIUS := 10.0
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
var _laser_hit_this_cast := false
var _warning_duration := ATTACK_WARNING
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


func _physics_process(_delta: float) -> void:
	if not _laser_active or _laser_hit_this_cast or not is_instance_valid(player) or player.health.is_dead():
		return
	var bounds := _player_laser_bounds()
	for line in _warning_lines:
		if _ray_hits_bounds(line, bounds):
			_laser_hit_this_cast = true
			_hit_player(false, &"energy")
			return


func _ready() -> void:
	player = get_node_or_null(player_path) as PlayerController
	_idle_texture = load(ART[kind])
	body.texture = _idle_texture
	EnemyEncounterRecorder.watch(self, ENCOUNTER_IDS[kind], false)
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
		await get_tree().create_timer(0.32, false).timeout
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
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	await get_tree().create_timer(0.035, false).timeout


func _rook_turn(generation: int) -> void:
	var here := _cell(global_position)
	var target := _cell(player.global_position)
	if here.x != target.x and here.y != target.y:
		var align := Vector2i(target.x, here.y) if absi(target.x - here.x) < absi(target.y - here.y) else Vector2i(here.x, target.y)
		await _move_to(align, 0.24)
		return
	_warning_cells.clear()
	var end := Vector2i(target.x, here.y) if here.y == target.y else Vector2i(here.x, target.y)
	var distance := maxi(absi(end.x - here.x), absi(end.y - here.y))
	for index in range(distance + 1):
		_warning_cells.append(here + Vector2i(signi(end.x - here.x), signi(end.y - here.y)) * index)
	_slash_warning = _point(end)
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(ATTACK_WARNING, false).timeout
	if not _current(generation): return
	_dashing = true
	_play_attack_frames("rook_slash")
	await get_tree().create_timer(0.28, false).timeout
	if not _current(generation): return
	await _move_to(end, 0.12)
	_dashing = false
	_clear_warning()
	if not _current(generation): return
	_fire_slash(2)
	await get_tree().create_timer(0.6 + _stagger_recovery, false).timeout
	_stagger_recovery = 0.0
	attack_finished.emit()


func _bishop_turn(generation: int) -> void:
	var here := _cell(global_position)
	var ray := _bishop_target_ray(here)
	if ray.is_empty():
		var best := _bishop_destination(here, _cell(player.global_position))
		if best != here:
			await _move_to(best, 0.10 + 0.012 * maxi(absi(best.x - here.x), absi(best.y - here.y)))
		return
	_warning_lines = [ray]
	_laser_warning = true
	_warning_duration = BISHOP_LASER_WARNING
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(BISHOP_LASER_WARNING, false).timeout
	if not _current(generation): return
	_play_attack_frames("bishop_laser")
	await get_tree().create_timer(0.18, false).timeout
	if not _current(generation): return
	_laser_active = true
	_laser_hit_this_cast = false
	queue_redraw()
	await get_tree().create_timer(LASER_LINGER, false).timeout
	_clear_warning()
	attack_finished.emit()


func _bishop_target_ray(here: Vector2i) -> PackedVector2Array:
	var bounds := _player_laser_bounds()
	for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var ray := _edge_ray(here, direction)
		if _ray_hits_bounds(ray, bounds):
			return ray
	return PackedVector2Array()


func _player_laser_bounds() -> Rect2:
	var hit_shape := player.hurt_box.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := hit_shape.shape as RectangleShape2D
	return Rect2(hit_shape.global_position - rectangle.size * 0.5, rectangle.size).grow(LASER_RADIUS)


func _ray_hits_bounds(ray: PackedVector2Array, bounds: Rect2) -> bool:
	if bounds.has_point(ray[0]) or bounds.has_point(ray[1]):
		return true
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(ray[0], ray[1], corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false


func _bishop_destination(here: Vector2i, target: Vector2i) -> Vector2i:
	var best := here
	var best_score := INF
	var candidates: Array[Vector2i] = [here]
	for xdir in [-1, 1]:
		for ydir in [-1, 1]:
			for step in range(1, maxi(GRID_MAX.x, GRID_MAX.y) + 1):
				var cell := here + Vector2i(xdir, ydir) * step
				if cell.x < 0 or cell.y < 0 or cell.x > GRID_MAX.x or cell.y > GRID_MAX.y:
					break
				candidates.append(cell)
	for cell in candidates:
		var dx := absi(target.x - cell.x)
		var dy := absi(target.y - cell.y)
		var distance := Vector2(cell).distance_to(Vector2(target))
		var range_penalty := maxf(6.0 - distance, 0.0) * 18.0 + maxf(distance - 9.0, 0.0) * 4.0
		var travel := Vector2(cell).distance_to(Vector2(here))
		var score := float(absi(dx - dy)) * 100.0 + range_penalty + absf(distance - 7.5) + travel * 0.2 + _projectile_risk(_point(cell))
		if cell == target:
			score += 200.0
		if score < best_score:
			best_score = score
			best = cell
	return best


func _projectile_risk(point: Vector2) -> float:
	var risk := 0.0
	for node in get_tree().get_nodes_in_group("combat_projectiles"):
		var shot := node as CombatProjectile
		if shot == null or shot.faction != CombatFaction.Id.PLAYER:
			continue
		var end := shot.global_position + shot.direction * shot.speed * 0.4
		var nearest := Geometry2D.get_closest_point_to_segment(point, shot.global_position, end)
		if nearest.distance_to(point) < 40.0:
			risk += 180.0
	return risk


func _queen_laser(generation: int) -> void:
	var here := _cell(global_position)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	_warning_lines.clear()
	for dir in dirs:
		_warning_lines.append(_edge_ray(here, Vector2(dir)))
	_laser_warning = true
	_warning_duration = ATTACK_WARNING
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(ATTACK_WARNING, false).timeout
	if not _current(generation): return
	_play_attack_frames("queen_laser")
	await get_tree().create_timer(0.28, false).timeout
	if not _current(generation): return
	_laser_active = true
	_laser_hit_this_cast = false
	queue_redraw()
	await get_tree().create_timer(LASER_LINGER, false).timeout
	_clear_warning()
	attack_finished.emit()


func _queen_jump(generation: int) -> void:
	var target := _queen_landing_cell(_cell(global_position), _cell(player.global_position))
	_warning_cells = [target]
	_slash_warning = _point(target)
	queue_redraw()
	attack_started.emit()
	await get_tree().create_timer(ATTACK_WARNING, false).timeout
	if not _current(generation): return
	_play_attack_frames("queen_landing")
	await get_tree().create_timer(0.28, false).timeout
	if not _current(generation): return
	await _move_to(target, 0.15)
	if not _current(generation): return
	_fire_slash(3)
	# Two blades per cardinal fan leave readable diagonal corridors.
	_warning_lines.clear()
	for quarter in 4:
		for offset in [-15.0, 15.0]:
			var dir := Vector2.RIGHT.rotated(deg_to_rad(float(quarter) * 90.0 + float(offset)))
			_warning_lines.append(_edge_line_from(global_position, dir))
	queue_redraw()
	await get_tree().create_timer(0.4, false).timeout
	if not _current(generation): return
	for line in _warning_lines:
		_fire_slash(3, (line[1] - line[0]).normalized())
	_clear_warning()
	attack_finished.emit()


func _queen_landing_cell(here: Vector2i, target: Vector2i) -> Vector2i:
	var best := here
	var best_distance := INF
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		for step in range(1, maxi(GRID_MAX.x, GRID_MAX.y) + 1):
			var cell: Vector2i = here + direction * step
			if cell.x < 0 or cell.y < 0 or cell.x > GRID_MAX.x or cell.y > GRID_MAX.y:
				break
			var distance: int = cell.distance_squared_to(target)
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best


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


func _fire_slash(cells: int, direction: Vector2 = Vector2.ZERO) -> void:
	var slash := SLASH_SCENE.new() as WingSlashProjectile
	get_parent().add_child(slash)
	slash.launch(self, player, global_position.direction_to(player.global_position) if direction.is_zero_approx() else direction, cells)


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
	_laser_hit_this_cast = false
	_warning_duration = ATTACK_WARNING
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
		await get_tree().create_timer(0.09, false).timeout
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
		var arc_phase := minf(_warning_elapsed / ATTACK_WARNING, 1.0)
		draw_arc(slash_center, 22.0, -PI * 0.72, -PI * 0.72 + PI * 1.44 * arc_phase, 24, Color(1.0, 0.94, 0.7, 0.85), 2.0)
	for line in _warning_lines:
		var local_line := PackedVector2Array()
		for point in line:
			local_line.append(to_local(point))
		if _laser_warning:
			draw_polyline(local_line, Color(1.0, 0.16, 0.06, 0.52) if _laser_active else Color(1.0, 0.65, 0.24, 0.26), 20.0 if _laser_active else 2.0)
			draw_polyline(local_line, Color(1.0, 0.88, 0.58, 0.94) if _laser_active else Color(1.0, 0.32, 0.12, 0.34), 6.0 if _laser_active else 2.5)
			if not _laser_active and local_line.size() > 1:
				var t := fmod(_warning_elapsed / _warning_duration, 1.0)
				var start: Vector2 = local_line[0]
				var end: Vector2 = local_line[local_line.size() - 1]
				draw_circle(start.lerp(end, t), 3.0, Color(1.0, 0.95, 0.72, 0.95))
		else:
			draw_polyline(local_line, Color(0.25, 0.85, 1.0, 0.7), 8.0)
