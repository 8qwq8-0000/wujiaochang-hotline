class_name WeaponComponentData
extends Resource

enum AttackKind {
	MELEE,
	PROJECTILE,
	SPREAD,
}

@export var id: StringName = &"weapon"
@export var display_name: String = "武器"
@export var attack_kind: AttackKind = AttackKind.PROJECTILE
@export_range(1, 99, 1) var damage: int = 1
@export_range(0.01, 5.0, 0.01) var cooldown: float = 0.25
@export_range(0.0, 100.0, 0.5) var heat_per_attack: float = 15.0
@export_range(1.0, 1000.0, 1.0) var attack_range: float = 72.0
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 440.0
@export_range(1, 12, 1) var projectile_count: int = 1
@export_range(0.0, 90.0, 1.0) var spread_degrees: float = 0.0
@export var damage_type: StringName = &"kinetic"
@export var status_tags: PackedStringArray = []
