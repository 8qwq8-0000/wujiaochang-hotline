class_name SceneContainerManager
extends Node

## Maaack Scene Loader 保留给菜单与整棵 SceneTree 切换。
## 本节点只替换 SceneContainer 的内容，
## 因而 RunManager、HUD、VFX 与音频管理器不会随楼层销毁。
signal load_started(scene_path: String)
signal load_progress_changed(progress: float)
signal scene_swapped(scene: Node, payload: Dictionary)
signal load_failed(scene_path: String, error: String)

@export_file("*.tscn") var initial_scene: String = "res://scenes/levels/floors/combat_prototype.tscn"
@export var scene_container_path: NodePath
@export var fade_rect_path: NodePath
@export_range(0.0, 2.0, 0.01) var fade_duration: float = 0.18

var _requested_path := ""
var _pending_payload: Dictionary = {}
var _is_loading := false

@onready var _scene_container: Node = get_node(scene_container_path)
@onready var _fade_rect: ColorRect = get_node_or_null(fade_rect_path)


func _ready() -> void:
	# Scene payload handlers may immediately pause the tree (for example, the
	# mandatory persona rest screen). The transition must still finish fading.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if _fade_rect != null:
		_fade_rect.modulate.a = 0.0
	if not initial_scene.is_empty():
		call_deferred("request_scene", initial_scene, {})


func request_scene(scene_path: String, payload: Dictionary = {}) -> bool:
	if _is_loading:
		return false
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("SceneContainerManager: invalid PackedScene path: %s" % scene_path)
		load_failed.emit(scene_path, "暂时无法进入目标区域")
		return false
	_is_loading = true
	_requested_path = scene_path
	_pending_payload = payload.duplicate(true)
	load_started.emit(scene_path)
	set_process(true)
	return true


func _process(_delta: float) -> void:
	set_process(false)
	if _is_loading:
		_swap_loaded_scene()


func _swap_loaded_scene() -> void:
	await _fade_to(1.0)
	# Godot 4.7 threaded loading leaks internal LoadTokens on shutdown.
	# Load behind the fade until godotengine/godot#121025 is available.
	var resource := ResourceLoader.load(_requested_path, "PackedScene")
	if not resource is PackedScene:
		_finish_with_error("暂时无法进入目标区域", "loaded resource is not a PackedScene")
		await _fade_to(0.0)
		return
	load_progress_changed.emit(1.0)
	for child in _scene_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	var instance := (resource as PackedScene).instantiate()
	_scene_container.add_child(instance)
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.set_scene_payload(_pending_payload)
	if instance.has_method("receive_scene_payload"):
		instance.receive_scene_payload(_pending_payload)
	_is_loading = false
	scene_swapped.emit(instance, _pending_payload)
	_pending_payload.clear()
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if _fade_rect == null or fade_duration <= 0.0:
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "modulate:a", alpha, fade_duration)
	await tween.finished


func _finish_with_error(message: String, technical_detail: String = "") -> void:
	_is_loading = false
	set_process(false)
	load_failed.emit(_requested_path, message)
	push_error("SceneContainerManager: %s" % (technical_detail if not technical_detail.is_empty() else message))
