class_name EnemySpawnMarker
extends Marker2D

@export var role_tag: StringName = &"melee_pressure"
@export var profile: EnemyProfile
@export var mandatory: bool = true
@export_range(0.0, 1.0, 0.05) var activation_chance: float = 1.0


func should_activate(random: RandomNumberGenerator) -> bool:
	return mandatory or random.randf() <= activation_chance
