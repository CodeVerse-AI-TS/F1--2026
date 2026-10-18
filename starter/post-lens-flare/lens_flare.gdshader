// Lens flare + sun glare for the Compatibility renderer. Fully procedural (no textures):
// hot core, wide glare, 6-blade starburst, anamorphic streak, a chromatic halo ring and a
// chain of hexagonal / round ghosts mirrored through the screen centre.
// Occlusion: a 3x3 grid of depth-buffer taps around the sun (Compatibility cannot read the
// depth buffer in the vertex stage), so the flare dims smoothly as trees, walls or the
// screen edge cover the sun. Additive full-screen quad: stacks with every other pass.
// Made by Summer for the starter shelf.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

// World-space direction TOWARD the sun. lens_flare.gd copies it from the sun light each frame.
uniform vec3 sun_direction = vec3(0.0, 0.25, -1.0);
uniform vec3 flare_color : source_color = vec3(1.0, 0.86, 0.66);
// Master brightness.
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
// Glare around the sun: hot core + wide bloom + veil over the whole frame.
uniform float glare : hint_range(0.0, 3.0) = 1.0;
// Starburst spikes around the sun.
uniform float starburst : hint_range(0.0, 3.0) = 1.0;
// Horizontal anamorphic streak (blue film-camera line through the sun).
uniform float streak : hint_range(0.0, 3.0) = 0.8;
uniform vec3 streak_color : source_color = vec3(0.45, 0.65, 1.0);
// Ghost chain (reflections inside the lens) and the halo ring.
uniform float ghosts : hint_range(0.0, 3.0) = 1.0;
uniform float halo : hint_range(0.0, 3.0) = 0.6;
// Scales the whole flare (1 = tuned for a 60-75 degree FOV).
uniform float size : hint_range(0.3, 3.0) = 1.0;
// Radius of the occlusion test around the sun (fraction of screen height).
uniform float occlusion_radius : hint_range(0.0, 0.1) = 0.018;
// Master fade (0 = off). lens_flare.gd hides the node at 0.
uniform float strength : hint_range(0.0, 1.0) = 1.0;

varying vec2 v_sun_uv;
varying float v_rev;
varying float v_vis;  // in front of the camera (0..1)

// 1 where the depth buffer still holds the cleared far value (open sky). Godot 4.4+ uses
// reverse-Z in both renderers (sky = 0); v_rev re-detects it from the projection so the
// test also holds for a standard-Z build (sky = 1).
float sky_at(vec2 uv, float rev) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	float sky = mix(step(0.9999995, d), step(d, 0.0000005), rev);
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return sky * inside.x * inside.y;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
	vec4 zn = PROJECTION_MATRIX * vec4(0.0, 0.0, -0.2, 1.0);
	vec4 zf = PROJECTION_MATRIX * vec4(0.0, 0.0, -2000.0, 1.0);
	float rev = zn.z / zn.w > zf.z / zf.w ? 1.0 : 0.0;
	v_rev = rev;
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(normalize(sun_direction), 0.0));
	float w = clip.w;
	vec2 suv = clip.xy / (abs(w) < 1e-4 ? 1e-4 : w) * 0.5 + 0.5;
	v_sun_uv = suv;
	v_vis = smoothstep(0.02, 0.2, w);
}

float hex_dist(vec2 v) {
	v = abs(v);
	return max(v.x * 0.866025 + v.y * 0.5, v.y);
}

// Soft aperture ghost with a brighter rim; `hex` 1 = hexagon, 0 = disc.
float ghost_shape(vec2 v, float r, float hex) {
	float d = mix(length(v), hex_dist(v), hex);
	float body = smoothstep(r, r * 0.82, d);
	float rim = smoothstep(r * 0.55, r * 0.97, d);
	return body * (0.3 + 0.7 * rim);
}

