class_name PlayerController
extends CharacterBody2D

@onready var health: HealthComponent = $HealthComponent
@onready var heat: HeatComponent = $HeatComponent
@onready var guard: GuardComponent = $GuardComponent
@onready var mobility: MobilityController = $MobilityController
@onready var weapons: WeaponController = $WeaponController
@onready var hurt_box: HurtBox2DComponent = $HurtBox

var aim_direction := Vector2.RIGHT
var _external_velocity := Vector2.ZERO
var _dead := false


func _ready() -> void:
	add_to_group("player")
	hurt_box.faction = CombatFaction.Id.PLAYER
	guard.heat_refund_requested.connect(heat.reduce_heat)
	guard.state_changed.connect(func(_state: GuardComponent.State) -> void: queue_redraw())
	health.died.connect(_on_died)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _dead or $ComponentInventory.is_open or event.is_echo():
		return
	if event.is_action_pressed("guard"):
		guard.begin_guard(aim_direction)
	if event.is_action_pressed("mobility_ability"):
		mobility.activate_ability(self, aim_direction)
	if event.is_action_pressed("weapon_switch"):
		weapons.cycle_weapon(1)
	if event.is_action_pressed("weapon_next"):
		weapons.cycle_weapon(1)
	if event.is_action_pressed("weapon_previous"):
		weapons.cycle_weapon(-1)
	for index in 4:
		if event.is_action_pressed("mobility_%d" % (index + 1)):
			mobility.set_mode(index)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		return
	aim_direction = global_position.direction_to(get_global_mouse_position())
	if aim_direction.is_zero_approx():
		aim_direction = Vector2.RIGHT
	guard.update_direction(aim_direction)
	var input_vector := Vector2.ZERO if $ComponentInventory.is_open else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not _external_velocity.is_zero_approx():
		velocity += _external_velocity
		_external_velocity = _external_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	mobility.tick(self, input_vector, aim_direction, delta)
	if not $ComponentInventory.is_open and Input.is_action_pressed("attack") and guard.can_attack():
		weapons.try_attack(global_position, aim_direction, self)
	queue_redraw()


func apply_knockback(force: Vector2) -> void:
	_external_velocity += force * mobility.get_knockback_multiplier()


func _on_died(_packet: DamagePacket) -> void:
	_dead = true
	modulate = Color(0.4, 0.4, 0.4, 0.7)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_message("线路中断：按 R 重开战斗", Color(1.0, 0.35, 0.25))


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.75, 1.0))
	draw_line(Vector2.ZERO, aim_direction * 18.0, Color.WHITE, 2.0)
	if guard.is_guard_active():
		var half_arc := deg_to_rad(guard.guard_arc_degrees * 0.5)
		var center_angle := aim_direction.angle()
		var color := Color(1.0, 0.75, 0.15) if guard.state == GuardComponent.State.PERFECT else Color(0.25, 0.8, 1.0)
		draw_arc(Vector2.ZERO, 19.0, center_angle - half_arc, center_angle + half_arc, 20, color, 3.0)
