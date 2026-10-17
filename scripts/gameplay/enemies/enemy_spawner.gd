class_name EnemySpawner
extends Node

signal enemy_spawned(enemy: EnemyController)
signal required_remaining_changed(remaining: int)
signal all_required_defeated

const ENEMY_SCENE := preload("res://scenes/actors/enemies/enemy.tscn")

@export var marker_root_path: NodePath
@export var spawn_parent_path: NodePath = NodePath("..")
@export var seed_offset: int = 0

@export var auto_spawn := true
@export var report_to_run_manager := true
var _plan_ready := false
var _spawn_plan: Array[EnemySpawnMarker] = []

var required_remaining: int = 0
var _spawned := false


func _ready() -> void:
	if auto_spawn:
		call_deferred("spawn_all")


func spawn_all() -> void:
	if _spawned:
		return
	_spawned = true
	_prepare_plan()
	var run_manager := get_node_or_null("/root/RunManager")
	var spawn_parent := get_node(spawn_parent_path) as Node2D
	if spawn_parent == null:
		push_error("EnemySpawner requires a Node2D spawn parent")
		return
	for marker in _spawn_plan:
		var enemy: EnemyController = ENEMY_SCENE.instantiate()
		enemy.profile = marker.profile
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
	if required_remaining == 0:
		all_required_defeated.emit()


func _on_enemy_defeated(_enemy: EnemyController, was_mandatory: bool) -> void:
	if not was_mandatory:
		return
	required_remaining = maxi(required_remaining - 1, 0)
	required_remaining_changed.emit(required_remaining)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null and report_to_run_manager:
		run_manager.set_mandatory_enemy_count(required_remaining)
	if required_remaining == 0:
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
		return required_remaining
	_prepare_plan()
	var count := 0
	for marker in _spawn_plan:
		if marker.mandatory:
			count += 1
	return count
