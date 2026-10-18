class_name BossAttackTelegraph
extends Node2D

enum Mode {
	NONE,
	ECHO,
	ORACLE_WARNING,
	ORACLE_STRIKE,
	LASER_WARNING,
	LASER_ACTIVE,
}

var mode := Mode.NONE
var origin := Vector2.ZERO
var target := Vector2.ZERO
var laser_rect := Rect2()
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


func clear() -> void:
	mode = Mode.NONE
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
			# Echo location is intentionally invisible. The room art performs a
			# short, subtle refraction pulse instead of drawing a sonar ring.
			pass
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
			var center_line := _laser_center_line(laser_rect, 2.0)
			draw_rect(center_line, Color(1.0, 0.32, 0.12, 0.34 + progress * 0.48), true)
		Mode.LASER_ACTIVE:
			draw_rect(laser_rect, Color(1.0, 0.16, 0.06, 0.52), true)
			draw_rect(_laser_center_line(laser_rect, 4.0), Color(1.0, 0.88, 0.58, 0.94), true)


func _laser_center_line(rect: Rect2, thickness: float) -> Rect2:
	if rect.size.x < rect.size.y:
		return Rect2(rect.get_center().x - thickness * 0.5, rect.position.y, thickness, rect.size.y)
	return Rect2(rect.position.x, rect.get_center().y - thickness * 0.5, rect.size.x, thickness)
