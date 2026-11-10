shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D atlas_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_size = vec2(256.0, 64.0);
uniform float tile_px = 16.0;
uniform float wave_strength = 0.0;

varying vec2 v_plane;
varying float v_tile;
varying float v_shade;
varying float v_emit;
varying float v_rough;

void vertex() {
	v_plane = UV;
	v_tile = floor(UV2.x + 0.5);
	v_shade = COLOR.r;
	v_emit = COLOR.a;
	v_rough = UV2.y;
}

void fragment() {
	float cols = atlas_size.x / tile_px;
	vec2 plane = v_plane;
	if (wave_strength > 0.0) {
		plane += vec2(TIME * 0.045, sin(TIME * 1.3 + v_plane.x * 0.4) * 0.12) * wave_strength * 8.0;
	}
	vec2 cell = vec2(mod(v_tile, cols), floor(v_tile / cols));
	vec2 local = clamp(fract(plane), vec2(0.035), vec2(0.965));
	vec2 uv = (cell * tile_px + local * tile_px) / atlas_size;
	vec4 tex = texture(atlas_tex, uv);
	ALBEDO = tex.rgb * COLOR.rgb;
	// contact AO: darken the base of side faces so blocks sit in the ground
	if (NORMAL.y < 0.5) {
		ALBEDO *= mix(0.80, 1.0, smoothstep(0.0, 0.30, fract(v_plane.y)));
	}
	ALPHA = tex.a;
	if (wave_strength > 0.0) {
		float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
		ALBEDO = mix(ALBEDO, vec3(0.62, 0.86, 0.95), fres * 0.55);
		ALPHA = clamp(ALPHA + fres * 0.24, 0.0, 0.96);
	}
	EMISSION = tex.rgb * v_emit * 1.9;
	ROUGHNESS = 0.5;
}
