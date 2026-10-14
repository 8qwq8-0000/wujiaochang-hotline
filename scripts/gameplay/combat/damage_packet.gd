class_name DamagePacket
extends RefCounted

var base_damage: int = 1
var source: Node
var source_faction: CombatFaction.Id = CombatFaction.Id.NEUTRAL
var damage_type: StringName = &"kinetic"
var status_tags: PackedStringArray = []
var source_position: Vector2 = Vector2.ZERO
var travel_direction: Vector2 = Vector2.ZERO
var knockback: Vector2 = Vector2.ZERO
var stagger_seconds: float = 0.0
var blockable: bool = true
var reflectable: bool = false
var is_projectile: bool = false
var is_melee: bool = false
var is_area_damage: bool = false
var reflected: bool = false


func duplicate_packet() -> DamagePacket:
	var copy := DamagePacket.new()
	copy.base_damage = base_damage
	copy.source = source if is_instance_valid(source) else null
	copy.source_faction = source_faction
	copy.damage_type = damage_type
	copy.status_tags = status_tags.duplicate()
	copy.source_position = source_position
	copy.travel_direction = travel_direction
	copy.knockback = knockback
	copy.stagger_seconds = stagger_seconds
	copy.blockable = blockable
	copy.reflectable = reflectable
	copy.is_projectile = is_projectile
	copy.is_melee = is_melee
	copy.is_area_damage = is_area_damage
	copy.reflected = reflected
	return copy
