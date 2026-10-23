shader_type canvas_item;
render_mode unshaded;

uniform vec4 glass_tint : source_color = vec4(0.16, 0.34, 0.42, 0.11);
uniform vec4 reflection_tint : source_color = vec4(0.58, 0.86, 0.92, 0.07);

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 pixel_uv = floor(UV * vec2(640.0, 72.0)) / vec2(640.0, 72.0);
	float diagonal = abs(fract(pixel_uv.x * 1.8 + pixel_uv.y * 0.72) - 0.32);
	float reflection = 1.0 - smoothstep(0.025, 0.10, diagonal);
	float edge_dust = smoothstep(0.72, 1.0, pixel_uv.y);
	float grime = step(0.88, hash21(floor(pixel_uv * vec2(92.0, 28.0))));
	vec3 color = mix(glass_tint.rgb, reflection_tint.rgb, reflection * 0.52);
	float alpha = glass_tint.a + reflection * reflection_tint.a + edge_dust * 0.018 + grime * 0.014;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.22));
}
