class_name EnvironmentArea
extends RefCounted

# Environment effects belong to an actual combat area, not the whole assembled floor.
static func for_actor(actor: Node2D) -> Node:
	var node: Node = actor
	while node != null:
		if node.has_signal("room_cleared"):
			return node
		node = node.get_parent()
	var container := CombatProjectile.room_for_actor(actor)
	for area in actor.get_tree().get_nodes_in_group("environment_areas"):
		if CombatProjectile.room_for_actor(area) == container and area.contains_world_point(actor.global_position):
			return area
	return container

static func visible_actors(source: Node2D, radius: float) -> Array[Node2D]:
	var actors: Array[Node2D] = []
	var area := for_actor(source)
	for actor in source.get_tree().get_nodes_in_group("status_actors"):
		if not actor is Node2D or actor.is_queued_for_deletion() or for_actor(actor) != area:
			continue
		var hurt := actor.get_node_or_null("HurtBox") as HurtBox2DComponent
		if hurt == null or hurt.health.is_dead() or source.global_position.distance_to(actor.global_position) > radius:
			continue
		var ray := PhysicsRayQueryParameters2D.create(source.global_position,actor.global_position,1)
		if source.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			actors.append(actor)
	return actors
