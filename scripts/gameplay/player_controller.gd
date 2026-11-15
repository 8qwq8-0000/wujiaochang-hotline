class_name PlayerController
extends CharacterBody2D

signal health_changed(current: int, maximum: int, delta: int)
signal heat_changed(current: float, maximum: float)
signal weapon_changed(data: WeaponComponentData)
signal dash_state_changed(active: bool, cooldown_remaining: float)
signal cyberware_changed(modules: PackedStringArray)
signal cyberware_triggered(module_id: StringName)
signal guard_state_changed(state: GuardComponent.State)
signal input_enabled_changed(enabled: bool)
signal interaction_requested(target: Node)
signal combat_feedback_requested(cue: StringName, world_position: Vector2)
signal player_died(packet: DamagePacket)

const DEFAULT_CONFIG := preload("res://resources/player/default_player_config.tres")
const AFTERIMAGE_INTERVAL := 0.05
const WORLD_AFTERIMAGE_INTERVAL := 0.13
const MOVEMENT_NOISE_INTERVAL := 0.35
const MOBILITY_BURST_NOISE_RADIUS := 220.0
const INPUT_BUFFER_SECONDS := 0.12
const CAMERA_SHAKE_SETTING := &"CameraShakeStrength"

@export var config: CombatPlayerConfig = DEFAULT_CONFIG

@onready var inventory: ComponentInventory = $ComponentInventory
@onready var health: HealthComponent = $HealthComponent
@onready var heat: HeatComponent = $HeatComponent
@onready var guard: GuardComponent = $GuardComponent
@onready var dash: DashController = $DashController
@onready var cyberware: CyberwareController = $CyberwareController
@onready var weapons: WeaponController = $WeaponController
@onready var statuses: StatusComponent = $StatusComponent
@onready var talent_core: TalentCoreController = $TalentCoreController
@onready var persona_combat: PersonaCombatController = $PersonaCombatController
@onready var circuit_breaker: CircuitBreakerComponent = $CircuitBreakerComponent
@onready var interactor: InteractorComponent = $InteractionDetector
@onready var hurt_box: HurtBox2DComponent = $HurtBox
@onready var visuals: PlayerVisualController = $VisualRoot
@onready var camera: Camera2D = $Camera2D
@onready var movement_loop: AudioStreamPlayer2D = $AudioSockets/MovementLoop

var aim_direction := Vector2.RIGHT
var _external_velocity := Vector2.ZERO
var _dead := false
var _input_enabled := true
var _attack_pressed := false
var _attack_released := false
var _attack_held := false
var _gravity_charging := false
var _gravity_charge_seconds := 0.0
var _gravity_pending := false
var _gravity_pending_seconds := 0.0
var _gravity_charge_bar: Node2D
var _afterimage_active_remaining := 0.0
var _afterimage_emit_remaining := 0.0
var _movement_effect_last_position := Vector2.ZERO
var _movement_noise_remaining := 0.0
var _attack_buffer_remaining := 0.0
var _attack_release_buffer_remaining := 0.0
var _guard_buffer_remaining := 0.0
var _dash_buffer_remaining := 0.0
var _camera_trauma := 0.0
var _camera_shake_direction := Vector2.RIGHT
var _camera_shake_phase := 0.0
var channel_curse_active := false
var _channel_base_config: CombatPlayerConfig
var _channel_base_dash: DashConfigData
var _channel_base_cooling := 0.0
var _camera_shake_last_usec := 0


func _ready() -> void:
	add_to_group("player")
	if config == null:
		config = DEFAULT_CONFIG
	_configure_movement_audio()
	health.configure_max_health(config.max_health)
	health.fatal_damage_interceptor = Callable(self, "_try_prevent_fatal_damage")
	hurt_box.faction = CombatFaction.Id.PLAYER
	hurt_box.damage_invulnerability_seconds = config.damage_invulnerability_seconds
	weapons.configure(config.default_weapon, config.debug_loadout_enabled)
	visuals.set_weapon(weapons.get_current_weapon())
	heat.set_physics_process(false)
	guard.state_changed.connect(_on_guard_state_changed)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	weapons.weapon_changed.connect(_on_weapon_changed)
	weapons.attack_performed.connect(_on_attack_performed)
	dash.dash_started.connect(_on_dash_started)
	dash.dash_ended.connect(_on_dash_ended)
	dash.cooldown_changed.connect(_on_dash_cooldown_changed)
	cyberware.cyberware_changed.connect(_on_cyberware_changed)
	cyberware.module_triggered.connect(_on_cyberware_triggered)
	hurt_box.hit_resolved.connect(_on_hit_resolved)
	interactor.interaction_requested.connect(_on_interaction_requested)
	circuit_breaker.circuit_breaker_triggered.connect(_on_circuit_breaker_triggered)
	if not config.debug_loadout_enabled:
		inventory._apply_equipment()
	_gravity_charge_bar = Node2D.new()
	_gravity_charge_bar.set_script(load("res://scripts/presentation/gravity_charge_bar.gd"))
	add_child(_gravity_charge_bar)
	_emit_public_state()
	_camera_shake_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_update_camera_shake()


