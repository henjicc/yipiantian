shader_type spatial;
uniform vec4 soil_color : source_color = vec4(0.40, 0.30, 0.19, 1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
varying vec3 soil_point;

float soil_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float soil_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(soil_hash(i), soil_hash(i + vec2(1.0, 0.0)), f.x),
		mix(soil_hash(i + vec2(0.0, 1.0)), soil_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	soil_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = soil_point.xz;
	float clods = soil_noise(p * 15.0);
	float pigment = soil_noise(p * 3.1);
	float grain = soil_noise(p * 72.0);
	ALBEDO = soil_color.rgb * (0.77 + 0.22 * pigment + 0.18 * clods + 0.055 * grain);
	ROUGHNESS = mix(0.98, 0.86, wetness);
	SPECULAR = mix(0.06, 0.16, wetness);
	// Tiny uneven clods, with no repeating board-like grooves or displaced roots.
	NORMAL_MAP = normalize(vec3((soil_noise((p + vec2(0.012, 0.0)) * 15.0) - clods) * 0.75,
		(soil_noise((p + vec2(0.0, 0.012)) * 15.0) - clods) * 0.75, 1.0)) * 0.5 + 0.5;
}
