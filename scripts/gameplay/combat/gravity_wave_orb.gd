class_name GravityWaveOrb
extends CombatProjectile

const BLUE := 0
const RED := 1
const PURPLE := 2
const BLUE_CHARGE_SECONDS := 3.0
const MAX_CHARGE_SECONDS := 6.0
const ORBIT_RADIUS := 96.0
const FIELD_RADIUS := 96.0
const PURPLE_GLIDE_SECONDS := 0.38
const PURPLE_GLIDE_DISTANCE := 58.0
const FUSION_SHOCKWAVE := preload("res://scripts/presentation/gravity_fusion_shockwave.gd")
const BLUE_TEXTURE := preload("res://assets/art/projectiles/gravity_wave/blue.png")
const RED_TEXTURE := preload("res://assets/art/projectiles/gravity_wave/red.png")
const PURPLE_TEXTURE := preload("res://assets/art/projectiles/gravity_wave/purple.png")
const TRAIL_BLUE := Color(0.24, 0.75, 1.0, 0.6)
const TRAIL_RED := Color(1.0, 0.27, 0.31, 0.62)
const TRAIL_PURPLE := Color(0.77, 0.37, 1.0, 0.75)

var kind := BLUE
var charge_seconds := 0.0
var radius := 24.0
var orbit_angle := 0.0
var orbit_speed := TAU / 2.0
var base_damage := 1
var blast_radius := 0.0
var _age := 0.0
var _consumed := false
var _last_hit: Dictionary = {}
var _fusion_origin := Vector2.ZERO
var _fusion_heading := Vector2.RIGHT
var _trail: CPUParticles2D


func _ready() -> void:
	super._ready()
	monitoring = false
	add_to_group("gravity_wave_orbs")


func setup_wave(owner: Node, heading: Vector2, seconds: float, multiplier: float = 1.0) -> void:
	setup(owner, CombatFaction.Id.PLAYER, heading, 1, 0.0)
	weapon_id = &"gravity_wave"
	charge_seconds = clampf(seconds, 0.0, MAX_CHARGE_SECONDS)
	kind = RED if charge_seconds >= BLUE_CHARGE_SECONDS else BLUE
	orbit_angle = heading.angle()
	lifetime = 10.0 if kind == RED else 20.0
	if kind == BLUE:
		radius = lerpf(24.0, 48.0, charge_seconds / BLUE_CHARGE_SECONDS)
		orbit_speed = TAU / 2.0
		base_damage = 1
	else:
		radius = 36.0
		orbit_speed = lerpf(TAU / 1.5, TAU / 0.75, (charge_seconds - BLUE_CHARGE_SECONDS) / (MAX_CHARGE_SECONDS - BLUE_CHARGE_SECONDS))
		base_damage = 1 if charge_seconds < 4.5 else (2 if charge_seconds < MAX_CHARGE_SECONDS else 3)
	damage = maxi(1, int(round(float(base_damage) * multiplier)))
	global_position = (owner as Node2D).global_position + Vector2.from_angle(orbit_angle) * ORBIT_RADIUS
	_set_visual()
	_setup_trail()
	_enforce_cap()


func configure_homing(target: Node2D, _turn_degrees_per_second: float) -> void:
	# Smart targeting selects the initial orbit phase; the projectile keeps its
	# authored clockwise speed after launch.
	if is_instance_valid(target) and is_instance_valid(source) and kind != PURPLE:
		orbit_angle = (target.global_position - (source as Node2D).global_position).angle()
		global_position = (source as Node2D).global_position + Vector2.from_angle(orbit_angle) * ORBIT_RADIUS


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_age += delta
	lifetime -= delta
	if (lifetime <= 0.0 and kind != PURPLE) or not is_instance_valid(source):
		queue_free()
		return
	if CombatProjectile.room_for_actor(source) != CombatProjectile.room_for_actor(self):
		queue_free()
		return
	if kind == PURPLE:
		_update_fusion_glide()
		_update_trail_direction()
		if _age >= PURPLE_GLIDE_SECONDS and _trail != null:
			_trail.emitting = false
		_touch_enemies()
		_touch_projectiles()
		if _age >= 0.8:
			_explode()
		return
	orbit_angle = wrapf(orbit_angle + orbit_speed * delta, 0.0, TAU)
	global_position = (source as Node2D).global_position + Vector2.from_angle(orbit_angle) * ORBIT_RADIUS
	_update_trail_direction()
	_apply_field(delta)
	_touch_enemies()
	_touch_projectiles()
	_check_fusion()