func _input(event: InputEvent) -> void:
	if event.is_action_released("attack"):
		_attack_held = false
		cyberware.cancel_automatic_fire_requests()


func _unhandled_input(event: InputEvent) -> void:
	if _dead or not _input_enabled or inventory.is_open or event.is_echo():
		return
	var world_stopped := cyberware.is_world_stopped()
	if world_stopped and not (event.is_action_pressed("attack") or event.is_action_released("attack")):
		return
	if not world_stopped:
		persona_combat.notify_player_input(event)
	if event.is_action_pressed("attack"):
		persona_combat.cancel_hunt_followups()
		_attack_pressed = true
		_attack_held = true
		_attack_buffer_remaining = 0.2 if persona_combat.has_stable_beat() else INPUT_BUFFER_SECONDS
		if weapons.get_current_weapon() != null and weapons.get_current_weapon().id == &"gravity_wave":
			_gravity_charging = true
			_gravity_charge_seconds = 0.0
	if event.is_action_released("attack"):
		_attack_released = true
		_attack_held = false
		cyberware.cancel_automatic_fire_requests()
		_attack_release_buffer_remaining = INPUT_BUFFER_SECONDS
		if _gravity_charging:
			_gravity_charging = false
			_gravity_pending = true
			_gravity_pending_seconds = _gravity_charge_seconds
	if event.is_action_pressed("guard"):
		persona_combat.cancel_hunt_followups()
		_guard_buffer_remaining = INPUT_BUFFER_SECONDS
	if event.is_action_pressed("mobility_ability"):
		_dash_buffer_remaining = 0.6 if persona_combat.has_hunt_chain() else INPUT_BUFFER_SECONDS
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		interactor.request_interaction(self)
	if InputMap.has_action("circuit_activate") and event.is_action_pressed("circuit_activate"):
		cyberware.submit_circuit_request(&"active", aim_direction, PackedStringArray(["主动"]))
	if event.is_action_pressed("weapon_switch") or event.is_action_pressed("weapon_next"):
		weapons.cycle_weapon(1)
	if event.is_action_pressed("weapon_previous"):
		weapons.cycle_weapon(-1)


