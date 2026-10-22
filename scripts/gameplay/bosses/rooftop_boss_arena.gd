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
const OPENING_GUARD_COUNT := 3
const PHASE_TWO_CAMERA_ZOOM := 0.8

@export var attack_loop_enabled := true

@onready var player: PlayerController = $Player
@onready var boss: RooftopWhaleGoddess = $Boss
@onready var support_spawner: EnemySpawner = $SupportSpawner
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var telegraph: BossAttackTelegraph = $AttackTelegraph
@onready var room_lighting: RooftopBossRoomLighting = $RoomLighting
@onready var exit_elevator: ExitElevator = $ExitElevator

var phase := Phase.MINIONS
var _attack_generation := 0
var _test_mode := false
var _test_player_state: Dictionary = {}
var _optical_disruption_remaining := 0.0


func _enter_tree() -> void:
	add_to_group("combat_rooms")
	add_to_group("environment_areas")


func _ready() -> void:
	_configure_guard_awareness()
	_configure_arena_camera()
	room_lighting.reset_to_phase_one()
	spawner.all_required_defeated.connect(_on_minions_cleared)
	boss.health.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	spawner.required_remaining_changed.connect(_on_opening_guards_remaining)
	support_spawner.all_required_defeated.connect(_on_supports_cleared)
	support_spawner.required_remaining_changed.connect(_on_support_count_changed)
	player.player_died.connect(_on_player_died)
	exit_elevator.entered.connect(_on_exit_entered)
	exit_elevator.set_enabled(false)
	_set_phase(Phase.MINIONS)
	_start_boss_music(1)
	boss.set_opening_guards(OPENING_GUARD_COUNT, OPENING_GUARD_COUNT)
	_publish_notice(&"boss_phase_one", "第一阶段 · 清除三名守卫，唤醒神像", Color(0.45, 0.9, 1.0), 2.4)


func _process(delta: float) -> void:
	_optical_disruption_remaining = maxf(_optical_disruption_remaining - delta, 0.0)


func apply_optical_disruption(_last_observed_position: Vector2, duration: float) -> void:
	if phase != Phase.BOSS_ACTIVE:
		return
	_optical_disruption_remaining = maxf(_optical_disruption_remaining, duration)
	_publish_notice(&"boss_optical_intruder", "神像火控失锁 · 正在重建索敌", Color(0.35, 0.95, 1.0), 0.9)


func _configure_guard_awareness() -> void:
	# Private profiles keep the arena override out of ordinary rooms and saves.
	for marker in $EnemySpawnPoints.get_children() + $SupportSpawnPoints.get_children():
		marker.profile = marker.profile.duplicate()
		marker.profile.max_health = 3 if marker.profile.role == EnemyProfile.Role.HEAVY_ANCHOR else 1
		marker.profile.full_room_awareness = true
		marker.profile.awareness_range = 1000.0
		marker.profile.vision_angle_degrees = 360.0
		marker.profile.hearing_range = 1000.0
		marker.profile.ally_alert_range = 500.0
		marker.profile.alert_memory_seconds = 10.0


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
	_clear_hostile_projectiles()
	_set_phase(Phase.AWAKENING)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(1)
	_publish_notice(&"boss_awakening", "静默协议解除 · 神像苏醒", Color(1.0, 0.72, 0.25), 2.0)
	player.set_physics_process(false)
	room_lighting.begin_awakening()
	_push_camera_to_altar()
	await boss.begin_awakening()
	if phase != Phase.AWAKENING or player.health.is_dead():
		player.set_physics_process(true)
		return
	_restore_player_camera()
	player.set_physics_process(true)
	_set_phase(Phase.BOSS_ACTIVE)
	_start_boss_music(2)
	_spawn_support_guards()
	_publish_notice(&"boss_phase_two", "第二阶段 · 五名守卫 · 每击败一名，神像失去一滴血", Color(1.0, 0.42, 0.2), 2.4)
	if attack_loop_enabled:
		_attack_generation += 1
		_run_attack_loop(_attack_generation)


func _run_attack_loop(generation: int) -> void:
	while phase == Phase.BOSS_ACTIVE and generation == _attack_generation:
		while _optical_disruption_remaining > 0.0:
			await get_tree().process_frame
			if not _attack_is_current(generation):
				return
		telegraph.clear()
		boss.play_echo_probe()
		room_lighting.pulse_echo()
		await get_tree().create_timer(0.35, false).timeout
		if not _attack_is_current(generation):
			return
		var snapshot := Vector2(
			clampf(player.global_position.x, ARENA_BOUNDS.position.x, ARENA_BOUNDS.end.x),
			clampf(player.global_position.y, ARENA_BOUNDS.position.y, ARENA_BOUNDS.end.y)
		)
		telegraph.show_oracle(snapshot, 0.72)
		await get_tree().create_timer(0.72, false).timeout
		if not _attack_is_current(generation):
			return
		telegraph.show_oracle(snapshot, 0.18, true)
		_damage_player_in_circle(snapshot, ORACLE_RADIUS)
		await get_tree().create_timer(0.36, false).timeout
		if not _attack_is_current(generation):
			return
		var lasers := _make_cross_lasers(snapshot)
		telegraph.show_cross(lasers, 0.78)
		await get_tree().create_timer(0.78, false).timeout
		if not _attack_is_current(generation):
			return
		telegraph.show_cross(lasers, 0.22, true)
		_damage_player_in_cross(lasers)
		await get_tree().create_timer(0.72, false).timeout
	telegraph.clear()


