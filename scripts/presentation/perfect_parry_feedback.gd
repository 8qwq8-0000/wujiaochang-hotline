class_name PerfectParryFeedback
extends Node2D

const TEXTURE := preload("res://assets/art/ui/feedback/perfect_purple.png")
const COMBO_SECONDS := 1.2
const DISPLAY_SECONDS := 0.7
const WIDTH := 72.0
const GROW_SECONDS := 0.22
var sprite: Sprite2D
var combo_count := 0
var popups_shown := 0
var _remaining := 0.0
var _elapsed := 0.0
var _player_id := 0
var _origin := Vector2.ZERO


func _ready() -> void:
	z_index = 100
	sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = false
	add_child(sprite)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)


func _process(delta: float) -> void:
	if combo_count > 0:
		_remaining -= delta
		if _remaining <= 0.0:
			combo_count = 0
	if not sprite.visible:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / DISPLAY_SECONDS, 0.0, 1.0)
	var growth := clampf(_elapsed / GROW_SECONDS, 0.0, 1.0)
	var pop := lerpf(0.15, 1.0, 1.0 - pow(1.0 - growth, 3.0))
	sprite.scale = Vector2.ONE * WIDTH / TEXTURE.get_width() * pop
	sprite.global_position = _origin + Vector2(0, -12.0 * progress)
	sprite.modulate.a = 1.0 - clampf((progress - 0.6) / 0.4, 0.0, 1.0)
	if progress >= 1.0:
		sprite.visible = false


func _on_damage_resolved(result: DamageResult) -> void:
	if get_tree().paused or not is_instance_valid(result.target) or not result.target is PlayerController:
		return
	var player := result.target as PlayerController
	if _player_id != player.get_instance_id():
		clear()
		_player_id = player.get_instance_id()
	if result.outcome in [DamageResult.Outcome.BLOCKED, DamageResult.Outcome.DAMAGED]:
		combo_count = 0
		return
	if result.outcome not in [DamageResult.Outcome.PERFECT_BLOCKED, DamageResult.Outcome.REFLECTED]:
		return
	combo_count = mini(combo_count + 1, 2)
	_remaining = COMBO_SECONDS
	if combo_count < 2:
		return
	popups_shown += 1
	_origin = player.global_position + Vector2(0, -72)
	_elapsed = 0.0
	sprite.visible = true
	sprite.modulate.a = 1.0
	_process(0.0)


func clear() -> void:
	combo_count = 0
	_remaining = 0.0
	_player_id = 0
	if is_instance_valid(sprite):
		sprite.visible = false
