class_name PersonaCombatController
extends Node2D

signal runtime_state_changed(state: Dictionary)
signal manual_perfect_guarded

const MARK_REFRESH_SECONDS := 0.25
const ROCK_FEEDBACK_MAX := 100.0
const ROCK_FEEDBACK_DECAY := 18.0
const ROCK_DECAY_DELAY := 0.65
const ROCK_MOVE_SPEED_BONUS_MAX := 0.20
const ROCK_ENERGY_RECOVERY_BONUS_MAX := 0.25
const ROCK_ATTACK_SPEED_BONUS_MAX := 0.30
const ROCK_DISTORTION_THRESHOLD := 60.0
const ROCK_DISTORTION_RADIUS := 48.0
const ROCK_OVERLOAD_RADIUS := 96.0
const ROCK_OVERLOAD_INTERVAL := 1.0
const ROCK_ENCORE_SECONDS := 4.0
const MASTER_ANALYSIS_SECONDS := 2.0
const MASTER_ANALYSIS_SAMPLES := 2
const MASTER_LOOP_SECONDS := 6.0
const MASTER_LOOP_PLAYER_INPUT_SECONDS := 3.0
const TAKEOVER_LANDING_RADII := [96.0, 80.0, 64.0, 48.0]
const TAKEOVER_LANDING_ANGLES := [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]
const TAKEOVER_ESCAPE_PROBE := 14.0
const HUNT_TRIGGER_DISTANCE := 40.0
const HUNT_MAX_SEGMENTS := 3
const HUNT_CHAIN_WINDOW := 0.6
const HUNT_PATH_REFRESH := 0.1
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
var _gaze_used_targets: Dictionary = {}
var _chase_path: PackedVector2Array = []
var _hunt_refresh_remaining := 0.0
var _hunt_segments := 0
var _hunt_window := 0.0
var _hunt_pending_refresh := false
var _hunt_cancel_pending := false
var _hunt_last_direction := Vector2.ZERO
var _borrowed_step_target_id := 0
var _borrowed_step_near := false
var _next_circuit_speed := 1.0
var _next_circuit_damage_bonus := 0
var _next_circuit_copy := false
var _counter_window_remaining := 0.0
var _read_opening_rounds: Dictionary = {}
var _borrowed_strike_target: WeakRef
var _resonance_remaining := 0.0
var _blood_step_remaining := 0.0
var _dash_speed_bonus_applied := 0.0

var _rock_decay_delay_remaining := 0.0
var _encore_remaining := 0.0
var _seamless_free_attack := false
var _seamless_switch_window := 0.0
var _alternate_attack_window := 0.0
var _overload_pulse_remaining := 0.0
var _performing_ai_attack := false
var _weapon_cooldowns: Dictionary = {}
var _last_weapon_id: StringName = &""
var _last_attack_weapon_id: StringName = &""
var _rock_alternations := 0
var _rock_overheat_had_feedback := false
var _feedback_hit_groups: Dictionary = {}
var _last_feedback_round_token := 0
var _attack_group_contexts: Dictionary = {}
var _attack_group_targets: Dictionary = {}
var _distortion_burst_groups: Dictionary = {}
var _terminal_burst_groups: Dictionary = {}
var _refutation_reward_remaining := 0.0

var _analysis_progress: Dictionary = {}
var _analyzed_attacks: Dictionary = {}
var _analyzed_sources: Dictionary = {}
var _proxy_counter_used: Dictionary = {}
var _proxy_counter_armed: Dictionary = {}
var _manual_validations := 0
var _pending_master_takeover := false
var _pending_ai_guard := false
var _ai_guard_active := false
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
	dash.dash_ended.connect(_on_hunt_dash_ended)


func _physics_process(delta: float) -> void:
	_tick_temporary_bonuses(delta)
	if not _has_active_persona() or health.is_dead():
		return
	match core.current_persona_id:
		TalentCoreController.DEEP_NINJA:
			_tick_deep_ninja(delta)
		TalentCoreController.LEGENDARY_MASTER:
			_tick_master_analysis(delta)
		TalentCoreController.ROCK_VIGILANTE:
			_tick_rock_vigilante(delta)
	queue_redraw()


