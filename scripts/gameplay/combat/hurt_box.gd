class_name HurtBox2DComponent
extends Area2D

signal hit_resolved(result: DamageResult)

@export var faction: CombatFaction.Id = CombatFaction.Id.NEUTRAL
@export var health_path: NodePath
@export var guard_path: NodePath
@export var actor_path: NodePath = NodePath("..")
@export_range(0.0, 2.0, 0.01) var damage_invulnerability_seconds: float = 0.0

@onready var health: HealthComponent = get_node(health_path)
@onready var guard: GuardComponent = get_node_or_null(guard_path)
@onready var actor: Node2D = get_node(actor_path)

var _invulnerability_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining - delta, 0.0)


func receive_hit(packet: DamagePacket) -> DamageResult:
	# Ignore friendly enemy hits before armor, guard, statuses or electric events.
	if packet.source_faction == CombatFaction.Id.ENEMY and faction == CombatFaction.Id.ENEMY:
		var friendly_hit := DamageResult.new()
		friendly_hit.packet = packet
		friendly_hit.target = actor
		return friendly_hit
	if actor.has_method("should_ignore_damage") and bool(actor.should_ignore_damage(packet)):
		var persona_ignored := DamageResult.new()
		persona_ignored.packet = packet
		persona_ignored.target = actor
		persona_ignored.ignore_reason = DamageResult.IgnoreReason.INVULNERABLE
		var persona_loop := Engine.get_main_loop()
		if persona_loop is SceneTree:
			var persona_events := (persona_loop as SceneTree).root.get_node_or_null("CombatEvents")
			if persona_events != null:
				persona_events.publish_damage(persona_ignored)
		hit_resolved.emit(persona_ignored)
		return persona_ignored
	if is_invulnerable():
		var ignored := DamageResult.new()
		ignored.packet = packet
		ignored.target = actor
		ignored.ignore_reason = DamageResult.IgnoreReason.INVULNERABLE
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			var events := (loop as SceneTree).root.get_node_or_null("CombatEvents")
			if events != null:
				events.publish_damage(ignored)
		hit_resolved.emit(ignored)
		return ignored
	if packet.base_damage > 0 and actor.has_method("try_absorb_hit") and bool(actor.try_absorb_hit(packet)):
		var absorbed := DamageResult.new()
		absorbed.packet = packet
		absorbed.target = actor
		absorbed.outcome = DamageResult.Outcome.BLOCKED
		absorbed.absorbed_damage = packet.base_damage
		absorbed.blocked = true
		hit_resolved.emit(absorbed)
		return absorbed
	if packet.damage_type == &"electric":
		if packet.electric_event.is_empty():
			packet.electric_event = ElectricReaction.begin_event(actor)
		if packet.electric_event.hit_ids.has(actor.get_instance_id()):
			var duplicate_hit := DamageResult.new()
			duplicate_hit.packet = packet
			duplicate_hit.target = actor
			return duplicate_hit
		packet.electric_event.hit_ids[actor.get_instance_id()] = true
	# Player-side AI personas can prepare a guard before the ordinary resolver
	# evaluates this packet. The hook is deliberately actor-owned so enemy and
	# environmental hurt boxes keep their existing behavior.
	if actor.has_method("try_persona_guard"):
		actor.try_persona_guard(packet)
	var result := DamageResolver.resolve(packet, actor, faction, health, guard)
	if result.final_damage + result.absorbed_damage == 0 and packet.damage_type == &"electric":
		packet.electric_event.hit_ids.erase(actor.get_instance_id())
	if result.final_damage + result.absorbed_damage > 0 and damage_invulnerability_seconds > 0.0:
		set_invulnerable(damage_invulnerability_seconds)
	if result.final_damage > 0 and actor.has_method("apply_knockback"):
		actor.apply_knockback(packet.knockback)
	var statuses := actor.get_node_or_null("StatusComponent")
	if result.final_damage > 0 and statuses != null:
		statuses.handle_hit(packet)
	hit_resolved.emit(result)
	return result


func set_invulnerable(duration: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining, duration)


func clear_invulnerability() -> void:
	_invulnerability_remaining = 0.0


func is_invulnerable() -> bool:
	if _invulnerability_remaining > 0.0:
		return true
	# Keep dash protection separate from post-hit/insurance protection. Ending a
	# dash must never erase another source's invulnerability window.
	var dash := actor.get_node_or_null("DashController") as DashController if is_instance_valid(actor) else null
	return dash != null and dash.provides_invulnerability()