func _physics_process(delta: float) -> void:
	_update_aim_direction()
	if _gravity_charging:
		_gravity_charge_seconds = minf(_gravity_charge_seconds + delta, GravityWaveOrb.MAX_CHARGE_SECONDS)
	if _gravity_charge_bar != null:
		_gravity_charge_bar.set("progress", _gravity_charge_seconds / GravityWaveOrb.MAX_CHARGE_SECONDS if _gravity_charging else 0.0)
		_gravity_charge_bar.queue_redraw()
	if cyberware.is_world_stopped():
		var world_input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if _input_enabled else Vector2.ZERO
		velocity = world_input * dash.config.walk_speed
		move_and_slide()
		weapons.update_attack_pose(global_position, aim_direction, self)
		visuals.update_visual(aim_direction, velocity, guard.state, guard.guard_arc_degrees, weapons.get_melee_swing_angle_offset(), _logical_aim_world_position())
		if _input_enabled and _should_attack_this_frame():
			var attack := _get_attack_transform()
			if weapons.try_attack(attack.origin, attack.x.normalized(), self, not _attack_pressed):
				_consume_attack_buffer()
		_tick_input_buffers(delta)
		persona_combat.queue_redraw()
		_afterimage_active_remaining = WORLD_AFTERIMAGE_INTERVAL + delta
		if not world_input.is_zero_approx():
			_tick_afterimages(delta, WORLD_AFTERIMAGE_INTERVAL)
		_update_camera(delta)
		return
	_consume_buffered_defense_actions()
	guard.update_direction(aim_direction)
	if _dead:
		velocity = Vector2.ZERO
		_update_movement_audio()
		visuals.update_visual(aim_direction, Vector2.ZERO, guard.state, guard.guard_arc_degrees)
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down") if _input_enabled else Vector2.ZERO
	dash.tick(self, input_vector, aim_direction, delta, _external_velocity)
	_tick_movement_noise(delta, input_vector)
	_external_velocity = _external_velocity.move_toward(Vector2.ZERO, config.knockback_recovery * delta)
	weapons.update_attack_pose(global_position, aim_direction, self)
	# The muzzle must use this frame's aim before an attack is spawned.
	visuals.update_visual(aim_direction, velocity, guard.state, guard.guard_arc_degrees, weapons.get_melee_swing_angle_offset(), _logical_aim_world_position())
	if _input_enabled and (guard.can_attack() or persona_combat.can_attack_during_guard()) and dash.can_attack() and _should_attack_this_frame():
		var attack := _get_attack_transform()
		if weapons.try_attack(attack.origin, attack.x.normalized(), self, not _attack_pressed):
			_consume_attack_buffer()
			_gravity_pending = false
		elif _gravity_pending and weapons.get_cooldown_remaining() <= 0.0:
			_gravity_pending = false
	_tick_input_buffers(delta)
	_update_camera(delta)
	visuals.update_visual(
		aim_direction,
		velocity,
		guard.state,
		guard.guard_arc_degrees,
		weapons.get_melee_swing_angle_offset(),
		_logical_aim_world_position()
	)
	_tick_movement_effect()
	_tick_afterimages(delta)
	_update_movement_audio()


func set_input_enabled(enabled: bool) -> void:
	if _input_enabled == enabled:
		return
	_input_enabled = enabled
	_attack_pressed = false
	_attack_released = false
	_attack_held = false
	_gravity_charging = false
	_gravity_pending = false
	_attack_buffer_remaining = 0.0
	_attack_release_buffer_remaining = 0.0
	_guard_buffer_remaining = 0.0
	_dash_buffer_remaining = 0.0
	if not enabled:
		velocity = Vector2.ZERO
	input_enabled_changed.emit(enabled)


func is_input_enabled() -> bool:
	return _input_enabled and not _dead


func equip_weapon(data: WeaponComponentData) -> void:
	weapons.equip_weapon(data)


func equip_cyberware(item: InventoryItem) -> void:
	cyberware.set_equipped_item(item)


func unequip_cyberware() -> void:
	cyberware.clear()


func set_circuit_breaker_equipped(equipped: bool) -> void:
	circuit_breaker.set_equipped(equipped)


func consume_persona_drink(persona_id: StringName) -> bool:
	if not talent_core.consume_persona_drink(persona_id):
		return false
	if cyberware.circuit.slot_capacity < CyberwareCircuitState.SLOT_COUNT:
		cyberware.circuit.set_slot_capacity(cyberware.circuit.slot_capacity + 1)
		cyberware.circuit.expand_capacity()
		cyberware.circuit_changed.emit(cyberware.export_circuit_state())
	return true


func set_persona_talent(persona_id: StringName, tier: int, talent_id: StringName) -> bool:
	return talent_core.set_talent_choice(persona_id, tier, talent_id)


func respec_persona(persona_id: StringName) -> bool:
	return talent_core.respec_persona(persona_id)


# Compatibility wrappers for prototype callers.
func set_combat_protocol(protocol_id: StringName) -> bool:
	return talent_core.set_protocol(protocol_id)


func set_protocol_talent(protocol_id: StringName, tier: int, talent_id: StringName) -> bool:
	return set_persona_talent(protocol_id, tier, talent_id)


func respec_protocol(protocol_id: StringName) -> bool:
	return respec_persona(protocol_id)


func refill_ai_takeover_charges() -> void:
	talent_core.refill_takeover_charges()


func apply_knockback(force: Vector2) -> void:
	_external_velocity += force * dash.get_knockback_multiplier()


func repair(amount: int) -> int:
	return health.repair(amount)


func receive_damage(packet: DamagePacket) -> DamageResult:
	return hurt_box.receive_hit(packet)