func _draw() -> void:
	if _is_active(TalentCoreController.DEEP_NINJA) and _has_talent(&"ceaseless_hunt") and _chase_path.size() > 1:
		var heading := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if heading.is_zero_approx():
			heading = player.aim_direction
		var ready := dash.cooldown_remaining <= 0.0 and heading.dot(_hunt_direction()) > 0.0
		var glow := 0.75 if ready else 0.27
		var reduced_flashes := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
		var pulse := 0.0 if reduced_flashes else float(Time.get_ticks_msec() % 800) / 800.0
		for index in range(1, _chase_path.size()):
			var a := to_local(_chase_path[index - 1])
			var b := to_local(_chase_path[index])
			draw_line(a, b, Color(0.22, 0.01, 0.04, glow * 0.7), 8.0, true)
			draw_line(a, b, Color(1.0, 0.12, 0.2, glow), 2.5, true)
			if not reduced_flashes and fposmod(float(index) * 0.23 - pulse, 1.0) < 0.18:
				draw_line(a.lerp(b, 0.35), a.lerp(b, 0.65), Color(1.0, 0.38, 0.55, glow), 3.5, true)
		draw_arc(to_local(_chase_path[_chase_path.size() - 1]), 7.0, 0.0, TAU, 16, Color(1.0, 0.16, 0.28, glow), 1.5, true)
	if _is_active(TalentCoreController.DEEP_NINJA) and _is_live_enemy(marked_target):
		var center := to_local(marked_target.global_position + Vector2(0.0, -10.0))
		draw_arc(center, 15.0, 0.0, TAU, 28, Color(0.75, 0.25, 1.0, 0.9), 2.0, true)
		draw_line(center + Vector2(-5.0, 0.0), center + Vector2(5.0, 0.0), Color(0.95, 0.65, 1.0), 1.0)
	if not _is_active(TalentCoreController.LEGENDARY_MASTER) or not _has_talent(&"open_model"):
		return
	for source_ref: WeakRef in _analyzed_sources.values():
		var source := source_ref.get_ref() as Node2D
		if not _is_live_analysis_target(source) or not _same_room_node(source):
			continue
		var from := to_local(source.global_position + Vector2(0.0, -10.0))
		var to := to_local(player.global_position + Vector2(0.0, -10.0))
		var warning: bool = source is EnemyController and source.state == EnemyController.State.WINDUP
		draw_dashed_line(from, to, Color(0.35, 0.95, 1.0, 0.9 if warning else 0.28), 2.0 if warning else 1.0, 5.0)
		if warning:
			draw_circle(to, 8.0, Color(0.35, 0.95, 1.0, 0.16), false, 1.5)
			var eta := maxf(float(source.get("_windup_remaining")), 0.0) if source is EnemyController else 0.0
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
		if _master_loop_remaining > 0.0:
			_master_loop_remaining = minf(_master_loop_remaining, MASTER_LOOP_PLAYER_INPUT_SECONDS)
		_cancel_soft_takeover(false)


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
	if guard.state in [GuardComponent.State.STARTUP, GuardComponent.State.PERFECT, GuardComponent.State.NORMAL]:
		return false
	var source_id := source.get_instance_id()
	var emergency := core.takeover_armed and core.takeover_charges > 0
	var aura_perfect := _master_loop_remaining > 0.0 and _master_loop_interval <= 0.0 and analyzed
	var proxy_perfect := _has_talent(&"proxy_counter") and analyzed and bool(_proxy_counter_armed.get(source_id, false)) and not bool(_proxy_counter_used.get(source_id, false))
	var proxy_normal := _has_talent(&"proxy_stance") and analyzed
	if not emergency and not aura_perfect and not proxy_perfect and not proxy_normal:
		return false
	var toward_source := packet.source_position - player.global_position
	if toward_source.is_zero_approx() and not packet.travel_direction.is_zero_approx():
		toward_source = -packet.travel_direction
	if guard.state == GuardComponent.State.RECOVERY:
		guard.reset_to_idle()
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
	if proxy_perfect or aura_perfect:
		_pending_master_counter = weakref(source)
	_pending_ai_guard = true
	_ai_guard_active = true
	if emergency:
		_pending_master_takeover = true
	return true


func reset_transient_state() -> void:
	_set_mark(null)
	_gaze_used_targets.clear()
	_read_opening_rounds.clear()
	_next_circuit_speed = 1.0
	_next_circuit_damage_bonus = 0
	_next_circuit_copy = false
	_counter_window_remaining = 0.0
	_clear_hunt_chain(false)
	rock_feedback = 0.0
	_marked_hit_streak = 0
	_marked_kill_streak = 0
	_recorded_marked_chain = 0
	_analysis_progress.clear()
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
	_ai_guard_active = false
	_weapon_cooldowns.clear()
	_seamless_free_attack = false
	_overload_pulse_remaining = 0.0
	_last_attack_weapon_id = &""
	_rock_alternations = 0
	_rock_overheat_had_feedback = false
	_encore_remaining = 0.0
	heat.set_overflow_enabled(false)
	_feedback_hit_groups.clear()
	_last_feedback_round_token = 0
	_attack_group_contexts.clear()
	_attack_group_targets.clear()
	_distortion_burst_groups.clear()
	_terminal_burst_groups.clear()
	_refutation_reward_remaining = 0.0
	_cancel_soft_takeover()
	_clear_temporary_modifiers()
	_apply_persona_modifiers()
	_emit_runtime_state()


