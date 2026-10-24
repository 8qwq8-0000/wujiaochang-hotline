extends Node2D

signal training_shot_fired(index: int)
const SCENE_PATH := "res://scenes/debug/parry_training.tscn"
const CENTER := Vector2(410, 216)
const MELEE_CENTER := Vector2(842, 216)
const ZONE_BOUNDARY := 640.0
const MELEE_TRAINING_RANGE := 48.0
const RADIUS := 112.0
const FAN_HALF_ANGLE := PI / 3.0
const BULLET_SPEED := 260.0
const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const SHOT := preload("res://scenes/combat/projectile.tscn")
var shot_interval := 0.9
var robot_health := 3
var robots: Array[EnemyController] = []
var melee_robot: EnemyController
var _melee_zone := false
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
	var damage_feedback := PlayerDamageFeedbackLayer.new()
	damage_feedback.name = "PlayerDamageFeedback"
	ui.add_child(damage_feedback)
	_build_ui()
	_make_label(self, "01 / 远程弹反", Vector2(230, 92), 12)
	_make_label(self, "02 / 近战弹反", Vector2(662, 92), 12)
	_make_label(self, "向右进入近战区 →", Vector2(480, 292), 11)
	_make_label(self, "← 返回远程区", Vector2(662, 292), 11)
	_reset_robots()
	get_node("/root/CombatEvents").damage_resolved.connect(_on_damage_resolved)
	queue_redraw()


func receive_scene_payload(payload: Dictionary) -> void:
	var settings: Dictionary = payload.get("training_settings", {})
	for key in ["interval", "health"]:
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
	_make_label(ui, "鼠标朝向敌人 · 右键盾反 · 向右穿过通道练习近战", Vector2(14, 40), 11)
	_build_player_health_display()
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
	_add_slider(column, "interval", "攻击间隔", 0.4, 2.0, 0.1, shot_interval, "秒")
	_add_slider(column, "health", "机器人血量", 1, 10, 1, robot_health, "点")
	var heal_button := Button.new()
	heal_button.name = "HealButton"
	heal_button.text = "恢复血量 [H]"
	heal_button.pressed.connect(restore_player_health)
	column.add_child(heal_button)
	_make_label(column, "左区：远程  /  右区：近战\n血量调整重置全部机器人\n本场训练不写入正式存档", Vector2.ZERO, 10)
	_button("重置训练 [R]", Vector2(500, 12), restart_training)
	_button("返回仓库", Vector2(500, 40), return_to_warehouse)
	_status = _make_label(ui, "", Vector2(14, 330), 11)
	_turn = _make_label(ui, "", Vector2(232, 76), 11)


func _health_bar_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, color])
	var texture := GradientTexture2D.new()
	texture.width = 1
	texture.height = 1
	texture.gradient = gradient
	return texture


func _build_player_health_display() -> void:
	var bar := TextureProgressBar.new()
	bar.nine_patch_stretch = true
	bar.name = "PlayerHealthBar"
	bar.position = Vector2(14, 59)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.texture_under = _health_bar_texture(Color("38222a"))
	bar.texture_progress = _health_bar_texture(Color("e84b50"))
	bar.size = Vector2(150, 8)
	ui.add_child(bar)
	var caption := _make_label(ui, "", Vector2(172, 53), 12)
	caption.name = "PlayerHealthLabel"
	var update := func(current: int, maximum: int, _delta: int) -> void:
		bar.max_value = maximum
		bar.value = current
		caption.text = "生命 %d/%d" % [current, maximum]
	player.health.health_changed.connect(update)
	update.call(player.health.current_health, player.health.max_health, 0)


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
			"interval":
				shot_interval = value
				if is_instance_valid(melee_robot):
					melee_robot.profile.attack_cooldown = value
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


