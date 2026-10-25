class_name PersonaDialogueController
extends Node

signal line_requested(text: String, priority: int, persona_id: StringName, queue_policy: int)

const TABLE_PATH := "res://data/tables/ai-dialogue-lines-v1.csv"
const IDLE_SECONDS := 20.0
const SCAN_INTERVAL := 0.1
const COOLDOWN_SECONDS := {
	&"reaction": 8.0,
	&"tactical": 15.0,
	&"banter": 30.0,
}
const PERSONA_IDS := {
	"naraku": TalentCoreController.DEEP_NINJA,
	"xiangshan": TalentCoreController.LEGENDARY_MASTER,
	"johnny": TalentCoreController.ROCK_VIGILANTE,
}
const BOND_RANKS := {"testing": 0, "synced": 1, "accomplice": 2}

var _lines: Array[Dictionary] = []
var _player: PlayerController
var _active_persona: StringName = &""
var _persona_before_switch: StringName = &""
var _known_levels: Dictionary = {}
var _cooldowns: Dictionary = {}
var _deferred_scripted: Array[Dictionary] = []
var _spotted_heavy_ids: Dictionary = {}
var _spotted_boss_ids: Dictionary = {}
var _idle_announced_rooms: Dictionary = {}
var _low_health_announced := false
var _idle_elapsed := 0.0
var _scan_remaining := 0.0


func _ready() -> void:
	_load_table()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.room_cleared.connect(_on_room_cleared)
	set_process(true)
	set_process_unhandled_input(true)


func bind_player(value: PlayerController) -> void:
	if _player == value:
		return
	_player = value
	_idle_elapsed = 0.0
	_low_health_announced = false
	if not is_instance_valid(_player):
		return
	_active_persona = _player.talent_core.current_persona_id
	_persona_before_switch = _active_persona
	_known_levels.clear()
	for persona_id in TalentCoreController.PERSONA_IDS:
		_known_levels[String(persona_id)] = _player.talent_core.get_persona_level(persona_id)
	_player.talent_core.persona_changed.connect(_on_persona_changed)
	_player.health_changed.connect(_on_health_changed)
	_player.heat.overheated.connect(_on_weapon_overheated)
	_player.persona_combat.manual_perfect_guarded.connect(_on_manual_perfect_guarded)


func bind_feedback_manager(manager: CombatFeedbackManager) -> void:
	if manager != null and not manager.kill_chain_feedback.is_connected(_on_kill_chain_feedback):
		manager.kill_chain_feedback.connect(_on_kill_chain_feedback)


func bind_rest_flow(rest_flow: Node) -> void:
	var callback := Callable(self, "_on_persona_consumed")
	if rest_flow != null and rest_flow.has_signal("persona_consumed") and not rest_flow.is_connected("persona_consumed", callback):
		rest_flow.connect("persona_consumed", callback)


func _process(delta: float) -> void:
	for group in _cooldowns.keys():
		_cooldowns[group] = maxf(float(_cooldowns[group]) - delta, 0.0)
	if not _deferred_scripted.is_empty() and _can_present_dialogue():
		for entry in _deferred_scripted:
			line_requested.emit(entry.text, entry.priority, entry.persona_id, CombatCommsController.QueuePolicy.APPEND)
		_deferred_scripted.clear()
		_cooldowns[&"banter"] = COOLDOWN_SECONDS[&"banter"]
	if not is_instance_valid(_player) or _player.health.is_dead():
		return
	_scan_remaining = maxf(_scan_remaining - delta, 0.0)
	if _scan_remaining <= 0.0:
		_scan_remaining = SCAN_INTERVAL
		_scan_visible_targets()
	_tick_idle(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"guard", &"mobility_ability", &"weapon_switch", &"weapon_next", &"weapon_previous"]:
		if event.is_action_pressed(action):
			_idle_elapsed = 0.0
			return


func _load_table(path: String = TABLE_PATH) -> void:
	_lines.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_load_imported_table()
		if _lines.is_empty():
			push_error("无法读取人格台词表：%s" % path)
		return
	var headers := file.get_csv_line()
	if not headers.is_empty():
		headers[0] = headers[0].trim_prefix("\ufeff")
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.size() != headers.size() or values.is_empty() or values[0].is_empty():
			continue
		var entry := {}
		for index in headers.size():
			entry[String(headers[index])] = String(values[index])
		_lines.append(entry)


