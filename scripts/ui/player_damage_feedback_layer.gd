class_name PlayerDamageFeedbackLayer
extends Control

enum Kind {
	DAMAGE,
	AREA_DAMAGE,
	ARMOR,
	PHASE,
	CIRCUIT_BREAKER,
}

const MERGE_SECONDS := 0.08
const CONTINUOUS_FULL_FEEDBACK_SECONDS := 0.85
const UI_SECTION := &"UISettings"
const REDUCED_FLASHES_SETTING := &"ReducedFlashes"

var _effects: Array[Dictionary] = []
var _continuous_feedback_at: Dictionary = {}
var _player: PlayerController
var _health_current := 0
var _health_maximum := 1
var _low_health_pulse_age := 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.low_health_pulse_requested.connect(_on_low_health_pulse)
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_bind_existing_player")


func _process(delta: float) -> void:
	_low_health_pulse_age += delta
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index].age = float(_effects[index].age) + delta
		if float(_effects[index].age) >= float(_effects[index].duration):
			_effects.remove_at(index)
	queue_redraw()


func preview_feedback() -> void:
	_add_effect(Kind.DAMAGE, Vector2(-0.82, -0.25), 0.85, true)
	_add_effect(Kind.ARMOR, Vector2(0.82, 0.15), 0.75)


func _on_tree_node_added(node: Node) -> void:
	if node is PlayerController:
		call_deferred("_bind_player", node)


func _bind_existing_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player != null:
		_bind_player(player)


func _bind_player(player: PlayerController) -> void:
	if not is_instance_valid(player) or _player == player:
		return
	_player = player
	_health_current = player.health.current_health
	_health_maximum = player.health.max_health
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	player.tree_exiting.connect(func() -> void: _player = null, CONNECT_ONE_SHOT)


func _on_health_changed(current: int, maximum: int, _delta: int) -> void:
	_health_current = current
	_health_maximum = maxi(maximum, 1)


func _on_low_health_pulse() -> void:
	_low_health_pulse_age = 0.0


func _on_damage_resolved(result: DamageResult) -> void:
	if result == null or not result.target is PlayerController:
		return
	_bind_player(result.target as PlayerController)
	var direction := _source_direction(result)
	if result.ignore_reason == DamageResult.IgnoreReason.INVULNERABLE:
		_add_effect(Kind.PHASE, direction, 0.55)
		return
	if result.fatal_damage_prevented:
		_add_effect(Kind.CIRCUIT_BREAKER, direction, 1.0, true)
		return
	if result.perfect:
		return
	if result.outcome == DamageResult.Outcome.BLOCKED:
		if result.absorbed_damage > 0:
			_add_effect(Kind.ARMOR, direction, 0.8)
		return
	if result.outcome != DamageResult.Outcome.DAMAGED or result.final_damage <= 0:
		return
	var strength := 1.0
	var heavy := _is_heavy_damage(result)
	if result.packet != null and result.packet.is_continuous_damage:
		var key := _continuous_key(result)
		var now := Time.get_ticks_usec() / 1_000_000.0
		if now - float(_continuous_feedback_at.get(key, -10.0)) < CONTINUOUS_FULL_FEEDBACK_SECONDS:
			strength = 0.32
			heavy = false
		else:
			_continuous_feedback_at[key] = now
	if result.absorbed_damage > 0:
		_add_effect(Kind.ARMOR, direction, 0.65)
		strength *= 0.72
	var kind := Kind.AREA_DAMAGE if result.packet != null and result.packet.is_area_damage else Kind.DAMAGE
	_add_effect(kind, direction, strength, heavy)


func _continuous_key(result: DamageResult) -> String:
	var source_id := result.packet.source.get_instance_id() if result.packet != null and is_instance_valid(result.packet.source) else 0
	return "%d:%s" % [source_id, String(result.packet.damage_type) if result.packet != null else ""]


func _source_direction(result: DamageResult) -> Vector2:
	if result.packet == null or not is_instance_valid(result.target):
		return Vector2.ZERO
	var target := result.target as Node2D
	var toward_source := result.packet.source_position - target.global_position
	if toward_source.is_zero_approx() and not result.packet.travel_direction.is_zero_approx():
		toward_source = -result.packet.travel_direction
	return toward_source.normalized() if not toward_source.is_zero_approx() else Vector2.ZERO


func _is_heavy_damage(result: DamageResult) -> bool:
	if not result.target is PlayerController:
		return result.final_damage >= 2
	var player := result.target as PlayerController
	var threshold := maxi(1, ceili(player.health.max_health * 0.34))
	return result.final_damage >= 2 or player.health.current_health <= threshold


