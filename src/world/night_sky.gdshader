shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

uniform float night = 0.0;
uniform float drift = 0.0;
uniform vec4 star_color : source_color = vec4(0.82, 0.88, 1.0, 1.0);
uniform float density = 0.984;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	for (int i = 0; i < 3; i++) {
		float scale = 150.0 + float(i) * 130.0;
		vec2 g = uv * scale + vec2(drift * (0.4 + 0.2 * float(i)), 0.0);
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5;
		float r = hash21(cell + float(i) * 19.0);
		if (r > density + float(i) * 0.004) {
			float d = length(f);
			float s = smoothstep(0.34, 0.02, d);
			a += s * (0.35 + 0.65 * hash21(cell + 7.0));
		}
	}
	// Fade the dome out near the horizon so stars never sit on the skyline.
	float band = smoothstep(0.16, 0.6, abs(uv.y - 0.5) * 2.0);
	float fade = band * clamp(night, 0.0, 1.0);
	ALBEDO = star_color.rgb;
	EMISSION = star_color.rgb * a * fade * 1.5;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