func _make_cross_lasers(snapshot: Vector2) -> Array[Rect2]:
	return [
		Rect2(clampf(snapshot.x - 7, ARENA_BOUNDS.position.x, ARENA_BOUNDS.end.x - 14), ARENA_BOUNDS.position.y, 14, ARENA_BOUNDS.size.y),
		Rect2(ARENA_BOUNDS.position.x, clampf(snapshot.y - 7, ARENA_BOUNDS.position.y, ARENA_BOUNDS.end.y - 14), ARENA_BOUNDS.size.x, 14),
	]


func _damage_player_in_cross(lasers: Array[Rect2]) -> void:
	for rect in lasers:
		if rect.has_point(player.global_position):
			_damage_player(rect.get_center())
			return


func _on_opening_guards_remaining(remaining: int) -> void:
	boss.set_opening_guards(remaining, OPENING_GUARD_COUNT)


func _spawn_support_guards() -> void:
	if support_spawner._spawned:
		return
	boss.health.begin_guard_link()
	boss.hurt_box.set_deferred("monitorable", false)
	var candidates: Array[Vector2] = [Vector2(220,270), Vector2(740,270), Vector2(340,320), Vector2(620,320), Vector2(220,440), Vector2(740,440)]
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return to_global(a).distance_squared_to(player.global_position) > to_global(b).distance_squared_to(player.global_position))
	var markers := $SupportSpawnPoints.get_children()
	for index in markers.size():
		markers[index].position = candidates[index]
		markers[index].profile = markers[index].profile.duplicate()
	support_spawner.spawn_all()


func _on_support_count_changed(remaining: int) -> void:
	boss.health.set_guard_damage_progress(5 - remaining, 5)
	_on_boss_health_changed(boss.health.current_health, boss.health.max_health, 0)


func _on_supports_cleared() -> void:
	if phase != Phase.BOSS_ACTIVE or not boss.health.guard_link_active:
		return
	boss.health.end_guard_link()
	boss.hurt_box.set_deferred("monitorable", true)
	_clear_hostile_projectiles()
	boss.queue_redraw()
	_publish_notice(&"boss_shield_down", "守卫已清除 · 护罩解除 · 神像只剩一滴血", Color(1, 0.75, 0.3), 2.4)


func _clear_support_guards() -> void:
	for enemy in $SupportEnemies.get_children():
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.queue_free()


func _clear_hostile_projectiles() -> void:
	for child in get_children():
		if child is CombatProjectile and child.faction == CombatFaction.Id.ENEMY:
			child.set_physics_process(false)
			child.queue_free()


func _on_player_died(_packet: DamagePacket) -> void:
	_attack_generation += 1
	telegraph.clear()
	_clear_hostile_projectiles()


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
	tween.parallel().tween_property(player.camera, "zoom", Vector2.ONE * PHASE_TWO_CAMERA_ZOOM, 0.45)


func _damage_player_in_circle(center: Vector2, radius: float) -> void:
	if player.global_position.distance_to(center) <= radius:
		_damage_player(center)


func _damage_player_in_rect(rect: Rect2) -> void:
	if rect.has_point(player.global_position):
		_damage_player(rect.get_center())


func _damage_player(source_position: Vector2, damage_type: StringName = &"energy") -> void:
	if get_tree().paused or phase != Phase.BOSS_ACTIVE or player.health.is_dead():
		return
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source = boss
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.damage_type = damage_type
	packet.source_position = source_position
	packet.travel_direction = source_position.direction_to(player.global_position)
	packet.blockable = false
	packet.is_area_damage = true
	player.receive_damage(packet)


func _on_boss_health_changed(_current: int, _maximum: int, _delta: int) -> void:
	# Boss state is communicated in-world by the statue halo and through AI comms.
	# The combat HUD deliberately has no boss health or phase label.
	pass


func _on_boss_defeated() -> void:
	if phase == Phase.CLEARED:
		return
	_attack_generation += 1
	telegraph.clear()
	_clear_support_guards()
	_clear_hostile_projectiles()
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
	phase_changed.emit(phase)


func _attack_is_current(generation: int) -> bool:
	return phase == Phase.BOSS_ACTIVE and generation == _attack_generation and is_instance_valid(player) and not player.health.is_dead()


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
	if _test_mode and event.is_action_pressed("restart_room") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_restart_boss_test()
		return
	if get_tree().current_scene.get_node_or_null("SceneFlow") != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