func try_persona_guard(packet: DamagePacket) -> bool:
	return persona_combat.try_proxy_guard(packet)


func try_cyberware_guard(packet: DamagePacket) -> DamageResult:
	return cyberware.try_cyberware_guard(packet)


func should_ignore_damage(packet: DamagePacket) -> bool:
	return persona_combat.should_ignore_damage(packet)


func get_persona_attack_context(data: WeaponComponentData) -> Dictionary:
	var context := persona_combat.get_attack_context(data)
	cyberware.augment_attack_context(data, context)
	return context


func prepare_persona_attack_group(group_id: int, context: Dictionary) -> void:
	persona_combat.prepare_attack_group(group_id, context)


func on_persona_attack_committed(data: WeaponComponentData, context: Dictionary, group_id: int) -> void:
	persona_combat.on_attack_committed(data, context, group_id)
	cyberware.on_attack_committed(data, context)


func modify_outgoing_damage(packet: DamagePacket, target: Node, base_damage: int) -> int:
	return persona_combat.modify_outgoing_damage(packet, target, base_damage)


func perform_persona_attack(direction: Vector2, forced: bool = false, damage_multiplier: float = 1.0) -> bool:
	if _dead or direction.is_zero_approx():
		return false
	aim_direction = direction.normalized()
	visuals.update_visual(
		aim_direction,
		velocity,
		guard.state,
		guard.guard_arc_degrees,
		weapons.get_melee_swing_angle_offset(),
		global_position + aim_direction * 64.0
	)
	var attack := _get_attack_transform()
	return weapons.try_forced_attack(attack.origin, attack.x.normalized(), self, damage_multiplier) if forced else weapons.try_attack(attack.origin, attack.x.normalized(), self)


func perform_persona_cooldown_free_attack(direction: Vector2, damage_multiplier: float = 1.0) -> bool:
	if _dead or direction.is_zero_approx():
		return false
	aim_direction = direction.normalized()
	var attack := _get_attack_transform()
	return weapons.try_cooldown_free_attack(attack.origin, attack.x.normalized(), self, damage_multiplier)


func perform_persona_terminal_attack(direction: Vector2) -> bool:
	if _dead or direction.is_zero_approx():
		return false
	aim_direction = direction.normalized()
	var attack := _get_attack_transform()
	return weapons.try_terminal_attack(attack.origin, attack.x.normalized(), self)


func get_health_state() -> Dictionary:
	return {"current": health.current_health, "maximum": health.max_health}


func get_heat_state() -> Dictionary:
	return {
		"current": heat.current_heat,
		"maximum": heat.effective_max(),
		"overflow": maxf(heat.current_heat - heat.effective_max(), 0.0),
		"overflow_visible": persona_combat.is_nuclear_frenzy_active() or heat.current_heat > heat.effective_max(),
		"overheated": heat.is_overheated,
	}


func get_weapon_display_name() -> String:
	var data := weapons.get_current_weapon()
	return data.display_name if data != null else "无"


func get_dash_display_name() -> String:
	return "固有突进"


func get_cyberware_display_name() -> String:
	return ComponentRolls.cyberware_title(cyberware.modules)


func get_guard_state() -> GuardComponent.State:
	return guard.state


func export_run_state() -> Dictionary:
	var weapon := weapons.get_current_weapon()
	return {
		"inventory": inventory.export_run_state(),
		"current_health": health.current_health,
		"channel_curse": channel_curse_active,
		"weapon_id": String(weapon.id) if weapon != null else "",
		"cyberware_circuit": cyberware.export_circuit_state(),
		"talent_core": talent_core.export_state(),
		"circuit_breaker": circuit_breaker.export_state(),
	}


