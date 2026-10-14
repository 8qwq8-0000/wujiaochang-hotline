class_name InteractorComponent
extends Area2D

signal interaction_requested(actor: Node, target: Node)
signal interaction_completed(actor: Node, target: Node)


func request_interaction(actor: Node2D) -> bool:
	var target := get_best_target(actor)
	if target == null:
		return false
	interaction_requested.emit(actor, target)
	if target.has_method("interact"):
		target.interact(actor)
		interaction_completed.emit(actor, target)
		return true
	return false


func get_best_target(actor: Node2D) -> Node:
	var best: Node
	var best_distance := INF
	var candidates: Array[Node] = []
	for area in get_overlapping_areas():
		candidates.append(_resolve_interactable(area))
	for body in get_overlapping_bodies():
		candidates.append(_resolve_interactable(body))
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.has_method("interact"):
			continue
		if candidate.has_method("can_interact") and not candidate.can_interact(actor):
			continue
		var candidate_2d := candidate as Node2D
		var distance := actor.global_position.distance_squared_to(candidate_2d.global_position) if candidate_2d != null else 0.0
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _resolve_interactable(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("interact"):
		return node
	if node.get_parent() != null and node.get_parent().has_method("interact"):
		return node.get_parent()
	return null
