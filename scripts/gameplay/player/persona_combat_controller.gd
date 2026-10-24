class_name PersonaCombatController
extends Node2D

signal runtime_state_changed(state: Dictionary)

const MARK_REFRESH_SECONDS := 0.25
const ROCK_FEEDBACK_MAX := 100.0
const ROCK_FEEDBACK_DECAY := 18.0
const ROCK_DECAY_DELAY := 0.65
const MASTER_ANALYSIS_SAMPLES := 2
const TAKEOVER_LANDING_RADII := [42.0, 56.0, 70.0]
const TAKEOVER_LANDING_ANGLES := [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI]
const TAKEOVER_ESCAPE_PROBE := 14.0
const HUNT_TRIGGER_DISTANCE := 40.0
const HUNT_PREVIEW_SECONDS := 0.18
const HUNT_MAX_SEGMENTS := 3
const MASTER_AURA_RADIUS := 220.0

@onready var player: PlayerController = get_parent() as PlayerController
@onready var core: TalentCoreController = player.get_node("TalentCoreController")
@onready var health: HealthComponent = player.get_node("HealthComponent")
@onready var heat: HeatComponent = player.get_node("HeatComponent")
@onready var guard: GuardComponent = player.get_node("GuardComponent")
@onready var dash: DashController = player.get_node("DashController")
@onready var weapons: WeaponController = player.get_node("WeaponController")
@onready var hurt_box: HurtBox2DComponent = player.get_node("HurtBox")

var marked_target: EnemyController
var rock_feedback := 0.0

var _mark_refresh_remaining := 0.0
var _marked_hit_streak := 0
var _read_opening_cooldowns: Dictionary = {}
var _marked_kill_streak := 0
var _recorded_marked_chain := 0
var _gaze_remaining := 0.0
var _gaze_attack_pending := false
var _chase_remaining := 0.0
var _chase_path: PackedVector2Array = []
var _chase_path_index := 0
var _borrowed_step_target_id := 0
var _borrowed_strike_target: WeakRef
var _resonance_remaining := 0.0
var _blood_step_remaining := 0.0
var _dash_speed_bonus_applied := 0.0

var _rock_decay_delay_remaining := 0.0
var _encore_remaining := 0.0
var _seamless_free_attack := false
var _seamless_switch_window := 0.0
var _alternate_attack_window := 0.0
var _overload_ready := true
var _performing_ai_attack := false
var _weapon_cooldowns: Dictionary = {}
var _last_weapon_id: StringName = &""
var _last_attack_weapon_id: StringName = &""
var _rock_alternations := 0
var _rock_overheat_had_feedback := false
var _feedback_hit_groups: Dictionary = {}
var _attack_group_contexts: Dictionary = {}
var _attack_group_targets: Dictionary = {}
var _terminal_burst_groups: Dictionary = {}
var _refutation_reward_remaining := 0.0

var _analysis_samples: Dictionary = {}
var _analyzed_attacks: Dictionary = {}
var _analyzed_sources: Dictionary = {}
var _proxy_counter_used: Dictionary = {}
var _proxy_counter_armed: Dictionary = {}
var _manual_validations := 0
var _pending_master_takeover := false
var _pending_ai_guard := false
var _guard_bonus_applied := 0.0
var _observed_threat: WeakRef
var _observed_attack_key := ""
var _master_loop_remaining := 0.0
var _master_loop_interval := 0.0
var _pending_master_counter: WeakRef
var _attack_speed_bonus_applied := 0.0


func _ready() -> void:
	core.persona_changed.connect(_on_persona_changed)
	core.persona_level_changed.connect(_on_persona_level_changed)
	core.talent_build_changed.connect(_on_talent_build_changed)
	core.takeover_armed_changed.connect(_on_takeover_armed_changed)
	weapons.attack_performed.connect(_on_attack_performed)
	weapons.weapon_changed.connect(_on_weapon_changed)
	heat.overheated.connect(_on_overheated)
	heat.recovered.connect(_on_heat_recovered)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.enemy_attack_performed.connect(_on_enemy_attack_performed)
	var current_weapon := weapons.get_current_weapon()
	_last_weapon_id = current_weapon.id if current_weapon != null else &""
	_apply_persona_modifiers()


func _physics_process(delta: float) -> void:
	_tick_temporary_bonuses(delta)
	if not _has_active_persona() or health.is_dead():
		return
	match core.current_persona_id:
		TalentCoreController.DEEP_NINJA:
			_tick_deep_ninja(delta)
		TalentCoreController.ROCK_VIGILANTE:
			_tick_rock_vigilante(delta)
	queue_redraw()


func _draw() -> void:
	if _chase_remaining > 0.0 and _chase_path.size() > 1:
		for index in range(1, _chase_path.size()):
			draw_dashed_line(to_local(_chase_path[index - 1]), to_local(_chase_path[index]), Color(0.8, 0.25, 1.0, 0.42), 2.0, 6.0)
	if _is_active(TalentCoreController.DEEP_NINJA) and _is_live_enemy(marked_target):
		var center := to_local(marked_target.global_position + Vector2(0.0, -10.0))
		draw_arc(center, 15.0, 0.0, TAU, 28, Color(0.75, 0.25, 1.0, 0.9), 2.0, true)
		draw_line(center + Vector2(-5.0, 0.0), center + Vector2(5.0, 0.0), Color(0.95, 0.65, 1.0), 1.0)
	if not _is_active(TalentCoreController.LEGENDARY_MASTER) or not _has_talent(&"open_model"):
		return
	for source_ref: WeakRef in _analyzed_sources.values():
		var source := source_ref.get_ref() as EnemyController
		if not _is_live_enemy(source) or not _same_room(source):
			continue
		var from := to_local(source.global_position + Vector2(0.0, -10.0))
		var to := to_local(player.global_position + Vector2(0.0, -10.0))
		var warning := source.state == EnemyController.State.WINDUP
		draw_dashed_line(from, to, Color(0.35, 0.95, 1.0, 0.9 if warning else 0.28), 2.0 if warning else 1.0, 5.0)
		if warning:
			draw_circle(to, 8.0, Color(0.35, 0.95, 1.0, 0.16), false, 1.5)
			var eta := maxf(float(source.get("_windup_remaining")), 0.0)
			draw_string(ThemeDB.fallback_font, to + Vector2(10.0, -7.0), "%.2fs" % eta, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.65, 0.95, 1.0, 0.9))


