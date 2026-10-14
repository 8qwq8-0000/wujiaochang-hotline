class_name WeaponController
extends Node2D

signal weapon_changed(index: int, data: WeaponComponentData)
signal attack_performed(data: WeaponComponentData)

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const DEFAULT_WEAPONS := [
	preload("res://resources/weapons/baton.tres"),
	preload("res://resources/weapons/service_pistol.tres"),
	preload("res://resources/weapons/scattergun.tres"),
]

@export var faction: CombatFaction.Id = CombatFaction.Id.PLAYER
@export var heat_component_path: NodePath

var weapons: Array[WeaponComponentData] = []
var current_index: int = 1
var _cooldown_remaining: float = 0.0

@onready var heat_component: HeatComponent = get_node(heat_component_path)


func _ready() -> void:
	for data in DEFAULT_WEAPONS:
		weapons.append(data)
	weapon_changed.emit(current_index, get_current_weapon())


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func get_current_weapon() -> WeaponComponentData:
	if weapons.is_empty():
		return null
	return weapons[current_index]


func select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_index or weapons[index] == null:
		return
	current_index = index
	weapon_changed.emit(current_index, get_current_weapon())


func cycle_weapon(step: int) -> void:
	if weapons.is_empty() or step == 0:
		return
	var direction := 1 if step > 0 else -1
	for offset in range(1, weapons.size() + 1):
		var index := posmod(current_index + direction * offset, weapons.size())
		if weapons[index] != null:
			select_weapon(index)
			return


func try_attack(origin: Vector2, direction: Vector2, source_node: Node) -> bool:
	var data := get_current_weapon()
	if data == null or _cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false
	if not heat_component.try_add_heat(data.heat_per_attack):
		return false
	_cooldown_remaining = data.cooldown
	match data.attack_kind:
		WeaponComponentData.AttackKind.MELEE:
			_perform_melee(data, origin, direction.normalized(), source_node)
		WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD:
			_perform_projectiles(data, origin, direction.normalized(), source_node)
	attack_performed.emit(data)
	return true


func _perform_melee(data: WeaponComponentData, origin: Vector2, direction: Vector2, source_node: Node) -> void:
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin + direction * data.attack_range)
	query.collision_mask = 24
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var world := get_viewport().world_2d
	if world == null:
		return
	var hits := world.direct_space_state.intersect_shape(query, 16)
	for hit in hits:
		var area: Object = hit.get("collider")
		if area == null or not area.has_method("receive_hit"):
			continue
		var packet := _make_packet(data, origin, direction, source_node)
		packet.is_melee = true
		packet.stagger_seconds = 0.75
		packet.knockback = direction * 120.0
		area.receive_hit(packet)


func _perform_projectiles(data: WeaponComponentData, origin: Vector2, direction: Vector2, source_node: Node) -> void:
	var count := maxi(data.projectile_count, 1)
	for index in count:
		var offset := 0.0
		if count > 1:
			offset = lerpf(-data.spread_degrees * 0.5, data.spread_degrees * 0.5, float(index) / float(count - 1))
		var projectile: CombatProjectile = PROJECTILE_SCENE.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = origin + direction * 18.0
		projectile.setup(source_node, faction, direction.rotated(deg_to_rad(offset)), data.damage, data.projectile_speed)


func _make_packet(data: WeaponComponentData, origin: Vector2, direction: Vector2, source_node: Node) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.base_damage = data.damage
	packet.source = source_node
	packet.source_faction = faction
	packet.damage_type = data.damage_type
	packet.status_tags = data.status_tags.duplicate()
	packet.source_position = origin
	packet.travel_direction = direction
	return packet


func set_equipped_weapon(data: WeaponComponentData) -> void:
	# Compatibility for integrations that still provide a single weapon.
	set_carried_weapons(data, null)


func set_carried_weapons(primary: WeaponComponentData, secondary: WeaponComponentData) -> void:
	weapons.assign([primary if primary != null else preload("res://resources/weapons/initial_baton.tres"), secondary])
	if current_index >= weapons.size() or weapons[current_index] == null:
		current_index = 0
	# Switching slots keeps the shared attack cooldown and player heat.
	weapon_changed.emit(current_index, get_current_weapon())
