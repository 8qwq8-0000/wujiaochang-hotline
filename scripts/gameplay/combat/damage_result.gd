class_name DamageResult
extends RefCounted

enum Outcome {
	IGNORED,
	DAMAGED,
	BLOCKED,
	PERFECT_BLOCKED,
	REFLECTED,
}

enum IgnoreReason {
	NONE,
	INVULNERABLE,
}

var outcome: Outcome = Outcome.IGNORED
var packet: DamagePacket
var target: Node
var final_damage: int = 0
var absorbed_damage: int = 0
var blocked: bool = false
var reflected: bool = false
var perfect: bool = false
var target_defeated: bool = false
var fatal_damage_prevented: bool = false
var ignore_reason: IgnoreReason = IgnoreReason.NONE
