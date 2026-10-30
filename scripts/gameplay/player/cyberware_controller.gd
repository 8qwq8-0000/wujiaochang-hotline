class_name CyberwareController
extends Node

signal cyberware_changed(modules: PackedStringArray)
signal module_triggered(module_id: StringName)

const SMART_FIRE := &"smart_fire"
const EXPLOSIVE_MAGAZINE := &"explosive_magazine"
const TACTICAL_COPROCESSOR := &"tactical_coprocessor"
const OPTICAL_INTRUDER := &"optical_intruder"
const KILL_HEAT_SINK := &"kill_heat_sink"
const HEAT_THRESHOLD_PULSER := &"heat_threshold_pulser"
const MOMENTUM_RECOVERY_TENDON := &"momentum_recovery_tendon"
const TRAJECTORY_ECHO_PROCESSOR := &"trajectory_echo_processor"
const BALLISTIC_TAKEOVER_PROTOCOL := &"ballistic_takeover_protocol"
const ARC_BALLISTIC_CORTEX := &"arc_ballistic_cortex"
const INERTIAL_INVERSION_VERTEBRA := &"inertial_inversion_vertebra"
const AXON_RECYCLER := &"axon_recycler"
const MICRO_ROTOR_REFLEX_BUNDLE := &"micro_rotor_reflex_bundle"
const PREDATORY_VESTIBULAR_RING := &"predatory_vestibular_ring"
const ARC_ATTACK_MEMORY_SECONDS := 3.0
const AXON_ATTACK_MEMORY_SECONDS := 3.0
const MICRO_ROTOR_ATTACK_MEMORY_SECONDS := 3.0
const PREDATORY_ATTACK_MEMORY_SECONDS := 3.0

var modules: PackedStringArray = []
var _data_by_module: Dictionary = {}
var _kill_heat_sink_cooldown_remaining := 0.0
var _heat_threshold_cooldown_remaining := 0.0
var _momentum_charge_remaining := 0.0
var _trajectory_echo_cooldown_remaining := 0.0
var _ballistic_takeover_cooldown_remaining := 0.0
var _inertial_inversion_cooldown_remaining := 0.0
var _inertial_inversion_triggered_this_dash := false
var _arc_attack_groups: Dictionary = {}
var _axon_recycler_attack_groups: Dictionary = {}
var _micro_rotor_attack_groups: Dictionary = {}
var _predatory_attack_groups: Dictionary = {}
var _predatory_dash_refresh_pending := false


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
	var heat := get_parent().get_node_or_null("HeatComponent") as HeatComponent
	if heat != null:
		heat.overheated.connect(_on_overheated)
	var dash := get_parent().get_node_or_null("DashController") as DashController
	if dash != null:
		dash.dash_damaged_enemy.connect(_on_dash_damaged_enemy)
		dash.dash_ended.connect(_on_dash_ended)


func _physics_process(delta: float) -> void:
	_kill_heat_sink_cooldown_remaining = maxf(_kill_heat_sink_cooldown_remaining - delta, 0.0)
	_heat_threshold_cooldown_remaining = maxf(_heat_threshold_cooldown_remaining - delta, 0.0)
	_momentum_charge_remaining = maxf(_momentum_charge_remaining - delta, 0.0)
	_trajectory_echo_cooldown_remaining = maxf(_trajectory_echo_cooldown_remaining - delta, 0.0)
	_ballistic_takeover_cooldown_remaining = maxf(_ballistic_takeover_cooldown_remaining - delta, 0.0)
	_inertial_inversion_cooldown_remaining = maxf(_inertial_inversion_cooldown_remaining - delta, 0.0)
	_tick_arc_attack_groups(delta)
	_tick_axon_recycler_groups(delta)
	_tick_micro_rotor_attack_groups(delta)
	_tick_predatory_attack_groups(delta)
	_try_ballistic_takeover()


