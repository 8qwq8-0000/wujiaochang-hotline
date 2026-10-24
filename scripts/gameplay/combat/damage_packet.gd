class_name DamagePacket
extends RefCounted

var base_damage: int = 1
var source: Node
var source_faction: CombatFaction.Id = CombatFaction.Id.NEUTRAL
var weapon_id: StringName = &""
var damage_type: StringName = &"kinetic"
var status_tags: PackedStringArray = []
var allow_status_reactions := true
# Shared only by hits belonging to one electric event; duplicate_packet preserves it.
var electric_event: Dictionary = {}
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
## Presentation-only grouping for pellets, beams, and other hits produced by one attack.
## It never participates in damage resolution.
var feedback_group_id: int = 0
## Marks recurring damage so presentation can show one clear warning followed by
## restrained pulses instead of replaying the full hit package every tick.
var is_continuous_damage: bool = false
## Environmental floor/hazard damage. Enemy explosives deliberately leave this false.
var is_terrain_damage: bool = false
## Marks the non-projectile hit that should create Overload Scream's first-hit burst.
var terminal_attack: bool = false


func duplicate_packet() -> DamagePacket:
	var copy := DamagePacket.new()
	copy.base_damage = base_damage
	copy.source = source if is_instance_valid(source) else null
	copy.source_faction = source_faction
	copy.weapon_id = weapon_id
	copy.damage_type = damage_type
	copy.status_tags = status_tags.duplicate()
	copy.allow_status_reactions = allow_status_reactions
	copy.electric_event = electric_event
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
	copy.feedback_group_id = feedback_group_id
	copy.is_continuous_damage = is_continuous_damage
	copy.is_terrain_damage = is_terrain_damage
	copy.terminal_attack = terminal_attack
	return copy
