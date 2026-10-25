class_name EnemyTacticalBrain
extends RefCounted

## Lightweight selector for combat intent. Movement, perception and attacks
## remain owned by EnemyController; this class only chooses an intention.
enum Intent {
	APPROACH,
	FLANK_LEFT,
	FLANK_RIGHT,
	HOLD_AND_ATTACK,
	RETREAT,
	STRAFE_LEFT,
	STRAFE_RIGHT,
	INTERCEPT,
}

var current_intent: Intent = Intent.APPROACH
var _decision_interval := 0.15
var _decision_remaining := 0.0
var _preferred_side := 1.0


func configure(decision_interval: float, preferred_side: float) -> void:
	_decision_interval = maxf(decision_interval, 0.05)
	_preferred_side = -1.0 if preferred_side < 0.0 else 1.0
	force_rethink()


func tick(delta: float, snapshot: Dictionary) -> Intent:
	_decision_remaining = maxf(_decision_remaining - delta, 0.0)
	if _decision_remaining <= 0.0:
		current_intent = decide(snapshot, _preferred_side)
		_decision_remaining = _decision_interval
	return current_intent


func force_rethink() -> void:
	_decision_remaining = 0.0


static func decide(snapshot: Dictionary, preferred_side: float = 1.0) -> Intent:
	var role := int(snapshot.get("role", EnemyProfile.Role.MELEE_PRESSURE))
	var distance := maxf(float(snapshot.get("distance", 0.0)), 0.0)
	var attack_range := maxf(float(snapshot.get("attack_range", 1.0)), 1.0)
	var distance_ratio := distance / attack_range
	var cooldown_ready := float(snapshot.get("cooldown_remaining", 0.0)) <= 0.0
	var nearby_allies := maxi(int(snapshot.get("nearby_allies", 0)), 0)
	var side_left := preferred_side < 0.0

	match role:
		EnemyProfile.Role.RANGED_SIGHTLINE:
			if distance_ratio <= 1.0 and cooldown_ready:
				return Intent.HOLD_AND_ATTACK
			# Strafing outside firing range can orbit forever without a shot.
			if distance_ratio <= 1.0:
				return Intent.STRAFE_LEFT if side_left else Intent.STRAFE_RIGHT
			return Intent.APPROACH
		EnemyProfile.Role.HEAVY_ANCHOR:
			return Intent.HOLD_AND_ATTACK if distance_ratio <= 1.0 else Intent.INTERCEPT
		_:
			if distance_ratio <= 1.0:
				return Intent.HOLD_AND_ATTACK
			if nearby_allies > 0 and distance_ratio > 1.75:
				return Intent.FLANK_LEFT if side_left else Intent.FLANK_RIGHT
			return Intent.APPROACH
