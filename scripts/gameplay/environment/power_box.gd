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
	prompt.theme = CyberUITheme.create_theme()
	prompt.add_theme_color_override("font_color", Color("e9f8f4"))
	prompt.z_as_relative = false
	prompt.z_index = 30
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		events.publish_message("充电台：%s · 本区域清场后失效" % RoomBuffComponent.TITLES[id], Color("9fe8ba"))
	$ActiveSigil.refresh()
	queue_redraw()

func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = self
	# A charging station is an interaction fixture, never a damage target.
	# Keep this no-op for direct melee/status callers and old scene references.
	return result

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	prompt.visible = player != null and not player.health.is_dead() and player.global_position.distance_to(global_position) <= 70
	if state == State.READY:
		prompt.text = "本区域已清场" if scope_room().get("cleared") == true else "E 领取随机增益"
	elif state == State.CLAIMED:
		prompt.text = "已领取增益 · 本区域清场失效"
	else:
		prompt.text = "充电台不可用"
	if prompt.visible:
		_update_prompt_placement()

func _update_prompt_placement() -> void:
	var text_size := Vector2(maxf(188, prompt.get_minimum_size().x), maxf(18, prompt.get_minimum_size().y))
	prompt.size = text_size
	var candidates: Array[Vector2] = [
		Vector2(-text_size.x * 0.5, -text_size.y - 34),
		Vector2(-text_size.x * 0.5, 28),
		Vector2(-text_size.x - 28, -text_size.y * 0.5),
		Vector2(28, -text_size.y * 0.5),
	]
	var shape := RectangleShape2D.new()
	# Extra lower clearance accounts for the wall artwork above its collider.
	shape.size = text_size + Vector2(8, 24)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1 | 128
	var solid := get_node_or_null("SolidBody") as StaticBody2D
	if solid != null:
		query.exclude = [solid.get_rid()]
	var room := scope_room() as CombatRoom
	for index in candidates.size():
		var point := candidates[index]
		if room != null:
			var in_room := room.to_local(to_global(point))
			in_room.x = clampf(in_room.x, 20, room.ROOM_SIZE.x - text_size.x - 20)
			in_room.y = clampf(in_room.y, 20, room.ROOM_SIZE.y - text_size.y - 20)
			point = to_local(room.to_global(in_room))
		if index == 0:
			prompt.position = point
		query.transform = Transform2D(0, to_global(point + text_size * 0.5 + Vector2(0, 8)))
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			prompt.position = point
			return

func _draw() -> void:
	var color := Color("5590a6") if state == State.READY else (Color("48775f") if state == State.CLAIMED else Color("394750"))
	draw_rect(Rect2(-14,-20,28,40), color)
	draw_rect(Rect2(-14,-20,28,40), Color("b7d2d7"), false, 2)
	draw_line(Vector2(-3,-12),Vector2(-7,1),Color("f6d478"),3)
	draw_line(Vector2(-7,1),Vector2(5,-1),Color("f6d478"),3)
	draw_line(Vector2(5,-1),Vector2(1,12),Color("f6d478"),3)
