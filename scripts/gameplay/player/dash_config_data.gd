class_name DashConfigData
extends Resource

@export_range(1.0, 1000.0, 1.0) var walk_speed := 125.0
@export_range(1.0, 5000.0, 1.0) var acceleration := 1250.0
@export_range(1.0, 5000.0, 1.0) var braking := 1650.0
@export_range(1.0, 1000.0, 1.0) var dash_speed := 420.0
@export_range(0.01, 2.0, 0.01) var dash_duration := 0.20
@export_range(0.0, 10.0, 0.05) var dash_cooldown := 1.20
@export_range(0.0, 1.0, 0.01) var invulnerability_seconds := 0.15
@export_range(1.0, 40.0, 1.0) var collision_radius := 14.0
@export_range(0, 10, 1) var collision_damage := 2
@export_range(0.0, 2.0, 0.05) var collision_stagger_seconds := 0.65
