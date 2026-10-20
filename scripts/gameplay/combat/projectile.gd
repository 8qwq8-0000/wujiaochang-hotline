class_name CombatProjectile
extends Area2D

@export var speed: float = 420.0
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var faction: CombatFaction.Id = CombatFaction.Id.NEUTRAL
@export var reflectable: bool = true
@export var tint: Color = Color.WHITE

var direction := Vector2.RIGHT
var source: Node
var damage_type: StringName = &"kinetic"
var status_tags: PackedStringArray = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_sync_visual()


func setup(owner_node: Node, source_faction: CombatFaction.Id, heading: Vector2, projectile_damage: int, projectile_speed: float) -> void:
	source = owner_node
	faction = source_faction
	direction = heading.normalized()
	damage = projectile_damage
	speed = projectile_speed
	tint = Color(0.3, 0.9, 1.0) if faction == CombatFaction.Id.PLAYER else Color(1.0, 0.25, 0.2)
	_sync_visual()


func _physics_process(delta: float) -> void:
	var next_position := global_position + direction * speed * delta
	# Sweep the whole step so fast player shots cannot skip a thin barrier.
	if faction == CombatFaction.Id.PLAYER:
		var shield_query := PhysicsRayQueryParameters2D.create(global_position, next_position, EnemyBarrierSkill.COLLISION_LAYER)
		shield_query.collide_with_areas = true
		shield_query.collide_with_bodies = false
		shield_query.hit_from_inside = true
		var shield_hit := get_world_2d().direct_space_state.intersect_ray(shield_query)
		if not shield_hit.is_empty():
			queue_free()
			return
	var query := PhysicsRayQueryParameters2D.create(global_position, next_position, 1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = next_position
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_line(Vector2.LEFT * 7.0, Vector2.ZERO, tint.darkened(0.25), 2.0)


func _sync_visual() -> void:
	rotation = direction.angle()
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual != null:
		visual.modulate = tint
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	# The player's upward-offset hurt box overlaps the upward muzzle position.
	# Ignore only the shooter, preserving friendly-fire hits on other actors.
	if area is HurtBox2DComponent and is_instance_valid(source) and area.actor == source:
		return
	# Oil receives only ignition shots; spent fire fields never absorb projectiles.
	if area is FuelPatch and (damage_type != &"fire" or area.burning):
		return
	if not area.has_method("receive_hit"):
		return
	var packet := _make_damage_packet()
	var result: DamageResult = area.receive_hit(packet)
	if result.reflected:
		faction = result.packet.source_faction
		source = result.packet.source if is_instance_valid(result.packet.source) else null
		direction = result.packet.travel_direction.normalized()
		tint = Color(0.95, 0.75, 0.15)
		_sync_visual()
		return
	queue_free()


func _make_damage_packet() -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = damage
	packet.damage_type = damage_type
	packet.status_tags = status_tags.duplicate()
	packet.source = source if is_instance_valid(source) else null
	packet.source_faction = faction
	packet.source_position = global_position - direction * 8.0
	packet.travel_direction = direction
	packet.knockback = direction * 85.0
	packet.is_projectile = true
	packet.reflectable = reflectable
	return packet


static func room_for_actor(actor: Node) -> Node:
	var node := actor
	while node != null:
		if node.is_in_group("combat_rooms"):
			return node
		node = node.get_parent()
	return actor.get_tree().current_scene
