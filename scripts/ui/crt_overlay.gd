class_name CRTOverlay
extends ColorRect

enum Strength { OFF, LOW, STANDARD }

const CRT_SHADER: Shader = preload("res://shaders/ui/crt_ui.gdshader")

@export var strength: Strength = Strength.OFF :
	set(value):
		strength = value
		_apply_strength()

var _glitch_remaining := 0.0
var _glitch_duration := 0.0


func _ready() -> void:
	add_to_group(&"crt_overlay")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = CRT_SHADER
	material = shader_material
	_apply_strength()


func _process(delta: float) -> void:
	if _glitch_remaining <= 0.0:
		return
	_glitch_remaining = maxf(_glitch_remaining - delta, 0.0)
	var ratio := _glitch_remaining / maxf(_glitch_duration, 0.01)
	_set_shader_parameter(&"event_glitch", ratio * (0.35 if strength == Strength.LOW else 0.7))
	if _glitch_remaining <= 0.0:
		visible = false


func set_strength(next_strength: Strength) -> void:
	strength = next_strength


func trigger_event_glitch(duration: float = 0.24) -> void:
	if strength == Strength.OFF:
		return
	_glitch_duration = maxf(duration, 0.01)
	_glitch_remaining = _glitch_duration
	visible = true
	_set_shader_parameter(&"event_glitch", 0.35 if strength == Strength.LOW else 0.7)


func _apply_strength() -> void:
	if not is_node_ready() or not material is ShaderMaterial:
		return
	visible = strength != Strength.OFF and _glitch_remaining > 0.0
	_set_shader_parameter(&"scanline_strength", 0.0)
	_set_shader_parameter(&"noise_strength", 0.0)
	_set_shader_parameter(&"flicker_strength", 0.0)
	if strength == Strength.OFF:
		_glitch_remaining = 0.0
		_set_shader_parameter(&"event_glitch", 0.0)


func _set_shader_parameter(parameter: StringName, value: Variant) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(parameter, value)
