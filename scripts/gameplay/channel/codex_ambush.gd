class_name CodexAmbush
extends Area2D

const TOTAL_WAVES := 3
const WAVE_HEALTH_STEP := 1
const WAVE_SPEED_STEP := 0.08
const MAX_WAVE_SPEED_BONUS := 0.4
const STATION := Vector2(112, 420)
var health: HealthComponent
var hurt_box: HurtBox2DComponent
var _flash := 0.0
var companion: CodexCompanion
var started := false
var resolved := false
var wave_number := 1
var station_ready := false
var offered := false
var dialogue: ChannelDialogue
var status: Label
var prompt: Label
@onready var floor_scene: Node2D = get_parent()
@onready var player: PlayerController = floor_scene.get_node("Player")
@onready var assembler: FloorAssembler = floor_scene.get_node("FloorAssembler")
@onready var room: CombatRoom = assembler.generated_rooms[0]
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	position = STATION
	add_to_group("companions")
	add_to_group("status_actors")
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 3
	add_child(health)
	health.set_current_health(int(run.codex_companion.get("altar_health", 3)))
	health.health_changed.connect(_on_altar_health_changed)
	health.died.connect(_on_altar_destroyed)
	hurt_box = HurtBox2DComponent.new()
	hurt_box.name = "AltarHurtBox"
	hurt_box.health_path = NodePath("../HealthComponent")
	hurt_box.faction = CombatFaction.Id.PLAYER
	hurt_box.collision_layer = 8
	hurt_box.collision_mask = 0
	hurt_box.monitoring = false
	hurt_box.damage_invulnerability_seconds = 1.2
	hurt_box.position = Vector2(0, 3)
	var hit_shape := CollisionShape2D.new()
	var hit_rectangle := RectangleShape2D.new()
	hit_rectangle.size = Vector2(82, 58)
	hit_shape.shape = hit_rectangle
	hurt_box.add_child(hit_shape)
	add_child(hurt_box)
	companion.protected_by_altar = true
	companion.queue_redraw()
	collision_layer = 32
	collision_mask = 0
	monitoring = false
	var interact_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 64
	interact_shape.shape = circle
	add_child(interact_shape)
	# Reuse the pictured shrine machine, core and projection assets.
	var art := Sprite2D.new()
	art.name = "RepairDeviceArt"
	art.texture = preload("res://assets/art/environment/hidden_shrine_v1/altar.tres")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.scale = Vector2(90, 75) / art.texture.get_size()
	add_child(art)
	var core := Sprite2D.new()
	core.name = "ChannelCoreArt"
	core.texture = preload("res://assets/art/environment/hidden_shrine_v1/core.tres")
	core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	core.scale = Vector2(28, 34) / core.texture.get_size()
	core.position = Vector2(0, -43)
	add_child(core)
	for floor_pass in [true, false]:
		var effect := preload("res://scripts/presentation/shrine_signal_effect.gd").new()
		effect.floor_pass = floor_pass
		effect.external_strength = 1.0
		effect.position = Vector2(0, 20 if floor_pass else 15)
		effect.z_index = -1 if floor_pass else 1
		add_child(effect)
	var body := StaticBody2D.new()
	body.position = Vector2(0, 18)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(72, 22)
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)
	prompt = Label.new()
	prompt.theme = CyberUITheme.create_theme()
	prompt.position = Vector2(-100, -94)
	prompt.size = Vector2(200, 38)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.add_theme_color_override("font_outline_color", Color("08101c"))
	add_child(prompt)
	var hud := CanvasLayer.new()
	hud.layer = 12
	add_child(hud)
	status = Label.new()
	status.theme = CyberUITheme.create_theme()
	status.position = Vector2(220, 80)
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_constant_override("outline_size", 3)
	status.add_theme_color_override("font_outline_color", Color("08101c"))
	hud.add_child(status)
	dialogue = ChannelDialogue.new()
	add_child(dialogue)
	companion.walk_target = global_position + Vector2(0, 54)
	room.spawner.enemy_spawned.connect(_on_enemy_spawned)
	room.spawner.required_remaining_changed.connect(_on_remaining_changed)
	_refresh_status()


func can_interact(actor: Node2D) -> bool:
	return not started and not resolved and station_ready and actor == player and player.is_input_enabled() and not player.health.is_dead() and not get_tree().paused and actor.global_position.distance_to(global_position) < 90


func interact(actor: Node2D) -> void:
	if can_interact(actor):
		offer_start()


func offer_start() -> void:
	if started or resolved or not run.codex_is_alive():
		return
	dialogue.open("Codex / 核心修复", "启动这台设备会暴露我们的位置。我留在这里修复核心，你负责抵御三波突袭。祭坛只有三格耐久，保护好它，清完第三波就能离开。\n\n准备好了吗？", [["再准备一下", Callable()], ["接受挑战", start]])


func start() -> void:
	if started or resolved or not run.codex_is_alive() or player.health.is_dead():
		return
	started = true
	companion.walk_target = Vector2.INF
	_notice("警报：第一波突袭抵达！共三波，守住祭坛！")
	_prepare_nearby_spawns()
	room.spawner.spawn_all()
	_save_checkpoint()
	_refresh_status()


