class_name VFXManager
extends Node2D

const EFFECT_SCENE := preload("res://scenes/presentation/effect_flash.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/presentation/damage_number.tscn")
const AFTERIMAGE_SCENE := preload("res://scenes/presentation/afterimage_effect.tscn")
const ARC_EFFECT := preload("res://scripts/presentation/electric_arc_effect.gd")
const STAIN_LAYER_SCRIPT := preload("res://scripts/presentation/cyber_stain_layer.gd")
const PERFECT_FEEDBACK := preload("res://scripts/presentation/perfect_parry_feedback.gd")
const IMPACT_EFFECT := preload("res://scripts/presentation/impact_particle_effect.gd")
const DEATH_EFFECT := preload("res://scripts/presentation/death_burst_effect.gd")
const AFTERIMAGE_COLOR := Color(0.25, 0.85, 1.0, 0.55)
const AFTERIMAGE_DURATION := 0.25
const FEEDBACK_GROUP_WINDOW_USEC := 90_000
const FEEDBACK_QUALITY_SETTING := &"FeedbackQuality"

@export_range(1, 256, 1) var total_effect_budget: int = 64
@export_range(1, 128, 1) var prewarm_count: int = 12
@export_range(1, 12, 1) var afterimage_budget: int = 6
@export_range(1, 128, 1) var stain_budget: int = 48
@export_range(1, 64, 1) var impact_budget: int = 24
@export_range(1, 24, 1) var death_effect_budget: int = 10

var _available: Array[EffectFlash] = []
var _active: Array[EffectFlash] = []
var _available_numbers: Array[DamageNumber] = []
var _active_numbers: Array[DamageNumber] = []
var _available_afterimages: Array[AfterimageEffect] = []
var _active_afterimages: Array[AfterimageEffect] = []
var _active_arcs: Array[Node2D] = []
var _available_impacts: Array[ImpactParticleEffect] = []
var _active_impacts: Array[ImpactParticleEffect] = []
var _active_deaths: Array[DeathBurstEffect] = []
var _stain_layer: Variant
var _stain_serial := 0
var perfect_feedback: PerfectParryFeedback
var _feedback_groups: Dictionary = {}
var _continuous_player_hurt_at: Dictionary = {}


func _ready() -> void:
	perfect_feedback = PERFECT_FEEDBACK.new()
	perfect_feedback.name = "PerfectParryFeedback"
	add_child(perfect_feedback)
	_attach_stain_layer(_current_scene_host())
	for _index in prewarm_count:
		_available.append(_create_effect())
	for _index in afterimage_budget:
		_available_afterimages.append(_create_afterimage())
	for _index in mini(prewarm_count, impact_budget):
		_available_impacts.append(_create_impact())
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.weapon_cue_requested.connect(_on_weapon_cue_requested)
		events.combat_moment_requested.connect(_on_combat_moment_requested)
		events.afterimage_requested.connect(spawn_afterimage)
		events.afterimages_clear_requested.connect(clear_afterimages)
		events.effect_requested.connect(spawn_flash)
		events.electric_arc_requested.connect(_spawn_arc)
		events.environment_discharge_requested.connect(func(point: Vector2, radius: float) -> void: spawn_flash(point, Color("69d6ec"), radius, 0.3))
		events.entity_defeated.connect(_on_entity_defeated)
	var feedback := get_node_or_null("../CombatFeedbackManager") as CombatFeedbackManager
	if feedback != null:
		feedback.kill_chain_feedback.connect(_on_kill_chain_feedback)
	var scene_flow := get_node_or_null("../SceneFlow")
	if scene_flow != null and scene_flow.has_signal("scene_swapped"):
		scene_flow.scene_swapped.connect(
			func(scene: Node, _payload: Dictionary) -> void:
				perfect_feedback.clear()
				_attach_stain_layer(scene)
		)


func _current_scene_host() -> Node:
	var container := get_node_or_null("../SceneContainer")
	if container != null and container.get_child_count() > 0:
		return container.get_child(0)
	return self