func get_runtime_snapshot() -> Dictionary:
	var threat := _observed_threat.get_ref() as Node if _observed_threat != null else null
	var threat_live := _is_live_analysis_target(threat) and _same_room_node(threat)
	var samples := _analysis_display_progress(threat) if threat_live else 0.0
	var rock_ratio := _rock_feedback_ratio()
	return {
		"persona_id": String(core.current_persona_id) if is_instance_valid(core) else "",
		"marked_target_id": marked_target.get_instance_id() if _is_live_enemy(marked_target) else 0,
		"rock_feedback": rock_feedback,
		"analyzed_attack_count": _analyzed_attacks.size(),
		"prediction_source_count": _analyzed_sources.size(),
		"soft_takeover_active": _gaze_remaining > 0.0 or _master_loop_remaining > 0.0,
		"blood_step_remaining": _blood_step_remaining,
		"resonance_remaining": _resonance_remaining,
		"gaze_active": _gaze_remaining > 0.0,
		"chase_active": _hunt_segments > 0,
		"analysis_has_threat": threat_live,
		"analysis_samples": minf(samples, MASTER_ANALYSIS_SECONDS),
		"analysis_required": MASTER_ANALYSIS_SECONDS,
		"guard_window_active": _guard_bonus_applied > 0.0,
		"ai_guard_active": _pending_ai_guard and guard.is_guard_active(),
		"master_loop_remaining": _master_loop_remaining,
		"master_takeover_pending": _pending_master_takeover,
		"seamless_free_attack": can_queue_seamless(),
		"encore_remaining": _encore_remaining,
		"rock_move_bonus_percent": rock_ratio * ROCK_MOVE_SPEED_BONUS_MAX * 100.0,
		"rock_energy_recovery_bonus_percent": rock_ratio * ROCK_ENERGY_RECOVERY_BONUS_MAX * 100.0,
		"rock_attack_speed_bonus_percent": rock_ratio * ROCK_ATTACK_SPEED_BONUS_MAX * 100.0,
		"distortion_active": _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"distortion_gain") and rock_feedback >= ROCK_DISTORTION_THRESHOLD,
		"overload_scream_active": _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"overload_scream") and rock_feedback >= ROCK_DISTORTION_THRESHOLD,
	}


func _tick_deep_ninja(delta: float) -> void:
	_mark_refresh_remaining = maxf(_mark_refresh_remaining - delta, 0.0)
	if not _is_live_enemy(marked_target) and _mark_refresh_remaining <= 0.0:
		_mark_refresh_remaining = MARK_REFRESH_SECONDS
		# Entering a room may establish an initial hunt mark, but that is not a
		# combat event and must not make Gaze fire as soon as the scene loads.
		_set_mark(_select_execution_target(), false)
	_gaze_remaining = maxf(_gaze_remaining - delta, 0.0)
	if _gaze_attack_pending and _gaze_remaining <= 0.0 and _is_live_enemy(marked_target) and weapons.get_cooldown_remaining() <= 0.0:
		_gaze_attack_pending = false
		player.cyberware.submit_weapon_fire(player.global_position.direction_to(marked_target.global_position), weapons.get_current_weapon())
	_hunt_refresh_remaining -= delta
	if _has_talent(&"ceaseless_hunt") and _hunt_refresh_remaining <= 0.0:
		_hunt_refresh_remaining = HUNT_PATH_REFRESH
		_prepare_hunt_path()
	if _hunt_window > 0.0 and not dash.is_dashing():
		_hunt_window = maxf(_hunt_window - delta, 0.0)
		if _hunt_window <= 0.0:
			_clear_hunt_chain()
	if _borrowed_strike_target != null and not dash.is_dashing():
		var strike_target := _borrowed_strike_target.get_ref() as EnemyController
		_borrowed_strike_target = null
		if _is_live_enemy(strike_target) and player.global_position.distance_to(strike_target.global_position) <= 48.0:
			_perform_karate_chop(strike_target)
	var near_mark := _has_talent(&"borrowed_step") and _is_live_enemy(marked_target) and player.global_position.distance_to(marked_target.global_position) <= HUNT_TRIGGER_DISTANCE
	if near_mark and not _borrowed_step_near:
		weapons.set_cooldown_remaining(0.0)
		_next_circuit_speed = 0.85
		_next_circuit_damage_bonus = 1
	_borrowed_step_near = near_mark


func _tick_rock_vigilante(delta: float) -> void:
	_rock_decay_delay_remaining = maxf(_rock_decay_delay_remaining - delta, 0.0)
	_seamless_switch_window = maxf(_seamless_switch_window - delta, 0.0)
	_alternate_attack_window = maxf(_alternate_attack_window - delta, 0.0)
	_refutation_reward_remaining = maxf(_refutation_reward_remaining - delta, 0.0)
	if _encore_remaining > 0.0:
		_encore_remaining = maxf(_encore_remaining - delta, 0.0)
		_set_rock_feedback(_encore_remaining / ROCK_ENCORE_SECONDS * ROCK_FEEDBACK_MAX)
		if _encore_remaining <= 0.0:
			weapons.set_cooldown_remaining(0.0)
	elif _rock_decay_delay_remaining <= 0.0 and rock_feedback > 0.0:
		var decay := ROCK_FEEDBACK_DECAY
		_set_rock_feedback(rock_feedback - decay * delta)
	_overload_pulse_remaining = maxf(_overload_pulse_remaining - delta, 0.0)


func _tick_master_analysis(delta: float) -> void:
	var visible_targets: Array[Node2D] = []
	var unresolved_targets: Array[Node2D] = []
	var completed_targets: Array[Node2D] = []
	var live_ids := {}
	for candidate in get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"bosses"):
		var target := candidate as Node2D
		if not _is_live_analysis_target(target) or not _same_room_node(target):
			continue
		var target_id := target.get_instance_id()
		live_ids[target_id] = true
		if not _is_in_player_view(target) or not _has_line_of_sight(target):
			if not _analyzed_sources.has(target_id):
				_analysis_progress[target_id] = 0.0
			continue
		visible_targets.append(target)
		if _analyzed_sources.has(target_id):
			continue
		unresolved_targets.append(target)
		var progress := minf(float(_analysis_progress.get(target_id, 0.0)) + delta, MASTER_ANALYSIS_SECONDS)
		_analysis_progress[target_id] = progress
		if progress >= MASTER_ANALYSIS_SECONDS:
			_analyzed_attacks[target_id] = true
			_analyzed_sources[target_id] = weakref(target)
			completed_targets.append(target)
	for target_id in _analysis_progress.keys():
		if not live_ids.has(target_id):
			_analysis_progress.erase(target_id)
	if not completed_targets.is_empty():
		_publish_notice(&"attack_analyzed", "看透了。接下来可以拆招。", Color(0.35, 0.9, 1.0))
		_trigger_master_loop_once()
	_observed_threat = null
	var display_target := _nearest_analysis_target(unresolved_targets)
	if display_target == null:
		display_target = _nearest_analysis_target(visible_targets)
	if display_target != null:
		_observed_threat = weakref(display_target)
		_observed_attack_key = ""
	_emit_runtime_state()


