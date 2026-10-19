class_name PlayerController
extends CharacterBody2D

signal health_changed(current: int, maximum: int, delta: int)
signal heat_changed(current: float, maximum: float)
signal weapon_changed(data: WeaponComponentData)
signal mobility_changed(mode: MobilityMode)
signal guard_state_changed(state: GuardComponent.State)
signal input_enabled_changed(enabled: bool)
signal interaction_requested(target: Node)
signal combat_feedback_requested(cue: StringName, world_position: Vector2)
signal player_died(packet: DamagePacket)

const DEFAULT_CONFIG := preload("res://resources/player/default_player_config.tres")
const FLIGHT_LOOP := preload("res://assets/audio/sfx/mobility/flight_loop.wav")
const AFTERIMAGE_INTERVAL := 0.05
const MOVEMENT_NOISE_INTERVAL := 0.35
const MOBILITY_BURST_NOISE_RADIUS := 220.0

@export var config: CombatPlayerConfig = DEFAULT_CONFIG

@onready var inventory: ComponentInventory = $ComponentInventory
@onready var health: HealthComponent = $HealthComponent
@onready var heat: HeatComponent = $HeatComponent
@onready var guard: GuardComponent = $GuardComponent
@onready var mobility: MobilityController = $MobilityController
@onready var weapons: WeaponController = $WeaponController
@onready var statuses: StatusComponent = $StatusComponent
@onready var talent_core: TalentCoreController = $TalentCoreController
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
var _afterimage_active_remaining := 0.0
var _afterimage_emit_remaining := 0.0
var _movement_noise_remaining := 0.0


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
	mobility.configure(config.default_mobility, config.debug_loadout_enabled)
	guard.heat_refund_requested.connect(heat.reduce_heat)
	guard.state_changed.connect(_on_guard_state_changed)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	heat.heat_changed.connect(_on_heat_changed)
	heat.overheated.connect(_on_overheated)
	heat.recovered.connect(_on_heat_recovered)
	weapons.weapon_changed.connect(_on_weapon_changed)
	weapons.attack_performed.connect(_on_attack_performed)
	mobility.mode_changed.connect(_on_mobility_changed)
	mobility.ability_activated.connect(_on_mobility_activated)
	hurt_box.hit_resolved.connect(_on_hit_resolved)
	interactor.interaction_requested.connect(_on_interaction_requested)
	circuit_breaker.circuit_breaker_triggered.connect(_on_circuit_breaker_triggered)
	if not config.debug_loadout_enabled:
		inventory._apply_equipment()
	_emit_public_state()


