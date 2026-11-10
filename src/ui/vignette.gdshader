shader_type canvas_item;
render_mode blend_mul, unshaded;

// Cinematic edge falloff: darkens the corners and cools them slightly so the
// centre of the frame stays the brightest, most readable area.
uniform float strength : hint_range(0.0, 1.0) = 0.40;
uniform float inner : hint_range(0.0, 1.0) = 0.52;
uniform vec3 tint : source_color = vec3(0.90, 0.95, 1.0);

void fragment() {
	vec2 d = SCREEN_UV - vec2(0.5);
	float r = length(d * vec2(1.0, 0.84)) * 1.32;
	float v = smoothstep(inner, 1.0, r);
	vec3 col = mix(vec3(1.0), tint, v * 0.9);
	col *= 1.0 - v * strength;
	COLOR = vec4(col, 1.0);
}