func _attach_stain_layer(host: Node) -> void:
	if not is_instance_valid(host):
		host = self
	if is_instance_valid(_stain_layer):
		_stain_layer.queue_free()
	_stain_layer = STAIN_LAYER_SCRIPT.new()
	_stain_layer.name = "CyberStainLayer"
	_stain_layer.stain_budget = stain_budget
	host.add_child(_stain_layer)
	# Root-level custom drawing and floor assemblers should render first, while
	# actors render afterward. Insert immediately before the first actor.
	var actor_index := -1
	for index in host.get_child_count():
		var child := host.get_child(index)
		if child == _stain_layer:
			continue
		if child.is_in_group("player") or child.is_in_group("enemies") or child.name == "Player":
			actor_index = index
			break
	if actor_index >= 0:
		host.move_child(_stain_layer, actor_index)


func spawn_death_stain(
	world_position: Vector2,
	profile: EnemyProfile,
	motion_direction: Vector2 = Vector2.ZERO,
	impact_direction: Vector2 = Vector2.ZERO
) -> void:
	if _stain_layer == null or profile == null:
		return
	_stain_serial += 1
	var run_seed := 0
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_seed = int(run_manager.run_seed)
	var cell := Vector2i(roundi(world_position.x), roundi(world_position.y))
	var seed_value := hash("%d:%s:%d:%d:%d" % [run_seed, profile.id, cell.x, cell.y, _stain_serial])
	_stain_layer.spawn_stain(
		world_position,
		seed_value,
		int(profile.role),
		motion_direction,
		impact_direction
	)


func clear_stains() -> void:
	if _stain_layer != null:
		_stain_layer.clear_stains()


func get_stain_count() -> int:
	return _stain_layer.get_stain_count() if _stain_layer != null else 0


func _on_entity_defeated(entity: Node) -> void:
	if entity is EnemyController:
		var enemy := entity as EnemyController
		_spawn_death_effect(enemy)
		spawn_death_stain(
			enemy.global_position,
			enemy.profile,
			enemy.death_motion_direction,
			enemy.death_impact_direction
		)


func _spawn_death_effect(enemy: EnemyController) -> void:
	if _active_deaths.size() >= death_effect_budget:
		_active_deaths.pop_front().stop()
	var effect := DEATH_EFFECT.new() as DeathBurstEffect
	add_child(effect)
	_active_deaths.append(effect)
	effect.finished.connect(func(finished_effect: DeathBurstEffect) -> void:
		_active_deaths.erase(finished_effect)
		finished_effect.queue_free()
	)
	var quality_scale := 0.58 if _is_low_feedback_quality() else 1.0
	effect.play(enemy, enemy.death_weapon_id, _telegraph_clarity_scale(enemy.global_position) * quality_scale)


func _spawn_arc(from: Vector2, to: Vector2, room: Node) -> void:
	if not is_instance_valid(room) or room.is_queued_for_deletion():
		return
	if _active_arcs.size() >= total_effect_budget:
		_active_arcs.pop_front().queue_free()
	var effect: Node2D = ARC_EFFECT.new()
	effect.setup(from, to)
	room.add_child(effect)
	_active_arcs.append(effect)
	effect.tree_exiting.connect(func() -> void: _active_arcs.erase(effect))


func _on_weapon_cue_requested(weapon_id: StringName, cue: StringName, world_position: Vector2) -> void:
	if weapon_id != &"cyberware" or cue != &"thermal_pulse":
		return
	var reduced_flashes := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
	for index in 3:
		_spawn_impact(world_position, &"thermal_pulse", false, Vector2.UP.rotated((float(index) - 1.0) * 0.72), reduced_flashes)


func _on_kill_chain_feedback(
	world_position: Vector2,
	stage: int,
	weapon_id: StringName,
	offscreen: bool,
	boss_final: bool,
	suppressed: bool
) -> void:
	if offscreen or suppressed:
		return
	var reduced_flashes := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
	if boss_final:
		spawn_flash(world_position, Color(0.45, 1.0, 0.68, 0.6 if reduced_flashes else 1.0), 24.0 if reduced_flashes else 38.0, 0.22 if reduced_flashes else 0.34)
		return
	if stage < 2:
		return
	var color := _weapon_color(weapon_id)
	var capped_stage := mini(stage, CombatFeedbackManager.KILL_CHAIN_MAX_STAGE)
	spawn_flash(world_position, Color(color, 0.32 if reduced_flashes else 0.64), 8.0 + capped_stage * 1.7, 0.1 + capped_stage * 0.012)