func notify_player_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (
		event.is_action_pressed("attack")
		or event.is_action_pressed("guard")
		or event.is_action_pressed("mobility_ability")
		or event.is_action_pressed("weapon_switch")
		or event.is_action_pressed("weapon_next")
		or event.is_action_pressed("weapon_previous")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("move_up")
		or event.is_action_pressed("move_down")
	):
		_cancel_soft_takeover()


func try_proxy_guard(packet: DamagePacket) -> bool:
	if (
		not _is_active(TalentCoreController.LEGENDARY_MASTER)
		or packet == null
		or not packet.blockable
		or packet.is_area_damage
	):
		return false
	var source := packet.source
	if not is_instance_valid(source):
		return false
	var key := _attack_key(packet)
	var analyzed := _is_attack_analyzed(source, key)
	if analyzed and _has_talent(&"calibrated_window") and guard.state in [GuardComponent.State.STARTUP, GuardComponent.State.PERFECT]:
		guard.extend_current_perfect_window(0.2)
	if guard.state != GuardComponent.State.IDLE:
		return false
	var source_id := source.get_instance_id()
	var emergency := core.takeover_armed and core.takeover_charges > 0
	if not emergency and (dash.is_dashing() or weapons.is_attack_active()):
		return false
	var aura_perfect := _master_loop_remaining > 0.0 and _master_loop_interval <= 0.0 and analyzed
	var proxy_perfect := _has_talent(&"proxy_counter") and analyzed and bool(_proxy_counter_armed.get(source_id, false)) and not bool(_proxy_counter_used.get(source_id, false))
	var proxy_normal := _has_talent(&"proxy_stance") and analyzed
	if not emergency and not aura_perfect and not proxy_perfect and not proxy_normal:
		return false
	var toward_source := packet.source_position - player.global_position
	if toward_source.is_zero_approx() and not packet.travel_direction.is_zero_approx():
		toward_source = -packet.travel_direction
	if not guard.begin_guard(toward_source):
		return false
	guard.advance_timing(guard.startup_seconds)
	if proxy_normal and not emergency and not proxy_perfect and not aura_perfect:
		guard.advance_timing(guard.perfect_seconds + guard.equipment_window_bonus)
	if proxy_perfect:
		_proxy_counter_used[source_id] = true
		_proxy_counter_armed.erase(source_id)
	if aura_perfect:
		_master_loop_interval = 0.8
		_pending_master_counter = weakref(source)
	_pending_ai_guard = true
	if emergency:
		_pending_master_takeover = true
	return true


func reset_transient_state() -> void:
	_set_mark(null)
	rock_feedback = 0.0
	_marked_hit_streak = 0
	_marked_kill_streak = 0
	_recorded_marked_chain = 0
	_analysis_samples.clear()
	_observed_threat = null
	_observed_attack_key = ""
	_master_loop_remaining = 0.0
	_analyzed_attacks.clear()
	_analyzed_sources.clear()
	_proxy_counter_used.clear()
	_proxy_counter_armed.clear()
	_manual_validations = 0
	_pending_master_takeover = false
	_pending_ai_guard = false
	_weapon_cooldowns.clear()
	_seamless_free_attack = false
	_overload_ready = true
	_last_attack_weapon_id = &""
	_rock_alternations = 0
	_rock_overheat_had_feedback = false
	_encore_remaining = 0.0
	heat.set_overflow_enabled(false)
	_feedback_hit_groups.clear()
	_attack_group_contexts.clear()
	_attack_group_targets.clear()
	_terminal_burst_groups.clear()
	_refutation_reward_remaining = 0.0
	_cancel_soft_takeover()
	_clear_temporary_modifiers()
	_apply_persona_modifiers()
	_emit_runtime_state()


func get_runtime_snapshot() -> Dictionary:
	var threat := _observed_threat.get_ref() as Node if _observed_threat != null else null
	var threat_live := is_instance_valid(threat) and CombatProjectile.room_for_actor(threat) == CombatProjectile.room_for_actor(player)
	if threat is EnemyController:
		threat_live = threat_live and _is_live_enemy(threat)
	var samples := _attack_sample_count(threat, _observed_attack_key) if threat_live else 0
	return {
		"persona_id": String(core.current_persona_id) if is_instance_valid(core) else "",
		"marked_target_id": marked_target.get_instance_id() if _is_live_enemy(marked_target) else 0,
		"rock_feedback": rock_feedback,
		"analyzed_attack_count": _analyzed_attacks.size(),
		"prediction_source_count": _analyzed_sources.size(),
		"soft_takeover_active": _gaze_remaining > 0.0 or _chase_remaining > 0.0 or _master_loop_remaining > 0.0,
		"blood_step_remaining": _blood_step_remaining,
		"resonance_remaining": _resonance_remaining,
		"gaze_active": _gaze_remaining > 0.0,
		"chase_active": _chase_remaining > 0.0,
		"analysis_has_threat": threat_live,
		"analysis_samples": mini(samples, MASTER_ANALYSIS_SAMPLES),
		"analysis_required": MASTER_ANALYSIS_SAMPLES,
		"guard_window_active": _guard_bonus_applied > 0.0,
		"ai_guard_active": _pending_ai_guard and guard.is_guard_active(),
		"master_loop_remaining": _master_loop_remaining,
		"master_takeover_pending": _pending_master_takeover,
		"seamless_free_attack": _seamless_free_attack,
		"encore_remaining": _encore_remaining,
		"distortion_active": _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"distortion_gain") and rock_feedback >= 60.0,
	}


