// Stylised opaque water: analytic ripple normals, flowing foam streaks, optional river banks
// (shallows + shore foam) and an optional eddy. No screen/depth reads, so it is Compatibility-safe
// and casts/receives shadows like any opaque surface. Use a subdivided PlaneMesh for vertex ripples.
// Generalised from Lantern Hollow layout/water.gdshader (Summer, original work).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.022, 0.115, 0.135);
uniform vec3 shallow_color : source_color = vec3(0.085, 0.27, 0.23);
uniform vec3 foam_color : source_color = vec3(0.53, 0.69, 0.58);
// 1 = 1.4 cm ripples. Ocean swell: wave_height 8, wave_scale 4.
uniform float wave_height = 1.0;
uniform float wave_scale = 1.0;
uniform float wave_speed = 1.0;
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform float flow_speed = 0.52;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.45;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.17;
// Fine moving ripples on top of the swell (normal only, no geometry).
uniform float detail_ripples : hint_range(0.0, 2.0) = 0.6;
// Fake sky reflection at grazing angles (helps a lot in Compatibility, which has no SSR).
uniform vec3 sky_tint : source_color = vec3(0.55, 0.68, 0.78);
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.5;
// River mode: a straight channel through channel_origin (world XZ); channel_side points across it.
uniform bool river_banks = false;
uniform vec2 channel_origin = vec2(0.0, 0.0);
uniform vec2 channel_side = vec2(1.0, 0.0);
uniform float channel_half_width = 2.25;
// Optional whirl at a world XZ point (0 strength = off).
uniform vec2 eddy_point = vec2(0.0, 0.0);
uniform float eddy_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 wp;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float surface(vec2 p) {
	p /= wave_scale;
	float t = TIME * wave_speed;
	float h = sin(p.x * 3.1 + p.y * 1.4 - t * 1.5) * 0.014 + sin(p.x * 6.7 - p.y * 2.6 + t * 2.1) * 0.007 + sin(p.y * 8.0 - t * 3.1) * 0.003;
	return h * wave_height * sqrt(wave_scale);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += surface(wp.xz);
}
void fragment() {
	vec2 p = wp.xz;
	float e = 0.045 * wave_scale;
	float dx = (surface(p + vec2(e, 0)) - surface(p - vec2(e, 0))) / (2.0 * e);
	float dz = (surface(p + vec2(0, e)) - surface(p - vec2(0, e))) / (2.0 * e);
	vec2 g = vec2(11.0, 4.0) * cos(dot(p, vec2(11.0, 4.0)) + TIME * 2.7) * 0.004;
	g += vec2(-7.0, 13.0) * cos(dot(p, vec2(-7.0, 13.0)) + TIME * 3.3) * 0.003;
	g += vec2(17.0, -9.0) * cos(dot(p, vec2(17.0, -9.0)) + TIME * 4.1) * 0.002;
	dx += g.x * detail_ripples;
	dz += g.y * detail_ripples;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-dx, 1.0, -dz)), 0.0)).xyz);
	vec2 fd = normalize(flow_direction + vec2(0.00001));
	vec2 fs = vec2(-fd.y, fd.x);
	float along = dot(p, fd) - TIME * flow_speed;
	float across = dot(p, fs);
	float ribbons = noise2(vec2(across * 7.0, along * 0.9));
	float flecks = noise2(vec2(across * 17.0, along * 3.0));
	float shallows = 0.0;
	float shore = 0.0;
	if (river_banks) {
		float bank = abs(dot(p - channel_origin, normalize(channel_side)));
		shallows = smoothstep(channel_half_width - 1.0, channel_half_width - 0.01, bank);
		shore = smoothstep(channel_half_width - 0.33, channel_half_width - 0.02, bank) * (0.3 + 0.7 * noise2(vec2(across, along) * 3.0));
	}
	float streak = smoothstep(0.73, 0.88, ribbons) * smoothstep(0.52, 0.8, flecks) * foam_amount;
	float eddy = sin(length((p - eddy_point) * vec2(1.5, 0.8)) * 19.0 - TIME * 3.0) * 0.5 + 0.5;
	float wake = exp(-length(p - eddy_point) * 0.7) * smoothstep(0.84, 0.98, eddy) * 0.35 * eddy_strength * 2.0;
	float foam = clamp(shore + streak + wake, 0.0, 0.85);
	vec3 water = mix(deep_color, shallow_color, shallows);
	water += vec3(0.015, 0.025, 0.022) * noise2(vec2(across, along) * 2.3);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	water = mix(water, sky_tint, fres * fresnel_strength);
	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(water_roughness, 0.65, foam);
	METALLIC = 0.08;
	SPECULAR = 0.8;
}
