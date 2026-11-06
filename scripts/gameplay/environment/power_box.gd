class_name PowerBox
extends Area2D

enum State { READY, CLAIMED, BROKEN }
const BUFF_ART := {
	&"attack_speed": preload("res://assets/art/ui/feedback/charging_station_v1/attack_speed_25.png"),
	&"guard_recovery": preload("res://assets/art/ui/feedback/charging_station_v1/guard_recovery_30.png"),
}
@export_range(16.0, 300.0, 1.0) var discharge_radius := 120.0
@export_enum("义体终端", "攻速", "能量恢复", "格挡后摇") var buff_choice := 0
var state := State.READY
var discharge_count := 0
var prompt: Label
var _buff_feedback: Node2D

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


func is_circuit_terminal() -> bool:
	return buff_choice == 0

func can_interact(actor: Node2D) -> bool:
	var terminal_available := is_circuit_terminal() and state in [State.READY, State.CLAIMED]
	if (state != State.READY and not terminal_available) or get_tree().paused or not actor is PlayerController:
		return false
	if not actor.is_input_enabled() or actor.health.is_dead() or actor.global_position.distance_to(global_position) > 76:
		return false
	if EnvironmentArea.for_actor(actor) != scope_room():
		return false
	var room_cleared: bool = scope_room().get("cleared") == true
	if (is_circuit_terminal() and not room_cleared) or (not is_circuit_terminal() and room_cleared):
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, actor.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func interact(actor: Node2D) -> void:
	if not can_interact(actor):
		return
	if is_circuit_terminal():
		_claim_circuit_terminal(actor as PlayerController)
		return
	var id: StringName = RoomBuffComponent.BUFFS[buff_choice - 1] if buff_choice > 0 else RoomBuffComponent.BUFFS.pick_random()
	var buffs := actor.get_node_or_null("RoomBuffComponent") as RoomBuffComponent
	if buffs == null:
		return
	state = State.CLAIMED
	if not buffs.apply_buff(id, scope_room()):
		state = State.READY
		return
	_show_buff_feedback(id, actor)
	set_deferred("collision_layer", 0)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_message("获得增益：%s。本区域清理后失效" % RoomBuffComponent.TITLES[id], Color("9fe8ba"))
	$ActiveSigil.refresh()
	queue_redraw()


func _claim_circuit_terminal(actor: PlayerController) -> void:
	var first_sync := state == State.READY
	var module_id := actor.cyberware.claim_terminal_module() if first_sync else StringName()
	state = State.CLAIMED
	$ActiveSigil.refresh()
	queue_redraw()
	var events := get_node_or_null("/root/CombatEvents")
	if first_sync and events != null:
		if module_id.is_empty():
			events.publish_message("义体终端已接入", Color("8fffe4"))
		else:
			var data := load(ComponentRolls.cyberware_resource_path(module_id)) as CyberwareData
			var title := data.display_name if data != null else String(module_id)
			events.publish_message("获得义体：%s" % title, Color("8fffe4"))
	var hud := get_tree().get_first_node_in_group(&"combat_hud")
	if hud != null:
		var editor: CyberwareCircuitPanel = hud.get_circuit_editor()
		if editor != null:
			editor.set_open(true)

func _show_buff_feedback(id: StringName, actor: Node2D) -> void:
	var feedback := Node2D.new()
	_buff_feedback = feedback
	prompt.hide()
	feedback.name = "ChargingBuffFeedback"
	feedback.add_to_group("charging_buff_feedback")
	feedback.z_as_relative = false
	feedback.z_index = 100
	add_child(feedback)
	feedback.top_level = true
	feedback.global_position = actor.global_position + Vector2(0, -80)
	if id == &"energy_recovery":
		var title := Label.new()
		title.text = "能量恢复 +50%"
		title.theme = CyberUITheme.create_theme()
		title.position = Vector2(-110, -15)
		title.size.x = 220
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("9fe8ba"))
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 3)
		feedback.add_child(title)
	else:
		var sprite := Sprite2D.new()
		sprite.texture = BUFF_ART[id]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var width := 220.0 if id == &"guard_recovery" else 184.0
		sprite.scale = Vector2.ONE * width / sprite.texture.get_width()
		feedback.add_child(sprite)
	var detail := Label.new()
	detail.text = "本区域清场后失效"
	detail.theme = CyberUITheme.create_theme()
	detail.position = Vector2(-110, 23)
	detail.size.x = 220
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", Color("e9f8f4"))
	detail.add_theme_color_override("font_outline_color", Color.BLACK)
	detail.add_theme_constant_override("outline_size", 2)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.add_child(detail)
	feedback.scale = Vector2.ONE * 0.35
	var tween := feedback.create_tween().set_parallel(true)
	tween.tween_property(feedback, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback, "position:y", feedback.position.y - 12, 1.3)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.35).set_delay(0.95)
	tween.chain().tween_callback(feedback.queue_free)

func receive_hit(packet: DamagePacket) -> DamageResult:
	var result := DamageResult.new()
	result.packet = packet
	result.target = self
	# A charging station is an interaction fixture, never a damage target.
	# Keep this no-op for direct melee/status callers and old scene references.
	return result

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	prompt.visible = not is_instance_valid(_buff_feedback) and player != null and not player.health.is_dead() and player.global_position.distance_to(global_position) <= 96
	if state == State.READY:
		if is_circuit_terminal():
			prompt.text = ControlPrompts.adapt("E 接入义体终端") if scope_room().get("cleared") == true else "清场后接入义体终端"
		else:
			prompt.text = "本区域已清场" if scope_room().get("cleared") == true else ControlPrompts.adapt("E 领取区域增益")
	elif state == State.CLAIMED:
		prompt.text = ControlPrompts.adapt("E 打开义体终端") if is_circuit_terminal() else "增益已领取（本区域清理后失效）"
	else:
		prompt.text = "充电台不可用"
	if prompt.visible:
		_update_prompt_placement()

func _update_prompt_placement() -> void:
	var text_size := Vector2(maxf(188, prompt.get_minimum_size().x), maxf(18, prompt.get_minimum_size().y))
	prompt.size = text_size
	var candidates: Array[Vector2] = [
		Vector2(-text_size.x * 0.5, -text_size.y - 42),
		Vector2(-text_size.x * 0.5, 40),
		Vector2(-text_size.x - 42, -text_size.y * 0.5),
		Vector2(42, -text_size.y * 0.5),
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
	draw_rect(Rect2(-32,-32,64,64), color)
	draw_rect(Rect2(-32,-32,64,64), Color("b7d2d7"), false, 2)
	draw_line(Vector2(-3,-12),Vector2(-7,1),Color("f6d478"),3)
	draw_line(Vector2(-7,1),Vector2(5,-1),Color("f6d478"),3)
	draw_line(Vector2(5,-1),Vector2(1,12),Color("f6d478"),3)