func _robot_position(index: int) -> Vector2:
	return CENTER + Vector2.UP.rotated((index - 1) * FAN_HALF_ANGLE) * RADIUS


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
		enemy.position = _robot_position(index)
		enemy.initial_facing = enemy.position.direction_to(CENTER)
		$Robots.add_child(enemy)
		enemy.set_physics_process(false)
		robots.append(enemy)
		_add_robot_health_display(enemy, "%02d" % (index + 1))
	if is_instance_valid(melee_robot):
		melee_robot.set_physics_process(false)
		melee_robot.queue_free()
	melee_robot = ENEMY.instantiate() as EnemyController
	melee_robot.profile = preload("res://resources/enemies/melee_pressure.tres").duplicate()
	melee_robot.profile.max_health = robot_health
	melee_robot.profile.attack_cooldown = shot_interval
	melee_robot.profile.attack_range = MELEE_TRAINING_RANGE
	melee_robot.profile.patrol_enabled = false
	melee_robot.profile.tactical_enabled = false
	melee_robot.profile.full_room_awareness = true
	melee_robot.profile.attack_knockback = 0.0
	melee_robot.stationary_test_target = true
	melee_robot.mandatory = false
	melee_robot.position = MELEE_CENTER + Vector2(64, 0)
	melee_robot.initial_facing = Vector2.LEFT
	$Robots.add_child(melee_robot)
	_add_robot_health_display(melee_robot, "近战")
	# Training owns timing so the fixed target never chases or moves from knockback.
	melee_robot.set_physics_process(false)
	_next_index = 0
	_shot_remaining = maxf(shot_interval, 1.0)
	last_fired_index = -1
	queue_redraw()


func _add_robot_health_display(enemy: EnemyController, title: String) -> void:
	var bar := TextureProgressBar.new()
	bar.nine_patch_stretch = true
	bar.name = "TrainingHealthBar"
	bar.position = Vector2(-24, -46)
	bar.texture_under = _health_bar_texture(Color("38222a"))
	bar.texture_progress = _health_bar_texture(Color("e84b50"))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = 10
	bar.size = Vector2(48, 5)
	enemy.add_child(bar)
	var caption := _make_label(enemy, "", Vector2(-32, -40), 10)
	caption.name = "TrainingHealthLabel"
	caption.z_index = 10
	var update := func(current: int, maximum: int, _delta: int) -> void:
		bar.max_value = maximum
		bar.value = current
		caption.text = "%s %d/%d" % [title, current, maximum]
	enemy.health.health_changed.connect(update)
	update.call(enemy.health.current_health, enemy.health.max_health, 0)


func _tick_melee_target(delta: float) -> void:
	var enemy := melee_robot
	enemy.velocity = Vector2.ZERO
	enemy._target = player
	enemy._attack_cooldown_remaining = maxf(0.0, enemy._attack_cooldown_remaining - delta)
	if enemy._stagger_remaining > 0.0:
		enemy._stagger_remaining = maxf(0.0, enemy._stagger_remaining - delta)
		if enemy._stagger_remaining <= 0.0:
			enemy.state = EnemyController.State.IDLE
		return
	var heading := enemy.global_position.direction_to(player.global_position)
	enemy.facing = heading
	if enemy.global_position.distance_to(player.global_position) > enemy.profile.attack_range:
		enemy.state = EnemyController.State.IDLE
		enemy._windup_remaining = 0.0
		enemy.visuals.cancel_attack()
		return
	if enemy.state == EnemyController.State.WINDUP:
		enemy._windup_remaining -= delta
		if enemy._windup_remaining <= 0.0:
			enemy.state = EnemyController.State.ATTACK
			enemy.perform_attack()
	elif enemy._attack_cooldown_remaining <= 0.0:
		enemy.state = EnemyController.State.WINDUP
		enemy._windup_remaining = enemy.profile.attack_windup
		enemy._attack_direction = heading
	enemy.queue_redraw()


func _physics_process(delta: float) -> void:
	if _leaving or player.health.is_dead() or _editing or _pointer_on_parameters():
		return
	_update_training_zone()
	if _melee_zone:
		if is_instance_valid(melee_robot) and not melee_robot.health.is_dead():
			_tick_melee_target(delta)
		return
	_shot_remaining -= delta
	if _shot_remaining <= 0.0:
		_fire_next()
		_shot_remaining = shot_interval


