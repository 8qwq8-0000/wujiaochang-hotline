class_name CyberpsychosisScreen
extends CanvasLayer

signal peak_started(source: StringName)
signal stage_crossed(stage: int)
signal music_cue_requested
signal music_stop_requested

const WINDOW_USEC := 60_000_000
const MODULES_TO_WARNING := 30
const MODULES_TO_ONSET := 75
const MODULES_TO_ECHO := 120
const MODULES_TO_PEAK := 150
const KILL_POINTS := 5
const DAMAGE_POINTS := 15
const BOSS_POINTS := 30
const ONSET_FADE_USEC := 800_000
const PEAK_FADE_USEC := 400_000
const PEAK_RELEASE_USEC := 600_000
const COOLDOWN_USEC := 30_000_000
const CAPTURE_INTERVAL_USEC := 85_000
const MOBILE_CAPTURE_INTERVAL_USEC := 160_000
const SHADER := preload("res://shaders/presentation/cyberpsychosis_screen.gdshader")

var _kill_times: Array[int] = []
var _module_times: Array[int] = []
var _frenzy_events: Array[Dictionary] = []
var _counted_boss_encounters: Dictionary = {}
var _reported_stage := 0
var _counted_kills: Dictionary = {}
var _last_action_usec := 0
var _last_capture_usec := 0
var _onset_started_usec := 0
var _peak_started_usec := 0
var _peak_release_usec := 0
var _peak_active := false
var _cooldown_until_usec := 0
var _cooldown_uses := 0
var _was_active_peak := false
var _peak_source: StringName
var _health_ratio := 1.0
var _bound_players: Dictionary = {}
var _history: Array[ImageTexture] = []
var _history_camera: Array[Vector2] = []
var _history_head := -1
var _capture_pending := false
var _capture_blocked_until_usec := 0
var _history_generation := 0
var _mobile := false
var _overlay: ColorRect
var _material: ShaderMaterial
var _film_overlay: ColorRect
var _film_material: ShaderMaterial


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mobile = OS.has_feature("android") or OS.has_feature("ios")
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("film_strength", 0.0)
	_material.set_shader_parameter("pixel_size", Vector2(1.0 / 640.0, 1.0 / 360.0))
	_overlay = ColorRect.new()
	_overlay.name = "FullScreen"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _material
	add_child(_overlay)
	_film_material = ShaderMaterial.new()
	_film_material.shader = SHADER
	_film_material.set_shader_parameter("film_strength", 1.0)
	_film_material.set_shader_parameter("pixel_size", Vector2(1.0 / 640.0, 1.0 / 360.0))
	var film_layer := CanvasLayer.new()
	film_layer.name = "FilmOverUI"
	film_layer.layer = 115
	add_child(film_layer)
	_film_overlay = ColorRect.new()
	_film_overlay.name = "FullScreenFilm"
	_film_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_film_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film_overlay.material = _film_material
	film_layer.add_child(_film_overlay)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
	var scene_flow := get_node_or_null("../SceneFlow")
	if scene_flow != null:
		scene_flow.load_started.connect(_on_scene_loading)
		scene_flow.scene_swapped.connect(_on_scene_swapped)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bind_existing_players")
	if DisplayServer.get_name() == "headless":
		_overlay.hide()
		_film_overlay.hide()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_trim_window(_kill_times, now)
	_trim_window(_module_times, now)
	_trim_frenzy_events(now)
	if _cooldown_until_usec > 0 and now >= _cooldown_until_usec:
		_cooldown_until_usec = 0
		_cooldown_uses = 0
		_module_times.clear()
	for target_id in _counted_kills.keys():
		if now - int(_counted_kills[target_id]) > WINDOW_USEC:
			_counted_kills.erase(target_id)
	var frenzy_points := get_frenzy_points()
	_reported_stage = mini(_reported_stage, _stage_for_points(frenzy_points))
	if frenzy_points < MODULES_TO_ONSET:
		_onset_started_usec = 0
	var release_mix := clampf(1.0 - float(now - _peak_release_usec) / PEAK_RELEASE_USEC, 0.0, 1.0) if _peak_release_usec > 0 else 0.0
	var visual_peak := _peak_active or release_mix > 0.0
	if _was_active_peak and not visual_peak:
		_clear_history()
	_was_active_peak = visual_peak
	var cooling := _cooldown_until_usec > 0 and not _peak_active
	var onset_mix := clampf(float(now - _onset_started_usec) / ONSET_FADE_USEC, 0.0, 1.0) if _onset_started_usec > 0 else 0.0
	var amplified := 0.0
	if frenzy_points >= MODULES_TO_WARNING:
		amplified = 0.08 + clampf(float(frenzy_points - MODULES_TO_WARNING) / float(MODULES_TO_ONSET - MODULES_TO_WARNING), 0.0, 1.0) * 0.07
	if frenzy_points >= MODULES_TO_ONSET:
		var progress := clampf(float(frenzy_points - MODULES_TO_ONSET) / float(MODULES_TO_PEAK - MODULES_TO_ONSET), 0.0, 1.0)
		var stronger := minf(0.42 + progress * 0.43 + minf(_kill_times.size() / 5.0, 1.0) * 0.05 + (1.0 - _health_ratio) * 0.05, 0.94)
		amplified = lerpf(amplified, stronger, onset_mix)
	if cooling:
		amplified = minf(0.08 + _cooldown_uses * 0.004, 0.16)
	var idle_seconds := float(now - _last_action_usec) / 1_000_000.0 if _last_action_usec > 0 else 999.0
	var release := 1.0 if idle_seconds < 1.2 else exp(-(idle_seconds - 1.2) / 2.0)
	var frenzy := clampf(amplified * release, 0.0, 0.94)
	var echo_strength := 0.0
	if not cooling and frenzy_points >= MODULES_TO_ECHO:
		echo_strength = clampf(0.16 + float(frenzy_points - MODULES_TO_ECHO) / float(MODULES_TO_PEAK - MODULES_TO_ECHO) * 0.30, 0.0, 0.46) * release
	var peak_mix := 0.0
	if _peak_active:
		peak_mix = clampf(float(now - _peak_started_usec) / PEAK_FADE_USEC, 0.0, 1.0)
	elif release_mix > 0.0:
		peak_mix = release_mix
	frenzy = lerpf(frenzy, 1.0, peak_mix)
	echo_strength = lerpf(echo_strength, 0.5, peak_mix)
	var peak_age := float(now - _peak_started_usec) / 1_000_000.0 if _peak_started_usec > 0 else 999.0
	var peak_pulse := clampf(1.0 - peak_age / 0.45, 0.0, 1.0) if _peak_active else 0.0
	_material.set_shader_parameter("frenzy", frenzy)
	_material.set_shader_parameter("echo_strength", echo_strength)
	_material.set_shader_parameter("peak_pulse", peak_pulse)
	_material.set_shader_parameter("peak_effect_scale", lerpf(1.0, 0.5, peak_mix))
	_material.set_shader_parameter("reduced_flashes", 1.0 if bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false)) else 0.0)
	_update_history_offsets()
	if _overlay.visible and echo_strength > 0.01 and not _capture_pending and now >= _capture_blocked_until_usec:
		var interval := MOBILE_CAPTURE_INTERVAL_USEC if _mobile else CAPTURE_INTERVAL_USEC
		if now - _last_capture_usec >= interval:
			_last_capture_usec = now
			_capture_pending = true
			_capture_frame()


