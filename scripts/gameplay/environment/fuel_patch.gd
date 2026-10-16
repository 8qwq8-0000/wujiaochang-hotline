class_name FuelPatch
extends Area2D

@export var radius := 64.0
var burning := false
var remaining := 8.0
var explosion_count := 0
var _pulse := 0.0

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
	_affect_actors(96.0, true)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_noise(self,global_position,240)
		events.fuel_explosion_requested.emit(global_position,96.0)

func _affect_actors(reach: float, deal_damage: bool) -> void:
	for actor in EnvironmentArea.visible_actors(self,reach):
		var hurt := actor.get_node("HurtBox") as HurtBox2DComponent
		if deal_damage:
			var packet := DamagePacket.new()
			packet.source = self
			packet.source_faction = CombatFaction.Id.ENVIRONMENT
			packet.damage_type = &"fire"
			packet.is_area_damage = true
			packet.blockable = false
			packet.source_position = global_position
			hurt.receive_hit(packet)
		else:
			actor.get_node("StatusComponent").add_status(&"oiled",6,["negative","oil"])

func _draw() -> void:
	var color := Color("d96625") if burning else Color("574d2a")
	color.a = 0.65
	draw_circle(Vector2.ZERO,radius,color)
	draw_arc(Vector2.ZERO,radius,0,TAU,40,Color("f5b74d") if burning else Color("b8a24f"),2)
	if burning:
		for index in 7:
			var point := Vector2.from_angle(index*TAU/7)*radius*0.55
			draw_colored_polygon(PackedVector2Array([point+Vector2(-5,5),point+Vector2(1,-12),point+Vector2(6,5)]),Color("ffdc75"))
