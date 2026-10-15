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
	if is_invulnerable():
		var ignored := DamageResult.new()
		ignored.packet = packet
		ignored.target = actor
		hit_resolved.emit(ignored)
		return ignored
	var result := DamageResolver.resolve(packet, actor, faction, health, guard)
	if result.final_damage > 0 and damage_invulnerability_seconds > 0.0:
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
	return _invulnerability_remaining > 0.0