func import_run_state(state: Dictionary) -> void:
	apply_channel_curse(bool(state.get("channel_curse", false)))
	if state.is_empty():
		return
	# Restore the independent circuit before inventory migration so any legacy
	# cyberware found in the old bag/slot is merged instead of overwritten.
	if state.has("cyberware_circuit") and state["cyberware_circuit"] is Dictionary:
		cyberware.import_circuit_state(state["cyberware_circuit"])
	if state.has("inventory") and state["inventory"] is Dictionary:
		inventory.import_run_state(state["inventory"])
	elif state.has("weapon_id"):
		weapons.equip_weapon_by_id(StringName(state["weapon_id"]))
	if state.has("talent_core") and state["talent_core"] is Dictionary:
		talent_core.import_state(state["talent_core"])
	if state.has("circuit_breaker") and state["circuit_breaker"] is Dictionary:
		circuit_breaker.import_state(state["circuit_breaker"])
	elif state.has("core") and state["core"] is Dictionary:
		# Import snapshots created before the talent core and breaker were split.
		circuit_breaker.import_state(state["core"])
	if state.get("inventory", {}).has("blackbox"):
		inventory.sync_insurance()
	elif state.has("circuit_breaker") or state.has("core"):
		# Migrate pre-item insurance state without granting an extra core.
		if not circuit_breaker.equipped:
			inventory.blackbox_slot.clear()
		else:
			var insurance := inventory.get_insurance_item()
			if insurance != null:
				insurance.set_property("circuit_breaker_used", circuit_breaker.circuit_breaker_used)
		inventory.sync_insurance()
	health.set_current_health(int(state.get("current_health", health.max_health)))
	talent_core.sync_health(health.current_health)
	reset_transient_state(true)


func export_recovery_state() -> Dictionary:
	return export_settlement_state(false)


func export_settlement_state(preserve_inventory: bool) -> Dictionary:
	var state := export_run_state()
	var archive := (state.talent_core as Dictionary).duplicate(true)
	if _has_persona_archive_content(archive):
		state["persona_archive"] = archive
	state.talent_core = talent_core.export_fresh_run_state()
	if preserve_inventory:
		state.inventory = inventory.export_settlement_inventory()
	else:
		state.inventory = inventory.export_recovery_inventory()
	state.cyberware_circuit = {
		"library": {},
		"slots": [],
		"slot_capacity": CyberwareCircuitState.INITIAL_SLOT_COUNT,
		"current_energy": CyberwareCircuitState.DEFAULT_MAXIMUM_ENERGY,
		"maximum_energy": CyberwareCircuitState.DEFAULT_MAXIMUM_ENERGY,
	}
	state["channel_curse"] = false
	state.current_health = _channel_base_config.max_health if channel_curse_active else config.max_health
	state.circuit_breaker.equipped = inventory.blackbox_slot.get_item() != null and inventory.blackbox_slot.get_item().get_property("slot", "") == "insurance"
	return state


func _has_persona_archive_content(archive: Dictionary) -> bool:
	for level: Variant in archive.get("persona_levels", {}).values():
		if int(level) > 0:
			return true
	for leaked: Variant in archive.get("semantic_leaks", {}).values():
		if bool(leaked):
			return true
	return not (archive.get("run_metrics", {}) as Dictionary).is_empty()


func reset_transient_state(preserve_circuit_queues: bool = false) -> void:
	_gravity_charging = false
	_gravity_pending = false
	for orb in get_tree().get_nodes_in_group("gravity_wave_orbs"):
		if orb is GravityWaveOrb and orb.source == self:
			orb.queue_free()
	var room_buff := get_node_or_null("RoomBuffComponent")
	if room_buff != null:
		room_buff.clear()
	heat.set_heat(0.0)
	heat.is_overheated = false
	statuses.clear_all()
	guard.reset_to_idle()
	dash.reset_transient_state()
	cyberware.reset_transient_state(preserve_circuit_queues)
	weapons.reset_transient_state()
	persona_combat.reset_transient_state()
	hurt_box.clear_invulnerability()
	_external_velocity = Vector2.ZERO
	_attack_pressed = false
	_attack_released = false
	_attack_held = false
	_afterimage_active_remaining = 0.0
	_afterimage_emit_remaining = 0.0
	_movement_effect_last_position = global_position
	_movement_noise_remaining = 0.0
	_clear_afterimages()


func _update_aim_direction() -> void:
	var mobile_input := get_node_or_null("/root/MobileInput")
	if mobile_input != null and mobile_input.is_touch_aim_active(self):
		aim_direction = mobile_input.get_aim_direction(self, aim_direction)
		return
	var mouse_delta := _logical_mouse_world_position() - global_position
	if mouse_delta.length() > config.aim_deadzone:
		aim_direction = mouse_delta.normalized()


func _get_weapon_aim_direction() -> Vector2:
	var data := weapons.get_current_weapon()
	if data == null or data.attack_kind == WeaponComponentData.AttackKind.MELEE:
		return aim_direction
	var direction := _logical_aim_world_position() - visuals.get_weapon_mount_global_position()
	return direction.normalized() if direction.length_squared() > 1.0 else aim_direction


