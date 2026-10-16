// Adapted from Joshua J Rideout's Godot CRT Shader at commit
// 165809c5c4e321786e2481bddc739f072476df62 (MIT).
// Project version removes curvature, rolling distortion and chromatic aberration
// so combat geometry remains stable while preserving scanlines and event glitches.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_strength : hint_range(0.0, 0.35) = 0.08;
uniform float noise_strength : hint_range(0.0, 0.12) = 0.015;
uniform float flicker_strength : hint_range(0.0, 0.08) = 0.01;
uniform float event_glitch : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phosphor_tint : source_color = vec3(0.94, 1.0, 0.96);

float random_value(vec2 seed) {
	return fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band_center = fract(TIME * 1.7);
	float band = 1.0 - smoothstep(0.0, 0.018, abs(uv.y - band_center));
	uv.x += sin(uv.y * 230.0 + TIME * 38.0) * 0.0035 * band * event_glitch;
	vec4 source = textureLod(screen_texture, uv, 0.0);
	float scan = sin(UV.y * 720.0 * 3.14159265);
	float scan_factor = 1.0 - scanline_strength * (0.5 + 0.5 * scan);
	float noise = (random_value(floor(UV * vec2(640.0, 360.0)) + floor(TIME * 24.0)) - 0.5) * noise_strength;
	float flicker = 1.0 + sin(TIME * 8.0) * flicker_strength;
	vec3 color = source.rgb * phosphor_tint * scan_factor * flicker + noise;
	float static_line = step(0.985, random_value(vec2(floor(UV.y * 120.0), floor(TIME * 18.0))));
	color = mix(color, vec3(random_value(UV * 900.0 + TIME)), static_line * event_glitch * 0.42);
	COLOR = vec4(color, source.a);
}
