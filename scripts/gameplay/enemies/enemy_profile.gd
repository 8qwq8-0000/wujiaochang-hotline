class_name EnemyProfile
extends Resource

enum PatrolAxis { AUTO_WALL, HORIZONTAL, VERTICAL }

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
@export_range(10.0, 1000.0, 1.0) var awareness_range: float = 240.0
@export_range(10.0, 1000.0, 1.0) var attack_range: float = 34.0
@export_range(0.1, 5.0, 0.1) var attack_cooldown: float = 0.9
@export_range(1, 10, 1) var damage: int = 1
@export var body_color: Color = Color(0.9, 0.2, 0.2)

@export_range(0.15, 1.5, 0.05) var attack_windup: float = 0.4

@export_range(10.0, 360.0, 5.0) var vision_angle_degrees: float = 120.0
@export_range(0.0, 1000.0, 1.0) var hearing_range: float = 240.0
@export_range(0.0, 1.0, 0.05) var blocked_sound_multiplier: float = 0.4
@export_range(0.0, 500.0, 1.0) var ally_alert_range: float = 96.0
@export_range(0.1, 10.0, 0.1) var alert_memory_seconds: float = 3.0

@export var patrol_enabled: bool = false
@export var patrol_axis: PatrolAxis = PatrolAxis.AUTO_WALL
@export_range(8.0, 128.0, 1.0) var patrol_distance: float = 32.0
@export_range(0.1, 1.0, 0.05) var patrol_speed_ratio: float = 0.45
@export_range(0.0, 5.0, 0.1) var patrol_pause_seconds: float = 1.2
@export_range(0.2, 5.0, 0.1) var patrol_blocked_timeout: float = 1.0
