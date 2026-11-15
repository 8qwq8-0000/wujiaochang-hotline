class_name WeaponController
extends Node2D

signal weapon_changed(index: int, data: WeaponComponentData)
signal attack_performed(data: WeaponComponentData)

const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectile.tscn"
const GRAVITY_WAVE_SCENE_PATH := "res://scenes/combat/gravity_wave_orb.tscn"
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
var persona_attack_speed_bonus := 0.0
var equipment_attack_speed_bonus := 0.0
var _current_weapon: WeaponComponentData = DEFAULT_WEAPON
var pending_charge_seconds := 0.0
var last_manual_charge_seconds := 0.0
var _cooldown_remaining: float = 0.0
var _swing_remaining: float = 0.0
var _swing_duration: float = 0.0
var _swing_direction := Vector2.RIGHT
var _swing_sign: float = -1.0
var _swing_hits: Dictionary = {}
var _swing_damage_multiplier := 1.0
var _feedback_group_serial := 0
var _active_feedback_group_id := 0
var _active_terminal_attack := false
var _active_status_tags: PackedStringArray = []
var _swing_status_tags: PackedStringArray = []

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


func try_attack(origin: Vector2, direction: Vector2, source_node: Node, automatic_repeat: bool = false) -> bool:
	var data := _current_weapon
	if data == null or direction.is_zero_approx():
		return false
	var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
	if data.id == &"gravity_wave" and cyberware != null and not cyberware.is_circuit_weapon_call_active():
		if _cooldown_remaining > 0.0:
			return false
		var charged := data.duplicate(true) as WeaponComponentData
		charged.charge_seconds = clampf(pending_charge_seconds, 0.0, GravityWaveOrb.MAX_CHARGE_SECONDS)
		if not cyberware.submit_weapon_fire(direction, charged):
			return false
		last_manual_charge_seconds = charged.charge_seconds
		_cooldown_remaining = data.cooldown / maxf(attack_speed_multiplier + persona_attack_speed_bonus + equipment_attack_speed_bonus, 0.01)
		return true
	if faction == CombatFaction.Id.PLAYER and cyberware != null and not cyberware.is_circuit_weapon_call_active():
		var frenzy := (source_node as PlayerController).persona_combat.is_nuclear_frenzy_active()
		if _cooldown_remaining > 0.0 and not frenzy and not (not automatic_repeat and cyberware.has_active_round() and (source_node as PlayerController).persona_combat.can_queue_seamless()):
			return false
		if not cyberware.submit_weapon_fire(direction, data, automatic_repeat):
			return false
		_cooldown_remaining = 0.0 if frenzy else data.cooldown / maxf(attack_speed_multiplier + persona_attack_speed_bonus + equipment_attack_speed_bonus, 0.01)
		return true
	var context := _attack_context(source_node, data)
	if _cooldown_remaining > 0.0 and not bool(context.get("ignore_cooldown", false)):
		return false
	_perform_attack(data, origin, direction.normalized(), source_node, 1.0, context)
	if source_node.has_method("on_persona_attack_committed"):
		source_node.on_persona_attack_committed(data, context, _active_feedback_group_id)
	return true


func perform_circuit_attack(data: WeaponComponentData, origin: Vector2, direction: Vector2, source_node: Node, damage_multiplier: float = 1.0, event_tags: PackedStringArray = []) -> bool:
	if data == null or direction.is_zero_approx():
		return false
	var previous_weapon := _current_weapon
	_current_weapon = data
	var tags := PackedStringArray(["cyberware_chain", "circuit_attack"])
	tags.append_array(event_tags)
	var context := _attack_context(source_node, data)
	context["forced"] = true
	context["ignore_cooldown"] = true
	context["extra_status_tags"] = tags
	_perform_attack(data, origin, direction.normalized(), source_node, damage_multiplier, context)
	if source_node.has_method("on_persona_attack_committed"):
		source_node.on_persona_attack_committed(data, context, _active_feedback_group_id)
	if data.attack_kind == WeaponComponentData.AttackKind.MELEE and (source_node.get_node_or_null("CyberwareController") as CyberwareController).get_circuit_calamity_layers() == 0:
		_swing_remaining = _swing_duration * 0.5
		_perform_melee_tick(data, origin, direction.normalized(), source_node)
		_cancel_swing()
	_current_weapon = previous_weapon
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
	_perform_attack(data, origin, direction.normalized(), source_node, maxf(damage_multiplier, 0.0), {"forced": true, "ignore_cooldown": true})
	return true