func _unhandled_input(event: InputEvent) -> void:
	if _dead or not _input_enabled or inventory.is_open or event.is_echo():
		return
	if event.is_action_pressed("attack"):
		_attack_pressed = true
		_attack_held = true
	if event.is_action_released("attack"):
		_attack_released = true
		_attack_held = false
	if event.is_action_pressed("guard") and mobility.can_guard():
		guard.begin_guard(aim_direction)
	if event.is_action_pressed("mobility_ability"):
		mobility.activate_ability(self, aim_direction, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		interactor.request_interaction(self)
	if event.is_action_pressed("weapon_switch") or event.is_action_pressed("weapon_next"):
		weapons.cycle_weapon(1)
	if event.is_action_pressed("weapon_previous"):
		weapons.cycle_weapon(-1)
	if config.debug_loadout_enabled:
		for index in 4:
			if event.is_action_pressed("mobility_%d" % (index + 1)):
				mobility.set_mode(index)


func _physics_process(delta: float) -> void:
	_update_aim_direction()
	var weapon_aim_direction := _get_weapon_aim_direction()
	guard.update_direction(aim_direction)
	if _dead:
		velocity = Vector2.ZERO
		_update_movement_audio()
		visuals.update_visual(aim_direction, Vector2.ZERO, guard.state, guard.guard_arc_degrees)
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down") if _input_enabled else Vector2.ZERO
	mobility.tick(self, input_vector, aim_direction, delta, _external_velocity)
	_tick_movement_noise(delta, input_vector)
	_external_velocity = _external_velocity.move_toward(Vector2.ZERO, config.knockback_recovery * delta)
	weapons.update_attack_pose(global_position, aim_direction, self)
	# The muzzle must use this frame's aim before an attack is spawned.
	visuals.update_visual(aim_direction, velocity, guard.state, guard.guard_arc_degrees, weapons.get_melee_swing_angle_offset(), get_global_mouse_position())
	if _input_enabled and guard.can_attack() and mobility.can_attack() and _should_attack_this_frame():
		var attack := _get_attack_transform()
		weapons.try_attack(attack.origin, attack.x.normalized(), self)
	_attack_pressed = false
	_attack_released = false
	_update_camera(delta)
	visuals.update_visual(
		aim_direction,
		velocity,
		guard.state,
		guard.guard_arc_degrees,
		weapons.get_melee_swing_angle_offset(),
		get_global_mouse_position()
	)
	_tick_afterimages(delta)
	_update_movement_audio()


func set_input_enabled(enabled: bool) -> void:
	if _input_enabled == enabled:
		return
	_input_enabled = enabled
	_attack_pressed = false
	_attack_released = false
	_attack_held = false
	if not enabled:
		velocity = Vector2.ZERO
	input_enabled_changed.emit(enabled)


func is_input_enabled() -> bool:
	return _input_enabled and not _dead


func equip_weapon(data: WeaponComponentData) -> void:
	weapons.equip_weapon(data)


func equip_mobility(data: MobilityMode) -> void:
	mobility.equip_mode(data)


func unequip_mobility() -> void:
	mobility.unequip_mode()


func set_circuit_breaker_equipped(equipped: bool) -> void:
	circuit_breaker.set_equipped(equipped)


func set_combat_protocol(protocol_id: StringName) -> bool:
	return talent_core.set_protocol(protocol_id)


func set_protocol_talent(protocol_id: StringName, tier: int, talent_id: StringName) -> bool:
	return talent_core.set_talent_choice(protocol_id, tier, talent_id)


func respec_protocol(protocol_id: StringName) -> bool:
	return talent_core.respec_protocol(protocol_id)


func refill_ai_takeover_charges() -> void:
	talent_core.refill_takeover_charges()


func apply_knockback(force: Vector2) -> void:
	_external_velocity += force * mobility.get_knockback_multiplier()


func repair(amount: int) -> int:
	return health.repair(amount)


func receive_damage(packet: DamagePacket) -> DamageResult:
	return hurt_box.receive_hit(packet)


func get_health_state() -> Dictionary:
	return {"current": health.current_health, "maximum": health.max_health}


func get_heat_state() -> Dictionary:
	return {"current": heat.current_heat, "maximum": heat.effective_max(), "overheated": heat.is_overheated}


func get_weapon_display_name() -> String:
	var data := weapons.get_current_weapon()
	return data.display_name if data != null else "无"


func get_mobility_display_name() -> String:
	var mode := mobility.get_current_mode()
	return mode.display_name if mode != null else "步行（无套件）"


func get_guard_state() -> GuardComponent.State:
	return guard.state


func export_run_state() -> Dictionary:
	var weapon := weapons.get_current_weapon()
	var mode := mobility.get_current_mode()
	return {
		"inventory": inventory.export_run_state(),
		"current_health": health.current_health,
		"weapon_id": String(weapon.id) if weapon != null else "",
		"mobility_id": String(mode.id) if mode != null else "walk",
		"talent_core": talent_core.export_state(),
		"circuit_breaker": circuit_breaker.export_state(),
	}


func import_run_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("inventory") and state["inventory"] is Dictionary:
		inventory.import_run_state(state["inventory"])
	elif state.has("weapon_id"):
		weapons.equip_weapon_by_id(StringName(state["weapon_id"]))
	if not state.has("inventory") and state.has("mobility_id"):
		mobility.equip_mode_by_id(StringName(state["mobility_id"]))
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
	reset_transient_state()


func export_recovery_state() -> Dictionary:
	var state := export_run_state()
	state.inventory = inventory.export_recovery_inventory()
	state.current_health = config.max_health
	state.circuit_breaker.equipped = inventory.blackbox_slot.get_item() != null and inventory.blackbox_slot.get_item().get_property("slot", "") == "insurance"
	return state


func reset_transient_state() -> void:
	var room_buff := get_node_or_null("RoomBuffComponent")
	if room_buff != null:
		room_buff.clear()
	heat.set_heat(0.0)
	heat.is_overheated = false
	statuses.clear_all()
	guard.reset_to_idle()
	mobility.reset_transient_state()
	weapons.reset_transient_state()
	hurt_box.clear_invulnerability()
	_external_velocity = Vector2.ZERO
	_attack_pressed = false
	_attack_released = false
	_attack_held = false
	_afterimage_active_remaining = 0.0
	_afterimage_emit_remaining = 0.0
	_movement_noise_remaining = 0.0
	_clear_afterimages()


func _update_aim_direction() -> void:
	var mouse_delta := get_global_mouse_position() - global_position
	if mouse_delta.length() > config.aim_deadzone:
		aim_direction = mouse_delta.normalized()


func _get_weapon_aim_direction() -> Vector2:
	var data := weapons.get_current_weapon()
	if data == null or data.attack_kind == WeaponComponentData.AttackKind.MELEE:
		return aim_direction
	var direction := get_global_mouse_position() - visuals.get_weapon_mount_global_position()
	return direction.normalized() if direction.length_squared() > 1.0 else aim_direction


func _update_camera(delta: float) -> void:
	var target := aim_direction * config.camera_look_ahead
	var weight := clampf(config.camera_look_ahead_response * delta, 0.0, 1.0)
	camera.position = camera.position.lerp(target, weight)


func _configure_movement_audio() -> void:
	movement_loop.bus = &"SFX"


func _update_movement_audio() -> void:
	var mode := mobility.get_current_mode()
	var desired_stream: AudioStream
	if mode != null and mode.id == &"flight":
		desired_stream = FLIGHT_LOOP
	if movement_loop.stream != desired_stream:
		movement_loop.stop()
		movement_loop.stream = desired_stream
	var should_play := not _dead and _input_enabled and velocity.length_squared() > 64.0
	if desired_stream != null and should_play:
		if not movement_loop.playing:
			movement_loop.play()
	elif movement_loop.playing:
		movement_loop.stop()


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
	match data.trigger_mode:
		WeaponComponentData.TriggerMode.AUTOMATIC:
			return _attack_held
		WeaponComponentData.TriggerMode.CHARGE:
			return _attack_released
		_:
			return _attack_pressed


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
	visuals.set_weapon(data)
	weapon_changed.emit(data)


func _on_mobility_changed(_index: int, mode: MobilityMode) -> void:
	_afterimage_active_remaining = 0.0
	_afterimage_emit_remaining = 0.0
	mobility_changed.emit(mode)


func _on_guard_state_changed(state: GuardComponent.State) -> void:
	guard_state_changed.emit(state)


func _on_attack_performed(_data: WeaponComponentData) -> void:
	visuals.play_weapon_attack()
	combat_feedback_requested.emit(&"attack", global_position)


func _on_mobility_activated(mode: MobilityMode) -> void:
	if mode != null and mode.id != &"walk" and mode.ability_active_seconds > 0.0:
		_afterimage_active_remaining = mode.ability_active_seconds
		_afterimage_emit_remaining = 0.0
		_publish_movement_noise(MOBILITY_BURST_NOISE_RADIUS)
	combat_feedback_requested.emit(&"mobility", global_position)


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
	var mode := mobility.get_current_mode()
	if mode == null:
		return 90.0
	match mode.id:
		&"flight":
			return 0.0
		&"quadruped":
			return 140.0
		&"wheel":
			return 180.0
		_:
			return 90.0


func _publish_movement_noise(radius: float) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_movement_noise(self, global_position, radius)


func _tick_afterimages(delta: float) -> void:
	if _afterimage_active_remaining <= 0.0 or _dead:
		return
	_afterimage_active_remaining = maxf(_afterimage_active_remaining - delta, 0.0)
	_afterimage_emit_remaining -= delta
	if _afterimage_emit_remaining > 0.0:
		return
	_afterimage_emit_remaining += AFTERIMAGE_INTERVAL
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_afterimage(self, visuals.body_sprite)


func _clear_afterimages() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.clear_afterimages(self)


func _on_hit_resolved(result: DamageResult) -> void:
	if result.final_damage <= 0:
		return
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
		events.publish_notice(&"player_defeated", "线路中断 · 按 R 重开战斗", Color(1.0, 0.35, 0.25), CombatNotice.Priority.HIGH, 0.0, 4.0)


func _emit_public_state() -> void:
	health_changed.emit(health.current_health, health.max_health, 0)
	heat_changed.emit(heat.current_heat, heat.effective_max())
	weapon_changed.emit(weapons.get_current_weapon())
	mobility_changed.emit(mobility.get_current_mode())
	guard_state_changed.emit(guard.state)


func _exit_tree() -> void:
	_clear_afterimages()
