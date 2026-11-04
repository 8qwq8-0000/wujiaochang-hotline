extends ChannelMission

var door: ChannelHiddenDoor
var _last_room: CombatRoom
var _claimed := false
var _transitioning := false
var _fade_layer: CanvasLayer
var _fade: ColorRect


func _ready() -> void:
	dialogue = ChannelDialogue.new()
	add_child(dialogue)
	_last_room = assembler.generated_rooms.back()
	_last_room.open_side("Right")
	room = preload("res://scripts/gameplay/channel/channel_shrine_room.gd").new()
	room.name = "HiddenShrineRoom"
	room.position = Vector2(4096, 0)
	room.terminal_action = use_task_terminal
	floor_scene.add_child(room)
	# A separate area has its own skyline, rather than stretching the hallway.
	var backdrop := CombatGlassBackdrop.new()
	backdrop.name = "ShrineSkyline"
	backdrop.position = room.position
	backdrop.configure(1, room.SIZE.x, room.SIZE.x, run.run_seed)
	floor_scene.add_child(backdrop)

	door = ChannelHiddenDoor.new()
	door.name = "UnlitHiddenDoor"
	door.position = _last_room.position + Vector2(952, 270)
	floor_scene.add_child(door)
	_build_area_transitions()
	call_deferred("_restore_hidden_checkpoint")


func _build_area_transitions() -> void:
	_add_transition_area(door.position + Vector2(4, 0), true)
	_add_transition_area(room.position + Vector2(22, 180), false)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 110
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


func _add_transition_area(point: Vector2, entering: bool) -> void:
	var area := Area2D.new()
	area.name = "ShrineAreaEntrance" if entering else "ShrineAreaReturn"
	area.position = point
	area.collision_layer = 0
	area.collision_mask = 2
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 84)
	collider.shape = shape
	area.add_child(collider)
	floor_scene.add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body == player and door.state == ChannelHiddenDoor.State.BROKEN and (entering or room.cleared):
			_transition_area(entering)
	)


func _transition_area(entering: bool) -> void:
	if _transitioning or player.health.is_dead():
		return
	_transitioning = true
	player.set_input_enabled(false)
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.16)
	await tween.finished
	player.global_position = room.to_global(Vector2(72, 180)) if entering else door.global_position + Vector2(-40, 0)
	inside = entering
	if entering and not room.started:
		room.start()
	_update_camera()
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, 0.16)
	await tween.finished
	player.set_input_enabled(true)
	_transitioning = false


func _restore_hidden_checkpoint() -> void:
	var saved: Dictionary = run.channel_resume.duplicate(true)
	_claimed = bool(saved.get("shrine_claimed", run.channel_record_found))
	task_done = _claimed
	choice_resolved = _claimed
	if bool(saved.get("hidden_door_broken", _claimed)):
		door.break_open(false)
	if bool(saved.get("hidden_room_cleared", _claimed)):
		room.restore_cleared()
		if _claimed:
			room.terminal.enabled = false
			room.terminal.title = "祭品已取走"
	# Migrate checkpoints made while the shrine still lived at the corridor end.
	if not saved.is_empty() and float(saved.get("x", 0)) > _last_room.position.x + CombatRoom.ROOM_SIZE.x and float(saved.get("x", 0)) < room.position.x:
		saved.x = room.position.x + clampf(float(saved.x) - (_last_room.position.x + 1120), 72, 590)
		saved.y = clampf(float(saved.get("y", 180)) - 90, 32, 320)
		run.channel_resume = saved
	# Parent restores inventory drops and safe player position, then consumes resume data.
	super._restore_or_checkpoint()
	_update_camera()


func allows_next_area() -> bool:
	return not inside


func _process(_delta: float) -> void:
	door.available = assembler._rooms_remaining == 0 and not _claimed
	inside = room.contains_world_point(player.global_position)
	if not inside and not _transitioning and door.state == ChannelHiddenDoor.State.BROKEN:
		var near_door := player.global_position - door.global_position
		if absf(near_door.x) < 18 and absf(near_door.y) < 40:
			_transition_area(true)

	if inside and room.cleared and not _transitioning and room.to_local(player.global_position).x < 40:
		_transition_area(false)
	if door.state == ChannelHiddenDoor.State.BROKEN and inside and not room.started and room.to_local(player.global_position).x >= 58:
		room.start()
		_notice("隐藏房入口已封锁，击败守卫后可查看祭坛")
	if assembler._rooms_remaining == 0:
		var count := room.living_enemies().size() if room.started and not room.cleared else 0
		if run.mandatory_enemies_remaining != count:
			run.set_mandatory_enemy_count(count)


func _update_camera() -> void:
	if room.contains_world_point(player.global_position):
		player.camera.limit_smoothed = false
		player.camera.limit_left = floori(room.global_position.x)
		player.camera.limit_top = floori(room.global_position.y - CombatGlassBackdrop.BACKDROP_HEIGHT)
		player.camera.limit_right = ceili(room.global_position.x + room.SIZE.x)
		player.camera.limit_bottom = ceili(room.global_position.y + room.SIZE.y)
	else:
		_last_room._configure_player_camera_if_inside()


func offer_entry() -> void:
	# No terminal entry: the player discovers the unlit door by shooting it.
	pass


func enter_room() -> void:
	if door.state == ChannelHiddenDoor.State.BROKEN:
		_transition_area(true)


func use_task_terminal() -> void:
	if _claimed or not room.cleared or player.health.is_dead():
		return
	dialogue.open("接线员 / 祭坛上的核心", "这是通往第二结局「频道归还」的前置道具：残损频道核心。\n\n拾取后，本次行动的生命上限变为 1，移速降低 15%，突进冷却增加 40%，散热降低 30%。\n\n拾取也会建立直连并关闭本局撤离，需要继续完成后续楼层和楼顶接管。诅咒持续到行动结束；不拾取仍可正常撤离。",
		[["放弃拾取 / 保持普通行动", decline_route], ["拾取核心 / 承受诅咒", accept_route]], decline_route)


func accept_route() -> void:
	if _claimed or not room.cleared:
		return
	var before := player.export_run_state()
	if not player.inventory.grant_channel_core():
		dialogue.open("背包已满", "请先空出一格，再拾取残损频道核心。", [["知道了", Callable()]])
		return
	var old_record: bool = run.channel_record_found
	run.channel_record_found = true
	if not run.activate_channel_route():
		run.channel_record_found = old_record
		player.import_run_state(before)
		_notice("核心尚未接入，请重试")
		return
	_claimed = true
	task_done = true
	choice_resolved = true
	player.apply_channel_curse(true)
	if not save_checkpoint():
		_claimed = false
		task_done = false
		choice_resolved = false
		run.channel_route_active = false
		run.channel_record_found = old_record
		player.import_run_state(before)
		dialogue.open("核心尚未拾取", store.error_message + "。诅咒没有生效，撤离仍可用，请重试。", [["知道了", Callable()]])
		return
	room.terminal.enabled = false
	room.terminal.title = "祭品已取走"



func decline_route() -> void:
	_notice("核心仍留在祭坛上，你可以正常撤离，也可以稍后回来")


func checkpoint_details() -> Dictionary:
	return {"hidden_door_broken": door.state == ChannelHiddenDoor.State.BROKEN,
		"hidden_room_cleared": room.cleared, "shrine_claimed": _claimed}


func checkpoint_discoveries() -> Array:
	return ["shrine_core"] if _claimed else []