func _capture_frame() -> void:
	var generation := _history_generation
	await RenderingServer.frame_post_draw
	_capture_pending = false
	if not is_inside_tree() or generation != _history_generation:
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var target_width := mini(image.get_width(), 320 if _mobile else 640)
	var target_height := maxi(roundi(float(image.get_height()) * target_width / image.get_width()), 2)
	if image.get_width() != target_width or image.get_height() != target_height:
		image.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)
	if not _history.is_empty() and _history[0].get_size() != Vector2(image.get_width(), image.get_height()):
		_history.clear()
		_history_camera.clear()
		_history_head = -1
	var capacity := 1 if _mobile else 3
	_history_head = (_history_head + 1) % capacity
	var camera := get_viewport().get_camera_2d()
	var camera_position := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	if _history.size() < capacity:
		_history.append(ImageTexture.create_from_image(image))
		_history_camera.append(camera_position)
	else:
		_history[_history_head].update(image)
		_history_camera[_history_head] = camera_position
	for index in range(_history.size()):
		var slot := posmod(_history_head - index, _history.size())
		_material.set_shader_parameter("history_%d" % (index + 1), _history[slot])
	_material.set_shader_parameter("history_count", _history.size())
	_material.set_shader_parameter("pixel_size", Vector2(1.0 / image.get_width(), 1.0 / image.get_height()))


func _update_history_offsets() -> void:
	if _history.is_empty():
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var screen_size := get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var current := camera.get_screen_center_position()
	for index in range(_history.size()):
		var slot := posmod(_history_head - index, _history.size())
		var delta := (current - _history_camera[slot]) * camera.zoom / screen_size
		_material.set_shader_parameter("history_offset_%d" % (index + 1), delta)


func _on_damage_resolved(result: DamageResult) -> void:
	if result != null and result.target is PlayerController and result.outcome == DamageResult.Outcome.DAMAGED and result.final_damage > 0:
		_add_frenzy_points(DAMAGE_POINTS, &"damage")
	if result == null or not result.target_defeated or result.packet == null:
		return
	if result.packet.source_faction != CombatFaction.Id.PLAYER or not result.packet.source is PlayerController:
		return
	if not is_instance_valid(result.target) or (not result.target is EnemyController and not result.target.is_in_group(&"bosses")):
		return
	var now := Time.get_ticks_usec()
	_trim_window(_kill_times, now)
	var target_id := result.target.get_instance_id()
	if _counted_kills.has(target_id):
		return
	_counted_kills[target_id] = now
	_kill_times.append(now)
	_last_action_usec = now
	_add_frenzy_points(KILL_POINTS, &"kill")


func _on_node_added(node: Node) -> void:
	if node is PlayerController:
		call_deferred("_bind_player", node)


