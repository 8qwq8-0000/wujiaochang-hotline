class_name WeaponMount
extends Node2D

const FALLBACK_VIEW := preload("res://scenes/weapons/weapon_view.tscn")

var current_view: WeaponView
var current_data: WeaponComponentData
var _warned_missing_views: Dictionary = {}


func set_weapon(data: WeaponComponentData) -> void:
	if data == current_data and is_instance_valid(current_view):
		return
	_clear_view()
	current_data = data
	if data == null:
		return
	var scene := data.view_scene
	if scene == null:
		scene = FALLBACK_VIEW
		if not _warned_missing_views.has(data.id):
			_warned_missing_views[data.id] = true
			push_warning("Weapon '%s' has no view_scene; using placeholder weapon view." % data.id)
	var instance := scene.instantiate()
	if not instance is WeaponView:
		push_warning("Weapon '%s' view root is not WeaponView; using placeholder weapon view." % data.id)
		instance.queue_free()
		instance = FALLBACK_VIEW.instantiate()
	add_child(instance)
	current_view = instance as WeaponView
	current_view.configure(data)
	current_view.cue_requested.connect(_on_cue_requested)
	current_view.play_equip()


func play_attack() -> void:
	if is_instance_valid(current_view):
		current_view.play_attack()


func cancel_feedback() -> void:
	if is_instance_valid(current_view):
		current_view.cancel_feedback()


func get_muzzle_global_position() -> Vector2:
	return current_view.get_muzzle_global_position() if is_instance_valid(current_view) else global_position


func _clear_view() -> void:
	if not is_instance_valid(current_view):
		current_view = null
		return
	current_view.cancel_feedback()
	remove_child(current_view)
	current_view.queue_free()
	current_view = null


func _on_cue_requested(weapon_id: StringName, cue: StringName, world_position: Vector2) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_weapon_cue(weapon_id, cue, world_position)
