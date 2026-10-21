extends Node2D

signal training_shot_fired(index: int)
const SCENE_PATH := "res://scenes/debug/parry_training.tscn"
const CENTER := Vector2(410, 216)
const RADIUS := 112.0
const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const SHOT := preload("res://scenes/combat/projectile.tscn")
var shot_interval := 0.9
var robot_health := 3
var bullet_speed := 260.0
var robots: Array[EnemyController] = []
var sliders: Dictionary = {}
var perfects := 0
var misses := 0
var last_fired_index := -1
var _next_index := 0
var _shot_remaining := 1.4
var _leaving := false
var _editing := false
var _panel: TerminalPanel
var _status: Label
var _turn: Label
var _hud: CanvasLayer
@onready var player: PlayerController = $Player
@onready var ui: CanvasLayer = $UI


func _enter_tree() -> void:
	add_to_group("combat_rooms")
	add_to_group("parry_training")


func _ready() -> void:
	get_node("/root/RunManager").begin_run()
	player.camera.enabled = false
	_hud = get_tree().current_scene.get_node_or_null("CombatHUD") as CanvasLayer
	if _hud != null:
		_hud.hide()
	_build_ui()
	_reset_robots()
	get_node("/root/CombatEvents").damage_resolved.connect(_on_damage_resolved)
	queue_redraw()


func receive_scene_payload(payload: Dictionary) -> void:
	var settings: Dictionary = payload.get("training_settings", {})
	for key in ["interval", "health", "speed"]:
		if settings.has(key):
			sliders[key].value = settings[key]


func _make_label(parent: Node, text: String, point: Vector2, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _build_ui() -> void:
	_make_label(ui, "盾反训练营 / PARRY LAB", Vector2(14, 10), 20)
	_make_label(ui, "鼠标瞄准来弹 · 右键盾反 · 连续两次完美触发 PERFECT!", Vector2(14, 40), 11)
	_panel = TerminalPanel.new()
	_panel.title = "训练参数"
	_panel.accent_color = Color("bb7bff")
	_panel.position = Vector2(12, 76)
	_panel.size = Vector2(184, 235)
	ui.add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_add_slider(column, "interval", "射击间隔", 0.4, 2.0, 0.1, shot_interval, "秒")
	_add_slider(column, "speed", "子弹速度", 120, 600, 20, bullet_speed, "px/s")
	_add_slider(column, "health", "机器人血量", 1, 10, 1, robot_health, "点")
	_make_label(column, "血量调整会重置全部机器人\n本场训练不写入正式存档", Vector2.ZERO, 10)
	_button("重置训练 [R]", Vector2(500, 12), restart_training)
	_button("返回仓库", Vector2(500, 40), return_to_warehouse)
	_status = _make_label(ui, "", Vector2(14, 330), 11)
	_turn = _make_label(ui, "", Vector2(232, 76), 11)


func _add_slider(parent: Node, key: String, title: String, minimum: float, maximum: float, step: float, initial: float, unit: String) -> void:
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 12)
	parent.add_child(caption)
	var slider := HSlider.new()
	slider.name = key.capitalize() + "Slider"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(160, 16)
	parent.add_child(slider)
	sliders[key] = slider
	var update := func(value: float) -> void:
		caption.text = "%s  %s %s" % [title, (str(int(value)) if step >= 1.0 else "%.1f" % value), unit]
	update.call(initial)
	slider.drag_started.connect(func() -> void: _editing = true)
	slider.drag_ended.connect(func(_changed: bool) -> void: _editing = false)
	slider.value_changed.connect(func(value: float) -> void:
		update.call(value)
		match key:
			"interval": shot_interval = value
			"speed": bullet_speed = value
			"health":
				robot_health = int(value)
				call_deferred("_reset_robots")
		_shot_remaining = shot_interval
		_clear_shots()
		var feedback := get_tree().current_scene.get_node_or_null("VFXManager/PerfectParryFeedback") as PerfectParryFeedback
		if feedback != null:
			feedback.clear()
	)


