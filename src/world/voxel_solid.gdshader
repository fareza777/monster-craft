shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back, depth_draw_opaque;

uniform sampler2D atlas_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_size = vec2(256.0, 64.0);
uniform float tile_px = 16.0;

varying vec2 v_plane;
varying float v_tile;
varying float v_shade;
varying float v_emit;

void vertex() {
	v_plane = UV;
	v_tile = floor(UV2.x + 0.5);
	v_shade = COLOR.r;
	v_emit = COLOR.a;
}

void fragment() {
	float cols = atlas_size.x / tile_px;
	vec2 cell = vec2(mod(v_tile, cols), floor(v_tile / cols));
	vec2 local = fract(v_plane);
	local = clamp(local, vec2(0.035), vec2(0.965));
	vec2 uv = (cell * tile_px + local * tile_px) / atlas_size;
	vec4 tex = texture(atlas_tex, uv);
	ALBEDO = tex.rgb * v_shade;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	EMISSION = tex.rgb * v_emit * 0.7;
	ROUGHNESS = 1.0;
}
