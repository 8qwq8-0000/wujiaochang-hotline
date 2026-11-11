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
	CHANNEL_TAKEOVER,
	SECOND_ENDING_PENDING,
}

const ROOM_SIZE := Vector2(1280.0, 900.0)
const ARENA_BOUNDS := Rect2(256.0, 300.0, 768.0, 448.0)
const ORACLE_RADIUS := 28.0
const OPENING_GUARD_COUNT := 2
const WING_GUARD_SCENE := preload("res://scenes/actors/bosses/wing_guard.tscn")
const LIGHTNING_TEXTURE := preload("res://assets/art/effects/boss/whale_lightning_strike.png")
const SUMMON_PROFILES := [preload("res://resources/enemies/melee_pressure.tres"), preload("res://resources/enemies/ranged_sightline.tres"), preload("res://resources/enemies/heavy_anchor.tres")]
const SUMMON_ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const PHASE_TWO_CAMERA_ZOOM := 0.8

@export var attack_loop_enabled := true

@onready var player: PlayerController = $Player
@onready var boss: RooftopWhaleGoddess = $Boss
@onready var support_spawner: EnemySpawner = $SupportSpawner
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var telegraph: BossAttackTelegraph = $AttackTelegraph
@onready var room_lighting: RooftopBossRoomLighting = $RoomLighting
@onready var exit_elevator: ExitElevator = $ExitElevator
@onready var summoned_root: Node2D = $SummonedEnemies

var phase := Phase.MINIONS
var _attack_generation := 0
var _test_mode := false
var _test_player_state: Dictionary = {}
var _optical_disruption_remaining := 0.0
var _opening_wings_remaining := 2
var _queen: WingGuard
var _summon_generation := 0
var _summon_cells: Array[Vector2i] = []
var _summon_progress := 0.0
var _summon_rng := RandomNumberGenerator.new()
var route_dialogue: ChannelDialogue
var channel_duel: ChannelBossDuel


func _enter_tree() -> void:
	add_to_group("combat_rooms")
	add_to_group("environment_areas")


func _ready() -> void:
	var run := get_node("/root/RunManager")
	if not run.channel_resume.is_empty():
		player.import_run_state(run.get_player_state())
	_configure_guard_awareness()
	_configure_arena_camera()
	room_lighting.reset_to_phase_one()
	boss.health.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	player.player_died.connect(_on_player_died)
	exit_elevator.entered.connect(_on_exit_entered)
	exit_elevator.set_enabled(false)
	_set_phase(Phase.MINIONS)
	_start_boss_music(1)
	boss.set_opening_guards(OPENING_GUARD_COUNT, OPENING_GUARD_COUNT)
	call_deferred("_resolve_ending_route")


func _process(delta: float) -> void:
	_optical_disruption_remaining = maxf(_optical_disruption_remaining - delta, 0.0)
	if not _summon_cells.is_empty():
		_summon_progress = minf(_summon_progress + delta / 0.8, 1.0)
		queue_redraw()


func _draw() -> void:
	for cell in _summon_cells:
		var polygon := BossFloorGeometry.cell_polygon(cell)
		var tint := Color(0.43, 0.95, 0.91) if phase == Phase.MINIONS else Color(0.98, 0.69, 1.0)
		for index in 4:
			draw_line(polygon[index], polygon[(index + 1) % 4], Color(tint.r, tint.g, tint.b, 0.4 + 0.55 * _summon_progress), 2.0)
		var center := BossFloorGeometry.cell_point(cell)
		draw_arc(center, 5.0 + 9.0 * _summon_progress, -PI * 0.5, -PI * 0.5 + TAU * _summon_progress, 24, tint, 1.5)


func apply_optical_disruption(_last_observed_position: Vector2, duration: float) -> void:
	if phase != Phase.BOSS_ACTIVE:
		return
	_optical_disruption_remaining = maxf(_optical_disruption_remaining, duration)
	_publish_notice(&"boss_optical_intruder", "神像火控失锁，正在重新索敌", Color(0.35, 0.95, 1.0), 0.9)