func _on_combat_moment_requested(kind: StringName, world_position: Vector2) -> void:
	var reduced_flashes := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
	match kind:
		&"boss_phase":
			spawn_flash(world_position, Color(0.35, 0.9, 1.0, 0.45 if reduced_flashes else 0.8), 28.0 if reduced_flashes else 44.0, 0.28)
		&"boss_break":
			spawn_flash(world_position, Color(1.0, 0.72, 0.25, 0.5 if reduced_flashes else 0.95), 32.0 if reduced_flashes else 50.0, 0.32)


func spawn_flash(world_position: Vector2, color: Color, radius: float, duration: float = 0.18) -> void:
	var effect: EffectFlash
	if not _available.is_empty():
		effect = _available.pop_back()
	elif _active.size() < total_effect_budget:
		effect = _create_effect()
	else:
		effect = _active.pop_front()
	_active.append(effect)
	effect.play(world_position, color, radius, duration)


func _create_effect() -> EffectFlash:
	var effect: EffectFlash = EFFECT_SCENE.instantiate()
	add_child(effect)
	effect.visible = false
	effect.set_process(false)
	effect.finished.connect(_release_effect)
	return effect


func _create_damage_number() -> DamageNumber:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	add_child(number)
	number.visible = false
	number.set_process(false)
	number.finished.connect(_release_damage_number)
	return number


func _create_afterimage() -> AfterimageEffect:
	var afterimage: AfterimageEffect = AFTERIMAGE_SCENE.instantiate()
	add_child(afterimage)
	afterimage.finished.connect(_release_afterimage)
	return afterimage


func _create_impact() -> ImpactParticleEffect:
	var effect := IMPACT_EFFECT.new() as ImpactParticleEffect
	add_child(effect)
	effect.finished.connect(_release_impact)
	return effect


func _spawn_impact(
	world_position: Vector2,
	weapon_id: StringName,
	heavy_material: bool,
	direction: Vector2,
	reduced_flashes: bool,
	strength_scale: float = 1.0
) -> void:
	var effect: ImpactParticleEffect
	if not _available_impacts.is_empty():
		effect = _available_impacts.pop_back()
	elif _active_impacts.size() < impact_budget:
		effect = _create_impact()
	else:
		effect = _active_impacts.pop_front()
		effect.stop()
		_available_impacts.erase(effect)
	_active_impacts.append(effect)
	var quality_scale := 0.56 if _is_low_feedback_quality() else 1.0
	effect.play(world_position, weapon_id, heavy_material, direction, reduced_flashes, _telegraph_clarity_scale(world_position) * quality_scale * strength_scale)


func _release_impact(effect: ImpactParticleEffect) -> void:
	_active_impacts.erase(effect)
	if not _available_impacts.has(effect):
		_available_impacts.append(effect)


func _release_effect(effect: EffectFlash) -> void:
	_active.erase(effect)
	if not _available.has(effect):
		_available.append(effect)


func _spawn_damage_number(world_position: Vector2, amount: int) -> void:
	var number: DamageNumber
	if not _available_numbers.is_empty():
		number = _available_numbers.pop_back()
	elif _active_numbers.size() < total_effect_budget:
		number = _create_damage_number()
	else:
		number = _active_numbers.pop_front()
	_active_numbers.append(number)
	number.play(world_position, amount, Color(1.0, 0.92, 0.72))


func _release_damage_number(number: DamageNumber) -> void:
	_active_numbers.erase(number)
	if not _available_numbers.has(number):
		_available_numbers.append(number)


func spawn_afterimage(source: Node, sprite: AnimatedSprite2D) -> void:
	_spawn_afterimage_variant(source, sprite, AFTERIMAGE_COLOR, AFTERIMAGE_DURATION, Vector2.ZERO, 0.0)


