class_name EnemySpawner
extends Node

signal enemy_spawned(enemy: EnemyController)
signal required_remaining_changed(remaining: int)
signal all_required_defeated

const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy.tscn"

@export var marker_root_path: NodePath
@export var spawn_parent_path: NodePath = NodePath("..")
@export var seed_offset: int = 0

@export var auto_spawn := true
@export var report_to_run_manager := true
var completion_held := false
var initial_wave_size := 0
var _spawn_cursor := 0
var health_bonus := 0
var melee_speed_multiplier := 1.0
var _plan_ready := false
var _spawn_plan: Array[EnemySpawnMarker] = []

var required_remaining: int = 0
var _spawned := false
var _defeated_ids := {}


func _ready() -> void:
	if auto_spawn:
		call_deferred("spawn_all")


func spawn_all() -> void:
	if _spawned:
		return
	_spawned = true
	spawn_pending_wave(initial_wave_size)


func spawn_pending_wave(count: int = 0) -> void:
	_prepare_plan()
	var run_manager := get_node_or_null("/root/RunManager")
	var spawn_parent := get_node(spawn_parent_path) as Node2D
	if spawn_parent == null:
		push_error("EnemySpawner requires a Node2D spawn parent")
		return
	# Resolve after scripts finish loading; room templates and enemy scripts can
	# otherwise preload each other and cache an empty PackedScene.
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	var end := _spawn_plan.size() if count <= 0 else mini(_spawn_cursor + count, _spawn_plan.size())
	var wave := _spawn_plan.slice(_spawn_cursor, end)
	_spawn_cursor = end
	for marker: EnemySpawnMarker in wave:
		var enemy: EnemyController = enemy_scene.instantiate()
		enemy.profile = marker.profile
		var speed_scaled := marker.profile.role == EnemyProfile.Role.MELEE_PRESSURE and not is_equal_approx(melee_speed_multiplier, 1.0)
		if health_bonus > 0 or speed_scaled:
			# Profiles are shared resources; scaling one floor must not alter others.
			enemy.profile = marker.profile.duplicate() as EnemyProfile
			enemy.profile.max_health += health_bonus
			if speed_scaled:
				enemy.profile.move_speed *= melee_speed_multiplier
		enemy.mandatory = marker.mandatory
		# Set the final local position before _ready records the patrol anchor.
		enemy.position = spawn_parent.to_local(marker.global_position)
		spawn_parent.add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		if marker.mandatory:
			required_remaining += 1
		enemy_spawned.emit(enemy)
	required_remaining_changed.emit(required_remaining)
	if run_manager != null and report_to_run_manager:
		run_manager.set_mandatory_enemy_count(required_remaining)
	if required_remaining == 0 and not completion_held:
		all_required_defeated.emit()


func _on_enemy_defeated(_enemy: EnemyController, was_mandatory: bool) -> void:
	if not was_mandatory or _defeated_ids.has(_enemy.get_instance_id()):
		return
	_defeated_ids[_enemy.get_instance_id()] = true
	required_remaining = maxi(required_remaining - 1, 0)
	required_remaining_changed.emit(required_remaining)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null and report_to_run_manager:
		run_manager.set_mandatory_enemy_count(required_remaining)
	if required_remaining == 0 and not completion_held:
		all_required_defeated.emit()

func _prepare_plan() -> void:
	if _plan_ready:
		return
	_plan_ready = true
	var random := RandomNumberGenerator.new()
	var run := get_node_or_null("/root/RunManager")
	random.seed = (run.run_seed if run != null else 1) + seed_offset
	for marker in get_node(marker_root_path).get_children():
		if marker is EnemySpawnMarker and marker.profile != null and marker.should_activate(random):
			_spawn_plan.append(marker)

func remaining_objectives() -> int:
	if _spawned:
		return required_remaining + (1 if completion_held else 0)
	_prepare_plan()
	var count := 0
	for marker in _spawn_plan:
		if marker.mandatory:
			count += 1
	return count


func planned_positions(relative_to: Node2D) -> Array[Vector2]:
	_prepare_plan()
	var points: Array[Vector2] = []
	for marker in _spawn_plan:
		points.append(relative_to.to_local(marker.global_position))
	return points


func release_completion() -> void:
	completion_held = false
	required_remaining_changed.emit(required_remaining)
	if required_remaining == 0:
		all_required_defeated.emit()