func _configure_guard_awareness() -> void:
	# Private profiles keep the arena override out of ordinary rooms and saves.
	for marker in $EnemySpawnPoints.get_children() + $SupportSpawnPoints.get_children():
		marker.profile = marker.profile.duplicate()
		marker.profile.max_health = 6 if marker.profile.role == EnemyProfile.Role.HEAVY_ANCHOR else 4
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
	_stop_summons()
	_clear_summoned_enemies()
	_clear_hostile_projectiles()
	_set_phase(Phase.AWAKENING)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(1)
	_publish_notice(&"boss_awakening", "静默协议解除，神像苏醒", Color(1.0, 0.72, 0.25), 2.0)
	_publish_combat_moment(&"boss_phase")
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
	await _flash_fuse_wings()
	if phase != Phase.BOSS_ACTIVE: return
	_start_summons()
	_publish_notice(&"boss_phase_two", "第二阶段：合翼卫每失去 7 点生命，神像失去 1 格耐久", Color(1.0, 0.42, 0.2), 2.4)
	_publish_combat_moment(&"boss_phase")
	if attack_loop_enabled:
		_attack_generation += 1
		_run_attack_loop(_attack_generation)


func _run_attack_loop(generation: int) -> void:
	while _attack_is_current(generation):
		while _optical_disruption_remaining > 0.0:
			await get_tree().process_frame
			if not _attack_is_current(generation): return
		var tier := clampi(boss.health.current_health, 1, 6)
		var counts := _attack_counts(tier)
		var point_count := counts.x
		var lane_count := counts.y
		var struck_this_round := false
		telegraph.show_echo(boss.global_position, 0.55)
		boss.play_echo_probe()
		room_lighting.pulse_echo()
		await get_tree().create_timer(0.55, false).timeout
		if not _attack_is_current(generation): return
		for index in point_count:
			var cell := _grid_cell(player.global_position)
			telegraph.show_thunder([cell], 0.7)
			await get_tree().create_timer(0.7, false).timeout
			if not _attack_is_current(generation): return
			telegraph.show_thunder([cell], 0.15, true)
			_show_lightning_at(cell)
			$LightningAudio.play()
			if not struck_this_round and player.global_position.distance_to(cell) <= 24.0:
				_damage_player(cell, &"electric")
				struck_this_round = true
			await get_tree().create_timer(0.15, false).timeout
			if not _attack_is_current(generation): return
		for index in lane_count:
			var snapshot := _grid_cell(player.global_position)
			var lane := _thunder_lane(snapshot, index % 2 == 0, index / 2)
			telegraph.show_thunder(lane, 0.7)
			await get_tree().create_timer(0.7, false).timeout
			if not _attack_is_current(generation): return
			for cell_index in lane.size():
				if not _attack_is_current(generation): return
				var cell := lane[cell_index]
				if cell_index % 4 == 0:
					$LightningAudio.play()
				telegraph.show_thunder([cell], 0.08, true)
				_show_lightning_at(cell)
				if not struck_this_round and player.global_position.distance_to(cell) <= 24.0:
					_damage_player(cell, &"electric")
					struck_this_round = true
				await get_tree().create_timer(0.035, false).timeout
		telegraph.clear()
		await get_tree().create_timer(2.4, false).timeout
	telegraph.clear()


func _attack_counts(tier: int) -> Vector2i:
	return Vector2i(
		1 if tier == 6 else 2 if tier >= 4 else 3 if tier >= 2 else 4,
		1 if tier >= 5 else 2 if tier >= 3 else 3 if tier == 2 else 4
	)


func _grid_cell(point: Vector2) -> Vector2:
	return BossFloorGeometry.cell_point(BossFloorGeometry.nearest_cell(point))