func _nearest_analysis_target(targets: Array[Node2D]) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for target in targets:
		var distance := player.global_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _trigger_master_loop_once() -> void:
	if not _has_talent(&"master_loop"):
		return
	for candidate in get_tree().get_nodes_in_group(&"enemies"):
		if candidate is EnemyController and _is_live_enemy(candidate) and player.global_position.distance_to(candidate.global_position) <= MASTER_AURA_RADIUS:
			candidate.apply_stagger(1.0)
	_master_loop_remaining = MASTER_LOOP_PLAYER_INPUT_SECONDS if _is_player_control_held() else MASTER_LOOP_SECONDS


func _is_player_control_held() -> bool:
	for action in [&"attack", &"guard", &"mobility_ability", &"weapon_switch", &"weapon_next", &"weapon_previous", &"move_left", &"move_right", &"move_up", &"move_down"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


func circuit_energy_multiplier() -> float:
	return 0.75 if _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0 else 1.0


func can_attack_during_guard() -> bool:
	return _is_active(TalentCoreController.LEGENDARY_MASTER) and _has_talent(&"calibrated_window") and _counter_window_remaining > 0.0


func has_stable_beat() -> bool:
	return _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"steady_beat")


func can_queue_seamless() -> bool:
	return _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"seamless_switch") and _seamless_switch_window > 0.0


func should_submit_dash_event() -> bool:
	return true


func has_hunt_chain() -> bool:
	return _hunt_segments > 0


func try_start_player_dash(movement: Vector2) -> bool:
	if dash.is_dashing():
		return false
	var chaining := _hunt_segments > 0 and _hunt_window > 0.0
	if chaining:
		dash.cooldown_remaining = 0.0
	elif dash.cooldown_remaining > 0.0:
		return false
	var heading := movement if not movement.is_zero_approx() else player.aim_direction
	var qualified := _is_active(TalentCoreController.DEEP_NINJA) and _has_talent(&"ceaseless_hunt") and _is_live_enemy(marked_target) and not _chase_path.is_empty() and heading.dot(_hunt_direction()) > 0.0
	if not qualified and chaining:
		_clear_hunt_chain()
		dash.cooldown_remaining = 0.0
	var started := dash.start_dash(player, player.aim_direction, movement, &"ninja_hunt" if qualified else &"dash")
	if started and qualified:
		_hunt_segments += 1
		_hunt_window = 0.0
		# The group pays its cooldown when the last segment or input window ends.
		dash.cooldown_remaining = 0.0
	return started


func cancel_hunt_followups() -> void:
	if _hunt_segments > 0:
		if dash.is_dashing():
			_hunt_cancel_pending = true
		else:
			_clear_hunt_chain()


func _on_hunt_dash_ended(cancelled: bool) -> void:
	if _hunt_segments <= 0:
		return
	if cancelled or _hunt_cancel_pending or _hunt_segments >= HUNT_MAX_SEGMENTS or not _is_live_enemy(marked_target):
		_clear_hunt_chain()
	else:
		_hunt_window = HUNT_CHAIN_WINDOW


func _clear_hunt_chain(apply_cooldown: bool = true) -> void:
	if _hunt_segments > 0 and apply_cooldown:
		dash.cooldown_remaining = 0.0 if _hunt_pending_refresh else dash.config.dash_cooldown
	elif _hunt_segments > 0:
		dash.cooldown_remaining = 0.0
	_hunt_segments = 0
	_hunt_window = 0.0
	_hunt_pending_refresh = false
	_hunt_cancel_pending = false
	if not apply_cooldown:
		_hunt_last_direction = Vector2.ZERO


func take_circuit_talent_effects() -> Dictionary:
	var effects := {"speed": _next_circuit_speed, "damage_bonus": _next_circuit_damage_bonus, "copy_first": _next_circuit_copy, "dual_channel": _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"dual_channel_performance")}
	_next_circuit_speed = 1.0
	_next_circuit_damage_bonus = 0
	_next_circuit_copy = false
	return effects


func on_circuit_attack_emitted(from_overload_wave: bool = false) -> void:
	if not from_overload_wave and _is_active(TalentCoreController.ROCK_VIGILANTE) and _has_talent(&"overload_scream") and rock_feedback >= ROCK_DISTORTION_THRESHOLD and _overload_pulse_remaining <= 0.0:
		_perform_overload_pulse()
		_overload_pulse_remaining = ROCK_OVERLOAD_INTERVAL


