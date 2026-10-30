extends Node2D

## Restrained signal VFX only. Radio equipment belongs to the animated sprite,
## so it shares the body pose, recoil, occlusion and death presentation.
const VIOLET := Color("d68bff")
const INK := Color("19192e")
var actor: EnemyController
var elapsed := 0.0
var rupture := false
var ground_ring: Node2D


func _ready() -> void:
	if not rupture:
		actor = get_parent() as EnemyController
	z_index = 8
	if not rupture:
		ground_ring = Node2D.new()
		ground_ring.name = "BroadcastRing"
		# SignalVisual is +8; place the ground ring at actor -1, under its boots.
		ground_ring.z_index = -9
		add_child(ground_ring)
		ground_ring.draw.connect(_draw_ground_ring)
	set_process(true)


func _process(delta: float) -> void:
	elapsed += delta
	if rupture and elapsed >= 0.55:
		queue_free()
		return
	visible = rupture or (is_instance_valid(actor) and (actor.profile.signal_emitter or actor.has_signal_boost()))
	if is_instance_valid(ground_ring):
		ground_ring.visible = visible and actor.profile.signal_emitter
		if ground_ring.visible:
			ground_ring.queue_redraw()
	if visible:
		queue_redraw()


func break_signal() -> void:
	var burst := get_script().new() as Node2D
	burst.rupture = true
	get_parent().get_parent().add_child(burst)
	burst.global_position = global_position
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		var remaining := false
		for source in get_tree().get_nodes_in_group("signal_emitters"):
			if source != actor and source is EnemyController and not source.is_queued_for_deletion() and not source.health.is_dead() and EnvironmentArea.for_actor(source) == EnvironmentArea.for_actor(actor):
				remaining = true
		var message := "增幅节点已摧毁，区域内仍有信号源" if remaining else "增幅信号已切断，敌方强化解除"
		events.publish_notice(&"signal_broken", message, VIOLET)


func _draw() -> void:
	if rupture:
		var progress := elapsed / 0.55
		# A short electrical break and falling fragments, not a floating UI badge.
		for index in 6:
			var angle := TAU * index / 6.0
			var origin := Vector2(0, -22)
			var point := origin + Vector2.from_angle(angle) * progress * 22 + Vector2(0, progress * progress * 26)
			draw_rect(Rect2(point.snapped(Vector2.ONE), Vector2(2, 3)), Color(VIOLET, 1.0 - progress))
		if progress < 0.45:
			draw_polyline(PackedVector2Array([Vector2(-11, -29), Vector2(-3, -24), Vector2(1, -30), Vector2(9, -23)]), Color(VIOLET, 1.0 - progress * 2), 1)
		return
	if not is_instance_valid(actor):
		return
	if not actor.profile.signal_emitter:
		# Restore the first version's recipient shield and speed chevrons.
		var center := Vector2(0, -54)
		var shield := PackedVector2Array([center + Vector2(-5, -5), center + Vector2(5, -5), center + Vector2(5, 1), center + Vector2(0, 6), center + Vector2(-5, 1), center + Vector2(-5, -5)])
		draw_colored_polygon(shield, INK)
		draw_polyline(shield, Color(VIOLET, 0.65 + 0.3 * sin(elapsed * 5)), 2)
		for side in [-1, 1]:
			var point := Vector2(side * 15, 1)
			draw_polyline(PackedVector2Array([point + Vector2(-3, 3), point + Vector2(0, -1), point + Vector2(3, 3)]), Color(VIOLET, 0.7), 2)



func _draw_ground_ring() -> void:
	ground_ring.draw_set_transform(Vector2(0, 10), 0, Vector2(1, 0.42))
	ground_ring.draw_arc(Vector2.ZERO, 20, 0, TAU, 48, Color(VIOLET, 0.5), 1.5)
	var phase := fmod(elapsed, 1.4) / 1.4
	for index in 2:
		var pulse := fmod(phase + index * 0.5, 1.0)
		ground_ring.draw_arc(Vector2.ZERO, 21 + pulse * 36, 0, TAU, 48, Color(VIOLET, (1.0 - pulse) * 0.42), 1.5)