func _thunder_lane(target: Vector2, horizontal: bool, offset: int) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	var target_cell := BossFloorGeometry.nearest_cell(target)
	var lane := clampi((target_cell.y if horizontal else target_cell.x) + offset, 0, BossFloorGeometry.GRID_MAX.y if horizontal else BossFloorGeometry.GRID_MAX.x)
	for index in range(BossFloorGeometry.GRID_MAX.x + 1 if horizontal else BossFloorGeometry.GRID_MAX.y + 1):
		cells.append(BossFloorGeometry.cell_point(Vector2i(index, lane) if horizontal else Vector2i(lane, index)))
	return cells


func _show_lightning_at(cell: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "WhaleLightningStrike"
	sprite.texture = LIGHTNING_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 21
	sprite.global_position = cell + Vector2(0, -44)
	sprite.scale = Vector2(0.06, 0.06)
	add_child(sprite)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.19)
	tween.tween_property(sprite, "scale", Vector2(0.055, 0.072), 0.19)
	tween.chain().tween_callback(sprite.queue_free)


func _on_opening_guards_remaining(remaining: int) -> void:
	boss.set_opening_guards(remaining, OPENING_GUARD_COUNT)


func _spawn_opening_wings() -> void:
	var left := _make_wing(WingGuard.Kind.ROOK, 20, BossFloorGeometry.cell_point(Vector2i(2, 5)), $Enemies)
	var right := _make_wing(WingGuard.Kind.BISHOP, 15, BossFloorGeometry.cell_point(Vector2i(21, 5)), $Enemies)
	left.defeated.connect(_on_opening_wing_defeated)
	right.defeated.connect(_on_opening_wing_defeated)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(2)


func _start_summons() -> void:
	_summon_generation += 1
	_run_summons(_summon_generation)


func _stop_summons() -> void:
	_summon_generation += 1
	_summon_cells.clear()
	queue_redraw()


func _run_summons(generation: int) -> void:
	while generation == _summon_generation and phase in [Phase.MINIONS, Phase.BOSS_ACTIVE]:
		var interval := 10.0 if phase == Phase.MINIONS else 8.0
		await get_tree().create_timer(interval, false).timeout
		if generation != _summon_generation or phase not in [Phase.MINIONS, Phase.BOSS_ACTIVE]: return
		var cap := 3 if phase == Phase.MINIONS else 4
		var count := mini(1 if phase == Phase.MINIONS else 2, cap - summoned_root.get_child_count())
		if count <= 0: continue
		_summon_cells = _choose_summon_cells(count)
		if _summon_cells.is_empty(): continue
		_summon_progress = 0.0
		room_lighting.pulse_echo()
		queue_redraw()
		await get_tree().create_timer(0.8, false).timeout
		if generation != _summon_generation or phase not in [Phase.MINIONS, Phase.BOSS_ACTIVE]: return
		for cell in _summon_cells:
			_spawn_summoned_enemy(cell)
		_summon_cells.clear()
		queue_redraw()


func _choose_summon_cells(count: int) -> Array[Vector2i]:
	var choices: Array[Vector2i] = []
	var player_cell := BossFloorGeometry.nearest_cell(player.global_position)
	for y in BossFloorGeometry.GRID_MAX.y + 1:
		for x in BossFloorGeometry.GRID_MAX.x + 1:
			var cell := Vector2i(x, y)
			if maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y)) <= 2: continue
			var point := BossFloorGeometry.cell_point(cell)
			if _summon_cell_occupied(point): continue
			choices.append(cell)
	var result: Array[Vector2i] = []
	while result.size() < count and not choices.is_empty():
		var index := _summon_rng.randi_range(0, choices.size() - 1)
		result.append(choices.pop_at(index))
	return result