func _apply_field(delta: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		var distance := (enemy as Node2D).global_position.distance_to(global_position)
		if distance > FIELD_RADIUS or distance < 0.01:
			continue
		var heading: Vector2 = (global_position - (enemy as Node2D).global_position).normalized() if kind == BLUE else ((enemy as Node2D).global_position - (source as Node2D).global_position).normalized()
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(heading * 45.0 * delta)
	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		if projectile == self or not projectile is CombatProjectile or projectile.faction != CombatFaction.Id.ENEMY:
			continue
		if projectile.global_position.distance_to(global_position) > FIELD_RADIUS:
			continue
		var heading: Vector2 = (global_position - projectile.global_position).normalized() if kind == BLUE else (projectile.global_position - (source as Node2D).global_position).normalized()
		projectile.direction = (projectile.direction + heading * 0.75 * delta).normalized()


func _touch_enemies() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 8 | 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not is_instance_valid(hurt.actor) or hurt.actor == source or hurt.faction != CombatFaction.Id.ENEMY:
			continue
		if CombatProjectile.room_for_actor(hurt.actor) != CombatProjectile.room_for_actor(self):
			continue
		var id := hurt.actor.get_instance_id()
		if _age - float(_last_hit.get(id, -100.0)) < (1000.0 if kind == PURPLE else 0.5):
			continue
		_last_hit[id] = _age
		var packet := _wave_packet(damage)
		if kind == RED:
			var heavy: bool = hurt.actor.is_in_group("bosses") or (hurt.actor is EnemyController and hurt.actor.profile != null and hurt.actor.profile.id == &"heavy_anchor")
			packet.knockback = (hurt.actor.global_position - (source as Node2D).global_position).normalized() * (180.0 if heavy else 650.0)
		var result: DamageResult = hurt.receive_hit(packet)
		_notify_cyberware_hit(result)
		if has_area_behavior:
			_bonus_explosion(hurt.actor)


func _touch_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		if projectile == self or not projectile is CombatProjectile or projectile.is_queued_for_deletion() or projectile.faction != CombatFaction.Id.ENEMY:
			continue
		if projectile.global_position.distance_to(global_position) > radius + 4.0:
			continue
		if kind == BLUE:
			lifetime = minf(lifetime + 5.0, 30.0)
			projectile.queue_free()
		elif kind == PURPLE:
			projectile.queue_free()
		else:
			projectile.direction = (projectile.global_position - (source as Node2D).global_position).normalized()
			projectile.global_position += projectile.direction * 12.0


func _check_fusion() -> void:
	for other in get_tree().get_nodes_in_group("gravity_wave_orbs"):
		if other == self or not other is GravityWaveOrb or other._consumed or other.kind == kind or other.kind == PURPLE or other.source != source:
			continue
		if global_position.distance_to(other.global_position) > radius + other.radius:
			continue
		var blue: GravityWaveOrb = self if kind == BLUE else other
		var red: GravityWaveOrb = self if kind == RED else other
		var fusion_position: Vector2 = (global_position + other.global_position) * 0.5
		var fused := (load("res://scenes/combat/gravity_wave_orb.tscn") as PackedScene).instantiate() as GravityWaveOrb
		get_parent().add_child(fused)
		fused.setup_fusion(blue, red, fusion_position)
		var shockwave := Node2D.new()
		shockwave.set_script(FUSION_SHOCKWAVE)
		get_parent().add_child(shockwave)
		shockwave.global_position = fusion_position
		_consumed = true
		other._consumed = true
		_fade_after_fusion()
		other._fade_after_fusion()
		return


func setup_fusion(blue: GravityWaveOrb, red: GravityWaveOrb, position: Vector2) -> void:
	source = blue.source
	faction = CombatFaction.Id.PLAYER
	weapon_id = &"gravity_wave"
	kind = PURPLE
	radius = 48.0
	global_position = position
	_fusion_origin = position
	_fusion_heading = Vector2.from_angle((position - (source as Node2D).global_position).angle() + PI * 0.5)
	orbit_angle = _fusion_heading.angle()
	base_damage = blue.base_damage + red.base_damage
	damage = blue.damage + red.damage
	blast_radius = lerpf(180.0, 360.0, (blue.radius - 24.0) / 24.0)
	lifetime = 0.8
	status_tags = blue.status_tags.duplicate()
	for tag in red.status_tags:
		if not tag in status_tags:
			status_tags.append(tag)
	feedback_group_id = blue.feedback_group_id
	circuit_arc_chains = maxi(blue.circuit_arc_chains, red.circuit_arc_chains)
	circuit_echo_layers = maxi(blue.circuit_echo_layers, red.circuit_echo_layers)
	electric_arc_enabled = blue.electric_arc_enabled or red.electric_arc_enabled
	explosion_radius = maxf(blue.explosion_radius, red.explosion_radius)
	explosion_damage = maxi(blue.explosion_damage, red.explosion_damage)
	has_area_behavior = blue.has_area_behavior or red.has_area_behavior
	_set_visual()
	_setup_trail()


func _update_fusion_glide() -> void:
	var progress := clampf(_age / PURPLE_GLIDE_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	global_position = _fusion_origin + _fusion_heading * PURPLE_GLIDE_DISTANCE * eased


func _fade_after_fusion() -> void:
	if _trail != null:
		_trail.emitting = false
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null:
		queue_free()
		return
	z_index = 3
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _explode() -> void:
	var shape := CircleShape2D.new()
	shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 8 | 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 256):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not is_instance_valid(hurt.actor) or hurt.actor == source or hurt.faction != CombatFaction.Id.ENEMY or seen.has(hurt.actor.get_instance_id()):
			continue
		if CombatProjectile.room_for_actor(hurt.actor) != CombatProjectile.room_for_actor(self):
			continue
		seen[hurt.actor.get_instance_id()] = true
		var packet := _wave_packet(damage * 2)
		packet.is_area_damage = true
		var result: DamageResult = hurt.receive_hit(packet)
		_notify_cyberware_hit(result)
	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		if projectile != self and projectile is CombatProjectile and projectile.faction == CombatFaction.Id.ENEMY and projectile.global_position.distance_to(global_position) <= blast_radius:
			projectile.queue_free()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(global_position, Color(0.55, 0.12, 0.95), blast_radius, 0.3)
	_consumed = true
	queue_free()


func _wave_packet(amount: int) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = amount
	packet.source = source
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.weapon_id = &"gravity_wave"
	packet.damage_type = &"energy"
	packet.status_tags = status_tags.duplicate()
	packet.source_position = global_position
	packet.travel_direction = Vector2.from_angle(orbit_angle)
	packet.knockback = Vector2.ZERO
	packet.is_projectile = true
	packet.feedback_group_id = feedback_group_id
	return packet


func _notify_cyberware_hit(result: DamageResult) -> void:
	if result == null or not is_instance_valid(source):
		return
	var cyberware := source.get_node_or_null("CyberwareController") as CyberwareController
	if cyberware != null and (circuit_arc_chains > 0 or circuit_echo_layers > 0):
		cyberware.on_circuit_projectile_hit(self, result)


func _bonus_explosion(direct_actor: Node2D) -> void:
	if explosion_radius <= 0.0 or explosion_damage <= 0:
		return
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, direct_actor.global_position)
	query.collision_mask = 8 | 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not is_instance_valid(hurt.actor) or hurt.actor == source or hurt.actor == direct_actor or hurt.faction != CombatFaction.Id.ENEMY or seen.has(hurt.actor.get_instance_id()):
			continue
		seen[hurt.actor.get_instance_id()] = true
		var packet := _wave_packet(explosion_damage)
		packet.is_area_damage = true
		var result: DamageResult = hurt.receive_hit(packet)
		_notify_cyberware_hit(result)