func try_cooldown_free_attack(origin: Vector2, direction: Vector2, source_node: Node, damage_multiplier: float = 1.0) -> bool:
	var data := _current_weapon
	if data == null or direction.is_zero_approx():
		return false
	var context := _attack_context(source_node, data)
	context["ignore_cooldown"] = true
	_perform_attack(data, origin, direction.normalized(), source_node, maxf(damage_multiplier, 0.0), context)
	if source_node.has_method("on_persona_attack_committed"):
		source_node.on_persona_attack_committed(data, context, _active_feedback_group_id)
	return true


func try_terminal_attack(origin: Vector2, direction: Vector2, source_node: Node) -> bool:
	var data := _current_weapon
	if data == null or direction.is_zero_approx():
		return false
	var context := _attack_context(source_node, data)
	context.erase("seamless_free")
	context.erase("refutation_bonus")
	context["forced"] = true
	context["terminal"] = true
	context["ignore_cooldown"] = true
	_perform_attack(data, origin, direction.normalized(), source_node, 2.0, context)
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func is_attack_active() -> bool:
	return _swing_remaining > 0.0


func set_cooldown_remaining(value: float) -> void:
	_cooldown_remaining = maxf(value, 0.0)


func reduce_cooldown(amount: float) -> void:
	set_cooldown_remaining(_cooldown_remaining - maxf(amount, 0.0))


func get_cooldown_duration_for_weapon_id(weapon_id: StringName) -> float:
	var data: WeaponComponentData = null
	if _current_weapon != null and _current_weapon.id == weapon_id:
		data = _current_weapon
	else:
		for candidate in weapons:
			if candidate != null and candidate.id == weapon_id:
				data = candidate
				break
	if data == null:
		return 0.0
	return data.cooldown / maxf(attack_speed_multiplier + persona_attack_speed_bonus + equipment_attack_speed_bonus, 0.01)


func _perform_attack(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float,
	context: Dictionary = {}
) -> void:
	_feedback_group_serial += 1
	_active_feedback_group_id = _feedback_group_serial
	_active_terminal_attack = bool(context.get("terminal", false))
	_active_status_tags = PackedStringArray(context.get("extra_status_tags", []))
	if source_node.has_method("prepare_persona_attack_group"):
		source_node.prepare_persona_attack_group(_active_feedback_group_id, context)
	if not bool(context.get("ignore_cooldown", false)):
		_cooldown_remaining = data.cooldown / maxf(attack_speed_multiplier + persona_attack_speed_bonus + equipment_attack_speed_bonus, 0.01)
	var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
	var consume_weapon_payload := not bool(context.get("forced", false)) and not _active_terminal_attack and (cyberware == null or not cyberware.is_circuit_weapon_call_active())
	if data.id == &"gravity_wave":
		_perform_gravity_wave(data, direction, source_node, damage_multiplier)
	elif cyberware != null and cyberware.get_circuit_calamity_layers() > 0:
		_perform_projectiles(data, origin, direction.normalized(), source_node, damage_multiplier, consume_weapon_payload)
	else:
		match data.attack_kind:
			WeaponComponentData.AttackKind.MELEE:
				_begin_melee(data, direction.normalized(), damage_multiplier)
			WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD:
				_perform_projectiles(data, origin, direction.normalized(), source_node, damage_multiplier, consume_weapon_payload)
			WeaponComponentData.AttackKind.BEAM:
				_perform_beam(data, origin, direction.normalized(), source_node, damage_multiplier)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and data.noise_radius > 0.0:
		events.publish_noise(source_node, origin, data.noise_radius)
	attack_performed.emit(data)
	_active_terminal_attack = false
	_active_status_tags.clear()


func _perform_gravity_wave(data: WeaponComponentData, direction: Vector2, source_node: Node, damage_multiplier: float) -> void:
	var orb := (load(GRAVITY_WAVE_SCENE_PATH) as PackedScene).instantiate() as GravityWaveOrb
	CombatProjectile.room_for_actor(source_node).add_child(orb)
	orb.setup_wave(source_node, direction, clampf(data.charge_seconds, 0.0, GravityWaveOrb.MAX_CHARGE_SECONDS), damage_multiplier)
	orb.feedback_group_id = _active_feedback_group_id
	orb.status_tags = data.status_tags.duplicate()
	orb.status_tags.append_array(_active_status_tags)
	var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
	if cyberware != null:
		cyberware.configure_projectile(orb, direction)


