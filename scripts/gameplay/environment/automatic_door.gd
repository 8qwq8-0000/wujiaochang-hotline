class_name AutomaticDoor
extends Node2D

@export var knockdown_seconds := 0.8
@export var knockdown_reach := 60.0
var opened := false
var slammed := false
var knocked_count := 0

func _ready() -> void:
	add_to_group("environment_doors")
	$Contact.body_entered.connect(_on_contact)

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
	slammed = body is PlayerController and body.mobility.is_ability_active() and body.velocity.dot(direction) > 80.0
	$Body/Shape.set_deferred("disabled",true)
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
		events.publish_noise(source,global_position,160)
		events.publish_message("冲刺撞门 · 门后敌人击倒 %.1f 秒" % knockdown_seconds,Color("f1cf85"))

func _draw() -> void:
	draw_rect(Rect2(-9,-36,18,72),Color("8aabb3"),false,3)
	if opened:
		draw_rect(Rect2(-3,-34,30,7),Color("40687b"))
		draw_rect(Rect2(-3,27,30,7),Color("40687b"))
	else:
		draw_rect(Rect2(-5,-32,10,64),Color("40687b"))
		draw_line(Vector2(-4,0),Vector2(4,0),Color("edcf82"),3)