func _load_imported_table() -> void:
	var columns := {
		"persona": load("res://data/tables/ai-dialogue-lines-v1.persona.translation") as Translation,
		"event": load("res://data/tables/ai-dialogue-lines-v1.event.translation") as Translation,
		"bond": load("res://data/tables/ai-dialogue-lines-v1.bond.translation") as Translation,
		"tier_min": load("res://data/tables/ai-dialogue-lines-v1.tier.translation") as Translation,
		"intensity": load("res://data/tables/ai-dialogue-lines-v1.intensity.translation") as Translation,
		"cooldown_group": load("res://data/tables/ai-dialogue-lines-v1.cooldown.translation") as Translation,
		"text": load("res://data/tables/ai-dialogue-lines-v1.text.translation") as Translation,
	}
	var text_column := columns.text as Translation
	if text_column == null:
		return
	for key in text_column.get_message_list():
		var entry := {"key": String(key)}
		for field in columns:
			var column := columns[field] as Translation
			entry[field] = String(column.get_message(key)) if column != null else ""
		_lines.append(entry)


func _select_line(event: StringName, persona_id: StringName) -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	var level := _player.talent_core.get_persona_level(persona_id)
	var relationship := _player.talent_core.get_relationship_stage(persona_id)
	var selected: Dictionary = {}
	var selected_rank := -1
	var selected_tier := -1
	for entry in _lines:
		if PERSONA_IDS.get(String(entry.persona), &"") != persona_id or StringName(entry.event) != event:
			continue
		var rank := int(BOND_RANKS.get(String(entry.bond), -1))
		var tier := int(entry.tier_min)
		if rank > relationship or tier > level:
			continue
		if rank > selected_rank or (rank == selected_rank and tier > selected_tier):
			selected = entry
			selected_rank = rank
			selected_tier = tier
	return selected


func _try_event(event: StringName, persona_id: StringName = &"") -> bool:
	if not is_instance_valid(_player):
		return false
	var speaker := persona_id if not persona_id.is_empty() else _player.talent_core.current_persona_id
	var entry := _select_line(event, speaker)
	if entry.is_empty():
		return false
	var group := StringName(entry.cooldown_group)
	if group != &"critical" and float(_cooldowns.get(group, 0.0)) > 0.0:
		return false
	var priority := _priority_for_group(group)
	var policy := CombatCommsController.QueuePolicy.DROP_IF_BUSY if group == &"banter" else CombatCommsController.QueuePolicy.LATEST
	line_requested.emit(String(entry.text), priority, speaker, policy)
	if COOLDOWN_SECONDS.has(group):
		_cooldowns[group] = COOLDOWN_SECONDS[group]
	return true


func _queue_scripted_event(event: StringName, persona_id: StringName) -> bool:
	var entry := _select_line(event, persona_id)
	if entry.is_empty():
		return false
	_deferred_scripted.append({
		"text": String(entry.text),
		"priority": _priority_for_group(StringName(entry.cooldown_group)),
		"persona_id": persona_id,
	})
	return true


func _priority_for_group(group: StringName) -> int:
	if group == &"critical":
		return CombatCommsController.Priority.CRITICAL
	if group in [&"reaction", &"tactical"]:
		return CombatCommsController.Priority.HIGH
	return CombatCommsController.Priority.NORMAL


func _on_persona_changed(persona_id: StringName) -> void:
	_persona_before_switch = _active_persona
	_active_persona = persona_id


func _on_persona_consumed(persona_id: StringName, level: int) -> void:
	if not is_instance_valid(_player):
		return
	var previous := _persona_before_switch if _active_persona == persona_id else _active_persona
	if not previous.is_empty() and previous != persona_id and _player.talent_core.get_persona_level(previous) > 0:
		_queue_scripted_event(&"switch_out", previous)
	var old_level := int(_known_levels.get(String(persona_id), 0))
	if old_level == 0 or previous != persona_id:
		_queue_scripted_event(&"station_switch", persona_id)
	if level > old_level and level >= 2:
		_queue_scripted_event(&"tier_up", persona_id)
	_known_levels[String(persona_id)] = level
	_active_persona = persona_id
	_persona_before_switch = persona_id