func _tick_deep_ninja(delta: float) -> void:
	_mark_refresh_remaining = maxf(_mark_refresh_remaining - delta, 0.0)
	if not _is_live_enemy(marked_target) and _mark_refresh_remaining <= 0.0:
		_mark_refresh_remaining = MARK_REFRESH_SECONDS
		# Entering a room may establish an initial hunt mark, but that is not a
		# combat event and must not make Gaze fire as soon as the scene loads.
		_set_mark(_select_execution_target(), false)
	_gaze_remaining = maxf(_gaze_remaining - delta, 0.0)
	if _gaze_attack_pending and _gaze_remaining <= 0.0 and _is_live_enemy(marked_target):
		_gaze_attack_pending = false
		_perform_ai_attack(player.global_position.direction_to(marked_target.global_position), true, 1.0)
	_chase_remaining = maxf(_chase_remaining - delta, 0.0)
	if _chase_remaining > 0.0:
		queue_redraw()
	elif not _chase_path.is_empty() and not dash.is_dashing():
		_execute_next_hunt_segment()
	if _borrowed_strike_target != null and not dash.is_dashing():
		var strike_target := _borrowed_strike_target.get_ref() as EnemyController
		_borrowed_strike_target = null
		if _is_live_enemy(strike_target) and player.global_position.distance_to(strike_target.global_position) <= 48.0:
			_perform_karate_chop(strike_target)
	if (
		_has_talent(&"borrowed_step")
		and _is_live_enemy(marked_target)
		and _borrowed_step_target_id != marked_target.get_instance_id()
		and player.global_position.distance_to(marked_target.global_position) <= HUNT_TRIGGER_DISTANCE
		and not dash.is_dashing()
	):
		_try_borrowed_step()


func _tick_rock_vigilante(delta: float) -> void:
	_rock_decay_delay_remaining = maxf(_rock_decay_delay_remaining - delta, 0.0)
	_seamless_switch_window = maxf(_seamless_switch_window - delta, 0.0)
	_alternate_attack_window = maxf(_alternate_attack_window - delta, 0.0)
	_refutation_reward_remaining = maxf(_refutation_reward_remaining - delta, 0.0)
	if _rock_decay_delay_remaining <= 0.0 and rock_feedback > 0.0:
		var decay := ROCK_FEEDBACK_DECAY * (0.55 if _has_talent(&"steady_beat") else 1.0)
		_set_rock_feedback(rock_feedback - decay * delta)
	if _encore_remaining > 0.0:
		_encore_remaining = maxf(_encore_remaining - delta, 0.0)
		_set_rock_feedback(_encore_remaining / 2.0 * ROCK_FEEDBACK_MAX)
		if _encore_remaining <= 0.0:
			heat.set_overflow_enabled(false)
	if heat.current_heat <= heat.effective_max() * 0.45:
		_overload_ready = true


func _tick_temporary_bonuses(delta: float) -> void:
	_master_loop_remaining = maxf(_master_loop_remaining - delta, 0.0)
	_master_loop_interval = maxf(_master_loop_interval - delta, 0.0)
	_blood_step_remaining = maxf(_blood_step_remaining - delta, 0.0)
	_resonance_remaining = maxf(_resonance_remaining - delta, 0.0)
	var wanted_dash_bonus := (0.2 if _blood_step_remaining > 0.0 else 0.0) + (0.2 if _resonance_remaining > 0.0 else 0.0)
	if not is_equal_approx(wanted_dash_bonus, _dash_speed_bonus_applied):
		dash.equipment_speed_bonus += wanted_dash_bonus - _dash_speed_bonus_applied
		_dash_speed_bonus_applied = wanted_dash_bonus
	_apply_guard_modifier()
	_apply_attack_speed_modifier()


func _on_damage_resolved(result: DamageResult) -> void:
	if result == null or result.packet == null:
		return
	if result.target == player:
		_on_incoming_result(result)
		return
	if result.packet.source != player or not result.target is EnemyController:
		return
	var enemy := result.target as EnemyController
	if _is_active(TalentCoreController.DEEP_NINJA):
		_on_deep_ninja_hit(enemy, result)
	elif _is_active(TalentCoreController.ROCK_VIGILANTE) and result.final_damage > 0:
		var group_id := result.packet.feedback_group_id
		if group_id > 0 and not _feedback_hit_groups.has(group_id) and _encore_remaining <= 0.0:
			_feedback_hit_groups[group_id] = true
			_set_rock_feedback(rock_feedback + _feedback_gain_for_weapon_id(result.packet.weapon_id))
			_rock_decay_delay_remaining = 1.5 if _has_talent(&"steady_beat") else ROCK_DECAY_DELAY
			while _feedback_hit_groups.size() > 64:
				_feedback_hit_groups.erase(_feedback_hit_groups.keys()[0])
	if result.final_damage > 0 and result.packet.terminal_attack and not _terminal_burst_groups.has(result.packet.feedback_group_id):
		_terminal_burst_groups[result.packet.feedback_group_id] = true
		_apply_terminal_burst(result.target as Node2D, result.packet)


