extends Node2D

const TEXTURE := preload("res://assets/art/weapons/placeholder/rail_cannon_beam.png")
var beam_length := 1000.0
var beam_width := 48.0
var falloff_start_distance := 160.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float falloff_start_ratio = 0.16;
void fragment() {
	vec4 beam = texture(TEXTURE, UV);
	float depth = smoothstep(falloff_start_ratio, 1.0, UV.x);
	vec3 near_tint = vec3(0.88, 1.0, 1.0);
	vec3 far_tint = vec3(0.12, 0.24, 0.72);
	float depth_alpha = mix(1.0, 0.28, depth);
	COLOR = vec4(beam.rgb * mix(near_tint, far_tint, depth), beam.a * depth_alpha) * COLOR;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter(
		"falloff_start_ratio",
		clampf(falloff_start_distance / maxf(beam_length, 1.0), 0.0, 1.0)
	)
	material = shader_material
	add_to_group("laser_beams")
	var tween := create_tween()
	tween.tween_interval(0.24)
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)

func _draw() -> void:
	draw_texture_rect(TEXTURE, Rect2(0.0, -beam_width * 0.5, beam_length, beam_width), false)
