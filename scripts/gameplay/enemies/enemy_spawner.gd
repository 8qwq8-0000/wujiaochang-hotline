class_name EnemySpawner
extends Node

signal enemy_spawned(enemy: EnemyController)
signal required_remaining_changed(remaining: int)
signal all_required_defeated

const ENEMY_SCENE := preload("res://scenes/actors/enemies/enemy.tscn")

@export var marker_root_path: NodePath
@export var spawn_parent_path: NodePath = NodePath("..")
@export var seed_offset: int = 0

var required_remaining: int = 0
var _spawned := false


func _ready() -> void:
	call_deferred("spawn_all")


func spawn_all() -> void:
	if _spawned:
		return
	_spawned = true
	var random := RandomNumberGenerator.new()
	var run_manager := get_node_or_null("/root/RunManager")
	var base_seed: int = run_manager.run_seed if run_manager != null else 1
	random.seed = base_seed + seed_offset
	var marker_root := get_node(marker_root_path)
	var spawn_parent := get_node(spawn_parent_path)
	for child in marker_root.get_children():
		if not child is EnemySpawnMarker:
			continue
		var marker := child as EnemySpawnMarker
		if marker.profile == null or not marker.should_activate(random):
			continue
		var enemy: EnemyController = ENEMY_SCENE.instantiate()
		enemy.profile = marker.profile
		enemy.mandatory = marker.mandatory
		spawn_parent.add_child(enemy)
		enemy.global_position = marker.global_position
		enemy.defeated.connect(_on_enemy_defeated)
		if marker.mandatory:
			required_remaining += 1
		enemy_spawned.emit(enemy)
	required_remaining_changed.emit(required_remaining)
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(required_remaining)
	if required_remaining == 0:
		all_required_defeated.emit()


func _on_enemy_defeated(_enemy: EnemyController, was_mandatory: bool) -> void:
	if not was_mandatory:
		return
	required_remaining = maxi(required_remaining - 1, 0)
	required_remaining_changed.emit(required_remaining)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(required_remaining)
	if required_remaining == 0:
		all_required_defeated.emit()
