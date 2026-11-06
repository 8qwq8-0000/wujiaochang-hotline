class_name CyberwareData
extends Resource

enum CircuitKind {
	STARTER,
	MODIFIER,
	EXECUTOR,
	RESTRUCTURER,
}

enum Grade {
	STARTER,
	STANDARD,
	MILITARY,
	FORBIDDEN,
}

@export var module_id: StringName
@export var display_name := "义体"
@export_multiline var description := ""
@export var circuit_kind := CircuitKind.EXECUTOR
@export var grade := Grade.STANDARD
@export var target_scope: Array[StringName] = []
@export_range(0.0, 200.0, 1.0) var circuit_energy_cost := 0.0
@export_range(0.0, 200.0, 1.0) var fixed_energy_refund := 0.0
@export var circuit_tags: PackedStringArray = []
@export_range(0.0, 180.0, 1.0) var targeting_half_angle_degrees := 25.0
@export_range(0.0, 1440.0, 1.0) var homing_turn_degrees_per_second := 360.0
@export_range(0.0, 256.0, 1.0) var explosion_radius := 48.0
@export_range(0, 10, 1) var explosion_damage := 1
@export_range(0.0, 5.0, 0.05) var optical_reacquire_delay := 0.60
@export_range(0.0, 30.0, 0.05) var trigger_cooldown := 0.50
@export_range(0.0, 256.0, 1.0) var overheat_pulse_radius := 64.0
@export_range(0.0, 5.0, 0.05) var overheat_pulse_stagger_seconds := 0.80
@export_range(0.0, 10.0, 0.05) var momentum_charge_seconds := 1.50
@export_range(0.0, 256.0, 1.0) var trajectory_echo_radius := 96.0
@export_range(0.0, 1.0, 0.05) var trajectory_echo_damage_ratio := 0.50
@export_range(0.0, 128.0, 1.0) var takeover_radius := 28.0
@export_range(0.0, 512.0, 1.0) var takeover_target_radius := 220.0
@export_range(0.0, 1440.0, 1.0) var takeover_homing_turn_degrees_per_second := 720.0
@export_range(0.0, 256.0, 1.0) var arc_chain_radius := 64.0
@export_range(0.0, 5.0, 0.05) var arc_paralysis_seconds := 0.20
@export_range(0, 8, 1) var arc_chain_targets := 2
@export_range(0.0, 256.0, 1.0) var inertia_pulse_radius := 56.0
@export_range(0.0, 5.0, 0.05) var inertia_pulse_stagger_seconds := 0.35
@export_range(0.0, 500.0, 5.0) var inertia_pulse_knockback := 180.0
@export_range(0.0, 10.0, 0.05) var axon_cooldown_reduction := 0.75
@export_range(0.0, 1.0, 0.05) var micro_rotor_hit_refund_ratio := 0.25
@export_range(0.0, 1.0, 0.05) var micro_rotor_kill_refund_ratio := 0.50