func _summon_cell_occupied(point: Vector2) -> bool:
	for root_node in [$Enemies, $SupportEnemies, summoned_root]:
		for enemy in root_node.get_children():
			if enemy is WingGuard and enemy.health.is_dead(): continue
			if enemy is EnemyController and enemy.health.is_dead(): continue
			if enemy is Node2D and enemy.global_position.distance_to(point) < 30.0: return true
			if enemy is WingGuard:
				for warning_cell in enemy._warning_cells:
					if BossFloorGeometry.cell_point(warning_cell).distance_to(point) < 24.0: return true
				for warning_line in enemy._warning_lines:
					for index in range(warning_line.size() - 1):
						if Geometry2D.get_closest_point_to_segment(point, warning_line[index], warning_line[index + 1]).distance_to(point) < 20.0: return true
	if telegraph.mode == BossAttackTelegraph.Mode.THUNDER_WARNING:
		for cell in telegraph.thunder_cells:
			if telegraph.to_global(cell).distance_to(point) < 24.0: return true
	return false


func _spawn_summoned_enemy(cell: Vector2i) -> void:
	var enemy := SUMMON_ENEMY.instantiate() as EnemyController
	var profile_count := 2 if phase == Phase.MINIONS else 3
	var profile := (SUMMON_PROFILES[_summon_rng.randi_range(0, profile_count - 1)] as EnemyProfile).duplicate() as EnemyProfile
	profile.max_health += 1 if phase == Phase.MINIONS else 2
	if profile.role == EnemyProfile.Role.MELEE_PRESSURE:
		profile.move_speed *= 1.1 if phase == Phase.MINIONS else 1.2
	profile.full_room_awareness = true
	profile.awareness_range = 1500.0
	profile.vision_angle_degrees = 360.0
	enemy.profile = profile
	enemy.mandatory = false
	enemy.set_meta("boss_summoned_minion", true)
	enemy.position = BossFloorGeometry.cell_point(cell)
	summoned_root.add_child(enemy)


func _clear_summoned_enemies() -> void:
	for enemy in summoned_root.get_children():
		enemy.queue_free()


func _flash_fuse_wings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.95, 0.78, 0.0)
	layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.96, 0.15)
	await tween.finished
	for wing in $Enemies.get_children():
		if wing is WingGuard and wing.health.is_dead(): wing.queue_free()
	_spawn_support_guards()
	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.35)
	await fade.finished
	layer.queue_free()


func _make_wing(kind: WingGuard.Kind, max_health: int, at: Vector2, parent: Node2D) -> WingGuard:
	var wing := WING_GUARD_SCENE.instantiate() as WingGuard
	wing.kind = kind
	wing.player_path = NodePath("../../Player")
	wing.get_node("HealthComponent").max_health = max_health
	wing.position = at
	parent.add_child(wing)
	return wing


func _on_opening_wing_defeated(_wing: WingGuard) -> void:
	_opening_wings_remaining = maxi(_opening_wings_remaining - 1, 0)
	boss.set_opening_guards(_opening_wings_remaining, OPENING_GUARD_COUNT)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_mandatory_enemy_count(_opening_wings_remaining)
	if _opening_wings_remaining == 0:
		_on_minions_cleared()


func _spawn_support_guards() -> void:
	if phase == Phase.CLEARED or is_instance_valid(_queen):
		return
	boss.health.begin_guard_link()
	boss.hurt_box.set_deferred("monitorable", false)
	_queen = _make_wing(WingGuard.Kind.QUEEN, 35, BossFloorGeometry.cell_point(Vector2i(11, 6)), $SupportEnemies)
	_queen.health_changed.connect(_on_queen_health_changed)
	_queen.defeated.connect(_on_queen_defeated)


func _on_queen_health_changed(current: int, _maximum: int) -> void:
	boss.health.set_guard_damage_progress((35 - current) / 7, 5)


func _on_queen_defeated(_wing: WingGuard) -> void:
	if phase != Phase.BOSS_ACTIVE or not boss.health.guard_link_active:
		return
	boss.health.set_guard_damage_progress(5, 5)
	boss.health.end_guard_link()
	boss.hurt_box.set_deferred("monitorable", true)
	_clear_hostile_projectiles()
	boss.queue_redraw()
	_publish_notice(&"boss_shield_down", "合翼卫崩解，神像只剩 1 格耐久", Color(1, 0.75, 0.3), 2.4)
	_publish_combat_moment(&"boss_break")


