class_name SentryTurret
extends StaticBody2D

const FOOTPRINT := Vector2(96, 96)
const PROJECTILE := preload("res://scenes/combat/projectile.tscn")

@export var detection_range := 420.0
@export var turn_speed_degrees := 135.0
@export var shot_interval := 1.5
@export var warning_seconds := 0.55
@export var projectile_speed := 260.0
@export var damage := 1

var destroyed := false
var volleys_fired := 0
var _cooldown := 1.5
var _warning := 0.0
var _locked_direction := Vector2.DOWN
var _projectiles: Array[CombatProjectile] = []
var _flash := 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var gun: Node2D = $Visuals/GunPivot

func _ready() -> void:
	add_to_group("sentry_turrets")
	health.died.connect(_on_destroyed)
	var room := get_parent()
	if room.has_signal("room_cleared"):
		room.room_cleared.connect(stop_firing)

func operational() -> bool:
	var room := get_parent()
	return not destroyed and is_inside_tree() and not get_tree().paused and room.get("active") == true and room.get("cleared") != true

func _target() -> PlayerController:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.health.is_dead() or EnvironmentArea.for_actor(player) != EnvironmentArea.for_actor(self):
		return null
	if global_position.distance_to(player.global_position) > detection_range:
		return null
	var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return null
	return player

func _physics_process(delta: float) -> void:
	_flash = maxf(0, _flash - delta)
	if not operational():
		_warning = 0
		queue_redraw()
		return
	_cooldown = maxf(0, _cooldown - delta)
	var player := _target()
	if player == null:
		_warning = 0
		queue_redraw()
		return
	if _warning > 0:
		_warning -= delta
		if _warning <= 0:
			fire_volley(_locked_direction)
			_cooldown = shot_interval
	else:
		var heading := global_position.direction_to(player.global_position)
		var desired := heading.angle() - PI * 0.5
		gun.rotation = rotate_toward(gun.rotation, desired, deg_to_rad(turn_speed_degrees) * delta)
		if _cooldown <= 0 and absf(angle_difference(gun.rotation, desired)) < 0.08:
			_locked_direction = Vector2.DOWN.rotated(gun.rotation)
			_warning = warning_seconds
	queue_redraw()

func fire_volley(heading: Vector2) -> Array[CombatProjectile]:
	var shots: Array[CombatProjectile] = []
	if not operational() or heading.is_zero_approx():
		return shots
	var forward := heading.normalized()
	var side := forward.orthogonal()
	_projectiles = _projectiles.filter(func(shot) -> bool: return is_instance_valid(shot))
	for lane in [-1.0, 1.0]:
		var origin: Vector2 = global_position + forward * 43.2 + side * lane * 7.2
		# A wall immediately beyond one muzzle absorbs only that lane.
		var ray := PhysicsRayQueryParameters2D.create(global_position, origin, 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var shot := PROJECTILE.instantiate() as CombatProjectile
		shot.position = get_parent().to_local(origin)
		shot.setup(self, CombatFaction.Id.ENEMY, forward, damage, projectile_speed)
		get_parent().add_child(shot)
		_projectiles.append(shot)
		shots.append(shot)
	volleys_fired += 1
	_flash = 0.08
	queue_redraw()
	return shots

func stop_firing() -> void:
	_warning = 0
	for shot in _projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	_projectiles.clear()
	queue_redraw()

func _on_destroyed(_packet: DamagePacket) -> void:
	if destroyed:
		return
	destroyed = true
	stop_firing()
	$StatusComponent.clear_all()
	# The intact wreck remains a solid obstacle. Keep navigation and physical
	# collision consistent with its visible silhouette after disabling combat.
	$HurtBox.set_deferred("collision_layer", 0)
	$Visuals.modulate = Color(0.34, 0.32, 0.31)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(global_position, Color(1, 0.45, 0.14), 50, 0.2)

func _draw() -> void:
	if not destroyed and is_instance_valid(health) and health.current_health < health.max_health:
		draw_line(Vector2(-22, -54), Vector2(22, -54), Color(0.12, 0.14, 0.17), 3)
		draw_line(Vector2(-22, -54), Vector2(-22 + 44.0 * health.current_health / health.max_health, -54), Color(0.95, 0.32, 0.18), 3)
	if _warning > 0:
		var side := _locked_direction.orthogonal()
		for lane in [-1.0, 1.0]:
			var origin: Vector2 = side * lane * 7.2 + _locked_direction * 43.2
			draw_line(origin, origin + _locked_direction * 100, Color(1, 0.18, 0.12, 0.65), 1.5)
	if _flash > 0:
		var heading := Vector2.DOWN.rotated(gun.rotation)
		for lane in [-1.0, 1.0]:
			draw_circle(heading * 43.2 + heading.orthogonal() * lane * 7.2, 5, Color(1, 0.7, 0.2))