func _enforce_cap() -> void:
	var peers: Array[GravityWaveOrb] = []
	for orb in get_tree().get_nodes_in_group("gravity_wave_orbs"):
		if orb is GravityWaveOrb and orb != self and orb.kind == kind and orb.source == source and not orb._consumed:
			peers.append(orb)
	if peers.size() >= 3:
		peers.sort_custom(func(a: GravityWaveOrb, b: GravityWaveOrb) -> bool: return a.get_instance_id() < b.get_instance_id())
		peers[0]._consumed = true
		peers[0].queue_free()


func _set_visual() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite == null:
		return
	sprite.texture = BLUE_TEXTURE if kind == BLUE else (RED_TEXTURE if kind == RED else PURPLE_TEXTURE)
	sprite.scale = Vector2.ONE * (radius * 2.0 / float(maxi(sprite.texture.get_width(), sprite.texture.get_height())))
	sprite.modulate = Color.WHITE


func _setup_trail() -> void:
	if _trail == null:
		_trail = CPUParticles2D.new()
		_trail.name = "TrailParticles"
		_trail.local_coords = false
		_trail.show_behind_parent = true
		_trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var pixel := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		pixel.fill(Color.WHITE)
		_trail.texture = ImageTexture.create_from_image(pixel)
		add_child(_trail)
	var tint := TRAIL_BLUE if kind == BLUE else (TRAIL_RED if kind == RED else TRAIL_PURPLE)
	var fade := Gradient.new()
	fade.set_color(0, tint)
	fade.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	_trail.color_ramp = fade
	_trail.amount = 9 if kind == BLUE else (12 if kind == RED else 18)
	_trail.lifetime = 0.35 if kind != PURPLE else 0.28
	_trail.speed_scale = 1.0
	_trail.spread = 20.0 if kind != PURPLE else 12.0
	_trail.initial_velocity_min = 18.0 if kind == BLUE else (30.0 if kind == RED else 50.0)
	_trail.initial_velocity_max = 38.0 if kind == BLUE else (55.0 if kind == RED else 75.0)
	_trail.gravity = Vector2.ZERO
	_trail.emitting = true
	_update_trail_direction()


func _update_trail_direction() -> void:
	if _trail == null or not is_instance_valid(source):
		return
	if kind == PURPLE:
		_trail.direction = -_fusion_heading
	else:
		var radial := (global_position - (source as Node2D).global_position).normalized()
		_trail.direction = -radial if kind == BLUE else radial


func _sync_visual() -> void:
	_set_visual()


func _on_area_entered(_area: Area2D) -> void:
	pass