func set_equipped_item(item: InventoryItem) -> void:
	modules = ComponentRolls.cyberware_modules(item)
	_data_by_module.clear()
	for module_id in modules:
		var path := ComponentRolls.cyberware_resource_path(module_id)
		if not path.is_empty():
			_data_by_module[StringName(module_id)] = load(path)
	if not has_module(MOMENTUM_RECOVERY_TENDON):
		_momentum_charge_remaining = 0.0
	if not has_module(ARC_BALLISTIC_CORTEX):
		_arc_attack_groups.clear()
	if not has_module(INERTIAL_INVERSION_VERTEBRA):
		_inertial_inversion_triggered_this_dash = false
	if not has_module(AXON_RECYCLER):
		_axon_recycler_attack_groups.clear()
	if not has_module(MICRO_ROTOR_REFLEX_BUNDLE):
		_micro_rotor_attack_groups.clear()
	if not has_module(PREDATORY_VESTIBULAR_RING):
		_predatory_attack_groups.clear()
		_predatory_dash_refresh_pending = false
	cyberware_changed.emit(modules.duplicate())


func clear() -> void:
	set_equipped_item(null)


func has_module(module_id: StringName) -> bool:
	return module_id in modules


func configure_projectile(projectile: CombatProjectile, aim_direction: Vector2) -> void:
	if projectile == null:
		return
	if has_module(SMART_FIRE):
		var smart := _data(SMART_FIRE)
		var target := _acquire_target(projectile.global_position, aim_direction, smart.targeting_half_angle_degrees)
		if target != null:
			projectile.configure_homing(target, smart.homing_turn_degrees_per_second)
			module_triggered.emit(SMART_FIRE)
	if has_module(EXPLOSIVE_MAGAZINE) and not projectile.has_area_behavior:
		var explosive := _data(EXPLOSIVE_MAGAZINE)
		projectile.configure_explosion(explosive.explosion_radius, explosive.explosion_damage)
	if has_module(ARC_BALLISTIC_CORTEX):
		projectile.configure_electric_arc()


func supports_automatic_fire(data: WeaponComponentData) -> bool:
	return (
		has_module(TACTICAL_COPROCESSOR)
		and data != null
		and data.trigger_mode != WeaponComponentData.TriggerMode.CHARGE
		and data.attack_kind in [WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD]
	)


func augment_attack_context(data: WeaponComponentData, context: Dictionary) -> void:
	var existing_heat_multiplier := maxf(float(context.get("heat_multiplier", 1.0)), 0.0)
	if (
		_momentum_charge_remaining <= 0.0
		or data == null
		or data.heat_per_attack * existing_heat_multiplier <= 0.0
	):
		return
	context["momentum_free_heat"] = true
	context["heat_multiplier"] = 0.0


func on_attack_committed(data: WeaponComponentData, context: Dictionary) -> void:
	if data == null or data.heat_per_attack <= 0.0 or not bool(context.get("momentum_free_heat", false)):
		return
	_momentum_charge_remaining = 0.0
	var player := get_parent() as PlayerController
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and player != null:
		events.request_effect(player.global_position, Color(0.25, 1.0, 0.95), 16.0, 0.18)
		events.publish_notice(&"momentum_recovery_tendon_release", "动能释放", Color(0.25, 1.0, 0.95), CombatNotice.Priority.NORMAL, 0.15, 0.55)


func reset_transient_state() -> void:
	_momentum_charge_remaining = 0.0
	_predatory_dash_refresh_pending = false


func get_momentum_charge_remaining() -> float:
	return _momentum_charge_remaining


func get_module_readiness(module_id: StringName) -> float:
	if not has_module(module_id):
		return 1.0
	var data := _data(module_id)
	if data == null or data.trigger_cooldown <= 0.0:
		return 1.0
	var remaining := 0.0
	match module_id:
		TRAJECTORY_ECHO_PROCESSOR:
			remaining = _trajectory_echo_cooldown_remaining
		BALLISTIC_TAKEOVER_PROTOCOL:
			remaining = _ballistic_takeover_cooldown_remaining
		INERTIAL_INVERSION_VERTEBRA:
			remaining = _inertial_inversion_cooldown_remaining
		_:
			return 1.0
	return clampf(1.0 - remaining / data.trigger_cooldown, 0.0, 1.0)


