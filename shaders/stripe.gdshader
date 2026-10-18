shader_type spatial;

uniform vec4 col_a : source_color = vec4(0.78, 0.06, 0.05, 1.0);
uniform vec4 col_b : source_color = vec4(0.93, 0.93, 0.9, 1.0);
uniform float period = 2.0;
uniform float roughness_value = 0.55;

void fragment() {
	float s = step(0.5, fract(UV.y / period));
	ALBEDO = mix(col_a.rgb, col_b.rgb, s);
	ROUGHNESS = roughness_value;
}
