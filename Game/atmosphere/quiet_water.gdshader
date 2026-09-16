shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.702, 0.788, 0.749, 1.0);
uniform vec2 ripple_center = vec2(0.0);
uniform float ripple_age = 10.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Only a tiny surface-normal shimmer; no scrolling painted colour texture.
	vec2 p = world_position.xz;
	float drift = sin(p.x * 2.1 + p.y * 1.3 + TIME * 0.27) * 0.010;
	float crossing = sin(p.x * -1.2 + p.y * 2.3 + TIME * 0.19) * 0.008;
	float radius = length(p - ripple_center);
	float ring = sin(radius * 15.0 - ripple_age * 5.0);
	float envelope = exp(-pow((radius - ripple_age * 0.55) * 3.0, 2.0)) * max(0.0, 1.0 - ripple_age / 4.0);
	NORMAL_MAP = vec3(0.5 + drift + ring * envelope * 0.016, 0.5 + crossing, 1.0);
	NORMAL_MAP_DEPTH = 0.25;
	ALBEDO = water_color.rgb;
	ROUGHNESS = 0.65;
	METALLIC = 0.0;
	SPECULAR = 0.18;
	// Match the courtyard water-to-painted-distance transition; no opaque horizon.
	ALPHA = 1.0 - smoothstep(22.0, 35.0, length(world_position.xz));
}
