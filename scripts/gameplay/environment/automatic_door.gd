class_name AutomaticDoor
extends Node2D

@export var knockdown_seconds := 0.8
@export var knockdown_reach := 60.0
@export var opening_width := 64.0
# Kept for old scene compatibility; doors now always break instead of swinging.
@export var hinged_visual := false
var opened := false
var slammed := false
var knocked_count := 0

func _ready() -> void:
	add_to_group("environment_doors")
	_apply_opening_width()
	$Contact.body_entered.connect(_on_contact)
	set_physics_process(true)


func configure_opening_width(value: float) -> void:
	opening_width = maxf(value, 1.0)
	if is_node_ready():
		_apply_opening_width()


func _apply_opening_width() -> void:
	var body_shape := $Body/Shape.shape.duplicate() as RectangleShape2D
	body_shape.size = Vector2(body_shape.size.x, opening_width)
	$Body/Shape.shape = body_shape
	var contact_shape := $Contact/Shape.shape.duplicate() as RectangleShape2D
	contact_shape.size = Vector2(contact_shape.size.x, opening_width + 8.0)
	$Contact/Shape.shape = contact_shape
	$RefinedArt.queue_redraw()


func _physics_process(_delta: float) -> void:
	if opened or get_tree().paused:
		return
	# Character navigation can settle flush against a static leaf before the
	# Area2D enter event is delivered. Treat that same overlap as body contact.
	for group in [&"player", &"enemies"]:
		for candidate in get_tree().get_nodes_in_group(group):
			if not candidate is Node2D:
				continue
			var local := to_local(candidate.global_position)
			if absf(local.x) <= 17.0 and absf(local.y) <= opening_width * 0.5 + 6.0:
				_on_contact(candidate)
				if opened:
					return

func _on_contact(body: Node2D) -> void:
	if opened or get_tree().paused or not (body is PlayerController or body is EnemyController) or body.health.is_dead():
		return
	if body is PlayerController and not body.is_input_enabled():
		return
	if EnvironmentArea.for_actor(body) != EnvironmentArea.for_actor(self):
		return
	var normal := global_transform.x.normalized()
	var side := (body.global_position-global_position).dot(normal)
	var direction := -normal if side > 0 else normal
	if body is EnemyController:
		# Never teleport an enemy across the leaf. Once the deferred collider
		# disable is flushed, its existing velocity and navigation target carry
		# it through naturally on the next physics frame.
		body._clear_navigation_recovery()
	_break_open(direction, body, body is PlayerController and body.dash.is_dashing() and body.velocity.dot(direction) > 80.0)

func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = self
	if not is_inside_tree() or opened or get_tree().paused or packet == null or not packet.is_projectile or packet.base_damage <= 0:
		return result
	var normal := global_transform.x.normalized()
	var direction := normal if packet.travel_direction.dot(normal) >= 0 else -normal
	if packet.travel_direction.is_zero_approx():
		direction = -normal if (packet.source_position - global_position).dot(normal) > 0 else normal
	var instigator: Node = packet.source if is_instance_valid(packet.source) else self
	_break_open(direction, instigator, false)
	result.outcome = DamageResult.Outcome.DAMAGED
	result.final_damage = 1
	result.target_defeated = true
	return result

func _break_open(direction: Vector2, source: Node, with_slam: bool) -> void:
	if opened:
		return
	# Reserve the break before callbacks so multiple bullets cannot duplicate it.
	opened = true
	slammed = with_slam
	set_physics_process(false)
	$Body/Shape.set_deferred("disabled",true)
	_spawn_break_fragments(direction)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_noise(source, global_position, 160.0 if slammed else 96.0)
		events.request_effect(global_position, Color("e6bc73"), 18.0, 0.12)
	if slammed:
		call_deferred("_knock_down",direction,source)
	queue_redraw()

