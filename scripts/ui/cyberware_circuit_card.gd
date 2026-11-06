class_name CyberwareCircuitCard
extends Button

const CARD_SOURCE := preload("res://assets/art/ui/os_hud/cyberware_card_graphite_a.png")
const CARD_SIZE := 52.0

class KindGlyph extends Control:
	var kind := -1

	func _draw() -> void:
		if kind < 0:
			return
		var ink := Color("dba968")
		draw_rect(Rect2(0, 0, 12, 12), Color("22282c"))
		match kind:
			0: # Starter: source pulse.
				draw_circle(Vector2(6, 6), 3.0, ink)
				draw_line(Vector2(6, 0), Vector2(6, 2), ink, 1.4)
			1: # Modifier: split path.
				draw_line(Vector2(2, 9), Vector2(6, 3), ink, 1.6)
				draw_line(Vector2(6, 3), Vector2(10, 9), ink, 1.6)
			2: # Effect: pulse burst.
				draw_colored_polygon(PackedVector2Array([Vector2(6, 1), Vector2(8, 5), Vector2(11, 6), Vector2(8, 7), Vector2(6, 11), Vector2(4, 7), Vector2(1, 6), Vector2(4, 5)]), ink)
			3: # Rule: four-way gate.
				draw_rect(Rect2(2, 2, 8, 8), ink, false, 1.4)
				draw_line(Vector2(6, 2), Vector2(6, 10), ink, 1.0)


var slot_index := -1
var module_id := StringName()
var circuit_owner_id := 0
var circuit_kind := -1
var module_texture: Texture2D
var drop_requested: Callable
var hover_requested: Callable
var drag_started: Callable
var right_click_requested: Callable
var _visual: Control
var _icon: TextureRect
var _glyph: KindGlyph
var _selection_line: ColorRect
var _shift_tween: Tween
var _drag_visibility_generation := 0


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * CARD_SIZE
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_visual = Control.new()
	_visual.name = "CardVisual"
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visual)
	var ceramic := ColorRect.new()
	ceramic.color = Color("30363a")
	ceramic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ceramic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.add_child(ceramic)
	var atlas := AtlasTexture.new()
	atlas.atlas = CARD_SOURCE
	atlas.region = Rect2(35, 35, 1184, 1184)
	var face := TextureRect.new()
	face.name = "GraphiteCardFace"
	face.texture = atlas
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.add_child(face)
	_icon = TextureRect.new()
	_icon.name = "ModuleIcon"
	_icon.position = Vector2(6, 6)
	_icon.size = Vector2(40, 40)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_icon)
	_glyph = KindGlyph.new()
	_glyph.name = "KindGlyph"
	_glyph.position = Vector2(38, 2)
	_glyph.size = Vector2(12, 12)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_glyph)
	_selection_line = ColorRect.new()
	_selection_line.name = "SelectionLine"
	_selection_line.color = Color("e7ac62")
	_selection_line.position = Vector2(6, 48)
	_selection_line.size = Vector2(40, 2)
	_selection_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_line.hide()
	_visual.add_child(_selection_line)
	_refresh_visual()


func set_module(id: StringName, texture: Texture2D, kind: int) -> void:
	module_id = id
	module_texture = texture
	circuit_kind = kind
	_refresh_visual()


func _refresh_visual() -> void:
	if _icon == null:
		return
	_icon.texture = module_texture
	_glyph.kind = circuit_kind
	_glyph.queue_redraw()
	modulate = Color.WHITE if not module_id.is_empty() else Color(0.45, 0.55, 0.58, 0.6)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if module_id.is_empty():
		return null
	var preview := CyberwareCircuitCard.new()
	preview.slot_index = slot_index
	preview.module_id = module_id
	preview.module_texture = module_texture
	preview.circuit_kind = circuit_kind
	preview.size = Vector2.ONE * CARD_SIZE
	preview.scale = get_global_transform().get_scale()
	preview.position = -preview.size * preview.scale * 0.5
	preview.modulate.a = 0.92
	if get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	if drag_started.is_valid():
		drag_started.call(slot_index)
	return {"type": &"cyberware_circuit_module", "owner_id": circuit_owner_id, "source_index": slot_index, "module_id": module_id}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not module_id.is_empty():
		if right_click_requested.is_valid():
			right_click_requested.call(slot_index)
			accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid := data is Dictionary and StringName(data.get("type", "")) == &"cyberware_circuit_module" and int(data.get("owner_id", -1)) == circuit_owner_id and int(data.get("source_index", -1)) != slot_index
	if valid and hover_requested.is_valid():
		hover_requested.call(int(data.get("source_index", -1)), slot_index)
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(Vector2.ZERO, data) and drop_requested.is_valid():
		drop_requested.call(int(data.get("source_index", -1)), slot_index)


func set_visual_offset(x: float) -> void:
	if _visual == null or is_equal_approx(_visual.position.x, x):
		return
	if _shift_tween != null and _shift_tween.is_valid():
		_shift_tween.kill()
	_shift_tween = create_tween()
	_shift_tween.tween_property(_visual, "position:x", x, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func reset_visual_offset() -> void:
	if _shift_tween != null and _shift_tween.is_valid():
		_shift_tween.kill()
	if _visual != null:
		_visual.position.x = 0.0


func set_drag_origin_hidden(hidden: bool) -> void:
	if _visual != null:
		_drag_visibility_generation += 1
		_visual.visible = not hidden


func restore_drag_origin_after_preview() -> void:
	var generation := _drag_visibility_generation
	await get_tree().process_frame
	while is_inside_tree() and get_viewport().gui_is_dragging():
		if generation != _drag_visibility_generation:
			return
		await get_tree().process_frame
	if generation == _drag_visibility_generation and is_instance_valid(_visual):
		_visual.show()


func set_selected(value: bool) -> void:
	if _selection_line != null:
		_selection_line.visible = value


func settle() -> void:
	if _visual == null:
		return
	if _shift_tween != null and _shift_tween.is_valid():
		_shift_tween.kill()
	_visual.pivot_offset = Vector2.ONE * (CARD_SIZE * 0.5)
	_visual.position.x = 1.5
	_visual.scale = Vector2(1.04, 0.94)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
