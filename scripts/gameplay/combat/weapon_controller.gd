class_name WeaponController
extends Node2D

signal weapon_changed(index: int, data: WeaponComponentData)
signal attack_performed(data: WeaponComponentData)

const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectile.tscn"
const LASER_BEAM := preload("res://scripts/presentation/laser_beam.gd")
const DEFAULT_WEAPON := preload("res://resources/weapons/service_pistol.tres")
const DEBUG_WEAPONS := [
	DEFAULT_WEAPON,
	preload("res://resources/weapons/scattergun.tres"),
]

@export var faction: CombatFaction.Id = CombatFaction.Id.PLAYER
@export var heat_component_path: NodePath

var weapons: Array[WeaponComponentData] = []
var current_index: int = 0
var debug_loadout_enabled: bool = false
var attack_speed_multiplier := 1.0
var _current_weapon: WeaponComponentData = DEFAULT_WEAPON
var _cooldown_remaining: float = 0.0
var _swing_remaining: float = 0.0
var _swing_duration: float = 0.0
var _swing_direction := Vector2.RIGHT
var _swing_sign: float = -1.0
var _swing_hits: Dictionary = {}
var _swing_damage_multiplier := 1.0

@onready var heat_component: HeatComponent = get_node(heat_component_path)


func _ready() -> void:
	for data in DEBUG_WEAPONS:
		weapons.append(data)
	weapon_changed.emit(current_index, _current_weapon)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_swing_remaining = maxf(_swing_remaining - delta, 0.0)


func configure(default_weapon: WeaponComponentData, enable_debug_loadout: bool) -> void:
	debug_loadout_enabled = enable_debug_loadout
	if enable_debug_loadout:
		weapons.assign(DEBUG_WEAPONS)
		equip_weapon(default_weapon if default_weapon != null else DEFAULT_WEAPON)
	else:
		set_carried_weapons(default_weapon if default_weapon != null else DEFAULT_WEAPON, null)


func get_current_weapon() -> WeaponComponentData:
	return _current_weapon


func equip_weapon(data: WeaponComponentData) -> void:
	if not debug_loadout_enabled:
		weapons[current_index] = data
	_current_weapon = data
	if debug_loadout_enabled and data != null:
		current_index = _index_for_id(data.id)
	_cancel_swing()
	weapon_changed.emit(current_index, _current_weapon)


func equip_weapon_by_id(id: StringName) -> bool:
	for data in weapons:
		if data.id == id:
			equip_weapon(data)
			return true
	return false


func select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_index or weapons[index] == null:
		return
	current_index = index
	_current_weapon = weapons[index]
	_cancel_swing()
	weapon_changed.emit(current_index, _current_weapon)


func cycle_weapon(step: int) -> void:
	if weapons.is_empty() or step == 0:
		return
	select_weapon(posmod(current_index + step, weapons.size()))


func update_attack_pose(origin: Vector2, _direction: Vector2, source_node: Node) -> void:
	if _swing_remaining <= 0.0 or _current_weapon == null:
		return
	_perform_melee_tick(_current_weapon, origin, _swing_direction, source_node)


func try_attack(origin: Vector2, direction: Vector2, source_node: Node) -> bool:
	var data := _current_weapon
	if data == null or _cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false
	if not heat_component.try_add_heat(data.heat_per_attack):
		return false
	_perform_attack(data, origin, direction.normalized(), source_node, 1.0)
	return true


func try_forced_attack(
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float = 1.0
) -> bool:
	var data := _current_weapon
	if data == null or direction.is_zero_approx():
		return false
	_perform_attack(data, origin, direction.normalized(), source_node, maxf(damage_multiplier, 0.0))
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func set_cooldown_remaining(value: float) -> void:
	_cooldown_remaining = maxf(value, 0.0)


func reduce_cooldown(amount: float) -> void:
	set_cooldown_remaining(_cooldown_remaining - maxf(amount, 0.0))