func _tick_temporary_bonuses(delta: float) -> void:
	if guard.state == GuardComponent.State.IDLE:
		_ai_guard_active = false
	_counter_window_remaining = maxf(_counter_window_remaining - delta, 0.0)
	_master_loop_remaining = maxf(_master_loop_remaining - delta, 0.0)
	_master_loop_interval = maxf(_master_loop_interval - delta, 0.0)
	_blood_step_remaining = maxf(_blood_step_remaining - delta, 0.0)
	_resonance_remaining = maxf(_resonance_remaining - delta, 0.0)
	var wanted_dash_bonus := (0.2 if _blood_step_remaining > 0.0 else 0.0) + (0.2 if _resonance_remaining > 0.0 else 0.0)
	if not is_equal_approx(wanted_dash_bonus, _dash_speed_bonus_applied):
		dash.equipment_speed_bonus += wanted_dash_bonus - _dash_speed_bonus_applied
		_dash_speed_bonus_applied = wanted_dash_bonus
	_apply_guard_modifier()
	_apply_rock_feedback_modifiers()


func _on_damage_resolved(result: DamageResult) -> void:
	if result == null or result.packet == null:
		return
	if result.target == player:
		_on_incoming_result(result)
		return
	if result.packet.source != player or not is_instance_valid(result.target) or not result.target is Node2D:
		return
	if _is_active(TalentCoreController.DEEP_NINJA):
		if result.target is EnemyController:
			_on_deep_ninja_hit(result.target as EnemyController, result)
	elif _is_active(TalentCoreController.ROCK_VIGILANTE) and result.final_damage > 0:
		var group_id := result.packet.feedback_group_id
		var feedback_key := "group:%d" % group_id
		var has_round_tag := false
		for tag in result.packet.status_tags:
			if String(tag).begins_with("circuit_round:"):
				feedback_key = String(tag)
				has_round_tag = true
				break
		if (group_id > 0 or has_round_tag) and not _feedback_hit_groups.has(feedback_key) and _encore_remaining <= 0.0:
			_feedback_hit_groups[feedback_key] = true
			_set_rock_feedback(rock_feedback + _feedback_gain_for_weapon_id(result.packet.weapon_id))
			_rock_decay_delay_remaining = 1.5 if _has_talent(&"steady_beat") else ROCK_DECAY_DELAY
			while _feedback_hit_groups.size() > 64:
				_feedback_hit_groups.erase(_feedback_hit_groups.keys()[0])
		_try_distortion_burst(result.target as Node2D, result.packet)
	if result.final_damage > 0 and result.packet.terminal_attack and not _terminal_burst_groups.has(result.packet.feedback_group_id):
		_terminal_burst_groups[result.packet.feedback_group_id] = true
		_apply_terminal_burst(result.target as Node2D, result.packet)


func _on_incoming_result(result: DamageResult) -> void:
	var was_ai_guard := _pending_ai_guard or _ai_guard_active
	_pending_ai_guard = false
	if result.perfect and not was_ai_guard:
		manual_perfect_guarded.emit()
	if not _is_active(TalentCoreController.LEGENDARY_MASTER):
		return
	var source := result.packet.source
	if not is_instance_valid(source) or source == player:
		return
	var key := _attack_key(result.packet)
	var analyzed := _is_attack_analyzed(source, key)
	if result.blocked and analyzed and _has_talent(&"calibrated_window") and not was_ai_guard:
		_counter_window_remaining = 0.8
		guard.skip_next_recovery = true
	if result.blocked and analyzed and _has_talent(&"open_model") and not was_ai_guard:
		player.cyberware.flush_active_round_after_guard(source as Node2D)
	if not result.perfect:
		return
	if _pending_master_counter != null:
		var counter_target := _pending_master_counter.get_ref() as Node2D
		_pending_master_counter = null
		if is_instance_valid(counter_target) and _has_line_of_sight(counter_target):
			call_deferred("_perform_master_counter", counter_target)
	if _pending_master_takeover:
		_pending_master_takeover = false
		_complete_takeover("已自动格挡致命攻击")
	if not analyzed:
		return
	if _has_talent(&"refutation_reward") and not was_ai_guard:
		_next_circuit_copy = true
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
	if _has_talent(&"read_opening") and Time.get_ticks_msec() >= int(_read_opening_cooldowns.get(enemy_id, 0)):
		_read_opening_cooldowns[enemy_id] = Time.get_ticks_msec() + 2000
		if not result.target_defeated:
			enemy.apply_stagger(0.65)
		for tag in result.packet.status_tags:
			if String(tag).begins_with("circuit_round:") and not _read_opening_rounds.has(tag):
				_read_opening_rounds[tag] = true
				player.cyberware.circuit.add_energy(15.0)
				break
		while _read_opening_rounds.size() > 64:
			_read_opening_rounds.erase(_read_opening_rounds.keys()[0])
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
		if _hunt_segments > 0:
			_hunt_pending_refresh = true
		else:
			dash.cooldown_remaining = 0.0
		_blood_step_remaining = 2.0
		_next_circuit_speed = 0.7
	if _has_talent(&"shared_hunt_resonance") and _marked_kill_streak >= 3:
		_marked_kill_streak = 0
		_resonance_remaining = 6.0
		_publish_notice(&"shared_hunt", "风林山火", Color(0.75, 0.35, 1.0))
	_set_mark(_select_execution_target(enemy), true)
	_hunt_refresh_remaining = 0.0


