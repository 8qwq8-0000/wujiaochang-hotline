class_name WeaponView
extends Node2D

signal cue_requested(weapon_id: StringName, cue: StringName, world_position: Vector2)

const COATING_SCRIPT := preload("res://scripts/presentation/procedural_coating_2d.gd")

@export var body_root_path: NodePath = NodePath("BodyRoot")
@export var muzzle_socket_path: NodePath = NodePath("MuzzleSocket")
@export var effect_socket_path: NodePath = NodePath("EffectSocket")
@export var muzzle_flash_path: NodePath = NodePath("MuzzleSocket/MuzzleFlash")
@export var melee_trail_path: NodePath = NodePath("EffectSocket/MeleeTrail")
@export var coating_path: NodePath = NodePath("BodyRoot/Coating")
@export_range(0.0, 16.0, 0.5) var recoil_distance: float = 3.0
@export_range(0.01, 0.5, 0.01) var feedback_seconds: float = 0.08
@export_range(0.0, 2.0, 0.01) var muzzle_flash_hold_seconds: float = 0.0
@export_range(0.01, 1.0, 0.01) var muzzle_flash_fade_seconds: float = 0.06

var data: WeaponComponentData
var _feedback_tween: Tween
var _body_position := Vector2.ZERO
var _body_scale := Vector2.ONE

@onready var body_root: Node2D = get_node_or_null(body_root_path) as Node2D
@onready var muzzle_socket: Marker2D = get_node_or_null(muzzle_socket_path) as Marker2D
@onready var effect_socket: Marker2D = get_node_or_null(effect_socket_path) as Marker2D
@onready var muzzle_flash: CanvasItem = get_node_or_null(muzzle_flash_path) as CanvasItem
@onready var melee_trail: CanvasItem = get_node_or_null(melee_trail_path) as CanvasItem
@onready var coating: Variant = get_node_or_null(coating_path)


func _ready() -> void:
	if body_root != null:
		_body_position = body_root.position
		_body_scale = body_root.scale
	cancel_feedback()


func configure(weapon_data: WeaponComponentData) -> void:
	data = weapon_data
	if coating == null:
		coating = get_node_or_null(coating_path)
	if coating != null and data != null:
		var run_seed := 0
		var run_manager := get_node_or_null("/root/RunManager")
		if run_manager != null:
			run_seed = int(run_manager.run_seed)
		coating.configure(hash("%d:%s" % [run_seed, data.id]), data.id)


func play_equip() -> void:
	cancel_feedback()
	if body_root == null:
		return
	body_root.scale = _body_scale * 0.8
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(body_root, "scale", _body_scale, 0.07)


func play_attack() -> void:
	cancel_feedback()
	if data == null:
		return
	if data.attack_kind == WeaponComponentData.AttackKind.MELEE:
		_play_melee_feedback()
		cue_requested.emit(data.id, &"swing", global_position)
	else:
		_play_projectile_feedback()
		cue_requested.emit(data.id, &"fire", get_muzzle_global_position())


func cancel_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null
	if body_root != null:
		body_root.position = _body_position
		body_root.scale = _body_scale
	_reset_effect(muzzle_flash)
	_reset_effect(melee_trail)


func get_muzzle_global_position() -> Vector2:
	return muzzle_socket.global_position if muzzle_socket != null else global_position


func _play_projectile_feedback() -> void:
	if body_root != null:
		body_root.position = _body_position - Vector2(recoil_distance, 0.0)
	if muzzle_flash != null and data.attack_kind != WeaponComponentData.AttackKind.BEAM:
		muzzle_flash.visible = true
		muzzle_flash.modulate = Color.WHITE
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if body_root != null:
		_feedback_tween.tween_property(body_root, "position", _body_position, feedback_seconds)
	if muzzle_flash != null:
		_feedback_tween.tween_property(muzzle_flash, "modulate:a", 0.0, muzzle_flash_fade_seconds).set_delay(muzzle_flash_hold_seconds)
	_feedback_tween.finished.connect(_finish_feedback)


func _play_melee_feedback() -> void:
	if melee_trail != null:
		melee_trail.visible = true
		melee_trail.modulate = Color.WHITE
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if melee_trail != null:
		_feedback_tween.tween_property(melee_trail, "modulate:a", 0.0, maxf(feedback_seconds, 0.12))
	else:
		_feedback_tween.tween_interval(maxf(feedback_seconds, 0.12))
	_feedback_tween.finished.connect(_finish_feedback)


func _finish_feedback() -> void:
	_feedback_tween = null
	if body_root != null:
		body_root.position = _body_position
		body_root.scale = _body_scale
	_reset_effect(muzzle_flash)
	_reset_effect(melee_trail)


func _reset_effect(effect: CanvasItem) -> void:
	if effect == null:
		return
	effect.visible = false
	effect.modulate = Color.WHITE
