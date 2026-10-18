class_name RooftopBossArena
extends Node2D

signal phase_changed(phase: Phase)
signal boss_defeated
signal room_cleared

enum Phase {
	MINIONS,
	AWAKENING,
	BOSS_ACTIVE,
	CLEARED,
}

const ROOM_SIZE := Vector2(960.0, 540.0)
const ARENA_BOUNDS := Rect2(152.0, 192.0, 656.0, 312.0)
const ORACLE_RADIUS := 28.0

@export var attack_loop_enabled := true

@onready var player: PlayerController = $Player
@onready var boss: RooftopWhaleGoddess = $Boss
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var telegraph: BossAttackTelegraph = $AttackTelegraph
@onready var room_lighting: RooftopBossRoomLighting = $RoomLighting
@onready var exit_elevator: ExitElevator = $ExitElevator
@onready var phase_label: Label = $Interface/PhaseLabel
@onready var health_label: Label = $Interface/HealthLabel

var phase := Phase.MINIONS
var _attack_generation := 0
var _laser_vertical := false
var _test_mode := false
var _test_player_state: Dictionary = {}


func _enter_tree() -> void:
	add_to_group("combat_rooms")
	add_to_group("environment_areas")


func _ready() -> void:
	_configure_arena_camera()
	room_lighting.reset_to_phase_one()
	spawner.all_required_defeated.connect(_on_minions_cleared)
	boss.health.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	exit_elevator.entered.connect(_on_exit_entered)
	exit_elevator.set_enabled(false)
	_set_phase(Phase.MINIONS)
	_start_boss_music(1)
	_on_boss_health_changed(boss.health.current_health, boss.health.max_health, 0)
	_publish_notice(&"boss_phase_one", "第一阶段 · 清除神像守卫", Color(0.45, 0.9, 1.0), 2.4)


func _configure_arena_camera() -> void:
	# The chapel is larger than the 640x360 logical viewport. The camera follows
	# the player while remaining inside the authored 960x540 room artwork.
	player.camera.position_smoothing_enabled = true
	player.camera.position_smoothing_speed = 7.0
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(ROOM_SIZE.x)
	player.camera.limit_bottom = int(ROOM_SIZE.y)


func contains_world_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, ROOM_SIZE).has_point(to_local(point))


func receive_scene_payload(payload: Dictionary) -> void:
	_test_mode = bool(payload.get("boss_test", false))
	if payload.has("player_state") and payload["player_state"] is Dictionary:
		_test_player_state = (payload["player_state"] as Dictionary).duplicate(true)
		player.import_run_state(_test_player_state)
	if _test_mode:
		_set_phase(phase)


func _on_minions_cleared() -> void:
	if phase != Phase.MINIONS:
		return
	_set_phase(Phase.AWAKENING)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(1)
	_publish_notice(&"boss_awakening", "静默协议解除 · 神像苏醒", Color(1.0, 0.72, 0.25), 2.0)
	player.set_physics_process(false)
	room_lighting.begin_awakening()
	_push_camera_to_altar()
	await boss.begin_awakening()
	if phase != Phase.AWAKENING:
		player.set_physics_process(true)
		return
	_restore_player_camera()
	player.set_physics_process(true)
	_set_phase(Phase.BOSS_ACTIVE)
	_start_boss_music(2)
	_publish_notice(&"boss_phase_two", "第二阶段 · 回声定位已启动", Color(1.0, 0.42, 0.2), 2.4)
	if attack_loop_enabled:
		_attack_generation += 1
		_run_attack_loop(_attack_generation)


func _run_attack_loop(generation: int) -> void:
	while phase == Phase.BOSS_ACTIVE and generation == _attack_generation:
		telegraph.clear()
		boss.play_echo_probe()
		room_lighting.pulse_echo()
		await get_tree().create_timer(0.35).timeout
		if not _attack_is_current(generation):
			return
		var snapshot := Vector2(
			clampf(player.global_position.x, ARENA_BOUNDS.position.x, ARENA_BOUNDS.end.x),
			clampf(player.global_position.y, ARENA_BOUNDS.position.y, ARENA_BOUNDS.end.y)
		)
		telegraph.show_oracle(snapshot, 0.72)
		await get_tree().create_timer(0.72).timeout
		if not _attack_is_current(generation):
			return
		telegraph.show_oracle(snapshot, 0.18, true)
		_damage_player_in_circle(snapshot, ORACLE_RADIUS)
		await get_tree().create_timer(0.36).timeout
		if not _attack_is_current(generation):
			return
		var laser := _make_laser_rect(snapshot)
		telegraph.show_laser(laser, 0.78)
		await get_tree().create_timer(0.78).timeout
		if not _attack_is_current(generation):
			return
		telegraph.show_laser(laser, 0.22, true)
		_damage_player_in_rect(laser)
		await get_tree().create_timer(0.72).timeout
	telegraph.clear()


