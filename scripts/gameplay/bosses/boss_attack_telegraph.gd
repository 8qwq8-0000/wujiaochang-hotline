class_name BossAttackTelegraph
extends Node2D

enum Mode {
	NONE,
	ECHO,
	ORACLE_WARNING,
	ORACLE_STRIKE,
	LASER_WARNING,
	LASER_ACTIVE,
	THUNDER_WARNING,
	THUNDER_ACTIVE,
}

var mode := Mode.NONE
var origin := Vector2.ZERO
var target := Vector2.ZERO
var laser_rect := Rect2()
var cross_lasers: Array[Rect2] = []
var thunder_cells: Array[Vector2] = []
var elapsed := 0.0
var duration := 1.0


func _process(delta: float) -> void:
	if mode == Mode.NONE:
		return
	elapsed = minf(elapsed + delta, duration)
	queue_redraw()


func show_echo(world_origin: Vector2, seconds: float) -> void:
	_begin(Mode.ECHO, seconds)
	origin = to_local(world_origin)


func show_oracle(world_target: Vector2, seconds: float, striking: bool = false) -> void:
	_begin(Mode.ORACLE_STRIKE if striking else Mode.ORACLE_WARNING, seconds)
	target = to_local(world_target)


func show_laser(world_rect: Rect2, seconds: float, active: bool = false) -> void:
	_begin(Mode.LASER_ACTIVE if active else Mode.LASER_WARNING, seconds)
	laser_rect = Rect2(to_local(world_rect.position), world_rect.size)
	cross_lasers = [laser_rect]


func show_cross(world_rects: Array[Rect2], seconds: float, active: bool = false) -> void:
	_begin(Mode.LASER_ACTIVE if active else Mode.LASER_WARNING, seconds)
	cross_lasers.clear()
	for rect in world_rects:
		cross_lasers.append(Rect2(to_local(rect.position), rect.size))


func show_thunder(world_cells: Array[Vector2], seconds: float, active: bool = false) -> void:
	_begin(Mode.THUNDER_ACTIVE if active else Mode.THUNDER_WARNING, seconds)
	thunder_cells.clear()
	for cell in world_cells:
		thunder_cells.append(to_local(cell))


func clear() -> void:
	mode = Mode.NONE
	cross_lasers.clear()
	thunder_cells.clear()
	queue_redraw()


