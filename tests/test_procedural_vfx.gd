@tool
extends McpTestSuite

const COATING_SCRIPT := preload("res://scripts/presentation/procedural_coating_2d.gd")
const STAIN_LAYER_SCRIPT := preload("res://scripts/presentation/cyber_stain_layer.gd")
const IMPACT_SCRIPT := preload("res://scripts/presentation/impact_particle_effect.gd")
const MOVEMENT_SCRIPT := preload("res://scripts/presentation/movement_particle_effect.gd")


func suite_name() -> String:
	return "procedural_vfx"


func test_coating_layout_is_seeded_and_bounded() -> void:
	var coating: Variant = track(COATING_SCRIPT.new())
	var test_rects: Array[Rect2] = [
		Rect2(0.0, 0.0, 12.0, 6.0),
		Rect2(14.0, 0.0, 10.0, 6.0),
	]
	coating.safe_rects = test_rects
	coating.mark_count = 2
	coating.configure(8128, &"test_weapon")
	var first_hash: int = coating.get_layout_hash()
	assert_eq(coating.get_mark_count(), 2)
	coating.configure(8128, &"test_weapon")
	assert_eq(coating.get_layout_hash(), first_hash)
	coating.configure(8129, &"test_weapon")
	assert_ne(coating.get_layout_hash(), first_hash)


func test_stains_are_deterministic_and_respect_budget() -> void:
	var layer: Variant = track(STAIN_LAYER_SCRIPT.new())
	layer.stain_budget = 2
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	layer.spawn_stain(Vector2.ZERO, 4001, EnemyProfile.Role.MELEE_PRESSURE)
	var first_hash: int = layer.get_stain_shape_hash(0)
	layer.clear_stains()
	layer.spawn_stain(Vector2.ZERO, 4001, EnemyProfile.Role.MELEE_PRESSURE)
	assert_eq(layer.get_stain_shape_hash(0), first_hash)
	layer.spawn_stain(Vector2(10.0, 0.0), 4002, EnemyProfile.Role.RANGED_SIGHTLINE)
	layer.spawn_stain(Vector2(20.0, 0.0), 4003, EnemyProfile.Role.HEAVY_ANCHOR)
	assert_eq(layer.get_stain_count(), 2)
	assert_eq(layer.get_retired_stain_count(), 1)


func test_stain_shape_uses_motion_and_impact_direction() -> void:
	var layer: Variant = track(STAIN_LAYER_SCRIPT.new())
	layer.obstacle_collision_mask = 0
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	layer.spawn_stain(
		Vector2.ZERO,
		8119,
		EnemyProfile.Role.MELEE_PRESSURE,
		Vector2.RIGHT,
		Vector2.DOWN
	)
	var data: Dictionary = layer.get_stain_debug_data(0)
	assert_eq(data["motion_direction"], Vector2.RIGHT)
	assert_eq(data["impact_direction"], Vector2.DOWN)
	var outline: PackedVector2Array = data["outer"]
	var minimum_x := INF
	var maximum_x := -INF
	for point in outline:
		minimum_x = minf(minimum_x, point.x)
		maximum_x = maxf(maximum_x, point.x)
	assert_gt(absf(minimum_x), maximum_x)
	var droplet_positions: PackedVector2Array = data["droplet_positions"]
	var average_y := 0.0
	for point in droplet_positions:
		average_y += point.y
	average_y /= maxf(float(droplet_positions.size()), 1.0)
	assert_gt(average_y, 0.0)


func test_stain_stops_processing_after_settling() -> void:
	var layer: Variant = track(STAIN_LAYER_SCRIPT.new())
	layer.obstacle_collision_mask = 0
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	layer.spawn_stain(Vector2.ZERO, 9201)
	layer._process(1.0)
	assert_false(layer.is_processing())


func test_vfx_manager_owns_and_clears_stains() -> void:
	var manager := track(VFXManager.new()) as VFXManager
	manager.prewarm_count = 1
	manager.stain_budget = 3
	(Engine.get_main_loop() as SceneTree).root.add_child(manager)
	var profile := EnemyProfile.new()
	profile.id = &"test"
	profile.role = EnemyProfile.Role.RANGED_SIGHTLINE
	manager.spawn_death_stain(Vector2(12.0, 18.0), profile)
	assert_eq(manager.get_stain_count(), 1)
	manager.clear_stains()
	assert_eq(manager.get_stain_count(), 0)


func test_impact_particles_follow_weapon_material_and_accessibility_budget() -> void:
	var effect: ImpactParticleEffect = track(IMPACT_SCRIPT.new()) as ImpactParticleEffect
	(Engine.get_main_loop() as SceneTree).root.add_child(effect)
	effect.play(Vector2.ZERO, &"scattergun", false, Vector2.RIGHT, false, 1.0)
	var standard_count := effect.get_particle_count()
	effect.play(Vector2.ZERO, &"scattergun", true, Vector2.RIGHT, false, 1.0)
	var heavy_count := effect.get_particle_count()
	effect.play(Vector2.ZERO, &"scattergun", false, Vector2.RIGHT, true, 1.0)
	var reduced_count := effect.get_particle_count()
	assert_gt(heavy_count, standard_count)
	assert_true(reduced_count < standard_count)
	assert_gt(reduced_count, 1)


