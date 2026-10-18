shader_type spatial;

uniform float cell = 0.75;

void fragment() {
	vec2 c = floor(UV / cell);
	float s = mod(c.x + c.y, 2.0);
	ALBEDO = vec3(mix(0.03, 0.92, s));
	ROUGHNESS = 0.6;
}
