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
@export_range(1.0, 500.0, 1.0) var move_speed: float = 76.0
@export var full_room_awareness := false
@export_range(10.0, 1000.0, 1.0) var awareness_range: float = 240.0
@export_range(10.0, 1000.0, 1.0) var attack_range: float = 34.0
@export_range(0.1, 5.0, 0.1) var attack_cooldown: float = 1.13
@export_range(1, 10, 1) var damage: int = 1
@export_range(0.0, 500.0, 1.0) var attack_knockback: float = 90.0
@export var body_color: Color = Color(0.9, 0.2, 0.2)

@export_range(0.15, 1.5, 0.05) var attack_windup: float = 0.4

@export_range(10.0, 360.0, 5.0) var vision_angle_degrees: float = 120.0
@export_range(0.0, 1000.0, 1.0) var hearing_range: float = 240.0
@export_range(0.0, 1.0, 0.05) var blocked_sound_multiplier: float = 0.4
@export_range(0.0, 500.0, 1.0) var ally_alert_range: float = 96.0
@export_range(0.1, 10.0, 0.1) var alert_memory_seconds: float = 3.0

@export_group("Role Abilities")
@export var barrier_enabled: bool = false
@export var barrier_duration: float = 3.0
@export var barrier_cooldown: float = 6.0
@export var self_destruct_enabled: bool = false
@export_range(0.1, 2.0, 0.05) var self_destruct_delay: float = 0.45
@export_range(1, 10, 1) var self_destruct_damage: int = 1
@export_range(0.0, 500.0, 1.0) var self_destruct_knockback: float = 260.0
@export_range(0.0, 1000.0, 1.0) var self_destruct_noise_radius: float = 300.0

@export_group("Tactical AI")
@export var tactical_enabled: bool = true
@export_range(0.05, 0.5, 0.05) var decision_interval: float = 0.15
@export_range(16.0, 128.0, 1.0) var flank_radius: float = 48.0
@export_range(5.0, 60.0, 1.0) var flank_angle_degrees: float = 42.0
@export_range(5.0, 60.0, 1.0) var strafe_angle_degrees: float = 20.0
@export_range(0.0, 0.5, 0.05) var target_prediction_seconds: float = 0.2

@export_group("Patrol")
@export var patrol_enabled: bool = false
@export var patrol_axis: PatrolAxis = PatrolAxis.AUTO_WALL
@export_range(8.0, 128.0, 1.0) var patrol_distance: float = 32.0
@export_range(0.1, 1.0, 0.05) var patrol_speed_ratio: float = 0.45
@export_range(0.0, 5.0, 0.1) var patrol_pause_seconds: float = 1.2
@export_range(0.2, 5.0, 0.1) var patrol_blocked_timeout: float = 1.0