func _bind_existing_players() -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is PlayerController:
			_bind_player(node)


func _bind_player(player: PlayerController) -> void:
	if not is_instance_valid(player) or _bound_players.has(player.get_instance_id()):
		return
	_bound_players[player.get_instance_id()] = true
	player.cyberware_triggered.connect(_on_module_triggered)
	player.health_changed.connect(_on_health_changed)
	player.player_died.connect(_on_player_died)
	_on_health_changed(player.health.current_health, player.health.max_health, 0)


func _on_module_triggered(_module_id: StringName) -> void:
	var now := Time.get_ticks_usec()
	_last_action_usec = now
	if _peak_active:
		return
	if now < _cooldown_until_usec:
		_cooldown_uses += 1
		return
	_trim_window(_module_times, now)
	_module_times.append(now)
	_add_frenzy_points(1, &"module")


func record_boss_encounter(encounter_id: int) -> void:
	if _counted_boss_encounters.has(encounter_id):
		return
	_counted_boss_encounters[encounter_id] = true
	_add_frenzy_points(BOSS_POINTS, &"boss")


func _add_frenzy_points(points: int, source: StringName) -> void:
	var now := Time.get_ticks_usec()
	_last_action_usec = now
	if _peak_active or now < _cooldown_until_usec:
		return
	_trim_frenzy_events(now)
	var previous_stage := _stage_for_points(get_frenzy_points())
	_reported_stage = mini(_reported_stage, previous_stage)
	_frenzy_events.append({"time": now, "points": points})
	var current_points := get_frenzy_points()
	var current_stage := _stage_for_points(current_points)
	if current_stage > previous_stage and current_stage > _reported_stage:
		_reported_stage = current_stage
		stage_crossed.emit(current_stage)
	if previous_stage < 2 and current_stage >= 2:
		_onset_started_usec = now
	if previous_stage < 3 and current_stage >= 3:
		_peak_source = &"modules" if source == &"module" else source
		music_cue_requested.emit()


func _stage_for_points(points: int) -> int:
	if points >= MODULES_TO_PEAK:
		return 3
	if points >= MODULES_TO_ONSET:
		return 2
	return 1 if points >= MODULES_TO_WARNING else 0


func get_frenzy_points() -> int:
	var total := 0
	for event in _frenzy_events:
		total += int(event.points)
	return total


func _trim_frenzy_events(now: int) -> void:
	while not _frenzy_events.is_empty() and now - int(_frenzy_events[0].time) > WINDOW_USEC:
		_frenzy_events.remove_at(0)


func _on_music_started() -> void:
	if _peak_active:
		return
	_peak_active = true
	_peak_started_usec = Time.get_ticks_usec()
	_peak_release_usec = 0
	peak_started.emit(_peak_source)


func _on_music_ended() -> void:
	if not _peak_active:
		return
	_peak_active = false
	_peak_release_usec = Time.get_ticks_usec()
	_cooldown_until_usec = _peak_release_usec + COOLDOWN_USEC
	_cooldown_uses = 0
	_module_times.clear()
	_kill_times.clear()
	_frenzy_events.clear()
	_reported_stage = 0


func _on_player_died(_packet: DamagePacket) -> void:
	_kill_times.clear()
	_module_times.clear()
	_frenzy_events.clear()
	_counted_boss_encounters.clear()
	_reported_stage = 0
	_counted_kills.clear()
	_last_action_usec = 0
	_onset_started_usec = 0
	_peak_started_usec = 0
	_peak_release_usec = 0
	_peak_active = false
	_cooldown_until_usec = 0
	_cooldown_uses = 0
	_was_active_peak = false
	_health_ratio = 1.0
	_clear_history()
	music_stop_requested.emit()


func _on_health_changed(current: int, maximum: int, _delta: int) -> void:
	_health_ratio = clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)


func _on_scene_loading(_scene_path: String) -> void:
	_capture_blocked_until_usec = Time.get_ticks_usec() + 1_000_000
	_kill_times.clear()
	_module_times.clear()
	_frenzy_events.clear()
	_counted_boss_encounters.clear()
	_reported_stage = 0
	_counted_kills.clear()
	_last_action_usec = 0
	_onset_started_usec = 0
	_peak_started_usec = 0
	_peak_release_usec = 0
	_peak_active = false
	_cooldown_until_usec = 0
	_cooldown_uses = 0
	_was_active_peak = false
	_clear_history()


func _on_scene_swapped(_scene: Node, _payload: Dictionary) -> void:
	_capture_blocked_until_usec = Time.get_ticks_usec() + 400_000
	_clear_history()


func _clear_history() -> void:
	_history_generation += 1
	_history.clear()
	_history_camera.clear()
	_history_head = -1
	if _material != null:
		_material.set_shader_parameter("history_count", 0)


func _trim_window(times: Array[int], now: int) -> void:
	while not times.is_empty() and now - times[0] > WINDOW_USEC:
		times.remove_at(0)


func get_window_counts() -> Dictionary:
	return {"kills": _kill_times.size(), "modules": _module_times.size(), "points": get_frenzy_points(), "peak_source": _peak_source}