func get_last_feedback_group_id() -> int:
	return _active_feedback_group_id


func _attack_context(source_node: Node, data: WeaponComponentData) -> Dictionary:
	if source_node.has_method("get_persona_attack_context"):
		var context: Variant = source_node.get_persona_attack_context(data)
		if context is Dictionary:
			return context
	return {}


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
	_swing_status_tags = _active_status_tags.duplicate()


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
	var melee_hits := world.direct_space_state.intersect_shape(query, 16)
	melee_hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.collider.global_position.distance_squared_to(origin) < b.collider.global_position.distance_squared_to(origin)
	)
	var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
	var penetrated_targets := 0
	for hit in melee_hits:
		var area: Object = hit.get("collider")
		if area == null or not area.has_method("receive_hit"):
			continue
		var instance_id := area.get_instance_id()
		if _swing_hits.has(instance_id):
			continue
		_swing_hits[instance_id] = true
		var packet := _make_packet(data, origin, sweep_direction, source_node, _swing_damage_multiplier)
		if cyberware != null and cyberware.get_circuit_penetration_boost():
			packet.base_damage *= 1 + penetrated_targets
		penetrated_targets += 1
		packet.is_melee = true
		packet.stagger_seconds = 0.75
		packet.knockback = sweep_direction * 120.0
		area.receive_hit(packet)


func _perform_projectiles(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float = 1.0,
	consume_weapon_payload: bool = false
) -> void:
	# Resolve after actor/room scripts finish loading to avoid a cyclic scene preload.
	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	var count := maxi(data.projectile_count, 1)
	var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
	var weapon_payload: Dictionary = {}
	if cyberware != null and consume_weapon_payload:
		weapon_payload = cyberware.take_pending_weapon_payload(_active_feedback_group_id)
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
		if cyberware != null and cyberware.is_world_stopped():
			projectile.begin_world_stop_launch()
		projectile.weapon_id = data.id
		projectile.damage_type = data.damage_type
		projectile.status_tags = data.status_tags.duplicate()
		projectile.status_tags.append_array(_active_status_tags)
		projectile.feedback_group_id = _active_feedback_group_id
		projectile.allows_trajectory_echo = data.attack_kind == WeaponComponentData.AttackKind.PROJECTILE and count == 1
		if cyberware != null and cyberware.get_circuit_calamity_layers() > 0:
			projectile.lifetime = maxf(projectile.lifetime, data.attack_range / maxf(projectile.speed, 1.0))
		if cyberware != null:
			cyberware.configure_projectile(projectile, direction, weapon_payload)
		if _active_terminal_attack:
			projectile.configure_explosion(48.0, 1)


