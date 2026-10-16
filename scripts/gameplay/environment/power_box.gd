class_name PowerBox
extends Area2D

enum State { READY, CLAIMED, BROKEN }
@export_range(16.0, 300.0, 1.0) var discharge_radius := 120.0
@export_enum("随机", "攻速", "散热", "格挡后摇") var buff_choice := 0
var state := State.READY
var discharge_count := 0
var prompt: Label

func _ready() -> void:
	add_to_group("power_boxes")
	prompt = Label.new()
	prompt.position = Vector2(-94, 25)
	prompt.size.x = 188
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	add_child(prompt)

func scope_room() -> Node:
	return EnvironmentArea.for_actor(self)

func can_interact(actor: Node2D) -> bool:
	if state != State.READY or get_tree().paused or not actor is PlayerController:
		return false
	if not actor.is_input_enabled() or actor.health.is_dead() or actor.global_position.distance_to(global_position) > 54:
		return false
	if EnvironmentArea.for_actor(actor) != scope_room() or scope_room().get("cleared") == true:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, actor.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func interact(actor: Node2D) -> void:
	if not can_interact(actor):
		return
	var id: StringName = RoomBuffComponent.BUFFS[buff_choice - 1] if buff_choice > 0 else RoomBuffComponent.BUFFS.pick_random()
	var buffs := actor.get_node_or_null("RoomBuffComponent") as RoomBuffComponent
	if buffs == null:
		return
	state = State.CLAIMED
	if not buffs.apply_buff(id, scope_room()):
		state = State.READY
		return
	set_deferred("collision_layer", 0)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_message("配电箱：%s · 本区域清场后失效" % RoomBuffComponent.TITLES[id], Color("9fe8ba"))
	queue_redraw()

func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = self
	if state != State.READY or packet.base_damage <= 0 or get_tree().paused:
		return result
	# Reserve the outcome before dispatching damage or interaction callbacks.
	state = State.BROKEN
	set_deferred("collision_layer", 0)
	result.outcome = DamageResult.Outcome.DAMAGED
	result.final_damage = 1
	result.target_defeated = true
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_damage(result)
	call_deferred("_discharge")
	queue_redraw()
	return result

func _discharge() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or discharge_count > 0:
		return
	discharge_count += 1
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_noise(self, global_position, 200.0)
		events.environment_discharge_requested.emit(global_position, discharge_radius)
		events.publish_message("配电箱放电 · 导电目标可触发电弧", Color("7bdcea"))
	var event := ElectricReaction.begin_event(self)
	for actor in EnvironmentArea.visible_actors(self, discharge_radius):
		var packet := DamagePacket.new()
		packet.source = self
		packet.source_faction = CombatFaction.Id.ENVIRONMENT
		packet.damage_type = &"electric"
		packet.status_tags = ["conductive"]
		packet.electric_event = event
		packet.is_area_damage = true
		packet.blockable = false
		packet.source_position = global_position
		actor.get_node("HurtBox").receive_hit(packet)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	prompt.visible = player != null and not player.health.is_dead() and player.global_position.distance_to(global_position) <= 70
	if state == State.READY:
		prompt.text = "区域已清场 · 仍可攻击放电" if scope_room().get("cleared") == true else "E 随机增益 / 攻击放电"
	elif state == State.CLAIMED:
		prompt.text = "已领取增益 · 本区域清场失效"
	else:
		prompt.text = "已放电 · 无法再领取"

func _draw() -> void:
	var color := Color("5590a6") if state == State.READY else (Color("48775f") if state == State.CLAIMED else Color("394750"))
	draw_rect(Rect2(-14,-20,28,40), color)
	draw_rect(Rect2(-14,-20,28,40), Color("b7d2d7"), false, 2)
	draw_line(Vector2(-3,-12),Vector2(-7,1),Color("f6d478"),3)
	draw_line(Vector2(-7,1),Vector2(5,-1),Color("f6d478"),3)
	draw_line(Vector2(5,-1),Vector2(1,12),Color("f6d478"),3)