func _on_attack_performed(data: WeaponComponentData) -> void:
	if not _is_active(TalentCoreController.ROCK_VIGILANTE) or data == null:
		return
	if _performing_ai_attack:
		return
	var round_token := player.cyberware.get_active_round_token()
	if round_token > 0 and round_token == _last_feedback_round_token:
		return
	_last_feedback_round_token = round_token
	var normalized_gain := _feedback_gain_for_weapon(data)
	core.add_run_metric(&"rock_attacks")
	if _encore_remaining <= 0.0:
		_set_rock_feedback(rock_feedback + normalized_gain * (2.0 if _has_talent(&"seamless_switch") and _seamless_switch_window > 0.0 else 1.0))
	_rock_decay_delay_remaining = ROCK_DECAY_DELAY
	_alternate_attack_window = 1.2
	_last_attack_weapon_id = data.id
	_seamless_switch_window = 1.2


func _on_weapon_changed(_index: int, data: WeaponComponentData) -> void:
	_last_weapon_id = data.id if data != null else &""


func _on_overheated() -> void:
	pass


func _on_heat_recovered() -> void:
	if _is_active(TalentCoreController.ROCK_VIGILANTE) and _rock_overheat_had_feedback:
		_record_relationship_event(TalentCoreController.ROCK_VIGILANTE)
	_rock_overheat_had_feedback = false
	_overload_pulse_remaining = 0.0


func _analysis_display_progress(source: Node) -> float:
	if not is_instance_valid(source):
		return 0.0
	var source_id := source.get_instance_id()
	if _analyzed_sources.has(source_id):
		return MASTER_ANALYSIS_SECONDS
	return float(_analysis_progress.get(source_id, 0.0))


func _is_attack_analyzed(source: Node, _key: String) -> bool:
	return is_instance_valid(source) and _analyzed_sources.has(source.get_instance_id())


func _attack_key(packet: DamagePacket) -> String:
	var source_kind := packet.source.get_class() if is_instance_valid(packet.source) else "unknown"
	return "%s:%s:%s" % [source_kind, String(packet.damage_type), "melee" if packet.is_melee else "ranged"]


func _set_mark(target: EnemyController, trigger_gaze: bool = false) -> void:
	if marked_target == target:
		return
	marked_target = target
	_hunt_refresh_remaining = 0.0
	if _has_talent(&"ceaseless_hunt") and _is_live_enemy(target):
		_prepare_hunt_path()
	elif target == null:
		_chase_path.clear()
	_marked_hit_streak = 0
	_borrowed_step_target_id = 0
	_borrowed_step_near = false
	if trigger_gaze and _is_live_enemy(marked_target) and _has_talent(&"gaze") and not _gaze_used_targets.has(marked_target.get_instance_id()):
		_gaze_used_targets[marked_target.get_instance_id()] = true
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
			_encore_remaining = ROCK_ENCORE_SECONDS
	_apply_rock_feedback_modifiers()
	if not is_equal_approx(previous, rock_feedback):
		_emit_runtime_state()


func _tick_overload_scream(delta: float) -> void:
	_overload_pulse_remaining = maxf(_overload_pulse_remaining - delta, 0.0)


func _perform_overload_pulse() -> void:
	if not _is_active(TalentCoreController.ROCK_VIGILANTE) or not _has_talent(&"overload_scream") or rock_feedback < ROCK_DISTORTION_THRESHOLD:
		return
	var shape := CircleShape2D.new()
	shape.radius = ROCK_OVERLOAD_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, player.global_position)
	query.collision_mask = 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 128):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not _is_live_hostile_target(hurt.actor):
			continue
		var target := hurt.actor as Node2D
		var target_id := target.get_instance_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		var packet := DamagePacket.new()
		packet.base_damage = 1
		packet.source = player
		packet.source_faction = CombatFaction.Id.PLAYER
		packet.weapon_id = &"overload_scream"
		packet.damage_type = &"sonic"
		packet.source_position = player.global_position
		packet.travel_direction = player.global_position.direction_to(target.global_position)
		packet.status_tags = PackedStringArray(["rock_overload_wave", "event_path:过载嘶鸣"])
		packet.is_area_damage = true
		var result := hurt.receive_hit(packet)
		if result.final_damage > 0 and target.has_method("apply_stagger"):
			target.apply_stagger(0.35)
	_request_rock_wave(player.global_position, ROCK_OVERLOAD_RADIUS, 0.25, Color("ffe34a"))


func _try_distortion_burst(primary_target: Node2D, source_packet: DamagePacket) -> void:
	var round_key := "group:%d" % source_packet.feedback_group_id
	for tag in source_packet.status_tags:
		if String(tag).begins_with("circuit_round:"):
			round_key = String(tag)
			break
	if source_packet.feedback_group_id <= 0 and not source_packet.status_tags.has("calamity_swing"):
		return
	if int(_distortion_burst_groups.get(round_key, 0)) >= 3:
		return
	var context: Dictionary = _attack_group_contexts.get(source_packet.feedback_group_id, {})
	var calamity_distortion := source_packet.status_tags.has("calamity_swing") and _has_talent(&"distortion_gain") and rock_feedback >= ROCK_DISTORTION_THRESHOLD
	if not (bool(context.get("distortion_burst", false)) or calamity_distortion) or source_packet.is_area_damage:
		return
	_distortion_burst_groups[round_key] = int(_distortion_burst_groups.get(round_key, 0)) + 1
	while _distortion_burst_groups.size() > 64:
		_distortion_burst_groups.erase(_distortion_burst_groups.keys()[0])
	var center := primary_target.global_position
	var shape := CircleShape2D.new()
	shape.radius = ROCK_DISTORTION_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	seen[primary_target.get_instance_id()] = true
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or not _is_live_hostile_target(hurt.actor):
			continue
		var target := hurt.actor as Node2D
		var target_id := target.get_instance_id()
		if seen.has(target_id) or not _same_room_node(target) or not _has_clear_path(center, target.global_position):
			continue
		seen[target_id] = true
		var packet := DamagePacket.new()
		packet.base_damage = 1
		packet.source = player
		packet.source_faction = CombatFaction.Id.PLAYER
		packet.weapon_id = &"distortion_gain"
		packet.damage_type = &"sonic"
		packet.source_position = center
		packet.is_area_damage = true
		hurt.receive_hit(packet)
	_request_rock_wave(center, ROCK_DISTORTION_RADIUS, 0.15, Color("ffae32"))


