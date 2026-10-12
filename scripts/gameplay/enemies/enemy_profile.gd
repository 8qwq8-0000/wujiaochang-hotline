class_name EnemyProfile
extends Resource

enum Role {
	MELEE_PRESSURE,
	RANGED_SIGHTLINE,
	HEAVY_ANCHOR,
}

@export var id: StringName = &"enemy"
@export var display_name: String = "敌人"
@export var role: Role = Role.MELEE_PRESSURE
@export_range(1, 20, 1) var max_health: int = 2
@export_range(1.0, 500.0, 1.0) var move_speed: float = 95.0
@export_range(10.0, 1000.0, 1.0) var awareness_range: float = 480.0
@export_range(10.0, 1000.0, 1.0) var attack_range: float = 34.0
@export_range(0.1, 5.0, 0.1) var attack_cooldown: float = 0.9
@export_range(1, 10, 1) var damage: int = 1
@export var body_color: Color = Color(0.9, 0.2, 0.2)
