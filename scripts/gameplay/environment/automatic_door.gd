class_name AutomaticDoor
extends Node2D

@export var knockdown_seconds := 0.8
@export var knockdown_reach := 60.0
# Kept for old scene compatibility; doors now always break instead of swinging.
@export var hinged_visual := false
var opened := false
var slammed := false
var knocked_count := 0

func _ready() -> void:
	add_to_group("environment_doors")
	$Contact.body_entered.connect(_on_contact)
	set_physics_process(true)


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
			if absf(local.x) <= 17.0 and absf(local.y) <= 38.0:
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
	opened = true
	set_physics_process(false)
	slammed = body is PlayerController and body.mobility.is_ability_active() and body.velocity.dot(direction) > 80.0
	$Body/Shape.set_deferred("disabled",true)
	if body is EnemyController:
		# Release a navigation agent that reached the leaf before its deferred
		# collider disable was flushed; this is a tiny breach step, not knockback.
		var breached_local := to_local(body.global_position)
		breached_local.x = -20.0 if side > 0.0 else 20.0
		body.global_position = to_global(breached_local)
		body.navigation_agent.target_position = body.global_position
		body._clear_navigation_recovery()
	_spawn_break_fragments(direction)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_noise(body, global_position, 160.0 if slammed else 96.0)
		events.request_effect(global_position, Color("e6bc73"), 18.0, 0.12)
	if slammed:
		call_deferred("_knock_down",direction,body)
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
		events.publish_message("冲刺撞门 · 门后敌人击倒 %.1f 秒" % knockdown_seconds,Color("f1cf85"))


func _spawn_break_fragments(direction: Vector2) -> void:
	var source := RefinedEnvironmentArt.art_texture("bulkhead_closed.png")
	var source_size := source.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var run := get_node_or_null("/root/RunManager")
	var run_seed := int(run.run_seed) if run != null else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ hash(str(get_path()))
	var fragment_count := rng.randi_range(4, 6)
	var cursor := 0.0
	for index in fragment_count:
		var remaining := source_size.x - cursor
		var pieces_left := fragment_count - index
		var width := remaining if pieces_left == 1 else clampf(remaining / float(pieces_left) * rng.randf_range(0.72, 1.28), source_size.x * 0.08, remaining - float(pieces_left - 1))
		var region := Rect2(cursor, 0.0, width, source_size.y)
		var fragment_texture := AtlasTexture.new()
		fragment_texture.atlas = source
		fragment_texture.region = region
		var fragment := Sprite2D.new()
		fragment.name = "DoorFragment%d" % index
		fragment.texture = fragment_texture
		fragment.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fragment.scale = Vector2(40.0 / source_size.x, 72.0 / source_size.y)
		fragment.position = Vector2((cursor + width * 0.5) / source_size.x * 40.0 - 20.0, 0.0)
		fragment.z_index = 4
		add_child(fragment)
		var burst := direction * rng.randf_range(8.0, 18.0) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(2.0, 8.0)
		var tween := fragment.create_tween().set_parallel(true)
		tween.tween_property(fragment, "position", fragment.position + burst, 0.12)
		tween.tween_property(fragment, "rotation", rng.randf_range(-0.22, 0.22), 0.12)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.12)
		tween.chain().tween_callback(fragment.queue_free)
		cursor += width
	for index in 5:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)])
		spark.color = Color("e6bc73") if index < 3 else Color(0.45, 0.48, 0.5, 0.7)
		spark.z_index = 5
		add_child(spark)
		var spark_target := direction * rng.randf_range(8.0, 20.0) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(3.0, 10.0)
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
