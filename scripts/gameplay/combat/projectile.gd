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
var weapon_id: StringName = &""
var damage_type: StringName = &"kinetic"
var status_tags: PackedStringArray = []
var homing_target: Node2D
var homing_turn_radians_per_second := 0.0
var explosion_radius := 0.0
var explosion_damage := 0
var has_area_behavior := false
var feedback_group_id: int = 0
var allows_trajectory_echo := false
var takeover_consumed := false
var electric_arc_enabled := false
var circuit_arc_chains := 0
var circuit_echo_layers := 0
var circuit_payload_group_id := 0
var circuit_base_explosion_radius := 0.0
var circuit_base_explosion_damage := 0
var circuit_base_area_behavior := false
var calamity_blade := false
var calamity_max_distance := 0.0
var _calamity_travelled := 0.0
var _electric_arc_phase := 0.0
var _resolved := false
var circuit_pierce_remaining := 0
var circuit_penetration_boost := false
var circuit_visual_scale := 1.0
@onready var _base_visual_scale: Vector2 = ($Visual as Sprite2D).scale
var _pierced_enemy_count := 0
var _pierced_actor_ids: Dictionary = {}
var _pierced_wall_rids: Array[RID] = []


func _ready() -> void:
	add_to_group("combat_projectiles")
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


func configure_homing(target: Node2D, turn_degrees_per_second: float) -> void:
	homing_target = target
	homing_turn_radians_per_second = deg_to_rad(maxf(turn_degrees_per_second, 0.0))
	tint = Color(0.35, 1.0, 0.9)
	_sync_visual()


func configure_explosion(radius: float, area_damage: int) -> void:
	explosion_radius = maxf(explosion_radius, maxf(radius, 0.0))
	explosion_damage += maxi(area_damage, 0)
	has_area_behavior = explosion_radius > 0.0 and explosion_damage > 0
	if has_area_behavior and homing_target == null:
		tint = Color(1.0, 0.62, 0.2)
		_sync_visual()


func configure_electric_arc() -> void:
	electric_arc_enabled = true
	if feedback_group_id <= 0:
		feedback_group_id = -int(get_instance_id())
	_sync_visual()


func configure_calamity_blade(max_distance: float = 0.0) -> void:
	calamity_blade = true
	calamity_max_distance = maxf(max_distance, 0.0)
	tint = Color(0.9, 0.13, 0.19)
	_sync_visual()


func can_be_taken_over() -> bool:
	return (
		not _resolved
		and not takeover_consumed
		and faction == CombatFaction.Id.ENEMY
		and reflectable
		and not has_area_behavior
	)


func take_over(owner_node: Node, target: Node2D, turn_degrees_per_second: float) -> bool:
	if not can_be_taken_over() or not is_instance_valid(owner_node) or not is_instance_valid(target):
		return false
	var heading := global_position.direction_to(target.global_position)
	if heading.is_zero_approx():
		return false
	takeover_consumed = true
	faction = CombatFaction.Id.PLAYER
	source = owner_node
	status_tags.clear()
	direction = heading
	homing_target = target
	homing_turn_radians_per_second = deg_to_rad(maxf(turn_degrees_per_second, 0.0))
	allows_trajectory_echo = false
	tint = Color(0.35, 1.0, 0.4)
	_sync_visual()
	return true


func _physics_process(delta: float) -> void:
	if electric_arc_enabled:
		_electric_arc_phase = fmod(_electric_arc_phase + delta * 34.0, TAU)
		queue_redraw()
	if is_instance_valid(homing_target) and homing_turn_radians_per_second > 0.0:
		var desired := global_position.direction_to(homing_target.global_position)
		if not desired.is_zero_approx():
			var next_angle := rotate_toward(direction.angle(), desired.angle(), homing_turn_radians_per_second * delta)
			direction = Vector2.from_angle(next_angle)
			_sync_visual()
	var travel := speed * delta
	if calamity_blade and calamity_max_distance > 0.0:
		travel = minf(travel, maxf(calamity_max_distance - _calamity_travelled, 0.0))
	var next_position := global_position + direction * travel
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
	var excluded := _pierced_wall_rids.duplicate()
	if is_instance_valid(source) and source is StaticBody2D:
		excluded.append(source.get_rid())
	query.exclude = excluded
	var wall_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not wall_hit.is_empty():
		if circuit_pierce_remaining != 0:
			if circuit_pierce_remaining > 0:
				circuit_pierce_remaining -= 1
			_pierced_wall_rids.append(wall_hit.rid)
			global_position = next_position
			lifetime -= delta
			if lifetime <= 0.0:
				queue_free()
			return
		global_position = wall_hit.position
		_resolved = true
		# Door leaves are world-blocking StaticBody2Ds. Notify their owning door
		# before consuming the impact; ordinary walls still just stop the shot.
		if wall_hit.collider.has_method("receive_projectile_hit"):
			wall_hit.collider.receive_projectile_hit(_make_damage_packet())
		var door: AutomaticDoor = wall_hit.collider.get_parent() as AutomaticDoor
		if door != null:
			door.receive_hit(_make_damage_packet())
		_detonate()
		queue_free()
		return
	global_position = next_position
	if calamity_blade and calamity_max_distance > 0.0:
		_calamity_travelled += travel
		if _calamity_travelled >= calamity_max_distance:
			queue_free()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	if calamity_blade:
		draw_colored_polygon(PackedVector2Array([Vector2(-14, -5), Vector2(10, -2), Vector2(18, 0), Vector2(10, 2), Vector2(-14, 5)]), Color(0.12, 0.02, 0.04))
		draw_line(Vector2(-12, -1), Vector2(16, 0), tint, 2.0)
		return
	draw_line(Vector2.LEFT * 7.0, Vector2.ZERO, tint.darkened(0.25), 2.0)
	if not electric_arc_enabled:
		return
	var points := PackedVector2Array()
	for index in 6:
		var t := float(index) / 5.0
		var x := lerpf(-9.0, 1.0, t)
		var y := 0.0 if index in [0, 5] else sin(_electric_arc_phase + index * 2.35) * 2.2
		points.append(Vector2(x, y))
	draw_polyline(points, Color(0.18, 0.65, 1.0, 0.78), 3.2, true)
	draw_polyline(points, Color(0.88, 0.98, 1.0, 0.96), 1.0, true)


