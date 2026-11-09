shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D history_1 : repeat_disable, filter_nearest;
uniform sampler2D history_2 : repeat_disable, filter_nearest;
uniform sampler2D history_3 : repeat_disable, filter_nearest;
uniform vec2 history_offset_1 = vec2(0.0);
uniform vec2 history_offset_2 = vec2(0.0);
uniform vec2 history_offset_3 = vec2(0.0);
uniform int history_count = 0;
uniform float frenzy : hint_range(0.0, 1.0) = 0.0;
uniform float echo_strength : hint_range(0.0, 1.0) = 0.0;
uniform float peak_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float peak_effect_scale : hint_range(0.0, 1.0) = 1.0;
uniform float reduced_flashes : hint_range(0.0, 1.0) = 0.0;
uniform float film_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 pixel_size = vec2(0.0015625, 0.002777778);

float luma(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 history_outline(sampler2D source, vec2 uv, vec3 current, vec3 tint, float weight) {
	vec3 old = texture(source, uv).rgb;
	float brightness = smoothstep(0.25, 0.62, max(old.r, max(old.g, old.b)));
	float faded_light = max(luma(old) - luma(current), (old.r - current.r) * 0.6);
	float changed = smoothstep(0.09, 0.32, faded_light);
	float edge = length(old - texture(source, uv + vec2(pixel_size.x, 0.0)).rgb)
		+ length(old - texture(source, uv + vec2(0.0, pixel_size.y)).rgb);
	float outline = smoothstep(0.08, 0.30, edge);
	float blood = smoothstep(0.08, 0.38, old.r - max(old.g, old.b));
	vec3 ghost_color = mix(tint, vec3(1.0, 0.09, 0.15), blood);
	return ghost_color * brightness * changed * max(outline, blood * 0.75) * weight;
}

void fragment() {
	vec2 cell = floor(SCREEN_UV / pixel_size);
	float film_frame = floor(TIME * 18.0);
	float minute = floor((TIME + 30.0) / 60.0);
	float minute_gate = 1.0 - step(1.0, mod(film_frame + 540.0, 1080.0));
	float weave = (step(0.5, hash21(vec2(minute, 41.0))) * 2.0 - 1.0) * minute_gate;
	vec2 uv = clamp(SCREEN_UV + vec2(weave * pixel_size.x * film_strength, 0.0), vec2(0.0), vec2(1.0));
	float radial = length((uv - vec2(0.5)) * vec2(1.0, 1.35));
	float periphery = smoothstep(0.19, 0.59, radial);
	float peak = smoothstep(0.84, 1.0, frenzy) * peak_pulse;
	float row_noise = hash21(vec2(floor(uv.y / pixel_size.y / 8.0), floor(TIME * 16.0)));
	vec2 shake = vec2((row_noise - 0.5) * pixel_size.x * 2.0 * peak * periphery * peak_effect_scale, 0.0);
	vec3 original = texture(screen_texture, uv + shake).rgb;
	float shadow = 1.0 - smoothstep(0.1, 0.46, luma(original));
	float dither = mod(cell.x + 2.0 * cell.y, 4.0) / 4.0 - 0.375;
	vec3 color = original * mix(vec3(1.0), vec3(0.91, 0.98, 1.07), film_strength);
	color = mix(color, vec3(luma(color)), 0.11 * film_strength);
	color += dither * shadow * 0.0165 * film_strength;
	float film_grain = hash21(cell * vec2(1.73, 2.19) + film_frame * 7.0) - 0.5;
	color += film_grain * 0.035 * film_strength;
	float scratch_time = floor(TIME * 3.2);
	float scratch_x = hash21(vec2(scratch_time, 17.0));
	float scratch_gate = step(0.37, hash21(vec2(scratch_time, 29.0)));
	float scratch = (1.0 - smoothstep(0.0, pixel_size.x * 1.5, abs(uv.x - scratch_x))) * scratch_gate;
	color += scratch * 0.0275 * film_strength;
	vec2 dust_cell = floor(uv / (pixel_size * 31.0));
	float dust_gate = step(0.965, hash21(dust_cell + film_frame * 0.43));
	vec2 dust_center = (dust_cell + vec2(0.5)) * pixel_size * 31.0;
	float dust = (1.0 - smoothstep(pixel_size.x * 0.7, pixel_size.x * 2.2, length((uv - dust_center) * vec2(1.0, 1.8)))) * dust_gate;
	color += dust * 0.04 * film_strength;
	vec3 bloom_sample = (texture(screen_texture, uv + vec2(pixel_size.x * 2.0, 0.0)).rgb + texture(screen_texture, uv - vec2(pixel_size.x * 2.0, 0.0)).rgb) * 0.5;
	color += vec3(0.05, 0.033, 0.018) * smoothstep(0.52, 0.9, luma(bloom_sample)) * film_strength;
	color *= 1.0 - smoothstep(0.34, 0.80, radial) * 0.045 * film_strength;
	color = mix(color, pow(color, vec3(0.9)) * vec3(0.80, 1.08, 1.23), frenzy * 0.42);
	color = mix(color, vec3(luma(color)) * vec3(0.87, 1.09, 1.14), frenzy * 0.18);
	vec3 split = vec3(
		texture(screen_texture, uv + vec2(pixel_size.x * 2.0, 0.0)).r,
		original.g,
		texture(screen_texture, uv - vec2(pixel_size.x * 2.0, 0.0)).b
	);
	color = mix(color, split, frenzy * periphery * 0.35 * peak_effect_scale);
	float noise = hash21(cell + floor(TIME * 30.0) * 13.0) - 0.5;
	color += noise * periphery * frenzy * 0.045 * peak_effect_scale;
	vec3 comparison = color;
	float echo = echo_strength * mix(0.24, 0.88, periphery);
	if (history_count > 0 && echo > 0.001) {
		color += history_outline(history_1, uv + history_offset_1, comparison, vec3(0.08, 0.93, 1.0), 0.85) * echo;
	}
	if (history_count > 1 && echo > 0.001) {
		color += history_outline(history_2, uv + history_offset_2, comparison, vec3(1.0, 0.08, 0.73), 0.62) * echo;
	}
	if (history_count > 2 && echo > 0.001) {
		color += history_outline(history_3, uv + history_offset_3, comparison, vec3(0.94, 0.98, 0.37), 0.35) * echo;
	}
	float white_heat = peak * (1.0 - reduced_flashes) * 0.09 * peak_effect_scale;
	color = mix(color, vec3(1.0, 0.94, 0.88), white_heat * periphery);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