func test_movement_feedback_uses_distinct_persona_palettes_and_shapes() -> void:
	assert_ne(
		MovementFeedbackStyle.primary_color(TalentCoreController.DEEP_NINJA),
		MovementFeedbackStyle.primary_color(TalentCoreController.LEGENDARY_MASTER)
	)
	assert_ne(
		MovementFeedbackStyle.visual_style(TalentCoreController.LEGENDARY_MASTER),
		MovementFeedbackStyle.visual_style(TalentCoreController.ROCK_VIGILANTE)
	)
	assert_gt(MovementFeedbackStyle.effect_strength(&"ninja_takeover"), MovementFeedbackStyle.effect_strength(&"dash"))


func test_movement_particles_keep_identity_when_quality_and_flashes_are_reduced() -> void:
	var effect := track(MOVEMENT_SCRIPT.new()) as MovementParticleEffect
	(Engine.get_main_loop() as SceneTree).root.add_child(effect)
	effect.play(
		Vector2.ZERO,
		Vector2(48.0, 0.0),
		TalentCoreController.ROCK_VIGILANTE,
		&"dash",
		&"path",
		Vector2.RIGHT,
		false,
		false,
		1.0
	)
	var standard_count := effect.get_particle_count()
	effect.play(
		Vector2.ZERO,
		Vector2(48.0, 0.0),
		TalentCoreController.ROCK_VIGILANTE,
		&"dash",
		&"path",
		Vector2.RIGHT,
		false,
		true,
		0.55
	)
	var reduced_count := effect.get_particle_count()
	assert_gt(standard_count, reduced_count)
	assert_gt(reduced_count, 1)


func test_dash_exposes_presentation_kind_without_changing_dash_rules() -> void:
	var dash := track(DashController.new()) as DashController
	var body := track(CharacterBody2D.new()) as CharacterBody2D
	assert_true(dash.start_dash(body, Vector2.RIGHT, Vector2.RIGHT, &"ninja_borrowed_step"))
	assert_eq(dash.active_effect_kind, &"ninja_borrowed_step")
	assert_true(dash.is_dashing())
	dash.cancel_dash(false)
	assert_false(dash.is_dashing())
	assert_eq(dash.active_effect_kind, &"dash")


func test_dense_hitstop_keeps_only_strongest_request_in_merge_window() -> void:
	var manager := CombatFeedbackManager.new()
	var original_scale := Engine.time_scale
	manager._request_global_slow(0.05)
	var first_end: int = manager._slow_until_usec
	manager._request_global_slow(0.02)
	assert_eq(manager._slow_until_usec, first_end)
	manager._request_global_slow(0.075)
	assert_gt(manager._slow_until_usec, first_end)
	manager._restore_time_scale()
	assert_true(is_equal_approx(Engine.time_scale, original_scale))
	manager.free()


func test_feedback_group_marks_followup_targets_as_secondary() -> void:
	var manager := CombatFeedbackManager.new()
	var source := Node.new()
	var packet := DamagePacket.new()
	packet.source = source
	packet.feedback_group_id = 7
	var result := DamageResult.new()
	result.packet = packet
	assert_false(manager._is_secondary_feedback_group(result))
	assert_true(manager._is_secondary_feedback_group(result))
	manager.free()
	source.free()


func test_player_damage_overlay_merges_dense_hurt_feedback() -> void:
	var layer := PlayerDamageFeedbackLayer.new()
	layer._add_effect(PlayerDamageFeedbackLayer.Kind.DAMAGE, Vector2.LEFT, 0.4)
	layer._add_effect(PlayerDamageFeedbackLayer.Kind.DAMAGE, Vector2.RIGHT, 0.9, true)
	assert_eq(layer._effects.size(), 1)
	assert_eq(layer._effects[0].direction, Vector2.RIGHT)
	assert_true(layer._effects[0].heavy)
	layer.free()


func test_kill_chain_accepts_player_direct_damage_and_rejects_environment() -> void:
	var manager := CombatFeedbackManager.new()
	var player := PlayerController.new()
	var enemy := EnemyController.new()
	var packet := DamagePacket.new()
	packet.source = player
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.weapon_id = &"service_pistol"
	var result := DamageResult.new()
	result.packet = packet
	result.target = enemy
	result.target_defeated = true
	assert_true(manager._qualifies_player_kill(result))
	packet.source_faction = CombatFaction.Id.ENVIRONMENT
	assert_false(manager._qualifies_player_kill(result))
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.source = enemy
	assert_false(manager._qualifies_player_kill(result))
	manager.free()
	player.free()
	enemy.free()


func test_kill_chain_tail_only_emits_for_multi_kill() -> void:
	var manager := CombatFeedbackManager.new()
	var ended_stages: Array[int] = []
	manager.kill_chain_ended.connect(func(stage: int) -> void: ended_stages.append(stage))
	manager._kill_chain_count = 1
	manager._reset_kill_chain(true)
	assert_true(ended_stages.is_empty())
	manager._kill_chain_count = 8
	manager._reset_kill_chain(true)
	assert_eq(ended_stages, [CombatFeedbackManager.KILL_CHAIN_MAX_STAGE])
	manager.free()
