class_name ControlHintTray
extends CanvasLayer

const WIDTH := 234.0
const HEIGHT := 218.0
const HANDLE := 14.0
const HANDLE_HEIGHT := 24.0
const HANDLE_SHEET := preload("res://assets/art/ui/os_hud/control_hint_tray_sheet_v1.png")

var _root: Control
var _tween: Tween
var _expanded := false
var _pending_open := false
var _owns_pause := false
var _handle: TextureButton
var _closed_texture: AtlasTexture
var _open_texture: AtlasTexture


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var rest := get_parent().get_node_or_null("PersonaRestFlow") as PersonaRestFlow
	if rest != null:
		rest.persona_consumed.connect(func(_id: StringName, _level: int) -> void: _pending_open = true)
		rest.rest_closed.connect(_on_rest_closed)
	var flow := get_parent().get_node_or_null("SceneFlow") as SceneContainerManager
	if flow != null:
		flow.load_started.connect(func(_path: String) -> void:
			_root.hide()
			_release_pause())
		flow.scene_swapped.connect(func(_scene: Node, _payload: Dictionary) -> void: _reset_for_scene())
	get_viewport().size_changed.connect(_place)
	_reset_for_scene()


func _build() -> void:
	_root = Control.new()
	_root.name = "ControlHintTray"
	_root.size = Vector2(WIDTH, HEIGHT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CyberUITheme.create_os_theme()
	add_child(_root)
	var panel := PanelContainer.new()
	panel.position = Vector2(HANDLE, 0)
	panel.size = Vector2(WIDTH - HANDLE, HEIGHT)
	_root.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = CyberUITheme.PANEL
	style.border_color = CyberUITheme.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var title := Label.new()
	title.text = "操作提示"
	title.add_theme_color_override("font_color", CyberUITheme.ACCENT_LIGHT)
	column.add_child(title)
	for line in ["背包 Tab       格挡 鼠标右键", "义体背包 C   突进 Space", "主动启动 F   暂停 Esc"]:
		var label := Label.new()
		label.text = line
		label.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
		column.add_child(label)
	var section := Label.new()
	section.text = "义体回路"
	section.add_theme_color_override("font_color", CyberUITheme.ACCENT_LIGHT)
	column.add_child(section)
	for line in ["启动器决定何时触发；义体按槽位顺序执行。", "回路消耗能量，能量会自动恢复。", "开火触发的射弹在回路执行后发射。"]:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
		column.add_child(label)
	_closed_texture = AtlasTexture.new()
	_closed_texture.atlas = HANDLE_SHEET
	_closed_texture.region = Rect2(112, 187, 352, 797)
	_open_texture = AtlasTexture.new()
	_open_texture.atlas = HANDLE_SHEET
	_open_texture.region = Rect2(891, 187, 351, 797)
	_handle = TextureButton.new()
	_handle.name = "TrayHandle"
	_handle.position = Vector2(0, (HEIGHT - HANDLE_HEIGHT) * 0.5)
	_handle.size = Vector2(HANDLE, HANDLE_HEIGHT)
	_handle.custom_minimum_size = _handle.size
	_handle.texture_normal = _closed_texture
	_handle.ignore_texture_size = true
	_handle.stretch_mode = TextureButton.STRETCH_SCALE
	_handle.tooltip_text = "展开或收起操作提示"
	_handle.focus_mode = Control.FOCUS_NONE
	_handle.pressed.connect(func() -> void: _set_expanded(not _expanded))
	_root.add_child(_handle)


func _on_rest_closed(_floor: int) -> void:
	if _pending_open:
		_pending_open = false
		_root.show()
		_set_expanded(true)


func _reset_for_scene() -> void:
	_release_pause()
	_expanded = false
	_pending_open = false
	_handle.texture_normal = _closed_texture
	_root.hide()
	_place()


func _place() -> void:
	if _root == null:
		return
	_root.position = Vector2(get_viewport().get_visible_rect().size.x - (WIDTH if _expanded else HANDLE), 70.0)


func _set_expanded(value: bool) -> void:
	if value and not _expanded:
		_owns_pause = not get_tree().paused
		get_tree().paused = true
	elif not value and _expanded:
		_release_pause()
	_expanded = value
	_handle.texture_normal = _open_texture if value else _closed_texture
	if _tween != null and _tween.is_running():
		_tween.kill()
	var target := get_viewport().get_visible_rect().size.x - (WIDTH if value else HANDLE)
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_root, "position:x", target, 0.35)


func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func _exit_tree() -> void:
	_release_pause()