func _button(text: String, point: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = point
	button.size = Vector2(126, 23)
	button.add_theme_font_size_override("font_size", 12)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(action)
	ui.add_child(button)


func _reset_robots() -> void:
	if _leaving or not is_inside_tree():
		return
	_clear_shots()
	for enemy in robots:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
			enemy.queue_free()
	robots.clear()
	for index in 3:
		var enemy := ENEMY.instantiate() as EnemyController
		enemy.profile = preload("res://resources/enemies/ranged_sightline.tres").duplicate()
		enemy.profile.max_health = robot_health
		enemy.profile.patrol_enabled = false
		enemy.stationary_test_target = true
		enemy.mandatory = false
		enemy.position = CENTER + Vector2.UP.rotated(TAU * index / 3.0) * RADIUS
		enemy.initial_facing = enemy.position.direction_to(CENTER)
		$Robots.add_child(enemy)
		robots.append(enemy)
		var nameplate := _make_label(enemy, "", Vector2(-30, 20), 10)
		enemy.health.health_changed.connect(func(current: int, maximum: int, _delta: int) -> void:
			nameplate.text = "%02d · %d/%d" % [index + 1, current, maximum]
		)
		nameplate.text = "%02d · %d/%d" % [index + 1, robot_health, robot_health]
	_next_index = 0
	_shot_remaining = maxf(shot_interval, 1.0)
	last_fired_index = -1
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _leaving or player.health.is_dead() or _editing or _pointer_on_parameters():
		return
	_shot_remaining -= delta
	if _shot_remaining <= 0.0:
		_fire_next()
		_shot_remaining = shot_interval


func _fire_next() -> void:
	for offset in 3:
		var index := (_next_index + offset) % 3
		var enemy := robots[index]
		if not is_instance_valid(enemy) or enemy.health.is_dead():
			continue
		var aim_point := player.hurt_box.global_position
		var heading := enemy.global_position.direction_to(aim_point)
		enemy.facing = heading
		enemy.visuals.play_impact(heading)
		var bullet := SHOT.instantiate() as CombatProjectile
		add_child(bullet)
		bullet.global_position = enemy.global_position + heading * 22.0
		bullet.setup(enemy, CombatFaction.Id.ENEMY, heading, 1, bullet_speed)
		_next_index = (index + 1) % 3
		last_fired_index = index
		training_shot_fired.emit(index)
		queue_redraw()
		return


func _pointer_on_parameters() -> bool:
	return is_instance_valid(_panel) and _panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _process(_delta: float) -> void:
	if _leaving:
		return
	if not player.health.is_dead() and not player.inventory.is_open:
		player.set_input_enabled(not _editing and not _pointer_on_parameters())
	_status.text = "耐久 %d/%d · 完美盾反 %d · 受击 %d · %s" % [player.health.current_health, player.health.max_health, perfects, misses, "已倒下，按 R 重置" if player.health.is_dead() else "WASD 移动 / 右键盾反"]
	var alive := 0
	for enemy in robots:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			alive += 1
	var next_alive := _next_index
	for offset in 3:
		var index := (_next_index + offset) % 3
		if is_instance_valid(robots[index]) and not robots[index].health.is_dead():
			next_alive = index
			break
	_turn.text = "已清空标靶 · R 重新练习" if alive == 0 else "下一位：%02d   间隔 %.1fs" % [next_alive + 1, maxf(_shot_remaining, 0.0)]


func _on_damage_resolved(result: DamageResult) -> void:
	if result.target != player:
		return
	if result.perfect:
		perfects += 1
	elif result.final_damage > 0:
		misses += 1


func _clear_shots() -> void:
	for node in get_children():
		if node is CombatProjectile:
			node.set_physics_process(false)
			node.queue_free()


func _flow() -> SceneContainerManager:
	return get_tree().current_scene.get_node_or_null("SceneFlow") as SceneContainerManager


func restart_training() -> bool:
	if _leaving:
		return false
	player.inventory.set_open(false)
	get_tree().paused = false
	var payload := {"training_settings": {"interval": shot_interval, "health": robot_health, "speed": bullet_speed}}
	var flow := _flow()
	if flow == null:
		return false
	if not flow.request_scene(SCENE_PATH, payload):
		return false
	_leaving = true
	player.set_input_enabled(false)
	return true


func return_to_warehouse() -> bool:
	if _leaving:
		return false
	player.inventory.set_open(false)
	get_tree().paused = false
	var flow := _flow()
	if flow == null or not flow.request_scene("res://scenes/levels/base/warehouse.tscn"):
		return false
	_leaving = true
	player.set_input_enabled(false)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_room") and not event.is_echo():
		get_viewport().set_input_as_handled()
		restart_training()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("101522"))
	for x in range(216, 633, 16):
		draw_line(Vector2(x, 64), Vector2(x, 340), Color("202334"))
	for y in range(68, 340, 16):
		draw_line(Vector2(216, y), Vector2(632, y), Color("202334"))
	draw_rect(Rect2(216, 64, 416, 276), Color("70508b"), false, 2)
	draw_arc(CENTER, RADIUS, 0, TAU, 96, Color("665078"), 1)
	draw_arc(CENTER, 24, 0, TAU, 32, Color("ba7cff"), 2)
	for index in 3:
		var point := CENTER + Vector2.UP.rotated(TAU * index / 3.0) * RADIUS
		draw_arc(point, 22, 0, TAU, 24, Color("cf9bff") if index == _next_index else Color("4c4262"), 2)


func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.show()
