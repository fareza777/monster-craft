shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, depth_draw_opaque;

uniform sampler2D atlas_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_size = vec2(256.0, 64.0);
uniform float tile_px = 16.0;

varying vec2 v_plane;
varying float v_tile;
varying float v_shade;
varying float v_emit;
varying float v_height;

void vertex() {
	v_plane = UV;
	v_tile = floor(UV2.x + 0.5);
	v_shade = COLOR.r;
	v_emit = COLOR.a;
	v_height = UV.y;
	float sway = sin(TIME * 1.7 + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.8);
	VERTEX.x += sway * v_height * 0.05;
	VERTEX.z += cos(TIME * 1.3 + MODEL_MATRIX[3].z * 0.9) * v_height * 0.035;
}

void fragment() {
	float cols = atlas_size.x / tile_px;
	vec2 cell = vec2(mod(v_tile, cols), floor(v_tile / cols));
	vec2 local = clamp(fract(v_plane), vec2(0.035), vec2(0.965));
	vec2 uv = (cell * tile_px + local * tile_px) / atlas_size;
	vec4 tex = texture(atlas_tex, uv);
	ALBEDO = tex.rgb * v_shade;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	EMISSION = tex.rgb * v_emit * 0.7;
	ROUGHNESS = 1.0;
}
