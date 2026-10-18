shader_type spatial;

uniform vec3 wall_color : source_color = vec3(0.9, 0.8, 0.65);
uniform float seed = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = wall_color;
	float rough = 0.85;
	float metal = 0.0;
	vec3 emi = vec3(0.0);
	if (abs(wnrm.y) < 0.5) {
		float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		vec2 cell = vec2(u / 3.6, wpos.y / 3.3);
		vec2 f = fract(cell);
		vec2 id = floor(cell);
		col *= 0.92 + 0.08 * hash(floor(wpos.xz * 0.5) + id);
		float band = step(f.y, 0.07);
		col *= 1.0 - band * 0.3;
		bool win = f.x > 0.24 && f.x < 0.76 && f.y > 0.22 && f.y < 0.86 && wpos.y > 3.3;
		if (win) {
			float h = hash(id + vec2(seed, seed * 1.7));
			col = vec3(0.03, 0.04, 0.06);
			rough = 0.06;
			metal = 0.8;
			if (h > 0.8) {
				emi = vec3(1.0, 0.68, 0.38) * 0.9;
			} else if (h < 0.3) {
				col = vec3(0.22, 0.33, 0.24);
				rough = 0.7;
				metal = 0.0;
			}
		}
		if (wpos.y < 3.3 && wpos.y > 0.4) {
			col *= 0.55;
		}
	} else {
		col = vec3(0.42, 0.28, 0.22);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emi;
}