func _has_clear_path(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _is_live_hostile_target(actor: Node) -> bool:
	return (
		is_instance_valid(actor)
		and actor is Node2D
		and _is_live_analysis_target(actor)
		and (actor.is_in_group(&"enemies") or actor.is_in_group(&"bosses"))
	)


func _request_rock_wave(position: Vector2, radius: float, duration: float, color: Color) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_rock_wave(position, color, radius, duration)


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
	_complete_takeover("夺身猎步：紧急撤离完成")


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
	var threats: Array[Vector2] = []
	var nearest := target.global_position
	var initial_clearance := player.global_position.distance_to(nearest)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not _is_live_enemy(candidate) or not _same_room(candidate):
			continue
		threats.append(candidate.global_position)
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance < initial_clearance:
			initial_clearance = distance
			nearest = candidate.global_position
	var preferred_direction := nearest.direction_to(player.global_position)
	if preferred_direction.is_zero_approx():
		preferred_direction = -player.aim_direction.normalized()
	if preferred_direction.is_zero_approx():
		preferred_direction = Vector2.LEFT
	var best_landing: Dictionary = {}
	var best_clearance := initial_clearance
	for radius: float in TAKEOVER_LANDING_RADII:
		for angle: float in TAKEOVER_LANDING_ANGLES:
			var destination := player.global_position + preferred_direction.rotated(angle) * radius
			var clearance := destination.distance_to(target.global_position)
			for threat in threats:
				clearance = minf(clearance, destination.distance_to(threat))
			if clearance > best_clearance + 0.1 and _is_safe_takeover_landing(destination):
				best_clearance = clearance
				best_landing = {"position": destination}
	return best_landing


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
		_complete_takeover("自动反击")


func _has_line_of_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target.global_position, 1)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _is_in_player_view(target: Node2D) -> bool:
	var camera := player.get_viewport().get_camera_2d()
	if camera == null:
		return true
	var viewport_size := player.get_viewport_rect().size / camera.zoom
	var visible_world := Rect2(camera.get_screen_center_position() - viewport_size * 0.5, viewport_size).grow(12.0)
	return visible_world.has_point(target.global_position)


func _is_live_analysis_target(target: Node) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or not target is Node2D:
		return false
	if target is EnemyController:
		return _is_live_enemy(target)
	if not target.is_in_group(&"bosses"):
		return false
	var target_health: Variant = target.get("health")
	return target_health == null or int(target_health.get("current_health")) > 0


func _complete_takeover(message: String) -> void:
	if core.consume_takeover_after_success():
		_publish_notice(&"persona_takeover", message, Color(1.0, 0.45, 0.85), CombatNotice.Priority.HIGH, 2.2)


func _cancel_soft_takeover(cancel_master_loop: bool = true) -> void:
	if dash.is_dashing() and dash.active_effect_kind in [&"ninja_chase", &"ninja_borrowed_step"]:
		dash.cancel_dash(true)
	_gaze_remaining = 0.0
	_gaze_attack_pending = false
	_chase_path.clear()
	if cancel_master_loop:
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


func get_attack_context(data: WeaponComponentData) -> Dictionary:
	var context := {}
	if _is_active(TalentCoreController.ROCK_VIGILANTE):
		if _has_talent(&"distortion_gain") and rock_feedback >= ROCK_DISTORTION_THRESHOLD:
			context["distortion_burst"] = true
	return context


func prepare_attack_group(group_id: int, context: Dictionary) -> void:
	_attack_group_contexts[group_id] = context.duplicate(true)
	_attack_group_targets[group_id] = {}
	while _attack_group_contexts.size() > 48:
		var oldest: Variant = _attack_group_contexts.keys()[0]
		_attack_group_contexts.erase(oldest)
		_attack_group_targets.erase(oldest)


func on_attack_committed(_data: WeaponComponentData, context: Dictionary, _group_id: int) -> void:
	pass


func modify_outgoing_damage(packet: DamagePacket, target: Node, base_damage: int) -> int:
	if packet != null and not packet.is_area_damage:
		for tag in packet.status_tags:
			if String(tag).begins_with("talent_direct_bonus:"):
				base_damage += int(String(tag).get_slice(":", 1))
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
	return data.feedback_gain


func _attack_key_from_parts(source: Node, damage_type: StringName, is_melee: bool) -> String:
	return "%s:%s:%s" % [source.get_class(), String(damage_type), "melee" if is_melee else "ranged"]