func _try_ballistic_takeover() -> void:
	if not has_module(BALLISTIC_TAKEOVER_PROTOCOL) or _ballistic_takeover_cooldown_remaining > 0.0:
		return
	var data := _data(BALLISTIC_TAKEOVER_PROTOCOL)
	var player := get_parent() as PlayerController
	if data == null or player == null:
		return
	var player_room := CombatProjectile.room_for_actor(player)
	var best_projectile: CombatProjectile
	var best_target: Node2D
	var best_distance_squared := data.takeover_radius * data.takeover_radius
	for candidate in get_tree().get_nodes_in_group("combat_projectiles"):
		var projectile := candidate as CombatProjectile
		if (
			projectile == null
			or not is_instance_valid(projectile)
			or projectile.is_queued_for_deletion()
			or not projectile.can_be_taken_over()
			or CombatProjectile.room_for_actor(projectile) != player_room
		):
			continue
		var distance_squared := player.global_position.distance_squared_to(projectile.global_position)
		if distance_squared > best_distance_squared:
			continue
		var target := _nearest_takeover_target(projectile.global_position, data.takeover_target_radius, player_room)
		if target == null:
			continue
		best_distance_squared = distance_squared
		best_projectile = projectile
		best_target = target
	if best_projectile == null or not best_projectile.take_over(player, best_target, data.takeover_homing_turn_degrees_per_second):
		return
	if has_module(ARC_BALLISTIC_CORTEX):
		best_projectile.configure_electric_arc()
	_ballistic_takeover_cooldown_remaining = data.trigger_cooldown
	module_triggered.emit(BALLISTIC_TAKEOVER_PROTOCOL)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_glitch_scan(player.global_position, Color(0.35, 1.0, 0.4), data.takeover_radius, player_room)
		events.request_effect(best_projectile.global_position, Color(0.35, 1.0, 0.4), 10.0, 0.16)
		events.electric_arc_requested.emit(player.global_position, best_projectile.global_position, player_room)
		events.publish_notice(&"ballistic_takeover_protocol", "弹道接管", Color(0.35, 1.0, 0.4), CombatNotice.Priority.NORMAL, 0.2, 0.7)


func _nearest_takeover_target(origin: Vector2, radius: float, room: Node) -> Node2D:
	var best: Node2D
	var best_distance_squared := radius * radius
	var player := get_parent() as PlayerController
	var world := player.get_world_2d() if player != null else null
	if world == null:
		return null
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		var target_id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(target_id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != room
		):
			continue
		seen[target_id] = true
		var distance_squared := origin.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			continue
		var sight := PhysicsRayQueryParameters2D.create(origin, target.global_position, 1)
		if not world.direct_space_state.intersect_ray(sight).is_empty():
			continue
		best_distance_squared = distance_squared
		best = target
	return best


func on_dash_started(last_observed_position: Vector2) -> void:
	_inertial_inversion_triggered_this_dash = false
	if not has_module(OPTICAL_INTRUDER):
		return
	var delay: float = _data(OPTICAL_INTRUDER).optical_reacquire_delay
	var player := get_parent() as PlayerController
	if player != null:
		delay += player.dash.config.dash_duration
	for target in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(target) and target.has_method("apply_optical_disruption"):
			target.apply_optical_disruption(last_observed_position, delay)
	module_triggered.emit(OPTICAL_INTRUDER)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"optical_intruder", "光学入侵：敌方索敌中断", Color(0.35, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.25, 0.9)


func _on_damage_resolved(result: DamageResult) -> void:
	_try_inertial_inversion(result)
	_try_arc_ballistic_cortex(result)
	_try_trajectory_echo(result)
	_try_kill_heat_sink(result)
	_try_axon_recycler(result)
	_try_micro_rotor_reflex_bundle(result)
	_try_predatory_vestibular_ring(result)