vec3 ghost(vec2 p, vec2 s, float f, float r, float hex, vec3 tint) {
	vec2 v = p - s * f;
	// Chromatic edge: each channel slightly different size.
	return tint * vec3(ghost_shape(v, r * 1.04, hex), ghost_shape(v, r, hex), ghost_shape(v, r * 0.96, hex));
}

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float angle_noise(float a) {
	float x = a * 9.549;  // 60 cells around the circle
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(mod(i, 60.0)), hash11(mod(i + 1.0, 60.0)), f);
}

void fragment() {
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float vis = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y)) * occlusion_radius * vec2(1.0 / aspect, 1.0);
			vis += sky_at(v_sun_uv + o, v_rev);
		}
	}
	vis = vis / 9.0 * v_vis;
	// No pop at the screen border (shelf rule 8): fade over the outer 6 % as the sun leaves the frame.
	vec2 sb = min(v_sun_uv, 1.0 - v_sun_uv);
	vis *= smoothstep(0.0, 0.06, min(sb.x, sb.y));
	if (vis <= 0.001) {
		discard;
	}
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	vec2 s = (v_sun_uv - 0.5) * vec2(aspect, 1.0);
	vec2 d = p - s;
	float r = length(d) / size;

	// Glare: tiny white-hot core, warm bloom, faint veil over the frame.
	float core = exp(-r * r / 0.0006) * 3.0;
	float bloom = exp(-r / 0.07) * 1.0 + exp(-r / 0.3) * 0.3;
	float veil = exp(-r / 1.1) * 0.08;
	vec3 col = (vec3(1.0, 0.97, 0.92) * core + flare_color * (bloom + veil)) * glare;

	// Starburst: 6 blades plus fine irregular streaks.
	float a = atan(d.y, d.x);
	float blades = pow(abs(cos(a * 3.0 + 0.35)), 140.0);
	float fine = pow(angle_noise(a), 5.0);
	col += flare_color * (blades * exp(-r / 0.26) * 1.1 + fine * exp(-r / 0.13) * 1.1) * starburst;

	// Anamorphic streak: wide soft band plus a thin hot line.
	float sx = exp(-abs(d.x) / (0.9 * size));
	col += streak_color * (exp(-abs(d.y) / (0.012 * size)) * 0.35 + exp(-abs(d.y) / (0.0028 * size)) * 1.2) * sx * streak;

	// Halo ring around the sun, rainbow edge.
	float hr = 0.42 * size;
	float rr = length(d);
	float hw = 0.022 * size;
	vec3 ring = vec3(exp(-pow((rr - hr * 1.04) / hw, 2.0)),
			exp(-pow((rr - hr) / hw, 2.0)),
			exp(-pow((rr - hr * 0.96) / hw, 2.0)));
	col += ring * vec3(1.0, 0.85, 0.95) * halo * 0.25;

	// Ghost chain along the line sun -> screen centre -> beyond.
	vec3 g = vec3(0.0);
	float z = size;
	g += ghost(p, s, 0.66, 0.034 * z, 0.0, vec3(1.0, 0.62, 0.32)) * 1.0;
	g += ghost(p, s, 0.42, 0.065 * z, 1.0, vec3(0.55, 1.0, 0.55)) * 0.5;
	g += ghost(p, s, 0.2, 0.024 * z, 0.0, vec3(1.0, 0.9, 0.6)) * 1.0;
	g += ghost(p, s, -0.18, 0.1 * z, 1.0, vec3(0.45, 0.65, 1.0)) * 0.45;
	g += ghost(p, s, -0.42, 0.045 * z, 0.0, vec3(1.0, 0.72, 0.38)) * 0.8;
	g += ghost(p, s, -0.7, 0.15 * z, 1.0, vec3(0.62, 0.45, 1.0)) * 0.3;
	g += ghost(p, s, -1.0, 0.065 * z, 1.0, vec3(1.0, 0.5, 0.72)) * 0.6;
	g += ghost(p, s, -1.35, 0.24 * z, 0.0, vec3(0.4, 0.9, 0.8)) * 0.16;
	col += g * ghosts * 0.6;

	ALBEDO = col * vis * intensity * strength;
}
