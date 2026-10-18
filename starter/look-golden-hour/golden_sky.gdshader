// Golden-hour photo sky: Poly Haven "Kloppenheim 06 (Pure Sky)" (CC0) rotated so the
// photographed sun sits where the look's DirectionalLight3D "Sun" points (13 deg altitude).
// Below the horizon the photo's mirrored half is replaced by a warm haze-to-ground ramp.
// Based on Lantern Hollow's photo_sky / weather_sky shaders (Summer Engine).
shader_type sky;
render_mode use_debanding;

uniform sampler2D panorama : filter_linear_mipmap, repeat_enable;
uniform float panorama_energy = 0.55;
// Yaw plus a 4.9 deg pitch: world direction -> panorama direction (sun_alignment.json).
uniform mat3 panorama_basis = mat3(vec3(-0.95632397, 0.04918204, 0.28814163), vec3(0.06725388, 0.99631908, 0.05315264), vec3(-0.28446685, 0.07020979, -0.95611150));
uniform vec3 ground_color : source_color = vec3(0.30, 0.25, 0.21);
uniform float ground_blend : hint_range(0.0, 1.0) = 1.0;
uniform vec3 warm_tint : source_color = vec3(1.0, 0.93, 0.84);
uniform float sun_glare : hint_range(0.0, 4.0) = 1.0;

vec2 pano_uv(vec3 d) {
	return vec2(atan(d.z, d.x) / 6.28318530718 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265359);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 photo = texture(panorama, pano_uv(normalize(panorama_basis * dir))).rgb * panorama_energy;
	vec3 hd = normalize(vec3(dir.x, 0.015, dir.z));
	vec3 haze = textureLod(panorama, pano_uv(normalize(panorama_basis * hd)), 4.0).rgb * panorama_energy;
	vec3 below = mix(haze, ground_color * panorama_energy * 2.0, smoothstep(0.0, 0.22, -dir.y));
	vec3 col = mix(photo, below, ground_blend * smoothstep(0.004, -0.02, dir.y)) * warm_tint;
	if (LIGHT0_ENABLED) {
		float mu = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (pow(mu, 900.0) * 1.5 + pow(mu, 60.0) * 0.12) * sun_glare;
	}
	COLOR = col;
}