func _make_laser_rect(snapshot: Vector2) -> Rect2:
	_laser_vertical = not _laser_vertical
	if _laser_vertical:
		return Rect2(clampf(snapshot.x - 7.0, ARENA_BOUNDS.position.x, ARENA_BOUNDS.end.x - 14.0), ARENA_BOUNDS.position.y, 14.0, ARENA_BOUNDS.size.y)
	return Rect2(ARENA_BOUNDS.position.x, clampf(snapshot.y - 7.0, ARENA_BOUNDS.position.y, ARENA_BOUNDS.end.y - 14.0), ARENA_BOUNDS.size.x, 14.0)


func _push_camera_to_altar() -> void:
	var altar_center := Vector2(480.0, 180.0)
	var desired_offset := player.to_local(altar_center)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player.camera, "position", desired_offset, 0.72)


func _restore_player_camera() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player.camera, "position", Vector2.ZERO, 0.45)


func _damage_player_in_circle(center: Vector2, radius: float) -> void:
	if player.global_position.distance_to(center) <= radius:
		_damage_player(center)


func _damage_player_in_rect(rect: Rect2) -> void:
	if rect.has_point(player.global_position):
		_damage_player(rect.get_center())


func _damage_player(source_position: Vector2) -> void:
	if player.health.is_dead():
		return
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source = boss
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.damage_type = &"energy"
	packet.source_position = source_position
	packet.travel_direction = source_position.direction_to(player.global_position)
	packet.blockable = false
	packet.is_area_damage = true
	player.receive_damage(packet)


func _on_boss_health_changed(current: int, maximum: int, _delta: int) -> void:
	if not is_instance_valid(health_label):
		return
	if phase in [Phase.MINIONS, Phase.AWAKENING]:
		health_label.text = "BOSS  ·  SIGNAL OFFLINE"
		return
	if phase == Phase.CLEARED:
		health_label.text = "BOSS  ·  CORE SILENT"
		return
	var segments := maxi(current - 1, 0)
	var core_text := "核心暴露" if current == 1 else "光环 %d/5" % segments
	health_label.text = "BOSS  %d/%d  ·  %s" % [current, maximum, core_text]


func _on_boss_defeated() -> void:
	if phase == Phase.CLEARED:
		return
	_attack_generation += 1
	telegraph.clear()
	_set_phase(Phase.CLEARED)
	exit_elevator.set_enabled(true)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(0)
	var music := _get_music_controller()
	if music != null:
		music.end_boss_music()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_room_cleared(self)
		events.publish_floor_cleared()
	_publish_notice(&"boss_defeated", "神谕中止 · 楼顶线路已开放", Color(0.4, 1.0, 0.62), 3.0)
	room_cleared.emit()
	boss_defeated.emit()


func _set_phase(next_phase: Phase) -> void:
	phase = next_phase
	match phase:
		Phase.MINIONS:
			phase_label.text = "PHASE I  ·  DORMANT STATUE"
			health_label.text = "BOSS  ·  SIGNAL OFFLINE"
		Phase.AWAKENING:
			phase_label.text = "TRANSITION  ·  AWAKENING"
			health_label.text = "BOSS  ·  SIGNAL OFFLINE"
		Phase.BOSS_ACTIVE:
			phase_label.text = "PHASE II  ·  ORACLE ONLINE"
			_on_boss_health_changed(boss.health.current_health, boss.health.max_health, 0)
		Phase.CLEARED:
			phase_label.text = "BOSS DEFEATED"
			health_label.text = "BOSS  ·  CORE SILENT"
	if _test_mode:
		phase_label.text += "  ·  TEST"
	phase_changed.emit(phase)


func _attack_is_current(generation: int) -> bool:
	return phase == Phase.BOSS_ACTIVE and generation == _attack_generation and is_instance_valid(player)


func _start_boss_music(music_phase: int) -> void:
	var music := _get_music_controller()
	if music != null:
		music.start_boss_phase(music_phase)


func _get_music_controller() -> CombatMusicController:
	return get_node_or_null("/root/Main/CombatMusic") as CombatMusicController


func _publish_notice(id: StringName, text: String, color: Color, seconds: float) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(id, text, color, CombatNotice.Priority.HIGH, 0.0, seconds)


func _on_exit_entered() -> void:
	if phase == Phase.CLEARED:
		if _test_mode:
			_return_to_warehouse()
		else:
			_publish_notice(&"boss_exit", "出口已解锁", Color(0.4, 1.0, 0.62), 1.4)


func _return_to_warehouse() -> bool:
	var flow := get_tree().current_scene.get_node_or_null("SceneFlow") as SceneContainerManager
	if flow == null:
		return false
	return flow.request_scene("res://scenes/levels/base/warehouse.tscn")


func _restart_boss_test() -> bool:
	var flow := get_tree().current_scene.get_node_or_null("SceneFlow") as SceneContainerManager
	if flow == null:
		return false
	return flow.request_scene(scene_file_path, {
		"player_state": _test_player_state,
		"boss_test": true,
	})


func _unhandled_input(event: InputEvent) -> void:
	if _test_mode and event.is_action_pressed("restart_room"):
		get_viewport().set_input_as_handled()
		_restart_boss_test()
		return
	if get_tree().current_scene.get_node_or_null("SceneFlow") != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