func _begin(next_mode: Mode, seconds: float) -> void:
	mode = next_mode
	elapsed = 0.0
	duration = maxf(seconds, 0.01)
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	match mode:
		Mode.ECHO:
			for layer in 2:
				var phase := clampf(progress * 1.25 - float(layer) * 0.24, 0.0, 1.0)
				if phase > 0.0:
					var radius := lerpf(18.0, 580.0, phase)
					var alpha := sin(phase * PI) * (0.58 if layer == 0 else 0.38)
					draw_arc(origin, radius, 0.0, TAU, 96, Color(0.28, 0.94, 1.0, alpha), 3.0)
					draw_arc(origin, radius + 5.0, 0.0, TAU, 96, Color(0.82, 0.67, 1.0, alpha * 0.48), 1.0)
		Mode.ORACLE_WARNING:
			var radius := lerpf(31.0, 24.0, progress)
			var violet := Color(0.76, 0.48, 1.0, 0.92)
			var white := Color(0.96, 0.92, 1.0, 0.94)
			for quadrant in 4:
				var start := quadrant * PI * 0.5 + 0.16
				draw_arc(target, radius, start, start + 0.68, 10, violet, 2.0)
			draw_line(target - Vector2(8.0, 0.0), target + Vector2(8.0, 0.0), white, 1.0)
			draw_line(target - Vector2(0.0, 8.0), target + Vector2(0.0, 8.0), white, 1.0)
			for offset in [Vector2(0.0, -radius), Vector2(radius, 0.0), Vector2(0.0, radius), Vector2(-radius, 0.0)]:
				draw_rect(Rect2(target + offset - Vector2.ONE * 1.5, Vector2(3.0, 3.0)), violet, true)
		Mode.ORACLE_STRIKE:
			draw_circle(target, 28.0, Color(0.72, 0.28, 1.0, 0.28 * (1.0 - progress)))
			draw_arc(target, lerpf(10.0, 31.0, progress), 0.0, TAU, 32, Color(1.0, 0.9, 1.0, 1.0 - progress), 2.0)
		Mode.LASER_WARNING:
			for rect in cross_lasers:
				draw_rect(rect, Color(1.0, 0.68, 0.25, 0.38 + progress * 0.35), false, 1.5)
				draw_rect(_laser_center_line(rect, 1.0), Color(1.0, 0.9, 0.58, 0.3 + progress * 0.4), true)
				var sweep := rect.position + (Vector2(rect.size.x * progress, 0) if rect.size.x > rect.size.y else Vector2(0, rect.size.y * progress))
				draw_circle(sweep, 3.0, Color(1.0, 0.96, 0.75, 0.9))
		Mode.LASER_ACTIVE:
			for rect in cross_lasers:
				draw_rect(rect, Color(1.0, 0.16, 0.06, 0.52), true)
				draw_rect(_laser_center_line(rect, 4.0), Color(1.0, 0.88, 0.58, 0.94), true)
		Mode.THUNDER_WARNING, Mode.THUNDER_ACTIVE:
			for cell in thunder_cells:
				var polygon := BossFloorGeometry.cell_polygon(BossFloorGeometry.nearest_cell(to_global(cell)))
				for index in polygon.size():
					polygon[index] = to_local(polygon[index])
				var active := mode == Mode.THUNDER_ACTIVE
				for index in polygon.size():
					draw_line(polygon[index], polygon[(index + 1) % polygon.size()], Color(0.96, 0.79, 0.38, 0.95 if active else 0.46 + progress * 0.44), 2.0)
				var ring_radius := lerpf(15.0, 4.0, progress) if not active else 15.0 + progress * 8.0
				draw_arc(cell, ring_radius, 0.0, TAU, 24, Color(0.79, 0.65, 1.0, 0.95 if active else 0.6 + progress * 0.3), 1.5)
				for arm in 4:
					var direction := Vector2.RIGHT.rotated(float(arm) * PI * 0.5)
					draw_line(cell + direction * 5.0, cell + direction * 12.0, Color(1.0, 0.91, 0.65, 0.8), 1.0)
				if active:
					var zig := PackedVector2Array([cell + Vector2(-8, -20), cell + Vector2(2, -5), cell + Vector2(-3, 3), cell + Vector2(8, 20)])
					draw_polyline(zig, Color(0.94, 0.98, 1.0, 0.98), 4.0)
	if mode == Mode.THUNDER_WARNING:
		for cell in thunder_cells:
			_draw_edge_hint(cell, progress)
	elif mode == Mode.LASER_WARNING:
		for rect in cross_lasers:
			_draw_edge_hint(rect.get_center(), progress)


func _draw_edge_hint(local_target: Vector2, progress: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := to_local(camera.get_screen_center_position())
	var half := get_viewport_rect().size * 0.5 / camera.zoom - Vector2(20, 20)
	var displacement := local_target - center
	if absf(displacement.x) <= half.x and absf(displacement.y) <= half.y:
		return
	var t := minf(half.x / maxf(absf(displacement.x), 0.01), half.y / maxf(absf(displacement.y), 0.01))
	var point := center + displacement * t
	var direction := displacement.normalized()
	var tip := point + direction * 7.0
	var side := direction.orthogonal() * 5.0
	var color := Color(1.0, 0.8, 0.36, 0.55 + progress * 0.4)
	for index in 3:
		var vertices := PackedVector2Array([tip, point - direction * 4.0 + side, point - direction * 4.0 - side])
		draw_line(vertices[index], vertices[(index + 1) % 3], color, 1.5)


func _laser_center_line(rect: Rect2, thickness: float) -> Rect2:
	if rect.size.x < rect.size.y:
		return Rect2(rect.get_center().x - thickness * 0.5, rect.position.y, thickness, rect.size.y)
	return Rect2(rect.position.x, rect.get_center().y - thickness * 0.5, rect.size.x, thickness)