func _physics_process(delta: float) -> void:
	_flash = maxf(0, _flash - delta)
	get_node("RepairDeviceArt").modulate = Color("ff9e9e") if _flash > 0 else Color.WHITE
	if player.health.is_dead() or not player.is_input_enabled() or resolved:
		return
	if not started:
		if not station_ready and companion.global_position.distance_to(companion.walk_target) <= 9:
			station_ready = true
			companion.walk_target = Vector2.INF
		if station_ready and not offered and player.global_position.distance_to(global_position) < 90:
			offered = true
			offer_start()
		_refresh_status()
		return
	_refresh_status()


func _on_enemy_spawned(enemy: EnemyController) -> void:
	enemy.profile = enemy.profile.duplicate()
	var escalation := maxi(wave_number - 1, 0)
	enemy.profile.max_health += escalation * WAVE_HEALTH_STEP
	enemy.health.configure_max_health(enemy.profile.max_health, true)
	if enemy.profile.role == EnemyProfile.Role.MELEE_PRESSURE:
		enemy.profile.move_speed *= 1.0 + minf(escalation * WAVE_SPEED_STEP, MAX_WAVE_SPEED_BONUS)
	enemy.profile.full_room_awareness = true
	enemy.pursue_player = true
	get_node("/root/CombatEvents").request_effect(enemy.global_position, Color("ed9167"), 28, 0.8)


func _on_remaining_changed(remaining: int) -> void:
	if not started or resolved or remaining != 0:
		return
	if wave_number < TOTAL_WAVES:
		wave_number += 1
		_notice("第 %d 波突袭抵达！敌人强度提升。" % wave_number)
		# Order: original first group, original third group, original second group.
		room.spawner._spawn_cursor = 0 if wave_number == 2 else 3
		_prepare_nearby_spawns()
		room.spawner.spawn_pending_wave(3)
	else:
		_complete()
	_refresh_status()


func _complete() -> void:
	if resolved:
		return
	resolved = true
	run.codex_companion.ambush_complete = true
	companion.escort_complete = true
	room.spawner.release_completion()
	_notice("核心修复完成。突袭已结束，前往楼顶。")
	_save_checkpoint()
	_refresh_status()


func _on_altar_destroyed(_packet: DamagePacket) -> void:
	if resolved:
		return
	resolved = true
	run.codex_companion.ambush_failed = true
	run.codex_companion.ambush_complete = false
	dialogue.close()
	# Only the units already present must be cleared; pending waves are cancelled.
	room.spawner._spawned = true
	room.spawner.release_completion()
	_notice("祭坛已被摧毁，后续增援停止。清理现场后，继续摧毁中枢。")
	_save_checkpoint()
	_refresh_status()


func _refresh_status() -> void:
	prompt.text = "核心修复设备"
	if resolved:
		status.text = "核心已修复 / 前往楼顶" if not health.is_dead() else "祭坛损毁 / 清理现场后前往楼顶"
	elif not station_ready:
		status.text = "等待 Codex 抵达修复设备"
	elif not started:
		status.text = "准备突袭 / 靠近祭坛交谈"
		if player.global_position.distance_to(global_position) < 90:
			prompt.text += "\n[E] 与 Codex 交谈"
	else:
		status.text = "突袭 %d/%d / 敌人 %d" % [wave_number, TOTAL_WAVES, room.spawner.required_remaining]


func _notice(message: String) -> void:
	get_node("/root/CombatEvents").publish_message(message, Color("efbd7a"))


func _save_checkpoint() -> void:
	var mission := floor_scene.get_node_or_null("ChannelMission") as ChannelMission
	if mission != null and not mission.save_checkpoint():
		_notice("行动进度保存失败，请检查存档空间")


func should_ignore_damage(packet: DamagePacket) -> bool:
	return not started or resolved or packet.source_faction == CombatFaction.Id.PLAYER


func _on_altar_health_changed(current: int, _maximum: int, delta: int) -> void:
	run.codex_companion.altar_health = current
	if delta < 0:
		_flash = 0.2
		if not run.save_codex_progress():
			_notice("祭坛耐久保存失败，请检查存档空间")
	queue_redraw()


func _draw() -> void:
	if health == null:
		return
	for index in 3:
		draw_rect(Rect2(-18 + index * 13, -62, 10, 5), Color("75e8df") if index < health.current_health else Color("39384d"))


func _prepare_nearby_spawns() -> void:
	room.spawner._prepare_plan()
	var points: Array[Vector2] = []
	var nav_map := companion.navigation.get_navigation_map()
	for y in range(208, 505, 24):
		for x in range(64, 409, 24):
			var point := Vector2(x, y)
			var distance := point.distance_to(global_position)
			if distance < 110 or distance > 260 or point.distance_to(player.global_position) < 96:
				continue
			if NavigationServer2D.map_get_closest_point(nav_map, point).distance_to(point) > 5:
				continue
			var query := PhysicsShapeQueryParameters2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 12
			query.shape = circle
			query.transform = Transform2D(0, point)
			query.collision_mask = 129
			if get_world_2d().direct_space_state.intersect_shape(query).is_empty():
				points.append(point)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return absf(a.distance_to(global_position) - 170) < absf(b.distance_to(global_position) - 170))
	var used: Array[Vector2] = []
	for index in range(room.spawner._spawn_cursor, room.spawner._spawn_plan.size()):
		for point in points:
			if used.any(func(other: Vector2) -> bool: return other.distance_to(point) < 48):
				continue
			room.spawner._spawn_plan[index].global_position = point
			used.append(point)
			break
