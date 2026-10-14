class_name WeaponComponentData
extends Resource

enum AttackKind {
	MELEE,
	PROJECTILE,
	SPREAD,
}

enum TriggerMode {
	SEMI_AUTO,
	AUTOMATIC,
	CHARGE,
}

@export var id: StringName = &"weapon"
@export var display_name: String = "武器"
@export var attack_kind: AttackKind = AttackKind.PROJECTILE
@export var trigger_mode: TriggerMode = TriggerMode.SEMI_AUTO
@export_range(1, 99, 1) var damage: int = 1
@export_range(0.01, 5.0, 0.01) var cooldown: float = 0.25
@export_range(0.0, 100.0, 0.5) var heat_per_attack: float = 15.0
@export_range(1.0, 1000.0, 1.0) var attack_range: float = 72.0
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 440.0
@export_range(1, 12, 1) var projectile_count: int = 1
@export_range(0.0, 90.0, 1.0) var spread_degrees: float = 0.0
@export_range(0.01, 1.0, 0.01) var melee_active_seconds: float = 0.12
@export_range(1.0, 180.0, 1.0) var melee_arc_degrees: float = 70.0
@export_range(1.0, 64.0, 1.0) var melee_hit_radius: float = 10.0
@export var damage_type: StringName = &"kinetic"
@export var status_tags: PackedStringArray = []

@export_range(0.0, 1000.0, 1.0) var noise_radius: float = 0.0