func _knock_down(direction: Vector2, source: Node2D) -> void:
	if not is_instance_valid(source) or not is_inside_tree():
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is EnemyController or enemy.health.is_dead() or EnvironmentArea.for_actor(enemy) != EnvironmentArea.for_actor(self):
			continue
		var delta: Vector2 = enemy.global_position-global_position
		if delta.dot(direction) <= 0 or delta.dot(direction) > knockdown_reach or absf(delta.cross(direction)) > 38:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position,enemy.global_position,1,[$Body.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		enemy.apply_stagger(knockdown_seconds)
		enemy.get_node("StatusComponent").add_status(&"knocked_down",knockdown_seconds,["negative","control"])
		enemy.apply_knockback(direction*120)
		knocked_count += 1
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_message("冲刺撞开门，门后的敌人倒地 %.1f 秒" % knockdown_seconds,Color("f1cf85"))


func _spawn_break_fragments(direction: Vector2) -> void:
	var horizontal := absf(sin(global_rotation)) > 0.5
	var source := CombatArchitecture.door_texture(horizontal)
	var art_rect := CombatArchitecture.door_rect(horizontal, opening_width)
	var source_size := source.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var run := get_node_or_null("/root/RunManager")
	var run_seed := int(run.run_seed) if run != null else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ hash(str(get_path()))
	var fragment_count := rng.randi_range(10, 14)
	var cursor := 0.0
	for index in fragment_count:
		var source_length := source_size.x if horizontal else source_size.y
		var remaining := source_length - cursor
		var pieces_left := fragment_count - index
		var width := remaining if pieces_left == 1 else clampf(remaining / float(pieces_left) * rng.randf_range(0.72, 1.28), source_length * 0.025, remaining - float(pieces_left - 1))
		var region := Rect2(cursor, 0.0, width, source_size.y) if horizontal else Rect2(0.0, cursor, source_size.x, width)
		var fragment_texture := AtlasTexture.new()
		fragment_texture.atlas = source
		fragment_texture.region = region
		var fragment := Sprite2D.new()
		fragment.name = "DoorFragment%d" % index
		fragment.texture = fragment_texture
		fragment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fragment.scale = art_rect.size / source_size
		fragment.rotation = -global_rotation
		var progress := (cursor + width * 0.5) / source_length
		var world_offset := Vector2(art_rect.position.x + progress * art_rect.size.x, art_rect.get_center().y) if horizontal else Vector2(art_rect.get_center().x, art_rect.position.y + progress * art_rect.size.y)
		fragment.position = world_offset.rotated(-global_rotation)
		fragment.z_index = 4
		add_child(fragment)
		var burst := (direction * rng.randf_range(14.0, 34.0) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(4.0, 14.0)).rotated(-global_rotation)
		var landing := fragment.position + burst
		var air_point := fragment.position + burst * 0.6 + Vector2(0, -12).rotated(-global_rotation)
		var tween := fragment.create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "position", air_point, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "rotation", -global_rotation + rng.randf_range(-0.8, 0.8), 0.32)
		tween.tween_property(fragment, "scale", fragment.scale * Vector2(0.55, 0.32), 0.32)
		tween.chain().tween_property(fragment, "position", landing, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			# Settled chips belong to the ground and persist until room unload.
			fragment.z_as_relative = false
			fragment.z_index = -1
			fragment.modulate = Color(0.62, 0.68, 0.73)
			fragment.set_meta("ground_debris", true)
		)
		cursor += width
	for index in 5:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)])
		spark.color = Color("e6bc73") if index < 3 else Color(0.45, 0.48, 0.5, 0.7)
		spark.z_index = 5
		add_child(spark)
		var spark_target := (direction * rng.randf_range(8.0, 20.0) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(3.0, 10.0)).rotated(-global_rotation)
		var spark_tween := spark.create_tween().set_parallel(true)
		spark_tween.tween_property(spark, "position", spark_target, 0.12)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.12)
		spark_tween.chain().tween_callback(spark.queue_free)

func _draw() -> void:
	draw_rect(Rect2(-9,-36,18,72),Color("8aabb3"),false,3)
	if opened:
		draw_rect(Rect2(-3,-34,30,7),Color("40687b"))
		draw_rect(Rect2(-3,27,30,7),Color("40687b"))
	else:
		draw_rect(Rect2(-5,-32,10,64),Color("40687b"))
		draw_line(Vector2(-4,0),Vector2(4,0),Color("edcf82"),3)
