class_name GuardComponent
extends Node

signal state_changed(state: State)
signal perfect_guarded(result: DamageResult)
signal heat_refund_requested(amount: float)

enum State {
	IDLE,
	STARTUP,
	PERFECT,
	NORMAL,
	RECOVERY,
}

@export_range(1.0, 360.0, 1.0) var guard_arc_degrees: float = 120.0
@export_range(0.0, 1.0, 0.01) var startup_seconds: float = 0.06
@export_range(0.01, 1.0, 0.01) var perfect_seconds: float = 0.12
@export_range(0.01, 1.0, 0.01) var normal_seconds: float = 0.18
@export_range(0.0, 1.0, 0.01) var recovery_seconds: float = 0.22
@export_range(0.0, 100.0, 1.0) var perfect_heat_refund: float = 18.0

var state: State = State.IDLE
var guard_direction: Vector2 = Vector2.RIGHT
var _time_remaining: float = 0.0
var _state_duration: float = 0.0
var recovery_multiplier := 1.0
var equipment_window_bonus := 0.0


func _physics_process(delta: float) -> void:
	advance_timing(delta)


func begin_guard(direction: Vector2) -> bool:
	if state != State.IDLE:
		return false
	guard_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_enter_state(State.STARTUP, startup_seconds)
	return true


func update_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		guard_direction = direction.normalized()


func can_attack() -> bool:
	return state == State.IDLE


func is_guard_active() -> bool:
	return state == State.PERFECT or state == State.NORMAL


func get_state_progress() -> float:
	if _state_duration <= 0.0:
		return 1.0
	return clampf(1.0 - _time_remaining / _state_duration, 0.0, 1.0)


func reset_to_idle() -> void:
	_enter_state(State.IDLE, 0.0)


func advance_timing(delta: float) -> void:
	var remaining_delta := maxf(delta, 0.0)
	while state != State.IDLE and remaining_delta >= _time_remaining:
		remaining_delta -= _time_remaining
		_advance_state()
		if _time_remaining <= 0.0 and state != State.IDLE:
			continue
	if state != State.IDLE:
		_time_remaining -= remaining_delta


func try_resolve(packet: DamagePacket, target: Node2D, target_faction: CombatFaction.Id) -> DamageResult:
	if not is_guard_active() or not packet.blockable or packet.is_area_damage:
		return null
	if not _is_inside_guard_arc(packet, target.global_position):
		return null
	var result := DamageResult.new()
	result.packet = packet
	result.target = target
	result.blocked = true
	if state == State.PERFECT:
		result.perfect = true
		if packet.is_projectile and packet.reflectable:
			result.outcome = DamageResult.Outcome.REFLECTED
			result.reflected = true
			var reflected_packet := packet.duplicate_packet()
			reflected_packet.source = target
			reflected_packet.source_faction = target_faction
			reflected_packet.travel_direction = -packet.travel_direction
			reflected_packet.reflected = true
			result.packet = reflected_packet
		else:
			result.outcome = DamageResult.Outcome.PERFECT_BLOCKED
			if packet.is_melee and is_instance_valid(packet.source) and packet.source.has_method("apply_stagger"):
				packet.source.apply_stagger(maxf(packet.stagger_seconds, 0.65))
		heat_refund_requested.emit(perfect_heat_refund)
		perfect_guarded.emit(result)
		_enter_state(State.NORMAL, normal_seconds)
	else:
		result.outcome = DamageResult.Outcome.BLOCKED
	return result


func _is_inside_guard_arc(packet: DamagePacket, target_position: Vector2) -> bool:
	var toward_source := packet.source_position - target_position
	if toward_source.is_zero_approx() and not packet.travel_direction.is_zero_approx():
		toward_source = -packet.travel_direction
	if toward_source.is_zero_approx():
		return false
	var threshold := cos(deg_to_rad(guard_arc_degrees * 0.5))
	return guard_direction.dot(toward_source.normalized()) >= threshold


func _advance_state() -> void:
	match state:
		State.STARTUP:
			_enter_state(State.PERFECT, perfect_seconds + equipment_window_bonus)
		State.PERFECT:
			_enter_state(State.NORMAL, normal_seconds)
		State.NORMAL:
			_enter_state(State.RECOVERY, recovery_seconds * recovery_multiplier)
		State.RECOVERY:
			_enter_state(State.IDLE, 0.0)


func _enter_state(next_state: State, duration: float) -> void:
	state = next_state
	_time_remaining = maxf(duration, 0.0)
	_state_duration = _time_remaining
	state_changed.emit(state)