func _update_training_zone() -> void:
	var next_melee := player.global_position.x >= ZONE_BOUNDARY
	if next_melee != _melee_zone:
		_melee_zone = next_melee
		_clear_shots()
		_shot_remaining = maxf(shot_interval, 1.0)
		if is_instance_valid(melee_robot) and not melee_robot.health.is_dead():
			melee_robot.position = MELEE_CENTER + Vector2(64, 0)
			melee_robot.velocity = Vector2.ZERO
			melee_robot.state = EnemyController.State.IDLE
			melee_robot._windup_remaining = 0.0
			melee_robot._attack_cooldown_remaining = shot_interval
			melee_robot.visuals.cancel_attack()
	$Camera2D.position.x = clampf(player.position.x - 90.0, 320.0, 752.0)


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
		bullet.setup(enemy, CombatFaction.Id.ENEMY, heading, 1, BULLET_SPEED)
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
	_status.text = "玩家血量 %d/%d · 完美盾反 %d · 受击 %d · %s" % [player.health.current_health, player.health.max_health, perfects, misses, "已倒下，按 H 或 R 重置" if player.health.is_dead() else "WASD 移动 / 右键盾反"]
	if _melee_zone:
		if not is_instance_valid(melee_robot) or melee_robot.health.is_dead():
			_turn.text = "近战区 · 标靶已击败，按 R 重置"
		elif melee_robot.state == EnemyController.State.WINDUP:
			_turn.text = "近战区 · 即将挥击！朝向敌人按右键"
		elif melee_robot.state == EnemyController.State.STAGGERED:
			_turn.text = "近战区 · 弹反成功，敌人硬直中"
		else:
			_turn.text = "近战区 · 走入敌人脚下红圈触发挥击"
		return
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
	_turn.text = "已清空标靶 · R 重新练习" if alive == 0 else "远程区 · 下一位：%02d   间隔 %.1fs" % [next_alive + 1, maxf(_shot_remaining, 0.0)]


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


func restore_player_health() -> bool:
	if _leaving:
		return false
	if player.health.is_dead():
		return restart_training()
	player.health.repair(player.health.max_health)
	return true


func restart_training() -> bool:
	if _leaving:
		return false
	player.inventory.set_open(false)
	get_tree().paused = false
	var payload := {"training_settings": {"interval": shot_interval, "health": robot_health}}
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
	if event is InputEventKey and event.pressed and not event.is_echo() and (event.physical_keycode == KEY_H or event.keycode == KEY_H):
		get_viewport().set_input_as_handled()
		restore_player_health()
		return
	if event.is_action_pressed("restart_room") and not event.is_echo():
		get_viewport().set_input_as_handled()
		restart_training()


func _draw() -> void:
	draw_rect(Rect2(-512, 0, 2048, 360), Color("101522"))
	for x in range(216, 633, 16):
		draw_line(Vector2(x, 64), Vector2(x, 340), Color("202334"))
	for y in range(68, 340, 16):
		draw_line(Vector2(216, y), Vector2(632, y), Color("202334"))
	draw_rect(Rect2(216, 64, 416, 276), Color("70508b"), false, 2)
	draw_arc(CENTER, RADIUS, -PI / 2.0 - FAN_HALF_ANGLE, -PI / 2.0 + FAN_HALF_ANGLE, 48, Color("665078"), 1)
	for index in [0, 2]:
		draw_line(CENTER, _robot_position(index), Color("4c4262"), 1)
	draw_arc(CENTER, 24, 0, TAU, 32, Color("ba7cff"), 2)
	for x in range(648, 1065, 16):
		draw_line(Vector2(x, 64), Vector2(x, 340), Color("202334"))
	for y in range(68, 340, 16):
		draw_line(Vector2(648, y), Vector2(1064, y), Color("202334"))
	draw_rect(Rect2(648, 64, 416, 276), Color("b5794a"), false, 2)
	draw_rect(Rect2(628, 208, 24, 64), Color("384b52"))
	draw_line(Vector2(620, 240), Vector2(660, 240), Color("f1c17b"), 3)
	draw_arc(MELEE_CENTER + Vector2(64, 0), MELEE_TRAINING_RANGE, 0, TAU, 48, Color("e84b50"), 1)
	for index in 3:
		var point := _robot_position(index)
		draw_arc(point, 22, 0, TAU, 24, Color("cf9bff") if index == _next_index else Color("4c4262"), 2)


func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.show()
