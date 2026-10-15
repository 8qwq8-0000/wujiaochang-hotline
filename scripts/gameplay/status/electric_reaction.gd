class_name ElectricReaction
extends RefCounted

const HOP_RADIUS := 96.0
const MAX_HOPS := 3
const ARC_DAMAGE := 1

static func begin_event(source: Node2D) -> Dictionary:
	var conductive_ids := {}
	for actor in source.get_tree().get_nodes_in_group("status_actors"):
		if actor.is_queued_for_deletion():
			continue
		var status: Node = actor.get_node_or_null("StatusComponent")
		if status != null and status.has_status(&"conductive"):
			conductive_ids[actor.get_instance_id()] = true
	return {"hit_ids": {}, "conductive_ids": conductive_ids, "remaining_hops": MAX_HOPS}

static func discharge(origin: Node2D, incoming: DamagePacket) -> int:
	if not is_instance_valid(origin) or not origin.is_inside_tree():
		return 0
	var room := EnvironmentArea.for_actor(origin)
	var current := origin.global_position
	var visited := {origin.get_instance_id(): true}
	var hits := 0
	for hop in MAX_HOPS:
		if int(incoming.electric_event.remaining_hops) <= 0:
			break
		var target := _nearest(origin, room, current, incoming, visited)
		if target == null:
			break
		incoming.electric_event.remaining_hops -= 1
		visited[target.get_instance_id()] = true
		var statuses: Node = target.get_node("StatusComponent")
		statuses.remove_status(&"conductive")
		var next := target.global_position
		var arc := incoming.duplicate_packet()
		arc.base_damage = ARC_DAMAGE
		arc.damage_type = &"electric"
		arc.status_tags = []
		arc.allow_status_reactions = false
		arc.blockable = false
		arc.reflectable = false
		arc.is_area_damage = true
		arc.is_projectile = false
		arc.is_melee = false
		arc.knockback = Vector2.ZERO
		arc.stagger_seconds = 0.0
		arc.source_position = current
		arc.travel_direction = current.direction_to(next)
		target.get_node("HurtBox").receive_hit(arc)
		var events := origin.get_node_or_null("/root/CombatEvents")
		if events != null:
			events.electric_arc_requested.emit(current, next, room)
		current = next
		hits += 1
	return hits

static func _nearest(origin: Node2D, room: Node, point: Vector2, packet: DamagePacket, visited: Dictionary) -> Node2D:
	var nearest: Node2D
	var distance_limit := HOP_RADIUS * HOP_RADIUS
	for actor in origin.get_tree().get_nodes_in_group("status_actors"):
		if not actor is Node2D or visited.has(actor.get_instance_id()) or actor == packet.source:
			continue
		if actor.is_queued_for_deletion() or EnvironmentArea.for_actor(actor) != room:
			continue
		if packet.electric_event.hit_ids.has(actor.get_instance_id()) or not packet.electric_event.conductive_ids.has(actor.get_instance_id()):
			continue
		var health := actor.get_node_or_null("HealthComponent") as HealthComponent
		var hurt := actor.get_node_or_null("HurtBox") as HurtBox2DComponent
		var statuses: Node = actor.get_node_or_null("StatusComponent")
		if health == null or health.is_dead() or hurt == null or hurt.is_invulnerable() or statuses == null or not statuses.has_status(&"conductive"):
			continue
		if CombatFaction.damage_multiplier(packet.source_faction, hurt.faction, packet.reflected) <= 0:
			continue
		var distance: float = point.distance_squared_to(actor.global_position)
		if distance > distance_limit:
			continue
		var ray := PhysicsRayQueryParameters2D.create(point, actor.global_position, 1)
		if not origin.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		if nearest == null or distance < distance_limit or actor.get_instance_id() < nearest.get_instance_id():
			nearest = actor
			distance_limit = distance
	return nearest