func _on_incoming_result(result: DamageResult) -> void:
	if not _is_active(TalentCoreController.LEGENDARY_MASTER):
		return
	var source := result.packet.source
	if not is_instance_valid(source) or source == player:
		return
	var key := _attack_key(result.packet)
	var was_ai_guard := _pending_ai_guard
	_pending_ai_guard = false
	var analyzed := _is_attack_analyzed(source, key)
	if result.blocked and analyzed and _has_talent(&"calibrated_window") and not was_ai_guard:
		guard.reset_to_idle()
	if not result.perfect:
		return
	if _pending_master_counter != null:
		var counter_target := _pending_master_counter.get_ref() as Node2D
		_pending_master_counter = null
		if is_instance_valid(counter_target) and _has_line_of_sight(counter_target):
			call_deferred("_perform_master_counter", counter_target)
	if _pending_master_takeover:
		_pending_master_takeover = false
		_complete_takeover("代行拆招：致命窗口已接管")
	if not analyzed:
		return
	if _has_talent(&"refutation_reward") and not was_ai_guard:
		weapons.set_cooldown_remaining(0.0)
		_refutation_reward_remaining = 2.0
	if not was_ai_guard:
		core.add_run_metric(&"manual_perfect_guards")
		_record_relationship_event(TalentCoreController.LEGENDARY_MASTER)
	if _has_talent(&"open_model") and not was_ai_guard:
		_manual_validations += 1
		if _manual_validations >= 2:
			_manual_validations = 0
			health.repair(1)


func _on_deep_ninja_hit(enemy: EnemyController, result: DamageResult) -> void:
	var was_marked := _is_live_enemy(marked_target) and enemy == marked_target
	if not was_marked:
		_set_mark(enemy, true)
		_marked_hit_streak = 0
	if result.final_damage <= 0:
		return
	_marked_hit_streak += 1
	var enemy_id := enemy.get_instance_id()
	if _has_talent(&"read_opening") and Time.get_ticks_msec() >= int(_read_opening_cooldowns.get(enemy_id, 0)) and not result.target_defeated:
		_read_opening_cooldowns[enemy_id] = Time.get_ticks_msec() + 2000
		enemy.apply_stagger(0.65)
	if not result.target_defeated:
		return
	if not was_marked:
		_set_mark(_select_execution_target(enemy), true)
		return
	_marked_kill_streak += 1
	_recorded_marked_chain += 1
	core.maximize_run_metric(&"highest_marked_kill_chain", _recorded_marked_chain)
	_record_relationship_event(TalentCoreController.DEEP_NINJA)
	if _has_talent(&"blood_step"):
		dash.cooldown_remaining = 0.0
		_blood_step_remaining = 2.0
	if _has_talent(&"shared_hunt_resonance") and _marked_kill_streak >= 3:
		_marked_kill_streak = 0
		_resonance_remaining = 6.0
		_publish_notice(&"shared_hunt", "风林山火", Color(0.75, 0.35, 1.0))
	_set_mark(_select_execution_target(enemy), true)
	if _has_talent(&"ceaseless_hunt") and _is_live_enemy(marked_target):
		_prepare_hunt_path()


func _on_attack_performed(data: WeaponComponentData) -> void:
	if not _is_active(TalentCoreController.ROCK_VIGILANTE) or data == null:
		return
	if _performing_ai_attack:
		return
	var normalized_gain := _feedback_gain_for_weapon(data)
	core.add_run_metric(&"rock_attacks")
	if _encore_remaining <= 0.0:
		_set_rock_feedback(rock_feedback + normalized_gain * (2.0 if _seamless_free_attack else 1.0))
	_rock_decay_delay_remaining = ROCK_DECAY_DELAY
	if (
		_has_talent(&"dual_channel_performance")
		and not _last_attack_weapon_id.is_empty()
		and data.id != _last_attack_weapon_id
		and _alternate_attack_window > 0.0
	):
		weapons.set_cooldown_remaining(weapons.get_cooldown_remaining() * 0.7)
		for key_name in _weapon_cooldowns.keys():
			_weapon_cooldowns[key_name] = float(_weapon_cooldowns[key_name]) * 0.7
		_rock_decay_delay_remaining = 1.5
		_record_relationship_event(TalentCoreController.ROCK_VIGILANTE)
	_alternate_attack_window = 1.2
	_last_attack_weapon_id = data.id
	_seamless_switch_window = 1.2
	if (
		_has_talent(&"overload_scream")
		and _overload_ready
		and not _performing_ai_attack
		and not heat.is_overheated
		and heat.current_heat >= heat.effective_max() * 0.85
	):
		_overload_ready = false
		call_deferred("_perform_overload_scream")


func _on_weapon_changed(_index: int, data: WeaponComponentData) -> void:
	if _is_active(TalentCoreController.ROCK_VIGILANTE):
		if _has_talent(&"dual_channel_performance"):
			if not _last_weapon_id.is_empty():
				_weapon_cooldowns[String(_last_weapon_id)] = weapons.get_cooldown_remaining()
			if data != null:
				weapons.set_cooldown_remaining(float(_weapon_cooldowns.get(String(data.id), 0.0)))
				_rock_decay_delay_remaining = ROCK_DECAY_DELAY + 0.35
		if _has_talent(&"seamless_switch"):
			_seamless_free_attack = _seamless_switch_window > 0.0 and not _last_attack_weapon_id.is_empty() and data != null and data.id != _last_attack_weapon_id
	_last_weapon_id = data.id if data != null else &""


func _on_overheated() -> void:
	if _is_active(TalentCoreController.ROCK_VIGILANTE):
		_rock_overheat_had_feedback = rock_feedback >= 35.0
		if _encore_remaining > 0.0:
			_encore_remaining *= 0.35
			_set_rock_feedback(_encore_remaining / 2.0 * ROCK_FEEDBACK_MAX)
		else:
			_set_rock_feedback(rock_feedback * 0.35)


func _on_heat_recovered() -> void:
	if _is_active(TalentCoreController.ROCK_VIGILANTE) and _rock_overheat_had_feedback:
		_record_relationship_event(TalentCoreController.ROCK_VIGILANTE)
	_rock_overheat_had_feedback = false