func get_live_projectile_aim_direction() -> Vector2:
	var mobile_input := get_node_or_null("/root/MobileInput")
	if mobile_input != null and mobile_input.is_touch_aim_active(self):
		return mobile_input.get_aim_direction(self, aim_direction)
	var direction := _logical_mouse_world_position() - visuals.get_weapon_mount_global_position()
	return direction.normalized() if direction.length_squared() > 1.0 else aim_direction


func _update_camera(delta: float) -> void:
	var target := aim_direction * config.camera_look_ahead
	var weight := clampf(config.camera_look_ahead_response * delta, 0.0, 1.0)
	camera.position = camera.position.lerp(target, weight)


func add_camera_trauma(direction: Vector2, strength: float) -> void:
	var configured_strength := clampf(float(PlayerConfig.get_config(&"UISettings", CAMERA_SHAKE_SETTING, 1.0)), 0.0, 1.0)
	if configured_strength <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_camera_trauma = maxf(_camera_trauma, clampf(strength * configured_strength, 0.0, 1.0))
	_camera_shake_direction = direction.normalized() if not direction.is_zero_approx() else aim_direction


func clear_camera_shake() -> void:
	_camera_trauma = 0.0
	camera.offset = Vector2.ZERO


func _update_camera_shake() -> void:
	var now := Time.get_ticks_usec()
	var real_delta := clampf(float(now - _camera_shake_last_usec) / 1_000_000.0, 0.0, 0.05)
	_camera_shake_last_usec = now
	if _camera_trauma <= 0.001:
		_camera_trauma = 0.0
		camera.offset = Vector2.ZERO
		return
	_camera_trauma = maxf(_camera_trauma - real_delta * 3.8, 0.0)
	_camera_shake_phase += real_delta * 58.0
	var amplitude := 6.0 * _camera_trauma * _camera_trauma
	var perpendicular := _camera_shake_direction.orthogonal()
	camera.offset = _camera_shake_direction * sin(_camera_shake_phase) * amplitude + perpendicular * sin(_camera_shake_phase * 1.73 + 0.8) * amplitude * 0.42


func _logical_mouse_world_position() -> Vector2:
	# Camera2D.offset is presentation-only; removing it keeps aim coordinates
	# stable while the rendered world shakes.
	return get_global_mouse_position() - camera.offset


func _logical_aim_world_position() -> Vector2:
	var mouse_position := _logical_mouse_world_position()
	var mobile_input := get_node_or_null("/root/MobileInput")
	if mobile_input != null and mobile_input.is_touch_aim_active(self):
		return mobile_input.get_aim_world_position(self, mouse_position)
	return mouse_position


func _consume_buffered_defense_actions() -> void:
	if not _input_enabled or _dead:
		return
	if _guard_buffer_remaining > 0.0 and dash.can_guard() and guard.begin_guard(aim_direction):
		_guard_buffer_remaining = 0.0
	if _dash_buffer_remaining > 0.0:
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if persona_combat.try_start_player_dash(movement):
			_dash_buffer_remaining = 0.0


func _tick_input_buffers(delta: float) -> void:
	_attack_buffer_remaining = maxf(_attack_buffer_remaining - delta, 0.0)
	_attack_release_buffer_remaining = maxf(_attack_release_buffer_remaining - delta, 0.0)
	_guard_buffer_remaining = maxf(_guard_buffer_remaining - delta, 0.0)
	_dash_buffer_remaining = maxf(_dash_buffer_remaining - delta, 0.0)
	_attack_pressed = _attack_buffer_remaining > 0.0
	_attack_released = _attack_release_buffer_remaining > 0.0


func _consume_attack_buffer() -> void:
	var data := weapons.get_current_weapon()
	if data != null and data.trigger_mode == WeaponComponentData.TriggerMode.CHARGE:
		_attack_release_buffer_remaining = 0.0
	else:
		_attack_buffer_remaining = 0.0
	_attack_pressed = false
	_attack_released = false


func _configure_movement_audio() -> void:
	movement_loop.bus = &"SFX"


func _update_movement_audio() -> void:
	# The retired flight loop must never leak into the fixed walk/dash model.
	if movement_loop.playing:
		movement_loop.stop()
	movement_loop.stream = null