func _on_damage_resolved(result: DamageResult) -> void:
	if not is_instance_valid(_player) or result == null or result.target != _player or result.outcome != DamageResult.Outcome.DAMAGED or result.final_damage <= 0:
		return
	var current := _player.health.current_health
	if current <= 0:
		return
	if current == 1:
		if not _low_health_announced:
			_low_health_announced = true
			_try_event(&"low_health")
		return
	_low_health_announced = false
	_try_event(&"damaged")


func _on_health_changed(current: int, _maximum: int, _delta: int) -> void:
	if current > 1:
		_low_health_announced = false


func _on_manual_perfect_guarded() -> void:
	_try_event(&"perfect_block")


func _on_weapon_overheated() -> void:
	_try_event(&"weapon_overheated")


func _on_kill_chain_feedback(_position: Vector2, stage: int, _weapon_id: StringName, _offscreen: bool, boss_final: bool, _suppressed: bool) -> void:
	if stage == 3 and not boss_final:
		_try_event(&"kill_chain")


func _on_room_cleared(room: Node) -> void:
	if room is CombatRoom:
		_try_event(&"victory")
	_idle_elapsed = 0.0


func _scan_visible_targets() -> void:
	if not _can_present_dialogue():
		return
	for candidate in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := candidate as EnemyController
		if enemy == null or enemy.profile == null or enemy.profile.role != EnemyProfile.Role.HEAVY_ANCHOR or enemy.health.is_dead():
			continue
		var enemy_id := enemy.get_instance_id()
		if _spotted_heavy_ids.has(enemy_id) or not _is_visible_target(enemy):
			continue
		if _try_event(&"enemy_spotted"):
			_spotted_heavy_ids[enemy_id] = true
	for candidate in get_tree().get_nodes_in_group(&"bosses"):
		var boss := candidate as Node2D
		if boss == null or _spotted_boss_ids.has(boss.get_instance_id()) or not _is_visible_target(boss):
			continue
		if _try_event(&"boss"):
			_spotted_boss_ids[boss.get_instance_id()] = true


func _tick_idle(delta: float) -> void:
	var room := _room_for_player()
	if not room is CombatRoom or room.cleared or not room.active:
		_idle_elapsed = 0.0
		return
	var room_id := room.get_instance_id()
	if _idle_announced_rooms.has(room_id):
		return
	if _player.velocity.length_squared() > 4.0 or _player.weapons.is_attack_active() or _player.guard.is_guard_active() or _player.dash.is_dashing() or _attack_is_imminent():
		_idle_elapsed = 0.0
		return
	_idle_elapsed += delta
	if _idle_elapsed >= IDLE_SECONDS and _try_event(&"idle"):
		_idle_announced_rooms[room_id] = true


func _attack_is_imminent() -> bool:
	for candidate in get_tree().get_nodes_in_group(&"enemies"):
		if candidate is EnemyController and candidate.state == EnemyController.State.WINDUP:
			return true
	return false


func _room_for_player() -> Node:
	if not is_instance_valid(_player):
		return null
	for room in get_tree().get_nodes_in_group(&"environment_areas"):
		if room.has_method("contains_world_point") and room.contains_world_point(_player.global_position):
			return room
	return null


func _can_present_dialogue() -> bool:
	return (
		is_instance_valid(_player)
		and not get_tree().paused
		and get_tree().get_nodes_in_group(&"warehouse").is_empty()
		and get_tree().get_nodes_in_group(&"intermission").is_empty()
	)


func _is_visible_target(target: Node2D) -> bool:
	if not is_instance_valid(_player) or CombatProjectile.room_for_actor(target) != CombatProjectile.room_for_actor(_player):
		return false
	var camera := _player.get_viewport().get_camera_2d()
	if camera != null:
		var size := _player.get_viewport_rect().size / camera.zoom
		if not Rect2(camera.get_screen_center_position() - size * 0.5, size).grow(12.0).has_point(target.global_position):
			return false
	var query := PhysicsRayQueryParameters2D.create(_player.global_position, target.global_position, 1)
	return _player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
