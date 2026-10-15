@tool
extends McpTestSuite


func suite_name() -> String:
	return "enemy_tactical_brain"


func _snapshot(role: EnemyProfile.Role, distance: float, attack_range: float, cooldown: float, allies: int = 0) -> Dictionary:
	return {
		"role": role,
		"distance": distance,
		"attack_range": attack_range,
		"cooldown_remaining": cooldown,
		"nearby_allies": allies,
	}


func test_melee_approaches_solo_and_flanks_with_support() -> void:
	var solo := EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.MELEE_PRESSURE, 100.0, 28.0, 0.0, 0), -1.0)
	var left := EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.MELEE_PRESSURE, 100.0, 28.0, 0.0, 1), -1.0)
	var right := EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.MELEE_PRESSURE, 100.0, 28.0, 0.0, 1), 1.0)
	assert_eq(solo, EnemyTacticalBrain.Intent.APPROACH)
	assert_eq(left, EnemyTacticalBrain.Intent.FLANK_LEFT)
	assert_eq(right, EnemyTacticalBrain.Intent.FLANK_RIGHT)


func test_ranged_retreats_strafes_and_attacks_by_spacing_and_cooldown() -> void:
	var close := EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.RANGED_SIGHTLINE, 80.0, 235.0, 0.0), 1.0)
	var cooling := EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.RANGED_SIGHTLINE, 190.0, 235.0, 0.6), -1.0)
	var ready := EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.RANGED_SIGHTLINE, 190.0, 235.0, 0.0), 1.0)
	assert_eq(close, EnemyTacticalBrain.Intent.RETREAT)
	assert_eq(cooling, EnemyTacticalBrain.Intent.STRAFE_LEFT)
	assert_eq(ready, EnemyTacticalBrain.Intent.HOLD_AND_ATTACK)


func test_heavy_leads_target_until_it_reaches_attack_range() -> void:
	assert_eq(
		EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.HEAVY_ANCHOR, 100.0, 34.0, 0.0)),
		EnemyTacticalBrain.Intent.INTERCEPT
	)
	assert_eq(
		EnemyTacticalBrain.decide(_snapshot(EnemyProfile.Role.HEAVY_ANCHOR, 30.0, 34.0, 0.0)),
		EnemyTacticalBrain.Intent.HOLD_AND_ATTACK
	)


func test_decision_interval_prevents_per_frame_intent_jitter() -> void:
	var brain := EnemyTacticalBrain.new()
	brain.configure(0.2, 1.0)
	var far := _snapshot(EnemyProfile.Role.MELEE_PRESSURE, 100.0, 28.0, 0.0)
	var close := _snapshot(EnemyProfile.Role.MELEE_PRESSURE, 20.0, 28.0, 0.0)
	assert_eq(brain.tick(0.0, far), EnemyTacticalBrain.Intent.APPROACH)
	assert_eq(brain.tick(0.05, close), EnemyTacticalBrain.Intent.APPROACH)
	assert_eq(brain.tick(0.2, close), EnemyTacticalBrain.Intent.HOLD_AND_ATTACK)
