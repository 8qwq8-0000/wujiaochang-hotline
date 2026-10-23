extends Node

## 战斗表现层只监听这里，不直接依赖武器、敌人或玩家实现。
signal noise_emitted(source: Node, origin: Vector2, radius: float)
signal movement_noise_emitted(source: Node, origin: Vector2, radius: float)
signal enemy_alerted(enemy: Node, world_position: Vector2)
signal effect_requested(world_position: Vector2, color: Color, radius: float, duration: float)

signal electric_arc_requested(from: Vector2, to: Vector2, room: Node)
signal environment_discharge_requested(position: Vector2, radius: float)

signal fuel_explosion_requested(position: Vector2, radius: float)

signal damage_resolved(result: DamageResult)
signal enemy_attack_performed(source: Node, damage_type: StringName, is_melee: bool)
signal perfect_guarded(result: DamageResult)
signal entity_defeated(entity: Node)
signal room_cleared(room: Node)
signal combat_area_progress(index: int, total: int, remaining: int, cleared: bool)
signal floor_cleared
signal combat_message_requested(text: String, color: Color)
signal combat_notice_requested(notice: CombatNotice)
signal operator_communication_requested(text: String)
signal weapon_cue_requested(weapon_id: StringName, cue: StringName, world_position: Vector2)
signal afterimage_requested(source: Node, sprite: AnimatedSprite2D)
signal path_afterimage_requested(source: Node, sprite: AnimatedSprite2D, world_position: Vector2)
signal afterimages_clear_requested(source: Node)
signal movement_effect_requested(
	source: Node,
	effect_kind: StringName,
	phase: StringName,
	from: Vector2,
	to: Vector2,
	direction: Vector2,
	cancelled: bool
)
signal combat_moment_requested(kind: StringName, world_position: Vector2)
signal low_health_pulse_requested


func publish_damage(result: DamageResult) -> void:
	damage_resolved.emit(result)
	if result.outcome == DamageResult.Outcome.PERFECT_BLOCKED or result.outcome == DamageResult.Outcome.REFLECTED:
		perfect_guarded.emit(result)


func publish_enemy_attack(source: Node, damage_type: StringName, is_melee: bool) -> void:
	if is_instance_valid(source):
		enemy_attack_performed.emit(source, damage_type, is_melee)


func publish_defeat(entity: Node) -> void:
	entity_defeated.emit(entity)


func publish_room_cleared(room: Node) -> void:
	room_cleared.emit(room)


func publish_floor_cleared() -> void:
	floor_cleared.emit()


func publish_message(text: String, color: Color = Color.WHITE) -> void:
	combat_message_requested.emit(text, color)


func publish_notice(
	id: StringName,
	text: String,
	color: Color = Color.WHITE,
	priority: CombatNotice.Priority = CombatNotice.Priority.NORMAL,
	merge_window: float = 0.0,
	display_seconds: float = 1.5
) -> void:
	combat_notice_requested.emit(CombatNotice.new(id, text, color, priority, merge_window, display_seconds))


func publish_operator_communication(text: String) -> void:
	if not text.is_empty():
		operator_communication_requested.emit(text)


func publish_noise(source: Node, origin: Vector2, radius: float) -> void:
	if is_instance_valid(source) and source.is_inside_tree() and radius > 0.0:
		noise_emitted.emit(source, origin, radius)


func publish_movement_noise(source: Node, origin: Vector2, radius: float) -> void:
	if is_instance_valid(source) and source.is_inside_tree() and radius > 0.0:
		movement_noise_emitted.emit(source, origin, radius)


func publish_enemy_alert(enemy: Node, world_position: Vector2) -> void:
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		enemy_alerted.emit(enemy, world_position)


func request_effect(world_position: Vector2, color: Color, radius: float, duration: float = 0.18) -> void:
	if radius > 0.0 and duration > 0.0:
		effect_requested.emit(world_position, color, radius, duration)


func publish_weapon_cue(weapon_id: StringName, cue: StringName, world_position: Vector2) -> void:
	weapon_cue_requested.emit(weapon_id, cue, world_position)


func request_afterimage(source: Node, sprite: AnimatedSprite2D) -> void:
	if is_instance_valid(source) and is_instance_valid(sprite):
		afterimage_requested.emit(source, sprite)


func request_path_afterimage(source: Node, sprite: AnimatedSprite2D, world_position: Vector2) -> void:
	if is_instance_valid(source) and is_instance_valid(sprite):
		path_afterimage_requested.emit(source, sprite, world_position)


func clear_afterimages(source: Node) -> void:
	if is_instance_valid(source):
		afterimages_clear_requested.emit(source)


func request_movement_effect(
	source: Node,
	effect_kind: StringName,
	phase: StringName,
	from: Vector2,
	to: Vector2,
	direction: Vector2,
	cancelled: bool = false
) -> void:
	if is_instance_valid(source):
		movement_effect_requested.emit(source, effect_kind, phase, from, to, direction, cancelled)


func publish_combat_moment(kind: StringName, world_position: Vector2) -> void:
	combat_moment_requested.emit(kind, world_position)


func publish_low_health_pulse() -> void:
	low_health_pulse_requested.emit()