func _perform_attack(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float
) -> void:
	_cooldown_remaining = data.cooldown / maxf(attack_speed_multiplier, 0.01)
	match data.attack_kind:
		WeaponComponentData.AttackKind.MELEE:
			_begin_melee(data, direction.normalized(), damage_multiplier)
		WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD:
			_perform_projectiles(data, origin, direction.normalized(), source_node, damage_multiplier)
		WeaponComponentData.AttackKind.BEAM:
			_perform_beam(data, origin, direction.normalized(), source_node, damage_multiplier)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and data.noise_radius > 0.0:
		events.publish_noise(source_node, origin, data.noise_radius)
	attack_performed.emit(data)


func clamp_projectile_origin(actor_origin: Vector2, muzzle_origin: Vector2) -> Vector2:
	var delta := muzzle_origin - actor_origin
	if delta.length_squared() <= 1.0:
		return muzzle_origin
	var world := get_viewport().world_2d
	if world == null:
		return muzzle_origin
	# A long barrel can extend past a touching enemy. Treat that hurtbox like a
	# muzzle obstruction, but ignore the shooter's own hurtbox and non-actor areas.
	var query := PhysicsRayQueryParameters2D.create(actor_origin, muzzle_origin, 1 | 8 | 16)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var excluded: Array[RID] = []
	var shooter := get_parent()
	var own_hurtbox := shooter.get_node_or_null("HurtBox") as HurtBox2DComponent
	if own_hurtbox != null:
		excluded.append(own_hurtbox.get_rid())
	for attempt in 32:
		query.exclude = excluded
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return muzzle_origin
		var collider: Object = hit.collider
		if collider is Area2D and not collider is HurtBox2DComponent:
			excluded.append(collider.get_rid())
			continue
		return Vector2(hit.position) - delta.normalized() * 1.5
	return actor_origin


func get_melee_swing_angle_offset() -> float:
	if _swing_remaining <= 0.0 or _swing_duration <= 0.0 or _current_weapon == null:
		return 0.0
	var progress := 1.0 - _swing_remaining / _swing_duration
	var half_arc := deg_to_rad(_current_weapon.melee_arc_degrees * 0.5)
	return lerpf(-half_arc, half_arc, progress) * _swing_sign


func reset_transient_state() -> void:
	_cooldown_remaining = 0.0
	_cancel_swing()


func _begin_melee(data: WeaponComponentData, direction: Vector2, damage_multiplier: float = 1.0) -> void:
	_swing_direction = direction
	_swing_duration = data.melee_active_seconds
	_swing_remaining = _swing_duration
	_swing_damage_multiplier = damage_multiplier
	_swing_sign *= -1.0
	_swing_hits.clear()


func _perform_melee_tick(data: WeaponComponentData, origin: Vector2, direction: Vector2, source_node: Node) -> void:
	var shape := CircleShape2D.new()
	shape.radius = data.melee_hit_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	var sweep_direction := direction.rotated(get_melee_swing_angle_offset())
	query.transform = Transform2D(0.0, origin + sweep_direction * data.attack_range)
	query.collision_mask = 24
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var world := get_viewport().world_2d
	if world == null:
		return
	for hit in world.direct_space_state.intersect_shape(query, 16):
		var area: Object = hit.get("collider")
		if area == null or not area.has_method("receive_hit"):
			continue
		var instance_id := area.get_instance_id()
		if _swing_hits.has(instance_id):
			continue
		_swing_hits[instance_id] = true
		var packet := _make_packet(data, origin, sweep_direction, source_node, _swing_damage_multiplier)
		packet.is_melee = true
		packet.stagger_seconds = 0.75
		packet.knockback = sweep_direction * 120.0
		area.receive_hit(packet)


