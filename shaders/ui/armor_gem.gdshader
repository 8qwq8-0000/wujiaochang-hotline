shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 gem = COLOR;
	float brightness = max(gem.r, max(gem.g, gem.b));
	vec3 blue = mix(vec3(0.16, 0.52, 0.88), vec3(0.88, 0.96, 1.0), brightness * brightness);
	COLOR = vec4(blue * brightness, gem.a);
}
