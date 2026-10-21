class_name CombatPlayerConfig
extends Resource

@export_range(1, 20, 1) var max_health: int = 3
@export_range(0.0, 2.0, 0.01) var damage_invulnerability_seconds: float = 0.18
@export_range(1.0, 5000.0, 1.0) var knockback_recovery: float = 900.0
@export_range(0.0, 64.0, 1.0) var aim_deadzone: float = 8.0
@export_range(0.0, 160.0, 1.0) var camera_look_ahead: float = 12.0
@export_range(0.1, 30.0, 0.1) var camera_look_ahead_response: float = 4.0
@export var debug_loadout_enabled: bool = false
@export var default_weapon: WeaponComponentData