func _spawn_afterimage_variant(
	source: Node,
	sprite: AnimatedSprite2D,
	color: Color,
	duration: float,
	drift_direction: Vector2,
	drift_distance: float
) -> void:
	if _is_low_feedback_quality() and _active_afterimages.size() >= 3:
		return
	var afterimage: AfterimageEffect
	if not _available_afterimages.is_empty():
		afterimage = _available_afterimages.pop_back()
	else:
		afterimage = _active_afterimages.pop_front()
		afterimage.stop()
	_active_afterimages.append(afterimage)
	if not afterimage.play(source, sprite, color, duration, drift_direction, drift_distance):
		_release_afterimage(afterimage)


func clear_afterimages(source: Node) -> void:
	if not is_instance_valid(source):
		return
	var source_id := source.get_instance_id()
	for afterimage in _active_afterimages.duplicate():
		if afterimage.source_id == source_id:
			afterimage.stop()
			_release_afterimage(afterimage)


func _release_afterimage(afterimage: AfterimageEffect) -> void:
	_active_afterimages.erase(afterimage)
	if not _available_afterimages.has(afterimage):
		_available_afterimages.append(afterimage)


func _on_damage_resolved(result: DamageResult) -> void:
	if not is_instance_valid(result.target):
		return
	var target := result.target as Node2D
	var reduced_flashes := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
	var weapon_id := result.packet.weapon_id if result.packet != null else &""
	var direction := _impact_direction(result)
	var impact_color := _weapon_color(weapon_id)
	var target_is_player := target is PlayerController
	var secondary_group_hit := _is_secondary_feedback_group(result) or _is_repeated_continuous_hurt(result)
	if result.ignore_reason == DamageResult.IgnoreReason.INVULNERABLE and target_is_player:
		_spawn_hit_afterimage(target, -direction, Color(0.48, 0.94, 1.0, 0.48), 9.0)
		return
	match result.outcome:
		DamageResult.Outcome.REFLECTED, DamageResult.Outcome.PERFECT_BLOCKED:
			spawn_flash(target.global_position, Color(1.0, 0.75, 0.15, 0.62 if reduced_flashes else 1.0), 16.0 if reduced_flashes else 21.0, 0.18 if reduced_flashes else 0.24)
			_publish_feedback_notice(&"perfect_guard", "完美格挡", Color("ffd45a"), CombatNotice.Priority.HIGH)
		DamageResult.Outcome.BLOCKED:
			spawn_flash(target.global_position, Color(0.25, 0.8, 1.0, 0.58 if reduced_flashes else 1.0), 12.0 if reduced_flashes else 15.0)
			_publish_feedback_notice(&"armor_absorb" if result.absorbed_damage > 0 else &"guard_block", "护甲吸收" if result.absorbed_damage > 0 else "格挡", Color("71dbff"), CombatNotice.Priority.NORMAL)
		DamageResult.Outcome.DAMAGED:
			if target_is_player:
				impact_color = Color("ff3157")
			elif secondary_group_hit:
				impact_color = impact_color.darkened(0.12)
			var flash_alpha := 0.3 if secondary_group_hit else (0.48 if reduced_flashes else 0.9)
			var flash_radius := 6.0 if secondary_group_hit else (8.0 if reduced_flashes else 11.0)
			spawn_flash(target.global_position, Color(impact_color, flash_alpha), flash_radius, 0.09 if secondary_group_hit else (0.09 if reduced_flashes else 0.13))
			var heavy_material := target is EnemyController and (target as EnemyController).profile != null and (target as EnemyController).profile.impact_material == EnemyProfile.ImpactMaterial.HEAVY_METAL
			var impact_weapon_id := _incoming_impact_id(result) if target_is_player else weapon_id
			_spawn_impact(target.global_position, impact_weapon_id, heavy_material, direction, reduced_flashes, 0.45 if secondary_group_hit else 1.0)
			if result.fatal_damage_prevented:
				spawn_flash(target.global_position, Color(1.0, 0.82, 0.22, 0.9), 22.0, 0.3)
				_spawn_hit_afterimage(target, -direction, Color(1.0, 0.78, 0.2, 0.58), 14.0)
			elif not secondary_group_hit:
				_spawn_hit_afterimage(target, -direction, Color(impact_color, 0.32 if reduced_flashes else 0.46), 7.0)
			if not reduced_flashes and not secondary_group_hit:
				var target_visual: Node = (target as EnemyController).visuals if target is EnemyController else ((target as PlayerController).visuals if target is PlayerController else null)
				if is_instance_valid(target_visual) and target_visual.has_method("flash_hit"):
					target_visual.flash_hit(impact_color)


