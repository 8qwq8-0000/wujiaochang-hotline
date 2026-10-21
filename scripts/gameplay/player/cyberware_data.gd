class_name CyberwareData
extends Resource

@export var module_id: StringName
@export var display_name := "义体"
@export_multiline var description := ""
@export_range(0.0, 180.0, 1.0) var targeting_half_angle_degrees := 25.0
@export_range(0.0, 1440.0, 1.0) var homing_turn_degrees_per_second := 360.0
@export_range(0.0, 256.0, 1.0) var explosion_radius := 48.0
@export_range(0, 10, 1) var explosion_damage := 1
@export_range(0.0, 5.0, 0.05) var optical_reacquire_delay := 0.60
@export_range(0.0, 1.0, 0.01) var kill_cooling_ratio := 0.30
@export_range(0.0, 30.0, 0.05) var trigger_cooldown := 0.50
@export_range(0.0, 256.0, 1.0) var overheat_pulse_radius := 64.0
@export_range(0.0, 5.0, 0.05) var overheat_pulse_stagger_seconds := 0.80