func _record_attack_sample(source: Node, key: String) -> void:
	_observed_threat = weakref(source)
	_observed_attack_key = key
	var source_id := source.get_instance_id()
	var sample_key := "%d:%s" % [source_id, key]
	var count := int(_analysis_samples.get(sample_key, 0)) + 1
	_analysis_samples[sample_key] = count
	if count < MASTER_ANALYSIS_SAMPLES or _analyzed_attacks.has(sample_key):
		return
	_analyzed_attacks[sample_key] = true
	_analyzed_sources[source_id] = weakref(source)
	_publish_notice(&"attack_analyzed", "格物演算完成：下一次可拆招", Color(0.35, 0.9, 1.0))
	if _has_talent(&"master_loop"):
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate is EnemyController and _is_live_enemy(candidate) and player.global_position.distance_to(candidate.global_position) <= MASTER_AURA_RADIUS:
				candidate.apply_stagger(1.0)
		_master_loop_remaining = 4.0
	_emit_runtime_state()


func _attack_sample_count(source: Node, key: String) -> int:
	return int(_analysis_samples.get("%d:%s" % [source.get_instance_id(), key], 0))


func _is_attack_analyzed(source: Node, key: String) -> bool:
	return bool(_analyzed_attacks.get("%d:%s" % [source.get_instance_id(), key], false))


func _attack_key(packet: DamagePacket) -> String:
	var source_kind := packet.source.get_class() if is_instance_valid(packet.source) else "unknown"
	return "%s:%s:%s" % [source_kind, String(packet.damage_type), "melee" if packet.is_melee else "ranged"]


func _set_mark(target: EnemyController, trigger_gaze: bool = false) -> void:
	if marked_target == target:
		return
	marked_target = target
	_marked_hit_streak = 0
	_borrowed_step_target_id = 0
	if trigger_gaze and _is_live_enemy(marked_target) and _has_talent(&"gaze"):
		player.aim_direction = player.global_position.direction_to(marked_target.global_position)
		_gaze_remaining = 0.18
		_gaze_attack_pending = true
	queue_redraw()
	_emit_runtime_state()


func _select_execution_target(excluded: EnemyController = null) -> EnemyController:
	var best: EnemyController
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as EnemyController
		if enemy == null or enemy == excluded or not _is_live_enemy(enemy) or not _same_room(enemy):
			continue
		var health_ratio := float(enemy.health.current_health) / float(maxi(enemy.health.max_health, 1))
		var score := health_ratio * 1000.0 + player.global_position.distance_to(enemy.global_position)
		if enemy.state == EnemyController.State.STAGGERED:
			score -= 220.0
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _same_room(enemy: EnemyController) -> bool:
	return CombatProjectile.room_for_actor(enemy) == CombatProjectile.room_for_actor(player)


func _is_live_enemy(enemy: Variant) -> bool:
	# A typed Object parameter rejects an already-freed target before the function
	# body can call is_instance_valid(), which can happen for one HUD frame after
	# room cleanup. Accept Variant at this boundary, then narrow only when valid.
	if not is_instance_valid(enemy) or not enemy is EnemyController:
		return false
	var actor := enemy as EnemyController
	return (
		actor.is_inside_tree()
		and actor.health != null
		and not actor.health.is_dead()
		and actor.state not in [EnemyController.State.DEAD, EnemyController.State.SELF_DESTRUCT]
	)


func _set_rock_feedback(value: float) -> void:
	var previous := rock_feedback
	rock_feedback = clampf(value, 0.0, ROCK_FEEDBACK_MAX)
	core.maximize_run_metric(&"peak_rock_feedback", rock_feedback)
	if (
		previous < ROCK_FEEDBACK_MAX
		and rock_feedback >= ROCK_FEEDBACK_MAX
	):
		_record_relationship_event(TalentCoreController.ROCK_VIGILANTE)
		if _has_talent(&"encore_autopilot"):
			_encore_remaining = 2.0
			heat.set_overflow_enabled(true)
	_apply_attack_speed_modifier()
	if not is_equal_approx(previous, rock_feedback):
		_emit_runtime_state()


func _perform_overload_scream() -> void:
	if not _is_active(TalentCoreController.ROCK_VIGILANTE) or heat.is_overheated:
		return
	var current_weapon := weapons.get_current_weapon()
	if current_weapon != null and current_weapon.attack_kind == WeaponComponentData.AttackKind.MELEE:
		await get_tree().create_timer(current_weapon.melee_active_seconds, false, true).timeout
		if not _is_active(TalentCoreController.ROCK_VIGILANTE) or heat.is_overheated or heat.current_heat < heat.effective_max() * 0.85:
			return
	var target := _select_execution_target()
	_performing_ai_attack = true
	var fired := _is_live_enemy(target) and player.perform_persona_terminal_attack(player.global_position.direction_to(target.global_position))
	_performing_ai_attack = false
	if fired:
		heat.try_add_heat(heat.effective_max())


func _perform_ai_attack(direction: Vector2, forced: bool = false, damage_multiplier: float = 1.0) -> bool:
	if direction.is_zero_approx() or _performing_ai_attack:
		return false
	_performing_ai_attack = true
	var success := player.perform_persona_attack(direction, forced, damage_multiplier)
	_performing_ai_attack = false
	return success


func _on_takeover_armed_changed(armed: bool) -> void:
	if not armed:
		_pending_master_takeover = false
		return
	call_deferred("_try_execute_takeover")


func _try_execute_takeover() -> void:
	if not core.takeover_armed or not _has_active_persona() or health.is_dead():
		return
	match core.current_persona_id:
		TalentCoreController.DEEP_NINJA:
			_execute_deep_takeover()
		TalentCoreController.ROCK_VIGILANTE:
			_execute_rock_takeover()
		TalentCoreController.LEGENDARY_MASTER:
			_pending_master_takeover = true