func _sync_visual() -> void:
	rotation = direction.angle()
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual != null:
		visual.modulate = tint
		visual.scale = _base_visual_scale * circuit_visual_scale
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if _resolved:
		return
	if area is HurtBox2DComponent and is_instance_valid(area.actor) and _pierced_actor_ids.has(area.actor.get_instance_id()):
		return
	# The player's upward-offset hurt box overlaps the upward muzzle position.
	# Enemy fire passes through allies so ranged units can fire from cover.
	if area is HurtBox2DComponent and is_instance_valid(source) and area.actor == source:
		return
	if area is HurtBox2DComponent and faction == CombatFaction.Id.PLAYER and is_instance_valid(area.actor) and area.actor.is_in_group("companions"):
		return
	if area is HurtBox2DComponent and faction == CombatFaction.Id.ENEMY and area.faction == CombatFaction.Id.ENEMY:
		return
	# Oil receives only ignition shots; spent fire fields never absorb projectiles.
	if area is FuelPatch and (damage_type != &"fire" or area.burning):
		return
	if not area.has_method("receive_hit"):
		return
	if circuit_payload_group_id > 0:
		var cyberware := source.get_node_or_null("CyberwareController") as CyberwareController if is_instance_valid(source) else null
		if cyberware == null or not cyberware.claim_weapon_payload_hit(circuit_payload_group_id):
			explosion_radius = circuit_base_explosion_radius
			explosion_damage = circuit_base_explosion_damage
			has_area_behavior = circuit_base_area_behavior
	var packet := _make_damage_packet()
	if circuit_penetration_boost and _pierced_enemy_count > 0:
		packet.base_damage = damage * (1 + _pierced_enemy_count)
	var direct_actor_id := 0
	if has_area_behavior and area is HurtBox2DComponent and is_instance_valid(area.actor):
		packet.base_damage += explosion_damage
		direct_actor_id = area.actor.get_instance_id()
	var result: DamageResult = area.receive_hit(packet)
	if result.reflected:
		faction = result.packet.source_faction
		source = result.packet.source if is_instance_valid(result.packet.source) else null
		direction = result.packet.travel_direction.normalized()
		tint = Color(0.95, 0.75, 0.15)
		_sync_visual()
		return
	if faction == CombatFaction.Id.PLAYER and is_instance_valid(source) and (circuit_arc_chains > 0 or circuit_echo_layers > 0):
		var cyberware := source.get_node_or_null("CyberwareController") as CyberwareController
		if cyberware != null:
			cyberware.on_circuit_projectile_hit(self, result)
	if result != null and result.final_damage > 0 and area is HurtBox2DComponent and is_instance_valid(area.actor) and (area.actor.is_in_group("enemies") or area.actor.is_in_group("bosses")) and circuit_pierce_remaining != 0:
		_pierced_actor_ids[area.actor.get_instance_id()] = true
		_pierced_enemy_count += 1
		if circuit_pierce_remaining > 0:
			circuit_pierce_remaining -= 1
		circuit_echo_layers = 0
		_detonate(direct_actor_id)
		return
	_resolved = true
	_detonate(direct_actor_id)
	queue_free()


func _make_damage_packet() -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = damage
	packet.damage_type = damage_type
	packet.status_tags = status_tags.duplicate()
	packet.source = source if is_instance_valid(source) else null
	packet.source_faction = faction
	packet.weapon_id = weapon_id
	packet.source_position = global_position - direction * 8.0
	packet.travel_direction = direction
	packet.knockback = direction * 85.0
	packet.is_projectile = true
	packet.reflectable = reflectable
	packet.feedback_group_id = feedback_group_id
	packet.allows_trajectory_echo = allows_trajectory_echo
	return packet


func _detonate(excluded_actor_id: int = 0) -> void:
	if not has_area_behavior:
		return
	has_area_behavior = false
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 8 | 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen: Dictionary = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not is_instance_valid(hurt.actor):
			continue
		var actor_id := hurt.actor.get_instance_id()
		if actor_id == excluded_actor_id or seen.has(actor_id) or hurt.actor == source:
			continue
		if room_for_actor(hurt.actor) != room_for_actor(self):
			continue
		seen[actor_id] = true
		var offset := hurt.actor.global_position - global_position
		var packet := DamagePacket.new()
		packet.base_damage = explosion_damage
		packet.damage_type = &"explosive"
		packet.source = source if is_instance_valid(source) else null
		packet.source_faction = faction
		packet.weapon_id = weapon_id
		packet.status_tags = status_tags.duplicate()
		packet.source_position = global_position
		packet.travel_direction = offset.normalized() if not offset.is_zero_approx() else direction
		packet.knockback = packet.travel_direction * 70.0
		packet.is_area_damage = true
		packet.feedback_group_id = feedback_group_id
		hurt.receive_hit(packet)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(global_position, Color(1.0, 0.52, 0.16), explosion_radius, 0.18)


static func room_for_actor(actor: Node) -> Node:
	var node := actor
	while node != null:
		if node.is_in_group("combat_rooms"):
			return node
		node = node.get_parent()
	return actor.get_tree().current_scene
