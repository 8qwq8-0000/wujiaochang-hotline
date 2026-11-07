class_name CodexCompanion
extends CharacterBody2D

const SPAWN_OFFSET := Vector2(-32, 0)
const ESCORT_SPEED := 50.0
var player: PlayerController
var escort_complete := false
var protected_by_altar := false
var follow_player := false
var walk_target := Vector2.INF
var _flash := 0.0
@onready var health: HealthComponent = $HealthComponent
@onready var hurt_box: HurtBox2DComponent = $HurtBox
@onready var visual: DragonSpriteAnimator = $DragonVisual
@onready var navigation: NavigationAgent2D = $NavigationAgent2D
@onready var run: Node = get_node("/root/RunManager")


static func spawn(parent: Node2D, actor: PlayerController, point: Vector2) -> CodexCompanion:
	var existing := parent.get_node_or_null("CodexCompanion") as CodexCompanion
	if existing != null:
		return existing
	var escort: CodexCompanion = load("res://scenes/actors/companions/codex_companion.tscn").instantiate()
	escort.player = actor
	escort.position = parent.to_local(point + SPAWN_OFFSET)
	parent.add_child(escort)
	return escort


func _ready() -> void:
	add_to_group("companions")
	add_to_group("status_actors")
	health.set_current_health(int(run.codex_companion.get("health", 0)))
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	queue_redraw()


func should_ignore_damage(packet: DamagePacket) -> bool:
	return protected_by_altar or escort_complete or health.is_dead() or packet.source_faction == CombatFaction.Id.PLAYER


func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	_flash = maxf(0, _flash - delta)
	visual.modulate = Color("ffacb9") if _flash > 0 else Color.WHITE
	var goal := walk_target
	if follow_player and is_instance_valid(player):
		goal = player.global_position if global_position.distance_to(player.global_position) > 40 else Vector2.INF
	if health.is_dead() or not is_instance_valid(player) or not player.is_input_enabled() or player.health.is_dead() or goal == Vector2.INF or global_position.distance_to(goal) <= 6:
		visual.update_motion(Vector2.ZERO)
		return
	var next := goal
	var nav_map := navigation.get_navigation_map()
	if nav_map.is_valid() and NavigationServer2D.map_get_iteration_id(nav_map) > 0:
		if not navigation.target_position.is_equal_approx(goal):
			navigation.target_position = goal
		var path_point := navigation.get_next_path_position()
		if not navigation.is_navigation_finished() and path_point.distance_squared_to(global_position) > 1:
			next = path_point
	var ray := PhysicsRayQueryParameters2D.create(global_position, next, 129)
	var before := global_position
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		visual.update_motion(Vector2.ZERO)
		return
	var speed := player.dash.config.walk_speed if follow_player else ESCORT_SPEED
	velocity = global_position.direction_to(next) * minf(speed, global_position.distance_to(next) / maxf(delta, 0.001))
	move_and_slide()
	visual.update_motion((global_position - before) / maxf(delta, 0.001), player.visuals.body_sprite)


func _on_health_changed(current: int, _maximum: int, delta: int) -> void:
	run.codex_companion.health = current
	if current == 0:
		run.codex_companion.arrived = false
	if delta < 0:
		_flash = 0.18
	if delta != 0:
		if not run.save_codex_progress():
			get_node("/root/CombatEvents").publish_message("Codex 同行状态保存失败，请留意存档空间")
	queue_redraw()


func _on_died(_packet: DamagePacket) -> void:
	velocity = Vector2.ZERO
	remove_from_group("companions")
	remove_from_group("status_actors")
	hurt_box.set_deferred("collision_layer", 0)
	visual.update_motion(Vector2.ZERO)
	visual.rotation = -PI * 0.5
	visual.modulate = Color(0.65, 0.5, 0.55, 0.65)
	get_node("/root/CombatEvents").publish_message("Codex 已倒下。继续登楼，按原计划摧毁中枢。")
	set_physics_process(false)
	queue_redraw()
