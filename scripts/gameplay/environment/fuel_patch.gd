class_name FuelPatch
extends Area2D

@export var radius := 64.0
var burning := false
var remaining := 8.0
var explosion_count := 0
var _pulse := 0.0
static var _flame_texture: Texture2D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	z_index = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collider.shape = shape
	add_child(collider)
	add_to_group("fuel_patches")
	queue_redraw()

func _physics_process(delta: float) -> void:
	var active_delta := minf(delta,remaining)
	remaining -= delta
	_pulse -= active_delta
	while _pulse <= 0 and remaining + delta > 0:
		_pulse += 1.0 if burning else 0.2
		_affect_actors(radius, burning)
	if remaining <= 0:
		queue_free()
	queue_redraw()

func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = self
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and not settings.are_elemental_reactions_enabled():
		return result
	if packet.base_damage > 0 and packet.damage_type in [&"fire", &"thermal"] and not burning and not get_tree().paused:
		# Reserve the transition before callbacks, including overlapping projectiles.
		burning = true
		remaining = 4.0
		_pulse = 1.0
		result.outcome = DamageResult.Outcome.DAMAGED
		result.final_damage = 1
		call_deferred("_explode")
	return result

func _explode() -> void:
	if explosion_count > 0 or not is_inside_tree() or is_queued_for_deletion():
		return
	explosion_count += 1
	var animation := FuelExplosionEffect.new()
	animation.name = "ExplosionAnimation"
	add_child(animation)
	_affect_actors(96.0, true)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_noise(self,global_position,240)
		events.fuel_explosion_requested.emit(global_position,96.0)

func _affect_actors(reach: float, deal_damage: bool) -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and not settings.are_elemental_reactions_enabled():
		return
	for actor in EnvironmentArea.visible_actors(self,reach):
		var hurt := actor.get_node("HurtBox") as HurtBox2DComponent
		if deal_damage:
			var packet := DamagePacket.new()
			packet.source = self
			packet.source_faction = CombatFaction.Id.ENVIRONMENT
			packet.damage_type = &"fire"
			packet.is_area_damage = true
			packet.is_continuous_damage = true
			packet.blockable = false
			packet.source_position = global_position
			hurt.receive_hit(packet)
		else:
			actor.get_node("StatusComponent").add_status(&"oiled",6,["negative","oil"])

func _draw() -> void:
	if not burning:
		draw_circle(Vector2.ZERO, radius, Color(0.34, 0.3, 0.16, 0.4))
		return
	# Scorched floor and flickering tongues keep the lingering hazard readable
	# without covering the explosion animation in an opaque orange disk.
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.1, 0.06, 0.25))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(0.95, 0.48, 0.12, 0.35), 1)
	draw_set_transform(Vector2.ZERO)
	if _flame_texture == null:
		var source := load(FuelExplosionEffect.SHEET) as Texture2D
		var cell := source.get_size() / Vector2(4, 2)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(Vector2(cell.x * 3, 0), cell)
		_flame_texture = atlas
	for index in 11:
		var angle := index * TAU / 11.0
		var point := Vector2(cos(angle) * radius * 0.65, sin(angle) * radius * 0.36)
		var height := 11 + sin(remaining * 13 + index * 1.9) * 4
		draw_texture_rect(_flame_texture, Rect2(point + Vector2(-8, -height), Vector2(16, height)), false, Color(1, 1, 1, 0.85))
