// Animated lava: two scrolling layers of the CC0 lava_rock maps (ambientCG Lava004, lava_molten_*) with pulsing glow.
// World XZ mapping (no UVs needed); intended for flat or gently sloped pools and rivers. Original shader (Summer).
shader_type spatial;

uniform sampler2D lava_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lava_emission : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lava_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile_metres = 3.0;
uniform vec2 flow = vec2(0.02, 0.035);
uniform float emission_energy : hint_range(0.0, 16.0) = 1.5;
uniform vec3 glow_tint : source_color = vec3(1.0, 0.5, 0.25);
// Molten lava is lit by its own glow; keep the lit albedo dark so sun and sky do not wash it out.
uniform float albedo_strength : hint_range(0.0, 1.0) = 0.25;
uniform float pulse : hint_range(0.0, 1.0) = 0.35;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz / tile_metres;
	vec2 uv1 = uv + flow * TIME;
	vec2 uv2 = uv * 0.71 + vec2(0.37, 0.11) - flow.yx * TIME * 0.6;
	vec3 a = mix(texture(lava_albedo, uv1).rgb, texture(lava_albedo, uv2).rgb, 0.4);
	vec3 e1 = texture(lava_emission, uv1).rgb;
	vec3 e2 = texture(lava_emission, uv2).rgb;
	vec3 e = max(e1, e2 * 0.8);
	float throb = 1.0 + pulse * sin(TIME * 1.7 + uv.x * 3.0 + uv.y * 2.0);
	ALBEDO = a * albedo_strength;
	EMISSION = e * glow_tint * emission_energy * throb;
	ROUGHNESS = 0.55;
	NORMAL_MAP = texture(lava_normal, uv1).rgb;
}