func _perform_projectiles(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float = 1.0
) -> void:
	# Resolve after actor/room scripts finish loading to avoid a cyclic scene preload.
	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	var count := maxi(data.projectile_count, 1)
	for index in count:
		var offset := 0.0
		if count > 1:
			offset = lerpf(-data.spread_degrees * 0.5, data.spread_degrees * 0.5, float(index) / float(count - 1))
		var projectile: CombatProjectile = projectile_scene.instantiate()
		CombatProjectile.room_for_actor(source_node).add_child(projectile)
		projectile.global_position = origin
		projectile.setup(
			source_node,
			faction,
			direction.rotated(deg_to_rad(offset)),
			maxi(int(round(data.damage * damage_multiplier)), 0),
			data.projectile_speed
		)
		projectile.damage_type = data.damage_type
		projectile.status_tags = data.status_tags.duplicate()
		var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
		if cyberware != null:
			cyberware.configure_projectile(projectile, direction)


func _perform_beam(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float = 1.0
) -> void:
	var room := CombatProjectile.room_for_actor(source_node)
	var space := get_world_2d().direct_space_state
	# Sweep the full beam width against walls, then use that same length for
	# both the visible light and its damage rectangle.
	var front := RectangleShape2D.new()
	front.size = Vector2(1.0, data.beam_width)
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = front
	sweep.transform = Transform2D(direction.angle(), origin)
	sweep.collision_mask = 1
	sweep.margin = 0.0
	var starts_in_wall := not space.intersect_shape(sweep, 1).is_empty()
	sweep.motion = direction * data.attack_range
	var length := 0.0 if starts_in_wall else data.attack_range * space.cast_motion(sweep)[0]
	if length <= 0.0:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, data.beam_width)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(direction.angle(), origin + direction * length * 0.5)
	query.collision_mask = 8 | 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.margin = 0.0
	var hit_actors := {}
	for hit in space.intersect_shape(query, 256):
		var area := hit.collider as Area2D
		if area == null or not area.has_method("receive_hit"):
			continue
		var actor: Node = area.actor if area is HurtBox2DComponent else area
		if not is_instance_valid(actor) or actor == source_node:
			continue
		if CombatProjectile.room_for_actor(actor) != room or hit_actors.has(actor.get_instance_id()):
			continue
		hit_actors[actor.get_instance_id()] = true
		var packet := _make_packet(data, origin, direction, source_node, damage_multiplier)
		packet.is_area_damage = true
		area.receive_hit(packet)
	var beam := Node2D.new()
	beam.set_script(LASER_BEAM)
	beam.set("beam_length", length)
	beam.set("beam_width", data.beam_width)
	room.add_child(beam)
	beam.global_position = origin
	beam.global_rotation = direction.angle()


func _make_packet(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float = 1.0
) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = maxi(int(round(data.damage * damage_multiplier)), 0)
	packet.source = source_node
	packet.source_faction = faction
	packet.damage_type = data.damage_type
	packet.status_tags = data.status_tags.duplicate()
	packet.source_position = origin
	packet.travel_direction = direction
	return packet


func _cancel_swing() -> void:
	_swing_remaining = 0.0
	_swing_duration = 0.0
	_swing_damage_multiplier = 1.0
	_swing_hits.clear()


func _index_for_id(id: StringName) -> int:
	for index in weapons.size():
		if weapons[index] != null and weapons[index].id == id:
			return index
	return -1


func set_equipped_weapon(data: WeaponComponentData) -> void:
	set_carried_weapons(data, null)


func set_carried_weapons(primary: WeaponComponentData, secondary: WeaponComponentData) -> void:
	weapons.assign([primary, secondary])
	if current_index >= weapons.size() or weapons[current_index] == null:
		current_index = 0 if primary != null else (1 if secondary != null else 0)
	var next_weapon := weapons[current_index]
	if _current_weapon != next_weapon:
		_cancel_swing()
	_current_weapon = next_weapon
	# A slot change cannot bypass attack cooldown or heat.
	weapon_changed.emit(current_index, _current_weapon)