func _same_room_node(actor: Node) -> bool:
	return CombatProjectile.room_for_actor(actor) == CombatProjectile.room_for_actor(player)


func _perform_master_counter(target: Node2D) -> void:
	if not is_instance_valid(target) or not _has_line_of_sight(target):
		return
	if not player.cyberware.has_event_starter(4):
		player.cyberware.submit_weapon_fire(player.global_position.direction_to(target.global_position), weapons.get_current_weapon(), true)


func _apply_terminal_burst(center: Node2D, source_packet: DamagePacket) -> void:
	if not is_instance_valid(center):
		return
	var shape := CircleShape2D.new()
	shape.radius = 48.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center.global_position)
	query.collision_mask = 16
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
		_chase_path.clear()
		return
	_chase_path = _build_hunt_path(marked_target.global_position, 1000)
	if _chase_path.size() >= 2:
		_hunt_last_direction = _hunt_direction()


func _hunt_direction() -> Vector2:
	if _chase_path.size() < 2:
		return _hunt_last_direction
	for index in range(1, _chase_path.size()):
		var direction := _chase_path[index] - player.global_position
		if direction.length_squared() > 64.0:
			return direction.normalized()
	return _hunt_last_direction


func _build_hunt_path(destination: Vector2, max_segments: int) -> PackedVector2Array:
	var navigation_map: RID = player.get_world_2d().navigation_map
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
		return PackedVector2Array()
	var closest := NavigationServer2D.map_get_closest_point(navigation_map, destination)
	var raw := NavigationServer2D.map_get_path(navigation_map, player.global_position, closest, true)
	if raw.size() < 2 or closest.distance_to(destination) > 12.0:
		return PackedVector2Array()
	if max_segments > HUNT_MAX_SEGMENTS:
		return _round_hunt_path(raw, navigation_map)
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


func _round_hunt_path(raw: PackedVector2Array, navigation_map: RID) -> PackedVector2Array:
	var rounded := PackedVector2Array([raw[0]])
	for index in range(1, raw.size() - 1):
		var corner := raw[index]
		var incoming := (corner - raw[index - 1]).normalized()
		var outgoing := (raw[index + 1] - corner).normalized()
		var radius := minf(12.0, minf(corner.distance_to(raw[index - 1]), corner.distance_to(raw[index + 1])) * 0.25)
		var before := corner - incoming * radius
		var after := corner + outgoing * radius
		var samples := PackedVector2Array()
		var safe := radius > 1.0
		for step in range(5):
			var t := float(step) / 4.0
			var point := before * (1.0 - t) * (1.0 - t) + corner * 2.0 * t * (1.0 - t) + after * t * t
			if NavigationServer2D.map_get_closest_point(navigation_map, point).distance_to(point) > 1.0:
				safe = false
			samples.append(point)
		if safe:
			for point in samples:
				rounded.append(point)
		else:
			rounded.append(corner)
	rounded.append(raw[raw.size() - 1])
	return rounded


func _on_persona_changed(_persona_id: StringName) -> void:
	_clear_hunt_chain()
	_cancel_soft_takeover()
	_next_circuit_speed = 1.0
	_next_circuit_damage_bonus = 0
	_next_circuit_copy = false
	_counter_window_remaining = 0.0
	_analysis_progress.clear()
	_observed_threat = null
	_observed_attack_key = ""
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
		_clear_hunt_chain()
		_apply_persona_modifiers()


func _apply_persona_modifiers() -> void:
	_apply_guard_modifier()
	_apply_rock_feedback_modifiers()


func _apply_guard_modifier() -> void:
	var wanted_guard_bonus := 0.04 if _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0 else 0.0
	guard.equipment_window_bonus += wanted_guard_bonus - _guard_bonus_applied
	_guard_bonus_applied = wanted_guard_bonus


func _apply_attack_speed_modifier() -> void:
	var wanted := 0.0
	if _is_active(TalentCoreController.ROCK_VIGILANTE):
		wanted = _rock_feedback_ratio() * ROCK_ATTACK_SPEED_BONUS_MAX
	elif _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0:
		wanted = 0.25
	weapons.persona_attack_speed_bonus = wanted
	_attack_speed_bonus_applied = wanted


func _apply_rock_feedback_modifiers() -> void:
	var ratio := _rock_feedback_ratio() if _is_active(TalentCoreController.ROCK_VIGILANTE) else 0.0
	dash.persona_walk_speed_bonus = ratio * ROCK_MOVE_SPEED_BONUS_MAX + (0.2 if _is_active(TalentCoreController.DEEP_NINJA) and _resonance_remaining > 0.0 else 0.0)
	(player.get_node("CyberwareController") as CyberwareController).circuit.persona_energy_recovery_bonus = ratio * ROCK_ENERGY_RECOVERY_BONUS_MAX
	_apply_attack_speed_modifier()


func _rock_feedback_ratio() -> float:
	return clampf(rock_feedback / ROCK_FEEDBACK_MAX, 0.0, 1.0)


func _clear_temporary_modifiers() -> void:
	guard.equipment_window_bonus -= _guard_bonus_applied
	weapons.persona_attack_speed_bonus = 0.0
	dash.persona_walk_speed_bonus = 0.0
	(player.get_node("CyberwareController") as CyberwareController).circuit.persona_energy_recovery_bonus = 0.0
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
