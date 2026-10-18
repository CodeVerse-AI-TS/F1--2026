// Small still basin (fountain, well, puddle, bath): concentric rings from the object's centre.
// From Lantern Hollow layout/fountain.gdshader (Summer, original work); colours exposed.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 water_color : source_color = vec3(0.035, 0.20, 0.19);
uniform vec3 ring_color : source_color = vec3(0.19, 0.39, 0.31);
uniform float ring_speed = 4.5;

varying vec2 local_pos;

float wave(vec2 p) {
	float r = length(p);
	return sin(r * 27.0 - TIME * ring_speed) * 0.0012 + sin(p.x * 23.0 + p.y * 17.0 + TIME * 2.0) * 0.0007;
}
void vertex() {
	local_pos = VERTEX.xz;
	VERTEX.y += wave(VERTEX.xz);
}
void fragment() {
	float e = 0.015;
	float dx = (wave(local_pos + vec2(e, 0)) - wave(local_pos - vec2(e, 0))) / (2.0 * e);
	float dz = (wave(local_pos + vec2(0, e)) - wave(local_pos - vec2(0, e))) / (2.0 * e);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-dx, 1.0, -dz)), 0.0)).xyz);
	float ring = pow(sin(length(local_pos) * 27.0 - TIME * ring_speed) * 0.5 + 0.5, 10.0);
	ALBEDO = mix(water_color, ring_color, ring * 0.06);
	ROUGHNESS = 0.25;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
