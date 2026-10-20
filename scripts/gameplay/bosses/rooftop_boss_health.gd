class_name RooftopBossHealth
extends HealthComponent

## Normal damage uses whole points. Linked guard damage keeps the fractional
## part separately: each of nine guard health points removes 1/3 health point
## from a six-point boss, leaving exactly three points after the wave.
var damage_enabled := false
var guard_link_active := false
var _fractional_damage := 0.0


func get_precise_health() -> float:
	return maxf(float(current_health) - _fractional_damage, 0.0)


func get_health_ratio() -> float:
	return get_precise_health() / max_health


func get_health_text() -> String:
	var value := get_precise_health()
	var amount := str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	return "%s/%d" % [amount, max_health]


func begin_guard_link() -> void:
	guard_link_active = true
	damage_enabled = false
	set_guard_damage_progress(0, 9)


func set_guard_damage_progress(lost_health: int, total_guard_health: int) -> void:
	if not guard_link_active:
		return
	var progress := clampf(float(lost_health) / maxi(total_guard_health, 1), 0.0, 1.0)
	var precise := max_health * (1.0 - progress * 0.5)
	var whole := int(ceil(precise))
	_fractional_damage = whole - precise
	set_current_health(whole)


func end_guard_link() -> void:
	guard_link_active = false
	damage_enabled = true


func apply_damage(amount: int, packet: DamagePacket) -> int:
	if not damage_enabled or guard_link_active or get_tree().paused or packet == null:
		return 0
	if packet.source_faction != CombatFaction.Id.PLAYER and not packet.reflected:
		return 0
	return super.apply_damage(amount, packet)