func _get_attack_transform() -> Transform2D:
	var data := weapons.get_current_weapon()
	if data == null or data.attack_kind == WeaponComponentData.AttackKind.MELEE:
		return Transform2D(aim_direction.angle(), global_position)
	var muzzle := visuals.get_weapon_muzzle_global_position()
	muzzle = weapons.clamp_projectile_origin(
		visuals.get_weapon_mount_global_position(),
		muzzle
	)
	var barrel_direction := visuals.weapon_pivot.global_transform.x.normalized()
	return Transform2D(barrel_direction.angle(), muzzle)


func _should_attack_this_frame() -> bool:
	var data := weapons.get_current_weapon()
	if data == null:
		return false
	if data.id == &"gravity_wave":
		weapons.pending_charge_seconds = _gravity_pending_seconds
		return _gravity_pending
	var mobile_input := get_node_or_null("/root/MobileInput")
	if mobile_input != null and mobile_input.is_manual_attack_active(self):
		return data.trigger_mode != WeaponComponentData.TriggerMode.CHARGE
	match data.trigger_mode:
		WeaponComponentData.TriggerMode.AUTOMATIC:
			return _attack_held
		WeaponComponentData.TriggerMode.CHARGE:
			return _attack_release_buffer_remaining > 0.0
		_:
			return _attack_held if cyberware.supports_automatic_fire(data) else _attack_buffer_remaining > 0.0


func _try_prevent_fatal_damage(_amount: int, _packet: DamagePacket) -> bool:
	if not circuit_breaker.try_prevent_fatal_damage():
		return false
	statuses.clear_all()
	hurt_box.set_invulnerable(1.2)
	return true


func _on_health_changed(current: int, maximum: int, delta: int) -> void:
	talent_core.sync_health(current)
	health_changed.emit(current, maximum, delta)


func _on_heat_changed(current: float, maximum: float) -> void:
	heat_changed.emit(current, maximum)


func _on_overheated() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"weapon_overheated", "武器过热", Color(1.0, 0.35, 0.2), CombatNotice.Priority.HIGH, 0.0, 1.8)


func _on_heat_recovered() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"weapon_recovered", "武器冷却完成", Color(0.35, 0.9, 1.0), CombatNotice.Priority.NORMAL)


func _on_weapon_changed(_index: int, data: WeaponComponentData) -> void:
	_gravity_charging = false
	_gravity_pending = false
	visuals.set_weapon(data)
	weapon_changed.emit(data)


func _on_cyberware_changed(modules: PackedStringArray) -> void:
	cyberware_changed.emit(modules)


func _on_cyberware_triggered(module_id: StringName) -> void:
	cyberware_triggered.emit(module_id)


func _on_guard_state_changed(state: GuardComponent.State) -> void:
	if state == GuardComponent.State.STARTUP:
		cyberware.submit_event_starters(4, guard.guard_direction, PackedStringArray(["格挡"]))
	guard_state_changed.emit(state)


func _on_attack_performed(_data: WeaponComponentData) -> void:
	cyberware.on_weapon_attack_performed(aim_direction)
	visuals.play_weapon_attack()
	combat_feedback_requested.emit(&"attack", global_position)


func _on_dash_started(direction: Vector2) -> void:
	if persona_combat.should_submit_dash_event():
		cyberware.submit_event_starters(2, direction, PackedStringArray(["突进"]))
	_afterimage_active_remaining = dash.config.dash_duration
	_afterimage_emit_remaining = 0.0
	_movement_effect_last_position = global_position
	_request_movement_effect(&"start", global_position, global_position, direction)
	_publish_movement_noise(MOBILITY_BURST_NOISE_RADIUS)
	cyberware.on_dash_started(global_position)
	dash_state_changed.emit(true, dash.cooldown_remaining)
	combat_feedback_requested.emit(&"dash", global_position)


func _on_dash_ended(cancelled: bool) -> void:
	var direction := dash.get_active_direction()
	if _movement_effect_last_position.distance_squared_to(global_position) > 1.0:
		_request_movement_effect(&"path", _movement_effect_last_position, global_position, direction)
	_request_movement_effect(&"end", global_position, global_position, direction, cancelled)
	_movement_effect_last_position = global_position
	_afterimage_active_remaining = 0.0
	dash_state_changed.emit(false, dash.cooldown_remaining)