func _add_effect(kind: Kind, direction: Vector2, strength: float, heavy: bool = false) -> void:
	var reduced := bool(PlayerConfig.get_config(UI_SECTION, REDUCED_FLASHES_SETTING, false))
	var duration := 0.42 if reduced else 0.24
	if kind == Kind.CIRCUIT_BREAKER:
		duration = 0.62 if reduced else 0.46
	elif kind == Kind.PHASE:
		duration = 0.34 if reduced else 0.22
	if kind in [Kind.DAMAGE, Kind.AREA_DAMAGE]:
		for effect in _effects:
			if effect.kind in [Kind.DAMAGE, Kind.AREA_DAMAGE] and float(effect.age) <= MERGE_SECONDS:
				if strength >= float(effect.strength) or heavy:
					effect.kind = kind
					effect.direction = direction
				effect.strength = maxf(float(effect.strength), strength)
				effect.heavy = bool(effect.heavy) or heavy
				effect.age = 0.0
				effect.duration = duration
			return
	_effects.append({
		"kind": kind,
		"direction": direction,
		"strength": clampf(strength, 0.0, 1.0),
		"heavy": heavy,
		"age": 0.0,
		"duration": duration,
		"reduced": reduced,
	})


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(24.0, minf(size.x, size.y) * 0.43)
	_draw_low_health_pulse()
	for effect in _effects:
		var ratio := clampf(float(effect.age) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
		var alpha := (1.0 - ratio) * float(effect.strength)
		if bool(effect.reduced):
			alpha *= 0.58
		match int(effect.kind):
			Kind.DAMAGE:
				_draw_damage_arc(center, radius, effect.direction, Color(1.0, 0.16, 0.3, alpha), bool(effect.heavy))
			Kind.AREA_DAMAGE:
				draw_arc(center, radius - 8.0 * ratio, 0.0, TAU, 64, Color(1.0, 0.14, 0.28, alpha * 0.72), 4.0, true)
			Kind.ARMOR:
				_draw_segmented_hex(center, radius - 10.0, Color(0.46, 0.9, 1.0, alpha * 0.88))
			Kind.PHASE:
				_draw_phase_line(center, radius, effect.direction, Color(0.55, 0.95, 1.0, alpha))
			Kind.CIRCUIT_BREAKER:
				_draw_circuit_breaker(center, radius, effect.direction, ratio, alpha)


func _draw_damage_arc(center: Vector2, radius: float, direction: Vector2, color: Color, heavy: bool) -> void:
	if direction.is_zero_approx():
		draw_arc(center, radius, 0.0, TAU, 64, color, 4.0, true)
		return
	var angle := direction.angle()
	draw_arc(center, radius, angle - 0.34, angle + 0.34, 18, color, 5.0 if heavy else 3.0, true)
	var point := center + direction * radius
	var tangent := direction.orthogonal()
	draw_line(point - tangent * 18.0, point - direction * 15.0, color, 3.0, true)
	draw_line(point + tangent * 18.0, point - direction * 15.0, color, 3.0, true)
	if heavy:
		var edge := Color(color, color.a * 0.28)
		draw_line(Vector2.ZERO, Vector2(size.x, 0.0), edge, 8.0)
		draw_line(Vector2(0.0, size.y), size, edge, 8.0)
		draw_line(Vector2.ZERO, Vector2(0.0, size.y), edge, 8.0)
		draw_line(Vector2(size.x, 0.0), size, edge, 8.0)


func _draw_segmented_hex(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 6:
		points.append(center + Vector2.from_angle(-PI * 0.5 + index * TAU / 6.0) * radius)
	for index in 6:
		var start := points[index].lerp(points[(index + 1) % 6], 0.08)
		var end := points[index].lerp(points[(index + 1) % 6], 0.78)
		draw_line(start, end, color, 3.0, true)


func _draw_phase_line(center: Vector2, radius: float, direction: Vector2, color: Color) -> void:
	var axis := direction if not direction.is_zero_approx() else Vector2.RIGHT
	var point := center + axis * radius
	var tangent := axis.orthogonal()
	draw_line(point - tangent * 34.0 - axis * 8.0, point + tangent * 34.0 + axis * 8.0, color, 3.0, true)
	draw_line(point - tangent * 22.0 - axis * 16.0, point + tangent * 22.0, Color(color, color.a * 0.45), 2.0, true)


func _draw_circuit_breaker(center: Vector2, radius: float, direction: Vector2, ratio: float, alpha: float) -> void:
	var axis := direction if not direction.is_zero_approx() else Vector2.UP
	_draw_damage_arc(center, radius, axis, Color(1.0, 0.12, 0.22, alpha * (1.0 - ratio * 0.65)), true)
	if ratio < 0.18:
		return
	var point := center + axis * radius
	var tangent := axis.orthogonal()
	var gold := Color(1.0, 0.83, 0.25, alpha)
	var crack := PackedVector2Array([
		point - tangent * 34.0,
		point - tangent * 12.0 - axis * 13.0,
		point + tangent * 2.0 + axis * 9.0,
		point + tangent * 17.0 - axis * 7.0,
		point + tangent * 36.0,
	])
	draw_polyline(crack, gold, 4.0, true)


func _draw_low_health_pulse() -> void:
	if _health_current <= 0 or _health_current > maxi(1, ceili(_health_maximum * 0.34)):
		return
	var pulse := pow(clampf(1.0 - _low_health_pulse_age / 0.34, 0.0, 1.0), 2.0)
	if pulse <= 0.01:
		return
	var alpha := pulse * (0.1 if bool(PlayerConfig.get_config(UI_SECTION, REDUCED_FLASHES_SETTING, false)) else 0.18)
	var color := Color(1.0, 0.12, 0.24, alpha)
	draw_line(Vector2.ZERO, Vector2(size.x, 0.0), color, 5.0)
	draw_line(Vector2(0.0, size.y), size, color, 5.0)
	draw_line(Vector2.ZERO, Vector2(0.0, size.y), color, 5.0)
	draw_line(Vector2(size.x, 0.0), size, color, 5.0)
