class_name ChannelTakeover
extends Node

const NAMES := ["验证签名", "恢复公共路由", "撤销中枢控制权"]
const POINTS := [Vector2(460, 390), Vector2(700, 340), Vector2(300, 340)]
const UPLOAD_SECONDS := 8.0
var terminals: Array[ChannelTerminal] = []
var guards: Array[EnemyController] = []
var dialogue: ChannelDialogue
var stage := 0
var progress := 0.0
var uploading := false
var warning := false
var completed := false
var _laser_clock := 0.0
var _laser_pending := false
var _hud: Label
@onready var arena: RooftopBossArena = get_parent()
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	dialogue = ChannelDialogue.new()
	add_child(dialogue)
	for index in POINTS.size():
		var terminal := ChannelTerminal.new()
		terminal.position = POINTS[index]
		terminal.title = NAMES[index]
		terminal.action = use_terminal.bind(index)
		terminal.enabled = index == 0
		terminal.highlighted = index == 0
		arena.add_child(terminal)
		terminals.append(terminal)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(14, 85)
	_hud.theme = CyberUITheme.create_theme()
	_hud.add_theme_color_override("font_outline_color", Color("061018"))
	_hud.add_theme_constant_override("outline_size", 3)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	arena.player.health.repair(1)
	get_node("/root/CombatEvents").publish_message("护罩已解除，频道接管终端已开放。修复 1 格耐久")


func use_terminal(index: int) -> void:
	if stage != index or uploading or warning or completed or arena.player.health.is_dead():
		return
	if index == 0:
		dialogue.open("楼顶 / 频道接管", "残损频道核心已接入。\n\n接下来需要依次操作三个终端，各上传 8 秒，并清除每批守卫。敌人接近当前终端会暂停上传。\n\n接管期间无法撤离，场地仍有低频单轴激光。可先整理装备再开始。", [["开始接管", begin_stage], ["先整理装备", Callable()]], Callable())
	else:
		begin_stage()


func begin_stage() -> void:
	if uploading or warning or completed:
		return
	warning = true
	terminals[stage].enabled = false
	terminals[stage].title = "维修入口增援 / 2 秒"
	# Visible markers precede spawning and choose the side farthest from player.
	var entrances := [Vector2(200, 220), Vector2(760, 460)]
	entrances.sort_custom(func(a: Vector2, b: Vector2) -> bool: return arena.player.position.distance_squared_to(a) > arena.player.position.distance_squared_to(b))
	var origin: Vector2 = entrances[0]
	var beacon := Node2D.new()
	beacon.position = origin
	beacon.z_index = 20
	arena.add_child(beacon)
	beacon.draw.connect(func() -> void: beacon.draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color("f3c579"), 3))
	beacon.queue_redraw()
	await get_tree().create_timer(2.0, false).timeout
	beacon.queue_free()
	if arena.player.health.is_dead():
		warning = false
		return
	var groups := [["melee_pressure", "melee_pressure"], ["ranged_sightline", "melee_pressure"], ["heavy_anchor", "signal_amplifier"]]
	for index in 2:
		var enemy: EnemyController = load(EnemySpawner.ENEMY_SCENE_PATH).instantiate()
		enemy.profile = load("res://resources/enemies/" + groups[stage][index] + ".tres").duplicate()
		enemy.profile.max_health = 4
		enemy.profile.self_destruct_enabled = false
		enemy.profile.full_room_awareness = true
		enemy.position = origin + Vector2(index * (-44 if origin.x > 480 else 44), 0)
		enemy.mandatory = false
		arena.add_child(enemy)
		guards.append(enemy)
	warning = false
	uploading = true
	_laser_clock = 0


func living_guards() -> Array[EnemyController]:
	var result: Array[EnemyController] = []
	for guard in guards:
		if is_instance_valid(guard) and not guard.health.is_dead():
			result.append(guard)
	return result


func _process(delta: float) -> void:
	if completed or arena.player.health.is_dead():
		return
	var living := living_guards()
	var blocked := living.any(func(guard: EnemyController) -> bool: return guard.position.distance_to(POINTS[stage]) < 72)
	_hud.text = "频道接管 %d/3 · %s\n%s" % [stage + 1, NAMES[stage], "清除终端附近的敌人，恢复上传" if blocked else ("上传 %.0f%%" % (progress / UPLOAD_SECONDS * 100) if uploading else "前往亮起的终端，按 E 操作")]
	if not uploading:
		return
	if not blocked:
		progress = minf(progress + delta, UPLOAD_SECONDS)
	terminals[stage].title = "%s / %.0f%%" % [NAMES[stage], progress / UPLOAD_SECONDS * 100]
	_laser_clock += delta
	if _laser_clock >= 5.0 and not _laser_pending:
		_laser_clock = 0
		_fire_laser()
	if progress >= UPLOAD_SECONDS and living.is_empty() and not _laser_pending:
		_finish_stage()


func _fire_laser() -> void:
	_laser_pending = true
	var snapshot := arena.player.position
	var beams := arena._make_cross_lasers(snapshot)
	var single: Array[Rect2] = [beams[stage % 2]]
	arena.telegraph.show_cross(single, 0.95)
	await get_tree().create_timer(0.95, false).timeout
	if not is_inside_tree() or arena.player.health.is_dead() or completed:
		_laser_pending = false
		return
	arena.telegraph.show_cross(single, 0.2, true)
	arena._damage_player_in_cross(single)
	await get_tree().create_timer(0.2, false).timeout
	arena.telegraph.clear()
	_laser_pending = false


func _finish_stage() -> void:
	uploading = false
	terminals[stage].title = NAMES[stage] + " / 完成"
	terminals[stage].accent = Color("83e6ad")
	terminals[stage].highlighted = false
	stage += 1
	progress = 0
	if stage == 3:
		completed = true
		arena.telegraph.clear()
		arena._clear_hostile_projectiles()
		_hud.hide()
		_show_ending(0)
	else:
		terminals[stage].enabled = true
		terminals[stage].highlighted = true
		get_node("/root/CombatEvents").publish_message("节点完成，前往下一个亮起的终端")


func _show_ending(page: int) -> void:
	var lines := ["神像的光环逐段熄灭，失控广播终于停止。\n\n终端：公共路由已恢复。中枢控制权已撤销。",
		"“这里……能发出去了吗？”\n\n“能听见。报你的位置。”\n\n断续的呼叫重新进入公共频道。",
		"接线员：公共频道恢复。下面开始接线。\n\n频道已经归还。人员救援仍将继续。"]
	if page == 0:
		arena.boss.glow_sprite.modulate = Color("75e8df")
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(arena.boss.glow_sprite, "modulate:a", 0.0, 1.0)
	dialogue.open("第二结局 / 频道归还", lines[page], [["完成接管" if page == 2 else "继续", complete_ending if page == 2 else _show_ending.bind(page + 1)]], complete_ending)


func complete_ending() -> void:
	if run.channel_takeover_complete:
		return
	run.channel_takeover_complete = true
	arena.boss.state = RooftopWhaleGoddess.State.DEFEATED
	arena.boss.halo_segments_remaining = 0
	arena.boss.glow_sprite.hide()
	arena.boss.queue_redraw()
	arena.boss.defeated.emit()
