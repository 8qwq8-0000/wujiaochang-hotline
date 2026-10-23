class_name DamageResolver
extends RefCounted


static func resolve(
	packet: DamagePacket,
	target: Node2D,
	target_faction: CombatFaction.Id,
	health: HealthComponent,
	guard: GuardComponent = null
) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = target
	if health == null or health.is_dead():
		return result
	if guard != null:
		var guard_result := guard.try_resolve(packet, target, target_faction)
		if guard_result != null:
			_publish(guard_result)
			return guard_result
	var adjusted_base := packet.base_damage
	if is_instance_valid(packet.source) and packet.source.has_method("modify_outgoing_damage"):
		adjusted_base = int(packet.source.modify_outgoing_damage(packet, target, adjusted_base))
	var multiplier := CombatFaction.damage_multiplier(packet.source_faction, target_faction, packet.reflected)
	var requested_damage := maxi(int(round(adjusted_base * multiplier)), 0)
	if requested_damage <= 0:
		_publish(result)
		return result
	var defense := target.get_node_or_null("DefenseComponent") as DefenseComponent
	if defense != null:
		result.absorbed_damage = defense.absorb(requested_damage)
		requested_damage -= result.absorbed_damage
		if requested_damage == 0:
			result.blocked = true
			result.outcome = DamageResult.Outcome.BLOCKED
			_publish(result)
			return result
	result.outcome = DamageResult.Outcome.DAMAGED
	result.final_damage = health.apply_damage(requested_damage, packet)
	result.fatal_damage_prevented = health.last_fatal_damage_prevented
	result.target_defeated = health.is_dead()
	_publish(result)
	return result


static func _publish(result: DamageResult) -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var events := (loop as SceneTree).root.get_node_or_null("CombatEvents")
		if events != null:
			events.publish_damage(result)
