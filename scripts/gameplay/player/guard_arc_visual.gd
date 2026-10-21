class_name GuardArcVisual
extends Node2D

const SHIELD_TEXTURE := preload("res://assets/art/vfx/player/parry_shield.png")
const DIRECTION_TEXTURES := {
	&"right": SHIELD_TEXTURE,
	&"left": preload("res://assets/art/vfx/player/parry_cardinal_v2/left.png"),
	&"up": preload("res://assets/art/vfx/player/parry_cardinal_v2/up.png"),
	&"down": preload("res://assets/art/vfx/player/parry_cardinal_v2/down.png"),
}
const DIRECTION_VECTORS := {&"right": Vector2.RIGHT, &"left": Vector2.LEFT, &"up": Vector2.UP, &"down": Vector2.DOWN}
const PERFECT_FLASH_SECONDS := 0.08

@export var guard_path := NodePath("../../GuardComponent")
@export var body_center := Vector2(0.0, -29.0)
@export var shield_distance := 22.0
@export var canvas_size := 72.0

var shield_sprite: Sprite2D
var direction_name: StringName = &"right"
var _guard: GuardComponent
var _direction := Vector2.RIGHT
var _perfect_flash_remaining := 0.0
var _disabled := false


func _ready() -> void:
	shield_sprite = Sprite2D.new()
	shield_sprite.name = "ShieldSprite"
	shield_sprite.texture = SHIELD_TEXTURE
	shield_sprite.hframes = 3
	shield_sprite.vframes = 3
	shield_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shield_sprite.scale = Vector2.ONE * canvas_size / (SHIELD_TEXTURE.get_width() / 3.0)
	add_child(shield_sprite)
	_guard = get_node_or_null(guard_path) as GuardComponent
	if _guard != null:
		_guard.state_changed.connect(_on_state_changed)
		_guard.perfect_guarded.connect(_on_perfect_guarded)
	_refresh()


func _process(delta: float) -> void:
	_perfect_flash_remaining = maxf(0.0, _perfect_flash_remaining - delta)
	_refresh()


func update_guard(_state: GuardComponent.State, direction: Vector2, _arc_degrees: float) -> void:
	if not direction.is_zero_approx():
		_direction = direction.normalized()
	_refresh()


func set_disabled(disabled: bool) -> void:
	_disabled = disabled
	_perfect_flash_remaining = 0.0
	_refresh()


func _on_state_changed(state: GuardComponent.State) -> void:
	if state == GuardComponent.State.IDLE or state == GuardComponent.State.STARTUP:
		_perfect_flash_remaining = 0.0
	_refresh()


func _on_perfect_guarded(_result: DamageResult) -> void:
	# A successful reflection enters NORMAL immediately; briefly keep the peak.
	_perfect_flash_remaining = PERFECT_FLASH_SECONDS
	_refresh()


func _refresh() -> void:
	if shield_sprite == null:
		return
	shield_sprite.visible = not _disabled and _guard != null and _guard.state != GuardComponent.State.IDLE
	if not shield_sprite.visible:
		return
	shield_sprite.position = body_center + _direction * shield_distance
	if absf(_direction.y) > absf(_direction.x) * 0.75:
		direction_name = &"up" if _direction.y < 0.0 else &"down"
	else:
		direction_name = &"left" if _direction.x < 0.0 else &"right"
	shield_sprite.texture = DIRECTION_TEXTURES[direction_name]
	var authored_direction: Vector2 = DIRECTION_VECTORS[direction_name]
	# Cardinal views use their own nine-frame art; diagonal aim adds only the residual turn.
	shield_sprite.rotation = wrapf(_direction.angle() - authored_direction.angle(), -PI, PI)
	# Negative world Z can hide the upward shield below the floor. Keep it on the
	# body's Z and order it before the body instead.
	z_index = 0 if direction_name == &"up" else 3
	var body := get_parent().get_node_or_null("BodyVisual")
	if direction_name == &"up" and body != null and get_index() > body.get_index():
		get_parent().move_child(self, body.get_index())
	var progress := _guard.get_state_progress()
	match _guard.state:
		GuardComponent.State.STARTUP:
			shield_sprite.frame = mini(3, int(progress * 4.0))
		GuardComponent.State.PERFECT:
			shield_sprite.frame = 4
		GuardComponent.State.NORMAL:
			shield_sprite.frame = 4 if _perfect_flash_remaining > 0.0 else 5 + mini(1, int(progress * 2.0))
		GuardComponent.State.RECOVERY:
			shield_sprite.frame = 7 + mini(1, int(progress * 2.0))