func _on_dash_cooldown_changed(remaining: float, _total: float) -> void:
	dash_state_changed.emit(dash.is_dashing(), remaining)


func _tick_movement_noise(delta: float, input_vector: Vector2) -> void:
	var radius := get_movement_noise_radius()
	if _dead or not _input_enabled or input_vector.is_zero_approx() or velocity.length_squared() <= 64.0 or radius <= 0.0:
		_movement_noise_remaining = 0.0
		return
	_movement_noise_remaining -= delta
	if _movement_noise_remaining > 0.0:
		return
	_movement_noise_remaining = MOVEMENT_NOISE_INTERVAL
	_publish_movement_noise(radius)


func get_movement_noise_radius() -> float:
	return 90.0


func _publish_movement_noise(radius: float) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_movement_noise(self, global_position, radius)


func _tick_afterimages(delta: float, interval: float = AFTERIMAGE_INTERVAL) -> void:
	if _afterimage_active_remaining <= 0.0 or _dead:
		return
	_afterimage_active_remaining = maxf(_afterimage_active_remaining - delta, 0.0)
	_afterimage_emit_remaining -= delta
	if _afterimage_emit_remaining > 0.0:
		return
	_afterimage_emit_remaining += interval
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_afterimage(self, visuals.body_sprite)


func _tick_movement_effect() -> void:
	if not dash.is_dashing() or _dead:
		return
	if _movement_effect_last_position.distance_squared_to(global_position) < 4.0:
		return
	_request_movement_effect(
		&"path",
		_movement_effect_last_position,
		global_position,
		dash.get_active_direction()
	)
	_movement_effect_last_position = global_position


func _request_movement_effect(
	phase: StringName,
	from: Vector2,
	to: Vector2,
	direction: Vector2,
	cancelled: bool = false
) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_movement_effect(self, dash.active_effect_kind, phase, from, to, direction, cancelled)


func _clear_afterimages() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.clear_afterimages(self)


func _on_hit_resolved(result: DamageResult) -> void:
	if result.final_damage <= 0:
		return
	persona_combat.cancel_hunt_followups()
	visuals.play_hurt_flash()
	combat_feedback_requested.emit(&"hurt", global_position)


func _on_interaction_requested(_actor: Node, target: Node) -> void:
	interaction_requested.emit(target)


func _on_circuit_breaker_triggered() -> void:
	combat_feedback_requested.emit(&"circuit_breaker", global_position)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"circuit_breaker", "断路保险触发", Color(1.0, 0.8, 0.2), CombatNotice.Priority.HIGH, 0.0, 2.0)


func _on_died(packet: DamagePacket) -> void:
	_dead = true
	set_input_enabled(false)
	hurt_box.set_deferred("monitorable", false)
	visuals.set_dead(true)
	_afterimage_active_remaining = 0.0
	_clear_afterimages()
	player_died.emit(packet)
	combat_feedback_requested.emit(&"death", global_position)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"player_defeated", "行动失败。按 R 重开战斗", Color(1.0, 0.35, 0.25), CombatNotice.Priority.HIGH, 0.0, 4.0)


func _emit_public_state() -> void:
	health_changed.emit(health.current_health, health.max_health, 0)
	heat_changed.emit(heat.current_heat, heat.effective_max())
	weapon_changed.emit(weapons.get_current_weapon())
	dash_state_changed.emit(dash.is_dashing(), dash.cooldown_remaining)
	cyberware_changed.emit(cyberware.modules.duplicate())
	guard_state_changed.emit(guard.state)


func _exit_tree() -> void:
	_clear_afterimages()


func apply_channel_curse(active: bool) -> void:
	if active == channel_curse_active:
		return
	if active:
		_channel_base_config = config
		_channel_base_dash = dash.config
		_channel_base_cooling = heat.dissipation_per_second
		config = config.duplicate()
		config.max_health = 1
		dash.config = dash.config.duplicate()
		dash.config.walk_speed *= 0.85
		dash.config.dash_cooldown *= 1.4
		heat.dissipation_per_second *= 0.7

	else:
		config = _channel_base_config
		dash.config = _channel_base_dash
		heat.dissipation_per_second = _channel_base_cooling

	channel_curse_active = active
	health.configure_max_health(config.max_health, false)
	talent_core.sync_health(health.current_health)
