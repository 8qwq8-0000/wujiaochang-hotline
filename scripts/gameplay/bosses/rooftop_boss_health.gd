class_name RooftopBossHealth
extends HealthComponent

## Each confirmed guard defeat removes exactly one of six health points.
var damage_enabled := false
var guard_link_active := false
var _guard_defeats := 0


func get_precise_health() -> float:
	return float(current_health)


func get_health_ratio() -> float:
	return get_precise_health() / max_health


func get_health_text() -> String:
	var value := get_precise_health()
	var amount := str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	return "%s/%d" % [amount, max_health]


func begin_guard_link() -> void:
	guard_link_active = true
	damage_enabled = false
	_guard_defeats = 0


func set_guard_damage_progress(lost_health: int, total_guard_health: int) -> void:
	if not guard_link_active:
		return
	# Counts confirmed defeats, never partial damage, healing or repeat signals.
	_guard_defeats = maxi(_guard_defeats, clampi(lost_health, 0, total_guard_health))
	set_current_health(maxi(max_health - _guard_defeats, 1))


func end_guard_link() -> void:
	guard_link_active = false
	damage_enabled = true


func apply_damage(amount: int, packet: DamagePacket) -> int:
	if not damage_enabled or guard_link_active or get_tree().paused or packet == null:
		return 0
	if packet.source_faction != CombatFaction.Id.PLAYER and not packet.reflected:
		return 0
	return super.apply_damage(amount, packet)
