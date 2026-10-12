class_name HurtBox2DComponent
extends Area2D

signal hit_resolved(result: DamageResult)

@export var faction: CombatFaction.Id = CombatFaction.Id.NEUTRAL
@export var health_path: NodePath
@export var guard_path: NodePath
@export var actor_path: NodePath = NodePath("..")

@onready var health: HealthComponent = get_node(health_path)
@onready var guard: GuardComponent = get_node_or_null(guard_path)
@onready var actor: Node2D = get_node(actor_path)


func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResolver.resolve(packet, actor, faction, health, guard)
	if result.final_damage > 0 and actor.has_method("apply_knockback"):
		actor.apply_knockback(packet.knockback)
	hit_resolved.emit(result)
	return result
