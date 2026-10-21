class_name VFXManager
extends Node2D

const EFFECT_SCENE := preload("res://scenes/presentation/effect_flash.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/presentation/damage_number.tscn")
const AFTERIMAGE_SCENE := preload("res://scenes/presentation/afterimage_effect.tscn")
const ARC_EFFECT := preload("res://scripts/presentation/electric_arc_effect.gd")
const STAIN_LAYER_SCRIPT := preload("res://scripts/presentation/cyber_stain_layer.gd")
const PERFECT_FEEDBACK := preload("res://scripts/presentation/perfect_parry_feedback.gd")
const AFTERIMAGE_COLOR := Color(0.25, 0.85, 1.0, 0.55)
const AFTERIMAGE_DURATION := 0.25

@export_range(1, 256, 1) var total_effect_budget: int = 64
@export_range(1, 128, 1) var prewarm_count: int = 12
@export_range(1, 12, 1) var afterimage_budget: int = 6
@export_range(1, 128, 1) var stain_budget: int = 48

var _available: Array[EffectFlash] = []
var _active: Array[EffectFlash] = []
var _available_numbers: Array[DamageNumber] = []
var _active_numbers: Array[DamageNumber] = []
var _available_afterimages: Array[AfterimageEffect] = []
var _active_afterimages: Array[AfterimageEffect] = []
var _active_arcs: Array[Node2D] = []
var _stain_layer: Variant
var _stain_serial := 0
var perfect_feedback: PerfectParryFeedback


func _ready() -> void:
	perfect_feedback = PERFECT_FEEDBACK.new()
	perfect_feedback.name = "PerfectParryFeedback"
	add_child(perfect_feedback)
	_attach_stain_layer(_current_scene_host())
	for _index in prewarm_count:
		_available.append(_create_effect())
		_available_numbers.append(_create_damage_number())
	for _index in afterimage_budget:
		_available_afterimages.append(_create_afterimage())
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.afterimage_requested.connect(spawn_afterimage)
		events.afterimages_clear_requested.connect(clear_afterimages)
		events.effect_requested.connect(spawn_flash)
		events.electric_arc_requested.connect(_spawn_arc)
		events.environment_discharge_requested.connect(func(point: Vector2, radius: float) -> void: spawn_flash(point, Color("69d6ec"), radius, 0.3))
		events.entity_defeated.connect(_on_entity_defeated)
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
		spawn_death_stain(
			enemy.global_position,
			enemy.profile,
			enemy.death_motion_direction,
			enemy.death_impact_direction
		)


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
	var afterimage: AfterimageEffect
	if not _available_afterimages.is_empty():
		afterimage = _available_afterimages.pop_back()
	else:
		afterimage = _active_afterimages.pop_front()
		afterimage.stop()
	_active_afterimages.append(afterimage)
	if not afterimage.play(source, sprite, AFTERIMAGE_COLOR, AFTERIMAGE_DURATION):
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
	match result.outcome:
		DamageResult.Outcome.REFLECTED, DamageResult.Outcome.PERFECT_BLOCKED:
			spawn_flash(target.global_position, Color(1.0, 0.75, 0.15), 21.0, 0.24)
		DamageResult.Outcome.BLOCKED:
			spawn_flash(target.global_position, Color(0.25, 0.8, 1.0), 15.0)
		DamageResult.Outcome.DAMAGED:
			spawn_flash(target.global_position, Color(1.0, 0.25, 0.2), 11.0, 0.14)
			_spawn_damage_number(target.global_position, result.final_damage)