func _try_kill_heat_sink(result: DamageResult) -> void:
	if (
		not has_module(KILL_HEAT_SINK)
		or _kill_heat_sink_cooldown_remaining > 0.0
		or result == null
		or not result.target_defeated
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var player := get_parent() as PlayerController
	if player == null or player.heat.current_heat <= 0.0:
		return
	var data := _data(KILL_HEAT_SINK)
	if data == null:
		return
	var target := result.target as Node2D
	player.heat.reduce_heat(player.heat.effective_max() * data.kill_cooling_ratio)
	_kill_heat_sink_cooldown_remaining = data.trigger_cooldown
	module_triggered.emit(KILL_HEAT_SINK)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(target.global_position, Color(0.25, 1.0, 0.9), 18.0, 0.22)
		events.request_effect(player.global_position, Color(0.25, 1.0, 0.9), 14.0, 0.18)
		events.electric_arc_requested.emit(
			target.global_position,
			player.global_position,
			CombatProjectile.room_for_actor(player)
		)
		events.publish_notice(&"kill_heat_sink", "击破散热", Color(0.25, 1.0, 0.9), CombatNotice.Priority.NORMAL, 0.2, 0.8)


func _try_axon_recycler(result: DamageResult) -> void:
	if (
		not has_module(AXON_RECYCLER)
		or result == null
		or not result.target_defeated
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(AXON_RECYCLER)
	if data == null:
		return
	var attack_key := _arc_attack_key(result.packet)
	if _axon_recycler_attack_groups.has(attack_key):
		return
	_axon_recycler_attack_groups[attack_key] = AXON_ATTACK_MEMORY_SECONDS
	_reduce_installed_cyberware_cooldowns(data.axon_cooldown_reduction)
	module_triggered.emit(AXON_RECYCLER)
	var target := result.target as Node2D
	var player := get_parent() as PlayerController
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and target != null and player != null:
		events.request_effect(target.global_position, Color(1.0, 0.62, 0.18), 11.0, 0.15)
		events.electric_arc_requested.emit(
			target.global_position,
			player.global_position,
			CombatProjectile.room_for_actor(player)
		)
		events.request_effect(player.global_position, Color(0.3, 0.9, 1.0), 12.0, 0.16)
		events.publish_notice(&"axon_recycler", "轴突回收  -%.2fs" % data.axon_cooldown_reduction, Color(0.45, 0.9, 1.0), CombatNotice.Priority.NORMAL, 0.2, 0.65)


func _reduce_installed_cyberware_cooldowns(seconds: float) -> void:
	var amount := maxf(seconds, 0.0)
	if has_module(KILL_HEAT_SINK):
		_kill_heat_sink_cooldown_remaining = maxf(_kill_heat_sink_cooldown_remaining - amount, 0.0)
	if has_module(HEAT_THRESHOLD_PULSER):
		_heat_threshold_cooldown_remaining = maxf(_heat_threshold_cooldown_remaining - amount, 0.0)
	if has_module(TRAJECTORY_ECHO_PROCESSOR):
		_trajectory_echo_cooldown_remaining = maxf(_trajectory_echo_cooldown_remaining - amount, 0.0)
	if has_module(BALLISTIC_TAKEOVER_PROTOCOL):
		_ballistic_takeover_cooldown_remaining = maxf(_ballistic_takeover_cooldown_remaining - amount, 0.0)
	if has_module(INERTIAL_INVERSION_VERTEBRA):
		_inertial_inversion_cooldown_remaining = maxf(_inertial_inversion_cooldown_remaining - amount, 0.0)


func _try_micro_rotor_reflex_bundle(result: DamageResult) -> void:
	if (
		not has_module(MICRO_ROTOR_REFLEX_BUNDLE)
		or result == null
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(MICRO_ROTOR_REFLEX_BUNDLE)
	var player := get_parent() as PlayerController
	if data == null or player == null or player.weapons == null:
		return
	var attack_key := _arc_attack_key(result.packet)
	var context: Dictionary = _micro_rotor_attack_groups.get(attack_key, {
		"remaining": MICRO_ROTOR_ATTACK_MEMORY_SECONDS,
		"refunded_ratio": 0.0,
	})
	var desired_ratio: float = data.micro_rotor_kill_refund_ratio if result.target_defeated else data.micro_rotor_hit_refund_ratio
	var refunded_ratio := float(context.get("refunded_ratio", 0.0))
	context["remaining"] = MICRO_ROTOR_ATTACK_MEMORY_SECONDS
	if desired_ratio <= refunded_ratio:
		_micro_rotor_attack_groups[attack_key] = context
		return
	var cooldown_duration := player.weapons.get_cooldown_duration_for_weapon_id(result.packet.weapon_id)
	if cooldown_duration <= 0.0:
		return
	var added_ratio := desired_ratio - refunded_ratio
	player.weapons.reduce_cooldown(cooldown_duration * added_ratio)
	context["refunded_ratio"] = desired_ratio
	_micro_rotor_attack_groups[attack_key] = context
	module_triggered.emit(MICRO_ROTOR_REFLEX_BUNDLE)
	var target := result.target as Node2D
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and target != null:
		events.request_effect(target.global_position, Color(0.4, 0.95, 1.0), 9.0, 0.12)
		events.request_effect(player.global_position, Color(1.0, 0.68, 0.22), 10.0, 0.14)
		events.publish_notice(&"micro_rotor_reflex_bundle", "微转子回转  %d%%" % roundi(desired_ratio * 100.0), Color(0.45, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.15, 0.55)


func _try_predatory_vestibular_ring(result: DamageResult) -> void:
	if (
		not has_module(PREDATORY_VESTIBULAR_RING)
		or result == null
		or not result.target_defeated
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.weapon_id.is_empty()
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var attack_key := _arc_attack_key(result.packet)
	if _predatory_attack_groups.has(attack_key):
		return
	_predatory_attack_groups[attack_key] = PREDATORY_ATTACK_MEMORY_SECONDS
	var player := get_parent() as PlayerController
	if player == null or player.dash == null:
		return
	var deferred_refresh := player.dash.is_dashing()
	if deferred_refresh:
		_predatory_dash_refresh_pending = true
	else:
		player.dash.refresh_cooldown()
	module_triggered.emit(PREDATORY_VESTIBULAR_RING)
	_publish_predatory_refresh_feedback(result.target as Node2D, deferred_refresh)


func _on_dash_ended(_cancelled: bool) -> void:
	if not _predatory_dash_refresh_pending:
		return
	_predatory_dash_refresh_pending = false
	if not has_module(PREDATORY_VESTIBULAR_RING):
		return
	var player := get_parent() as PlayerController
	if player == null or player.dash == null:
		return
	if is_zero_approx(player.dash.cooldown_remaining):
		return
	player.dash.refresh_cooldown()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(player.global_position, Color(0.25, 0.95, 1.0), 14.0, 0.16)
		events.publish_notice(&"predatory_vestibular_ring_ready", "突进刷新", Color(0.35, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.12, 0.5)


func _publish_predatory_refresh_feedback(target: Node2D, deferred_refresh: bool) -> void:
	var player := get_parent() as PlayerController
	var events := get_node_or_null("/root/CombatEvents")
	if events == null or player == null:
		return
	if target != null:
		events.request_effect(target.global_position, Color(1.0, 0.2, 0.18), 10.0, 0.14)
	events.request_effect(player.global_position, Color(0.3, 0.9, 1.0), 12.0, 0.15)
	var notice := "突进待刷新" if deferred_refresh else "突进刷新"
	events.publish_notice(&"predatory_vestibular_ring", notice, Color(0.35, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.15, 0.55)


func _try_inertial_inversion(result: DamageResult) -> void:
	var player := get_parent() as PlayerController
	if (
		not has_module(INERTIAL_INVERSION_VERTEBRA)
		or _inertial_inversion_cooldown_remaining > 0.0
		or _inertial_inversion_triggered_this_dash
		or result == null
		or result.packet == null
		or result.target != player
		or result.ignore_reason != DamageResult.IgnoreReason.INVULNERABLE
		or result.packet.source_faction != CombatFaction.Id.ENEMY
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or player == null
		or not player.dash.provides_invulnerability()
	):
		return
	var data := _data(INERTIAL_INVERSION_VERTEBRA)
	if data == null:
		return
	_inertial_inversion_triggered_this_dash = true
	_inertial_inversion_cooldown_remaining = data.trigger_cooldown
	var player_room := CombatProjectile.room_for_actor(player)
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		var target_id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(target_id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != player_room
			or player.global_position.distance_to(target.global_position) > data.inertia_pulse_radius
		):
			continue
		seen[target_id] = true
		var direction := player.global_position.direction_to(target.global_position)
		if direction.is_zero_approx():
			direction = -player.dash.get_active_direction()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		if target.has_method("apply_stagger"):
			target.call("apply_stagger", data.inertia_pulse_stagger_seconds)
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", direction * data.inertia_pulse_knockback)
	module_triggered.emit(INERTIAL_INVERSION_VERTEBRA)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(player.global_position, Color(0.35, 0.92, 1.0), data.inertia_pulse_radius, 0.22)
		events.request_effect(player.global_position, Color(0.9, 0.98, 1.0), data.inertia_pulse_radius * 0.55, 0.12)
		events.publish_notice(&"inertial_inversion_vertebra", "惯性逆变", Color(0.35, 0.92, 1.0), CombatNotice.Priority.NORMAL, 0.2, 0.65)


func _try_arc_ballistic_cortex(result: DamageResult) -> void:
	if (
		not has_module(ARC_BALLISTIC_CORTEX)
		or result == null
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.is_continuous_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(ARC_BALLISTIC_CORTEX)
	var player := get_parent() as PlayerController
	var origin := result.target as Node2D
	if data == null or player == null or origin == null:
		return
	var attack_key := _arc_attack_key(result.packet)
	var context: Dictionary = _arc_attack_groups.get(attack_key, {
		"remaining": ARC_ATTACK_MEMORY_SECONDS,
		"targets": {},
	})
	context["remaining"] = ARC_ATTACK_MEMORY_SECONDS
	var targets: Dictionary = context.get("targets", {})
	var target_id := origin.get_instance_id()
	if targets.has(target_id):
		_arc_attack_groups[attack_key] = context
		return
	targets[target_id] = true
	_apply_arc_paralysis(origin, data.arc_paralysis_seconds)
	var events := get_node_or_null("/root/CombatEvents")
	var room := CombatProjectile.room_for_actor(player)
	if events != null:
		var from := result.packet.source_position
		if from.is_zero_approx():
			from = player.global_position
		events.electric_arc_requested.emit(from, origin.global_position, room)
		events.request_effect(origin.global_position, Color(0.38, 0.9, 1.0), 8.0, 0.12)
	var chain_origin := origin
	for _index in data.arc_chain_targets:
		var chained := _nearest_arc_target(chain_origin.global_position, data.arc_chain_radius, room, targets)
		if chained == null:
			break
		targets[chained.get_instance_id()] = true
		_apply_arc_paralysis(chained, data.arc_paralysis_seconds)
		if events != null:
			events.electric_arc_requested.emit(chain_origin.global_position, chained.global_position, room)
			events.request_effect(chained.global_position, Color(0.38, 0.9, 1.0), 8.0, 0.12)
		chain_origin = chained
	context["targets"] = targets
	_arc_attack_groups[attack_key] = context
	module_triggered.emit(ARC_BALLISTIC_CORTEX)


func _arc_attack_key(packet: DamagePacket) -> String:
	var group_id := packet.feedback_group_id
	if group_id <= 0:
		group_id = -int(packet.get_instance_id())
	var source_id := packet.source.get_instance_id() if is_instance_valid(packet.source) else 0
	return "%d:%d" % [source_id, group_id]


func _nearest_arc_target(origin: Vector2, radius: float, room: Node, excluded: Dictionary) -> Node2D:
	var best: Node2D
	var best_distance_squared := radius * radius
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		var id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(id)
			or excluded.has(id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != room
		):
			continue
		seen[id] = true
		var distance_squared := origin.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			continue
		best_distance_squared = distance_squared
		best = target
	return best


func _apply_arc_paralysis(target: Node2D, seconds: float) -> void:
	if target.has_method("apply_paralysis"):
		target.call("apply_paralysis", seconds)
	elif target.has_method("apply_stagger"):
		target.call("apply_stagger", seconds)


func _tick_arc_attack_groups(delta: float) -> void:
	for key in _arc_attack_groups.keys():
		var context: Dictionary = _arc_attack_groups[key]
		context["remaining"] = maxf(float(context.get("remaining", 0.0)) - delta, 0.0)
		if is_zero_approx(float(context["remaining"])):
			_arc_attack_groups.erase(key)
		else:
			_arc_attack_groups[key] = context


func _tick_axon_recycler_groups(delta: float) -> void:
	for key in _axon_recycler_attack_groups.keys():
		var remaining := maxf(float(_axon_recycler_attack_groups[key]) - delta, 0.0)
		if is_zero_approx(remaining):
			_axon_recycler_attack_groups.erase(key)
		else:
			_axon_recycler_attack_groups[key] = remaining


func _tick_micro_rotor_attack_groups(delta: float) -> void:
	for key in _micro_rotor_attack_groups.keys():
		var context: Dictionary = _micro_rotor_attack_groups[key]
		context["remaining"] = maxf(float(context.get("remaining", 0.0)) - delta, 0.0)
		if is_zero_approx(float(context["remaining"])):
			_micro_rotor_attack_groups.erase(key)
		else:
			_micro_rotor_attack_groups[key] = context


func _tick_predatory_attack_groups(delta: float) -> void:
	for key in _predatory_attack_groups.keys():
		var remaining := maxf(float(_predatory_attack_groups[key]) - delta, 0.0)
		if is_zero_approx(remaining):
			_predatory_attack_groups.erase(key)
		else:
			_predatory_attack_groups[key] = remaining


func _try_trajectory_echo(result: DamageResult) -> void:
	if (
		not has_module(TRAJECTORY_ECHO_PROCESSOR)
		or _trajectory_echo_cooldown_remaining > 0.0
		or result == null
		or result.final_damage <= 0
		or result.packet == null
		or not result.packet.allows_trajectory_echo
		or result.packet.source != get_parent()
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(TRAJECTORY_ECHO_PROCESSOR)
	var player := get_parent() as PlayerController
	var origin := result.target as Node2D
	if data == null or player == null or origin == null:
		return
	var target := _nearest_echo_target(origin, data.trajectory_echo_radius)
	if target == null:
		return
	var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
	if hurt == null:
		return
	var direction := origin.global_position.direction_to(target.global_position)
	var packet := DamagePacket.new()
	packet.base_damage = maxi(int(ceil(float(result.final_damage) * data.trajectory_echo_damage_ratio)), 1)
	packet.source = player
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.weapon_id = result.packet.weapon_id
	packet.damage_type = result.packet.damage_type
	packet.allow_status_reactions = false
	packet.source_position = origin.global_position
	packet.travel_direction = direction
	packet.is_area_damage = true
	hurt.receive_hit(packet)
	_trajectory_echo_cooldown_remaining = data.trigger_cooldown
	module_triggered.emit(TRAJECTORY_ECHO_PROCESSOR)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.electric_arc_requested.emit(
			origin.global_position,
			target.global_position,
			CombatProjectile.room_for_actor(player)
		)
		events.request_effect(origin.global_position, Color(0.68, 0.3, 1.0), 11.0, 0.16)
		events.request_effect(target.global_position, Color(0.25, 0.95, 1.0), 13.0, 0.18)
		events.publish_notice(&"trajectory_echo_processor", "轨迹折射", Color(0.55, 0.55, 1.0), CombatNotice.Priority.NORMAL, 0.2, 0.65)


func _nearest_echo_target(origin: Node2D, radius: float) -> Node2D:
	var best: Node2D
	var best_distance_squared := radius * radius
	var room := CombatProjectile.room_for_actor(origin)
	var world := origin.get_world_2d()
	if world == null:
		return null
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate == origin:
			continue
		var target := candidate as Node2D
		var target_id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(target_id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != room
		):
			continue
		seen[target_id] = true
		var distance_squared := origin.global_position.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			continue
		var sight := PhysicsRayQueryParameters2D.create(origin.global_position, target.global_position, 1)
		if not world.direct_space_state.intersect_ray(sight).is_empty():
			continue
		best_distance_squared = distance_squared
		best = target
	return best


func _on_overheated() -> void:
	if not has_module(HEAT_THRESHOLD_PULSER) or _heat_threshold_cooldown_remaining > 0.0:
		return
	var player := get_parent() as PlayerController
	var data := _data(HEAT_THRESHOLD_PULSER)
	if player == null or data == null:
		return
	var player_room := CombatProjectile.room_for_actor(player)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is EnemyController or not is_instance_valid(candidate):
			continue
		var enemy := candidate as EnemyController
		if (
			CombatProjectile.room_for_actor(enemy) != player_room
			or player.global_position.distance_to(enemy.global_position) > data.overheat_pulse_radius
		):
			continue
		enemy.apply_stagger(data.overheat_pulse_stagger_seconds)
	_heat_threshold_cooldown_remaining = data.trigger_cooldown
	module_triggered.emit(HEAT_THRESHOLD_PULSER)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(player.global_position, Color(1.0, 0.28, 0.08), data.overheat_pulse_radius, 0.32)
		events.request_effect(player.global_position, Color(1.0, 0.72, 0.18), data.overheat_pulse_radius * 0.62, 0.20)
		events.publish_weapon_cue(&"cyberware", &"thermal_pulse", player.global_position)
		events.publish_notice(&"heat_threshold_pulser", "热阈释放", Color(1.0, 0.55, 0.15), CombatNotice.Priority.NORMAL, 0.2, 0.9)


func _on_dash_damaged_enemy(target: Node2D) -> void:
	if not has_module(MOMENTUM_RECOVERY_TENDON):
		return
	var data := _data(MOMENTUM_RECOVERY_TENDON)
	var player := get_parent() as PlayerController
	if data == null or player == null:
		return
	_momentum_charge_remaining = data.momentum_charge_seconds
	module_triggered.emit(MOMENTUM_RECOVERY_TENDON)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		var receiver_position := player.visuals.get_weapon_mount_global_position()
		if is_instance_valid(target):
			events.request_effect(target.global_position, Color(0.25, 1.0, 0.95), 12.0, 0.16)
			events.electric_arc_requested.emit(
				target.global_position,
				receiver_position,
				CombatProjectile.room_for_actor(player)
			)
		events.request_effect(receiver_position, Color(0.25, 1.0, 0.95), 14.0, 0.18)
		events.publish_notice(&"momentum_recovery_tendon", "零热待发", Color(0.25, 1.0, 0.95), CombatNotice.Priority.NORMAL, 0.15, data.momentum_charge_seconds)


func _data(module_id: StringName) -> CyberwareData:
	return _data_by_module.get(module_id) as CyberwareData


func _acquire_target(origin: Vector2, aim_direction: Vector2, half_angle_degrees: float) -> Node2D:
	var best: Node2D
	var best_score := INF
	var heading := aim_direction.normalized()
	if heading.is_zero_approx():
		return null
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		if CombatProjectile.room_for_actor(target) != CombatProjectile.room_for_actor(get_parent()):
			continue
		var offset := target.global_position - origin
		if offset.is_zero_approx():
			continue
		var angle := absf(rad_to_deg(heading.angle_to(offset.normalized())))
		if angle > half_angle_degrees:
			continue
		var ray := PhysicsRayQueryParameters2D.create(origin, target.global_position, 1)
		if not target.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var score := angle * 8.0 + offset.length() * 0.01
		if score < best_score:
			best_score = score
			best = target
	return best