func _execute_deep_takeover() -> void:
	if not _is_live_enemy(marked_target):
		_set_mark(_select_execution_target())
	if not _is_live_enemy(marked_target):
		return
	var landing := _find_safe_takeover_landing(marked_target)
	if landing.is_empty():
		return
	var origin := player.global_position
	# An emergency relocation can trigger during an ordinary or talent dash.
	# End that locked-direction motion before moving, otherwise the next physics
	# frame can drive the player back into a partition or narrow doorway.
	dash.cancel_dash(false)
	_cancel_soft_takeover()
	player.velocity = Vector2.ZERO
	_request_takeover_feedback(origin, landing.position, true)
	player.global_position = landing.position
	_request_takeover_feedback(origin, landing.position, false)
	player.aim_direction = player.global_position.direction_to(marked_target.global_position)
	hurt_box.set_invulnerable(0.8)
	_complete_takeover("夺身猎步：安全位移完成")


func _request_takeover_feedback(origin: Vector2, destination: Vector2, before_move: bool) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events == null:
		return
	var direction := origin.direction_to(destination)
	if before_move:
		events.request_movement_effect(player, &"ninja_takeover", &"start", origin, origin, direction)
		events.request_afterimage(player, player.visuals.body_sprite)
		return
	var previous := origin
	for index in range(1, 5):
		var point := origin.lerp(destination, float(index) / 4.0)
		events.request_movement_effect(player, &"ninja_takeover", &"path", previous, point, direction)
		previous = point
	events.request_movement_effect(player, &"ninja_takeover", &"end", destination, destination, direction)
	events.request_afterimage(player, player.visuals.body_sprite)


func _find_safe_takeover_landing(target: EnemyController) -> Dictionary:
	var enemy_facing := target.facing.normalized()
	if enemy_facing.is_zero_approx():
		enemy_facing = target.global_position.direction_to(player.global_position)
	if enemy_facing.is_zero_approx():
		enemy_facing = Vector2.RIGHT
	var preferred_direction := -enemy_facing
	for radius: float in TAKEOVER_LANDING_RADII:
		for angle: float in TAKEOVER_LANDING_ANGLES:
			var destination := target.global_position + preferred_direction.rotated(angle) * radius
			if _is_safe_takeover_landing(destination):
				return {"position": destination}
	return {}


func _is_safe_takeover_landing(destination: Vector2) -> bool:
	var room := CombatProjectile.room_for_actor(player)
	if room is CombatRoom and not (room as CombatRoom).contains_world_point(destination):
		return false
	var motion := destination - player.global_position
	if motion.is_zero_approx() or player.test_move(player.global_transform, motion, null, 0.08, true):
		return false
	var landing_transform := player.global_transform
	landing_transform.origin = destination
	var hazard_shape := CircleShape2D.new()
	hazard_shape.radius = dash.config.collision_radius
	var hazard_query := PhysicsShapeQueryParameters2D.new()
	hazard_query.shape = hazard_shape
	hazard_query.transform = landing_transform
	hazard_query.collision_mask = 16
	hazard_query.collide_with_areas = true
	hazard_query.collide_with_bodies = false
	for hit in player.get_world_2d().direct_space_state.intersect_shape(hazard_query, 32):
		var collider: Node = hit.collider
		if collider is FuelPatch or collider.is_in_group("hazards") or collider.is_in_group("traps"):
			return false
	var up_blocked := player.test_move(landing_transform, Vector2.UP * TAKEOVER_ESCAPE_PROBE, null, 0.08, true)
	var down_blocked := player.test_move(landing_transform, Vector2.DOWN * TAKEOVER_ESCAPE_PROBE, null, 0.08, true)
	var left_blocked := player.test_move(landing_transform, Vector2.LEFT * TAKEOVER_ESCAPE_PROBE, null, 0.08, true)
	var right_blocked := player.test_move(landing_transform, Vector2.RIGHT * TAKEOVER_ESCAPE_PROBE, null, 0.08, true)
	return not (up_blocked and down_blocked) and not (left_blocked and right_blocked)


func _execute_rock_takeover() -> void:
	var target := _select_execution_target()
	if not _is_live_enemy(target) or not _has_line_of_sight(target):
		return
	var direction := player.global_position.direction_to(target.global_position)
	if _perform_ai_attack(direction, true, 1.6):
		_complete_takeover("返场齐射：过热与冷却限制已旁路")


func _has_line_of_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target.global_position, 1)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _complete_takeover(message: String) -> void:
	if core.consume_takeover_after_success():
		_publish_notice(&"persona_takeover", message, Color(1.0, 0.45, 0.85), CombatNotice.Priority.HIGH, 2.2)


func _cancel_soft_takeover() -> void:
	if dash.is_dashing() and dash.active_effect_kind in [&"ninja_chase", &"ninja_borrowed_step"]:
		dash.cancel_dash(true)
	_gaze_remaining = 0.0
	_gaze_attack_pending = false
	_chase_remaining = 0.0
	_chase_path.clear()
	_chase_path_index = 0
	_master_loop_remaining = 0.0
	_borrowed_strike_target = null


func _on_enemy_attack_performed(source: Node, damage_type: StringName, is_melee: bool) -> void:
	if not _is_active(TalentCoreController.LEGENDARY_MASTER) or not source is Node2D:
		return
	var actor := source as Node2D
	if not _same_room_node(actor) or not _has_line_of_sight(actor):
		return
	var key := _attack_key_from_parts(source, damage_type, is_melee)
	var already_analyzed := _is_attack_analyzed(source, key)
	if already_analyzed and _has_talent(&"proxy_counter") and not bool(_proxy_counter_used.get(source.get_instance_id(), false)):
		_proxy_counter_armed[source.get_instance_id()] = true
	_record_attack_sample(source, key)