func _impact_direction(result: DamageResult) -> Vector2:
	if result.packet != null:
		if not result.packet.travel_direction.is_zero_approx():
			return result.packet.travel_direction.normalized()
		if not result.packet.knockback.is_zero_approx():
			return result.packet.knockback.normalized()
	return Vector2.RIGHT


func _incoming_impact_id(result: DamageResult) -> StringName:
	if result.packet == null:
		return &"incoming_projectile"
	if result.packet.damage_type == &"explosive" or result.packet.is_area_damage:
		return &"incoming_explosive"
	if result.packet.is_melee:
		return &"incoming_melee"
	return &"incoming_projectile"


func _spawn_hit_afterimage(target: Node2D, direction: Vector2, color: Color, distance: float) -> void:
	var sprite: AnimatedSprite2D
	if target is PlayerController:
		sprite = (target as PlayerController).visuals.body_sprite
	elif target is EnemyController:
		sprite = (target as EnemyController).visuals.body
	if sprite != null:
		_spawn_afterimage_variant(target, sprite, color, 0.16, direction, distance)


func _is_secondary_feedback_group(result: DamageResult) -> bool:
	if result.packet == null or result.packet.feedback_group_id <= 0 or not is_instance_valid(result.packet.source):
		return false
	var now := Time.get_ticks_usec()
	var key := "%d:%d" % [result.packet.source.get_instance_id(), result.packet.feedback_group_id]
	var previous := int(_feedback_groups.get(key, -1_000_000))
	_feedback_groups[key] = now
	for existing_key in _feedback_groups.keys():
		if now - int(_feedback_groups[existing_key]) > 1_000_000:
			_feedback_groups.erase(existing_key)
	return now - previous <= FEEDBACK_GROUP_WINDOW_USEC


func _is_low_feedback_quality() -> bool:
	return int(PlayerConfig.get_config(&"UISettings", FEEDBACK_QUALITY_SETTING, 1)) == 0


func _is_repeated_continuous_hurt(result: DamageResult) -> bool:
	if not result.target is PlayerController or result.packet == null or not result.packet.is_continuous_damage:
		return false
	var now := Time.get_ticks_usec()
	var source_id := result.packet.source.get_instance_id() if is_instance_valid(result.packet.source) else 0
	var key := "%d:%s" % [source_id, String(result.packet.damage_type)]
	var previous := int(_continuous_player_hurt_at.get(key, -10_000_000))
	_continuous_player_hurt_at[key] = now
	return now - previous < 850_000


func _weapon_color(weapon_id: StringName) -> Color:
	match weapon_id:
		&"scattergun":
			return Color("ff9c45")
		&"rail_cannon":
			return Color("85f5ff")
		&"thermal_pulse":
			return Color("ff5b38")
		&"baton", &"initial_baton":
			return Color("dbeeff")
		_:
			return Color("ffe18a")


func _telegraph_clarity_scale(world_position: Vector2) -> float:
	for enemy_node in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy_node is EnemyController or not is_instance_valid(enemy_node):
			continue
		var enemy := enemy_node as EnemyController
		if enemy.state in [EnemyController.State.WINDUP, EnemyController.State.SELF_DESTRUCT] and enemy.global_position.distance_to(world_position) <= 110.0:
			return 0.35
	return 1.0


func _publish_feedback_notice(id: StringName, text: String, color: Color, priority: CombatNotice.Priority) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(id, text, color, priority, 0.15, 0.55)
