shader_type canvas_item;
render_mode unshaded;

uniform vec4 atlas_region;
uniform vec2 frame_origin;
uniform vec2 region_size;
uniform float stroke = 0.0;
varying vec4 vertex_tint;
varying vec2 sprite_uv;

void vertex() {
	vertex_tint = COLOR;
	// QuadMesh's V coordinate rises upward; the sprite atlas starts at the top.
	sprite_uv = vec2(UV.x, 1.0 - UV.y);
	vec2 pixel = frame_origin + sprite_uv * region_size;
	// Keep the robe-side root pinned and bend the free end of the painted tail.
	float reach = smoothstep(257.0, 357.0, pixel.x);
	float spine_y = mix(339.0, 292.0, reach);
	float fin = reach * (1.0 - smoothstep(20.0, 82.0, abs(pixel.y - spine_y)));
	VERTEX += fin * vec2(stroke * 24.0, stroke * 55.0);
}

void fragment() {
	vec2 half_pixel = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 atlas_uv = atlas_region.xy + sprite_uv * atlas_region.zw;
	atlas_uv = clamp(atlas_uv, atlas_region.xy + half_pixel, atlas_region.xy + atlas_region.zw - half_pixel);
	COLOR = texture(TEXTURE, atlas_uv) * vertex_tint;
}