func get_attack_context(_data: WeaponComponentData) -> Dictionary:
	var context := {}
	var heat_multiplier := 1.0
	if _is_active(TalentCoreController.ROCK_VIGILANTE):
		if _has_talent(&"steady_beat"):
			heat_multiplier *= 0.75
		if _has_talent(&"distortion_gain") and rock_feedback >= 60.0:
			heat_multiplier *= 1.3
			context["distortion_bonus"] = true
		if _seamless_free_attack:
			heat_multiplier = 0.0
			context["seamless_free"] = true
		if _encore_remaining > 0.0:
			context["ignore_cooldown"] = true
			context["allow_overheat"] = true
			heat_multiplier = 2.0
	if _is_active(TalentCoreController.LEGENDARY_MASTER) and _refutation_reward_remaining > 0.0:
		heat_multiplier = 0.0
		context["refutation_bonus"] = true
	if _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0:
		heat_multiplier *= 0.75
		context["resonance_bonus"] = true
	context["heat_multiplier"] = heat_multiplier
	return context


func prepare_attack_group(group_id: int, context: Dictionary) -> void:
	_attack_group_contexts[group_id] = context.duplicate(true)
	_attack_group_targets[group_id] = {}
	while _attack_group_contexts.size() > 48:
		var oldest: Variant = _attack_group_contexts.keys()[0]
		_attack_group_contexts.erase(oldest)
		_attack_group_targets.erase(oldest)


func on_attack_committed(_data: WeaponComponentData, context: Dictionary, _group_id: int) -> void:
	if bool(context.get("seamless_free", false)):
		_seamless_free_attack = false
	if bool(context.get("refutation_bonus", false)):
		_refutation_reward_remaining = 0.0


func modify_outgoing_damage(packet: DamagePacket, target: Node, base_damage: int) -> int:
	if packet.weapon_id == &"karate_chop":
		return base_damage
	if packet.feedback_group_id <= 0:
		return base_damage + (1 if _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0 and dash.is_dashing() else 0)
	var context: Dictionary = _attack_group_contexts.get(packet.feedback_group_id, {})
	if context.is_empty() or not is_instance_valid(target):
		return base_damage
	var targets: Dictionary = _attack_group_targets.get(packet.feedback_group_id, {})
	var target_id := target.get_instance_id()
	if targets.has(target_id):
		return base_damage
	targets[target_id] = true
	_attack_group_targets[packet.feedback_group_id] = targets
	var bonus := 0
	bonus += 1 if bool(context.get("distortion_bonus", false)) else 0
	bonus += 1 if bool(context.get("refutation_bonus", false)) else 0
	bonus += 1 if bool(context.get("resonance_bonus", false)) else 0
	return base_damage + bonus


func should_ignore_damage(packet: DamagePacket) -> bool:
	return (
		packet != null
		and (packet.is_terrain_damage or packet.source_faction == CombatFaction.Id.ENVIRONMENT)
		and _is_active(TalentCoreController.DEEP_NINJA)
		and _resonance_remaining > 0.0
	)


func is_nuclear_frenzy_active() -> bool:
	return _is_active(TalentCoreController.ROCK_VIGILANTE) and _encore_remaining > 0.0


func _feedback_gain_for_current_weapon() -> float:
	return _feedback_gain_for_weapon(weapons.get_current_weapon())


func _feedback_gain_for_weapon_id(weapon_id: StringName) -> float:
	for data in weapons.weapons:
		if data != null and data.id == weapon_id:
			return _feedback_gain_for_weapon(data)
	return _feedback_gain_for_current_weapon()


func _feedback_gain_for_weapon(data: WeaponComponentData) -> float:
	if data == null:
		return 0.0
	return data.heat_per_attack / maxf(heat.effective_max(), 1.0) * ROCK_FEEDBACK_MAX


func _attack_key_from_parts(source: Node, damage_type: StringName, is_melee: bool) -> String:
	return "%s:%s:%s" % [source.get_class(), String(damage_type), "melee" if is_melee else "ranged"]


func _same_room_node(actor: Node) -> bool:
	return CombatProjectile.room_for_actor(actor) == CombatProjectile.room_for_actor(player)


func _perform_master_counter(target: Node2D) -> void:
	if _master_loop_remaining <= 0.0 or not is_instance_valid(target) or not _has_line_of_sight(target):
		return
	player.perform_persona_cooldown_free_attack(player.global_position.direction_to(target.global_position), 1.0)


func _apply_terminal_burst(center: Node2D, source_packet: DamagePacket) -> void:
	if not is_instance_valid(center):
		return
	var shape := CircleShape2D.new()
	shape.radius = 48.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center.global_position)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not is_instance_valid(hurt.actor) or seen.has(hurt.actor.get_instance_id()):
			continue
		seen[hurt.actor.get_instance_id()] = true
		var packet := DamagePacket.new()
		packet.base_damage = 1
		packet.source = player
		packet.source_faction = CombatFaction.Id.PLAYER
		packet.weapon_id = source_packet.weapon_id
		packet.damage_type = &"explosive"
		packet.source_position = center.global_position
		packet.is_area_damage = true
		packet.feedback_group_id = source_packet.feedback_group_id
		hurt.receive_hit(packet)


func _try_borrowed_step() -> void:
	var landing := _find_safe_takeover_landing(marked_target)
	if landing.is_empty():
		return
	var path := _build_hunt_path(Vector2(landing.position), 1)
	if path.size() != 2:
		return
	if dash.start_scripted_dash(player, path[1], &"ninja_borrowed_step"):
		_borrowed_step_target_id = marked_target.get_instance_id()
		_borrowed_strike_target = weakref(marked_target)


func _perform_karate_chop(target: EnemyController) -> void:
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source = player
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.weapon_id = &"karate_chop"
	packet.source_position = player.global_position
	packet.travel_direction = player.global_position.direction_to(target.global_position)
	packet.is_melee = true
	packet.stagger_seconds = 0.65
	var result := target.hurt_box.receive_hit(packet)
	if result.final_damage > 0 and not result.target_defeated:
		target.apply_stagger(0.65)


