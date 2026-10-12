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


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	queue_redraw()


func setup(owner_node: Node, source_faction: CombatFaction.Id, heading: Vector2, projectile_damage: int, projectile_speed: float) -> void:
	source = owner_node
	faction = source_faction
	direction = heading.normalized()
	damage = projectile_damage
	speed = projectile_speed
	tint = Color(0.3, 0.9, 1.0) if faction == CombatFaction.Id.PLAYER else Color(1.0, 0.25, 0.2)
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, tint)
	draw_line(-direction * 7.0, Vector2.ZERO, tint.darkened(0.25), 2.0)


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("receive_hit"):
		return
	var packet := DamagePacket.new()
	packet.base_damage = damage
	packet.source = source
	packet.source_faction = faction
	packet.source_position = global_position - direction * 8.0
	packet.travel_direction = direction
	packet.knockback = direction * 85.0
	packet.is_projectile = true
	packet.reflectable = reflectable
	var result: DamageResult = area.receive_hit(packet)
	if result.reflected:
		faction = result.packet.source_faction
		source = result.packet.source
		direction = result.packet.travel_direction.normalized()
		tint = Color(0.95, 0.75, 0.15)
		queue_redraw()
		return
	queue_free()
