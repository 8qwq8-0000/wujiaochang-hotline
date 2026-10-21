class_name FuelBarrel
extends Area2D

var broken := false
var patch: FuelPatch

func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = self
	if broken or packet.base_damage <= 0 or get_tree().paused:
		return result
	broken = true
	set_deferred("collision_layer", 0)
	result.outcome = DamageResult.Outcome.DAMAGED
	result.final_damage = 1
	result.target_defeated = true
	call_deferred("_spill")
	queue_redraw()
	return result

func _spill() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var debris := BombDebrisEffect.new()
	debris.name = "BombDebris"
	add_child(debris)
	patch = FuelPatch.new()
	EnvironmentArea.for_actor(self).add_child(patch)
	patch.global_position = global_position
	var fire := DamagePacket.new()
	fire.damage_type = &"fire"
	patch.receive_hit(fire)

func _draw() -> void:
	draw_rect(Rect2(-13,-17,26,34),Color("57504a") if broken else Color("b16e32"))
	for y in [-11,11]:
		draw_line(Vector2(-13,y),Vector2(13,y),Color("f1c88a"),3)
	if not broken:
		draw_colored_polygon(PackedVector2Array([Vector2(-5,7),Vector2(0,-8),Vector2(6,7)]),Color("ffdf7e"))