func _perform_beam(
	data: WeaponComponentData,
	origin: Vector2,
	direction: Vector2,
	source_node: Node,
	damage_multiplier: float = 1.0
) -> void:
	var room := CombatProjectile.room_for_actor(source_node)
	var space := get_world_2d().direct_space_state
	# The rail beam forms inside its first five 32 px body lengths. Obstacles in
	# that formation corridor cannot choke the shot at the muzzle; beyond it the
	# first wall clips both damage and presentation.
	var penetration_distance := minf(data.beam_wall_penetration_distance, data.attack_range)
	var front := RectangleShape2D.new()
	front.size = Vector2(1.0, data.beam_width)
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = front
	sweep.transform = Transform2D(direction.angle(), origin + direction * penetration_distance)
	sweep.collision_mask = 1
	sweep.margin = 0.0
	var starts_in_wall := not space.intersect_shape(sweep, 1).is_empty()
	var remaining_range := data.attack_range - penetration_distance
	sweep.motion = direction * remaining_range
	var length := penetration_distance
	var contact_length := penetration_distance
	if not starts_in_wall:
		var motion_result := space.cast_motion(sweep)
		length += remaining_range * motion_result[0]
		contact_length += remaining_range * motion_result[1]
	var cyberware := source_node.get_node_or_null("CyberwareController") as CyberwareController
	var pierce := cyberware.get_circuit_pierce_remaining() if cyberware != null else 0
	if pierce != 0:
		length = data.attack_range
		if pierce > 0:
			var beam_start := origin + direction * penetration_distance
			var beam_end := origin + direction * data.attack_range
			var first_wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(beam_start, beam_end, 1))
			if not first_wall.is_empty():
				var next_ray := PhysicsRayQueryParameters2D.create(beam_start, beam_end, 1)
				next_ray.exclude = [first_wall.rid]
				var second_wall := space.intersect_ray(next_ray)
				if not second_wall.is_empty():
					length = origin.distance_to(second_wall.position)
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
	# Static door leaves have no hurtbox. Include the clipped contact face so
	# cast_motion's safe distance does not leave the blocking door untouched.
	var door_shape := RectangleShape2D.new()
	door_shape.size = Vector2(contact_length + 1.0, data.beam_width)
	var door_query := PhysicsShapeQueryParameters2D.new()
	door_query.shape = door_shape
	door_query.transform = Transform2D(direction.angle(), origin + direction * contact_length * 0.5)
	door_query.collision_mask = 1
	door_query.margin = 0.0
	for hit in space.intersect_shape(door_query, 256):
		if hit.collider.has_method("receive_projectile_hit"):
			var special_packet := _make_packet(data, origin, direction, source_node, damage_multiplier)
			special_packet.is_beam = true
			hit.collider.receive_projectile_hit(special_packet)
			continue
		var door := hit.collider.get_parent() as AutomaticDoor
		if door == null or CombatProjectile.room_for_actor(door) != room:
			continue
		var distance := clampf((door.global_position - origin).dot(direction), 0.0, length)
		var packet := _make_packet(data, origin, direction, source_node, damage_multiplier * _beam_damage_multiplier(data, distance))
		packet.is_beam = true
		door.receive_hit(packet)
	var hit_actors := {}
	var beam_hits := space.intersect_shape(query, 256)
	beam_hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.collider.global_position - origin).dot(direction) < (b.collider.global_position - origin).dot(direction)
	)
	var penetrated_targets := 0
	for hit in beam_hits:
		var area := hit.collider as Area2D
		if area == null or not area.has_method("receive_hit"):
			continue
		var actor: Node = area.actor if area is HurtBox2DComponent else area
		if not is_instance_valid(actor) or actor == source_node:
			continue
		if CombatProjectile.room_for_actor(actor) != room or hit_actors.has(actor.get_instance_id()):
			continue
		hit_actors[actor.get_instance_id()] = true
		var actor_distance := clampf((actor.global_position - origin).dot(direction), 0.0, length)
		var beam_multiplier := _beam_damage_multiplier(data, actor_distance)
		var packet := _make_packet(data, origin, direction, source_node, damage_multiplier * beam_multiplier)
		if cyberware != null and cyberware.get_circuit_penetration_boost():
			packet.base_damage *= 1 + penetrated_targets
		penetrated_targets += 1
		packet.is_area_damage = true
		packet.is_beam = true
		area.receive_hit(packet)
	var beam := Node2D.new()
	beam.set_script(LASER_BEAM)
	beam.set("beam_length", length)
	beam.set("beam_width", data.beam_width * (cyberware.get_circuit_visual_scale() if cyberware != null else 1.0))
	beam.set("falloff_start_distance", penetration_distance)
	room.add_child(beam)
	beam.global_position = origin
	beam.global_rotation = direction.angle()


func _beam_damage_multiplier(data: WeaponComponentData, distance: float) -> float:
	var falloff_start := minf(data.beam_wall_penetration_distance, data.attack_range)
	if distance <= falloff_start or falloff_start >= data.attack_range:
		return 1.0
	var progress := inverse_lerp(falloff_start, data.attack_range, distance)
	return lerpf(1.0, data.beam_end_damage_multiplier, progress)


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
	packet.weapon_id = data.id
	packet.damage_type = data.damage_type
	packet.status_tags = data.status_tags.duplicate()
	packet.status_tags.append_array(_swing_status_tags if data.attack_kind == WeaponComponentData.AttackKind.MELEE else _active_status_tags)
	packet.source_position = origin
	packet.travel_direction = direction
	packet.feedback_group_id = _active_feedback_group_id
	packet.terminal_attack = _active_terminal_attack and data.attack_kind in [WeaponComponentData.AttackKind.MELEE, WeaponComponentData.AttackKind.BEAM]
	packet.allows_trajectory_echo = data.attack_kind == WeaponComponentData.AttackKind.BEAM
	return packet


func _cancel_swing() -> void:
	_swing_remaining = 0.0
	_swing_duration = 0.0
	_swing_damage_multiplier = 1.0
	_swing_hits.clear()
	_swing_status_tags.clear()


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
