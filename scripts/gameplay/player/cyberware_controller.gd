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

var modules: PackedStringArray = []
var _data_by_module: Dictionary = {}
var _kill_heat_sink_cooldown_remaining := 0.0
var _heat_threshold_cooldown_remaining := 0.0


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
	var heat := get_parent().get_node_or_null("HeatComponent") as HeatComponent
	if heat != null:
		heat.overheated.connect(_on_overheated)


func _physics_process(delta: float) -> void:
	_kill_heat_sink_cooldown_remaining = maxf(_kill_heat_sink_cooldown_remaining - delta, 0.0)
	_heat_threshold_cooldown_remaining = maxf(_heat_threshold_cooldown_remaining - delta, 0.0)


func set_equipped_item(item: InventoryItem) -> void:
	modules = ComponentRolls.cyberware_modules(item)
	_data_by_module.clear()
	for module_id in modules:
		var path := ComponentRolls.cyberware_resource_path(module_id)
		if not path.is_empty():
			_data_by_module[StringName(module_id)] = load(path)
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


func supports_automatic_fire(data: WeaponComponentData) -> bool:
	return (
		has_module(TACTICAL_COPROCESSOR)
		and data != null
		and data.trigger_mode != WeaponComponentData.TriggerMode.CHARGE
		and data.attack_kind in [WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD]
	)


func on_dash_started(last_observed_position: Vector2) -> void:
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
