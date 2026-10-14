extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-18, -18, 36, 36), Color(0.75, 0.12, 0.12, 0.45), true)
	draw_rect(Rect2(-18, -18, 36, 36), Color(1.0, 0.3, 0.2), false, 2.0)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("receive_damage"):
		return
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source = self
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = global_position
	packet.travel_direction = global_position.direction_to(body.global_position)
	packet.knockback = packet.travel_direction * 90.0
	body.receive_damage(packet)