func _clear_support_guards() -> void:
	for enemy in $SupportEnemies.get_children():
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.queue_free()


func _clear_hostile_projectiles() -> void:
	for child in get_children() + $Enemies.get_children() + $SupportEnemies.get_children():
		if child is WingSlashProjectile or (child is CombatProjectile and child.faction == CombatFaction.Id.ENEMY):
			child.set_physics_process(false)
			child.queue_free()


func _on_player_died(_packet: DamagePacket) -> void:
	_attack_generation += 1
	_stop_summons()
	telegraph.clear()
	_clear_hostile_projectiles()
	if is_instance_valid(channel_duel):
		channel_duel.stop_combat()


func _push_camera_to_altar() -> void:
	var altar_center := Vector2(640.0, 280.0)
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
	if get_tree().paused or phase not in [Phase.BOSS_ACTIVE, Phase.CHANNEL_TAKEOVER] or player.health.is_dead():
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
	if is_instance_valid(channel_duel) and channel_duel.stage != ChannelBossDuel.Stage.COMPLETE:
		channel_duel.begin_ending()
		return
	_attack_generation += 1
	_stop_summons()
	_clear_summoned_enemies()
	telegraph.clear()
	for guard in $Enemies.get_children():
		if guard is WingGuard:
			guard.set_active(false)
			guard.queue_free()
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
	_publish_notice(&"boss_defeated", "公共频道已恢复，楼顶出口已开放" if is_instance_valid(channel_duel) else "神谕中止，楼顶出口已开放", Color(0.4, 1.0, 0.62), 3.0)
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


func _publish_combat_moment(kind: StringName) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_combat_moment(kind, boss.global_position)


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


func _save_channel_checkpoint() -> void:
	var run := get_node("/root/RunManager")
	if not run.channel_route_active or _test_mode:
		return
	var saved := {"scene": scene_file_path, "seed": run.run_seed, "floor": 3, "route": run.export_channel_state(),
		"player": player.export_run_state(), "elapsed": float(Time.get_ticks_msec() - run.run_started_msec) / 1000,
		"medical_used": run.codex_medical_supply_used}
	if not get_node("/root/WarehouseStore").save_channel_progress(saved):
		_publish_notice(&"channel_save_error", "楼顶检查点保存失败，请检查可用空间", Color("e37662"), 3.0)
	run.channel_resume.clear()


func _resolve_ending_route() -> void:
	var run := get_node("/root/RunManager")
	if not _test_mode and run.channel_route_active and run.codex_is_alive() and bool(run.codex_companion.get("ambush_complete", false)) and run.carries_channel_core(player):
		run.codex_companion.arrived = true
		_set_phase(Phase.SECOND_ENDING_PENDING)
		_attack_generation += 1
		boss.health.damage_enabled = false
		boss.hurt_box.set_deferred("monitorable", false)
		for enemies in [$Enemies, $SupportEnemies]:
			for enemy in enemies.get_children():
				enemy.set_physics_process(false)
				enemy.queue_free()
		telegraph.clear()
		_clear_hostile_projectiles()
		run.set_mandatory_enemy_count(1)
		_save_channel_checkpoint()
		channel_duel = ChannelBossDuel.new()
		channel_duel.name = "ChannelBossDuel"
		add_child(channel_duel)
		return
	else:
		EnemyEncounterRecorder.watch(boss, "rooftop_whale_goddess", false)
		_spawn_opening_wings()
		_summon_rng.randomize()
		_start_summons()
		_publish_notice(&"boss_phase_one", "第一阶段：击碎左右翼卫，唤醒神像", Color(0.45, 0.9, 1.0), 2.4)
	_save_channel_checkpoint()