func _prepare_hunt_path() -> void:
	if not _is_live_enemy(marked_target):
		return
	var toward := player.global_position.direction_to(marked_target.global_position)
	var destination := marked_target.global_position - toward * 36.0
	_chase_path = _build_hunt_path(destination, HUNT_MAX_SEGMENTS)
	if _chase_path.size() < 2:
		_chase_path.clear()
		return
	_chase_path_index = 1
	_chase_remaining = HUNT_PREVIEW_SECONDS
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		for point in _chase_path:
			events.request_path_afterimage(player, player.visuals.body_sprite, point)


func _build_hunt_path(destination: Vector2, max_segments: int) -> PackedVector2Array:
	var maps := NavigationServer2D.get_maps()
	if maps.is_empty():
		return PackedVector2Array()
	var navigation_map: RID = maps[0]
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
		return PackedVector2Array()
	var closest := NavigationServer2D.map_get_closest_point(navigation_map, destination)
	var raw := NavigationServer2D.map_get_path(navigation_map, player.global_position, closest, true)
	if raw.size() < 2 or closest.distance_to(destination) > 12.0:
		return PackedVector2Array()
	var max_length := dash.config.dash_speed * dash.config.dash_duration * (1.0 + dash.equipment_speed_bonus)
	var result := PackedVector2Array([player.global_position])
	for index in range(1, raw.size()):
		var from: Vector2 = result[result.size() - 1]
		var to: Vector2 = raw[index]
		var distance := from.distance_to(to)
		var pieces := maxi(ceili(distance / maxf(max_length, 1.0)), 1)
		for piece in range(1, pieces + 1):
			result.append(from.lerp(to, float(piece) / pieces))
			if result.size() - 1 > max_segments:
				return PackedVector2Array()
	return result


func _execute_next_hunt_segment() -> void:
	if _chase_path_index >= _chase_path.size() or not _is_live_enemy(marked_target):
		_chase_path.clear()
		return
	var destination := _chase_path[_chase_path_index]
	_chase_path_index += 1
	if not dash.start_scripted_dash(player, destination, &"ninja_chase"):
		_chase_path.clear()


func _on_persona_changed(_persona_id: StringName) -> void:
	_cancel_soft_takeover()
	_encore_remaining = 0.0
	heat.set_overflow_enabled(false)
	_set_mark(null)
	_pending_master_takeover = false
	_pending_ai_guard = false
	_apply_persona_modifiers()
	if core.takeover_armed:
		call_deferred("_try_execute_takeover")


func _on_persona_level_changed(persona_id: StringName, _level: int) -> void:
	if persona_id == core.current_persona_id:
		_apply_persona_modifiers()


func _on_talent_build_changed(persona_id: StringName, _tier: int, _talent_id: StringName) -> void:
	if persona_id == core.current_persona_id:
		_apply_persona_modifiers()


func _apply_persona_modifiers() -> void:
	_apply_guard_modifier()
	_apply_attack_speed_modifier()


func _apply_guard_modifier() -> void:
	var wanted_guard_bonus := 0.04 if _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0 else 0.0
	guard.equipment_window_bonus += wanted_guard_bonus - _guard_bonus_applied
	_guard_bonus_applied = wanted_guard_bonus


func _apply_attack_speed_modifier() -> void:
	var wanted := 0.0
	if _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"distortion_gain") and rock_feedback >= 60.0:
		wanted = 0.30
	elif _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0:
		wanted = 0.25
	weapons.attack_speed_multiplier += wanted - _attack_speed_bonus_applied
	_attack_speed_bonus_applied = wanted


func _clear_temporary_modifiers() -> void:
	guard.equipment_window_bonus -= _guard_bonus_applied
	weapons.attack_speed_multiplier -= _attack_speed_bonus_applied
	dash.equipment_speed_bonus -= _dash_speed_bonus_applied
	_guard_bonus_applied = 0.0
	_attack_speed_bonus_applied = 0.0
	_dash_speed_bonus_applied = 0.0
	_blood_step_remaining = 0.0
	_resonance_remaining = 0.0


func _has_active_persona() -> bool:
	return is_instance_valid(core) and core.get_persona_level(core.current_persona_id) > 0


func _is_active(persona_id: StringName) -> bool:
	return _has_active_persona() and core.current_persona_id == persona_id


func _has_talent(talent_id: StringName) -> bool:
	return talent_id in core.get_active_talents()


func _record_relationship_event(persona_id: StringName) -> void:
	if not core.record_relationship_event(persona_id):
		return
	var stage := core.get_relationship_stage(persona_id)
	var lines := {
		TalentCoreController.DEEP_NINJA: [
			"下一道猎痕，我会替你提前半步。",
			"别再分你我。我们正用同一具身体狩猎。",
		],
		TalentCoreController.LEGENDARY_MASTER: [
			"你的修正已进入我的模型。继续。",
			"不必等我报出窗口。你已经知道我会如何拆解。",
		],
		TalentCoreController.ROCK_VIGILANTE: [
			"这次换台踩在拍子上了。再来一轮。",
			"别把线路交给我——现在它本来就是我们的。",
		],
	}
	var persona_lines: Array = lines.get(persona_id, [])
	if stage <= 0 or stage > persona_lines.size():
		return
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_operator_communication(String(persona_lines[stage - 1]))


func _publish_notice(
	id: StringName,
	text: String,
	color: Color,
	priority: CombatNotice.Priority = CombatNotice.Priority.NORMAL,
	display_seconds: float = 1.5
) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(id, text, color, priority, 0.15, display_seconds)


func _emit_runtime_state() -> void:
	runtime_state_changed.emit(get_runtime_snapshot())


func _exit_tree() -> void:
	_clear_temporary_modifiers()
