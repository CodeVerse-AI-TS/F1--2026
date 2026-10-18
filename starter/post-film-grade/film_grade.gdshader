// Film grade on a full-screen quad: chromatic edge fringe, exposure, contrast,
// saturation, warm/cool temperature, split toning (shadow / highlight tints),
// vignette and animated film grain. Made by Summer for the starter shelf.
// Drawn first in the transparent pass (render_priority -128) so particles, glass
// and other transparent objects drawn after it stay visible. Only ONE full-screen
// colour grade works at a time (all of them read the same pre-transparent copy).
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float exposure : hint_range(0.2, 3.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 1.08;
// -1 cool (blue) .. +1 warm (amber)
uniform float temperature : hint_range(-1.0, 1.0) = 0.25;
uniform vec3 shadow_tint : source_color = vec3(0.32, 0.45, 0.55);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.82, 0.6);
uniform float split_amount : hint_range(0.0, 1.0) = 0.3;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.9;
uniform float grain : hint_range(0.0, 0.3) = 0.035;
// Screen-edge RGB split, as a fraction of the screen (0 = off).
uniform float chromatic : hint_range(0.0, 0.02) = 0.003;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0031308)), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cv = uv - 0.5;
	vec2 off = cv * dot(cv, cv) * chromatic * 8.0;
	vec3 src = texture(screen_tex, uv).rgb;
	vec3 c = vec3(texture(screen_tex, uv + off).r, src.g, texture(screen_tex, uv - off).b);
	c = clamp(c * exposure, 0.0, 4.0);
	vec3 s = to_srgb(c);
	s = (s - 0.5) * contrast + 0.5;
	float l = dot(s, vec3(0.2126, 0.7152, 0.0722));
	s = mix(vec3(l), s, saturation);
	s *= vec3(1.0 + temperature * 0.08, 1.0 + temperature * 0.01, 1.0 - temperature * 0.1);
	float k = smoothstep(0.1, 0.75, l);
	vec3 tone = mix(shadow_tint, highlight_tint, k);
	s = mix(s, s * tone / max(dot(tone, vec3(0.2126, 0.7152, 0.0722)), 0.05), split_amount * (1.0 - abs(k - 0.5)));
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float r = length(cv * vec2(aspect, 1.0)) / (0.5 * aspect);
	s *= 1.0 - vignette * smoothstep(1.0 - vignette_softness * 0.6, 1.0 + vignette_softness * 0.2, r);
	s += (hash12(uv * VIEWPORT_SIZE + fract(TIME * 7.0) * 64.0) - 0.5) * grain;
	ALBEDO = mix(src, to_linear(max(s, vec3(0.0))), strength);
}
