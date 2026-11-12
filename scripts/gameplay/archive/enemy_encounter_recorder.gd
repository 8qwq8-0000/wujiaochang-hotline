class_name EnemyEncounterRecorder
extends Node

var enemy_id := ""
var _cooldown := 0.0
var _requires_line_of_sight := true


static func watch(actor: Node2D, identity: String, requires_line_of_sight := true) -> void:
	if not EnemyCatalog.contains(identity):
		return
	var recorder := EnemyEncounterRecorder.new()
	recorder.enemy_id = identity
	recorder._requires_line_of_sight = requires_line_of_sight
	actor.add_child(recorder)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = 0.25
	var store := get_node_or_null("/root/WarehouseStore")
	if store == null:
		return
	if enemy_id in store.get_codex().get("enemies", []):
		queue_free()
		return
	var run := get_node_or_null("/root/RunManager")
	var actor := get_parent() as Node2D
	var health := actor.get_node_or_null("HealthComponent")
	if health != null and health.is_dead():
		return
	var prologue := false
	var ancestor: Node = actor
	while ancestor != null:
		if ancestor.scene_file_path == "res://scenes/levels/prologue/hotline_prologue.tscn":
			prologue = true
			break
		ancestor = ancestor.get_parent()
	if run == null or (not run.persistent_run and not prologue):
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.health.is_dead() or not actor.is_visible_in_tree():
		return
	if CombatProjectile.room_for_actor(actor) != CombatProjectile.room_for_actor(player):
		return
	if EnvironmentArea.for_actor(actor) != EnvironmentArea.for_actor(player):
		return
	if _requires_line_of_sight:
		var screen_position := actor.get_global_transform_with_canvas().origin
		if not actor.get_viewport_rect().has_point(screen_position):
			return
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, actor.global_position, 1)
		if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return
	# Uses the store's atomic writer and test-session isolation. Retry failures.
	if store.record_enemy_encounter(enemy_id):
		queue_free()
