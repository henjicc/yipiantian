shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.62, 0.75, 0.73, 1.0);
uniform sampler2D painted_water : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 ripple_center = vec2(0.0);
uniform float ripple_age = 10.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	// Fixed pigment follows world space. Only the restrained surface light moves.
	vec2 flow = vec2(dot(p, vec2(0.848, -0.530)), dot(p, vec2(0.530, 0.848)));
	vec2 mirrored = 1.0 - abs(1.0 - mod(flow * vec2(0.11, 0.14) + vec2(0.35, 0.6), 2.0));
	vec3 pigment = texture(painted_water, vec2(mirrored.x, 0.90 + mirrored.y * 0.08)).rgb;
	float broad = sin(flow.y * 1.7 + sin(flow.x * 0.31) * 1.6);
	float broken = sin(flow.x * 0.63 + sin(flow.y * 0.41)) * 0.5 + 0.5;
	float glint = pow(max(0.0, sin(flow.y * 8.7 + sin(flow.x * 0.37) + TIME * 0.22)), 10.0) * smoothstep(0.35, 0.85, broken);
	float distance_fade = 1.0 - smoothstep(15.0, 34.0, length(p));
	float drift = sin(flow.y * 2.1 + TIME * 0.27) * 0.025;
	float crossing = sin(flow.x * 0.6 + flow.y * 3.3 + TIME * 0.19) * 0.012;
	float radius = length(p - ripple_center);
	float ring = sin(radius * 15.0 - ripple_age * 5.0);
	float envelope = exp(-pow((radius - ripple_age * 0.55) * 3.0, 2.0)) * max(0.0, 1.0 - ripple_age / 4.0);
	NORMAL_MAP = vec3(0.5 + drift + ring * envelope * 0.016, 0.5 + crossing, 1.0);
	NORMAL_MAP_DEPTH = 0.25;
	vec3 colour = mix(water_color.rgb, pigment, 0.07);
	colour += (broad * 0.012 + glint * 0.018) * distance_fade;
	// Reversed-Z Vulkan depth is reconstructed, never treated as linear distance.
	// Contact is the actual opaque bank/boat below this fragment, not a guessed ring.
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec4 opaque_world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 opaque_position = opaque_world.xyz / opaque_world.w;
	float water_depth = max(0.0, world_position.y - opaque_position.y);
	float contact = (1.0 - smoothstep(0.02, 0.38, water_depth)) * step(0.00001, depth);
	colour = mix(colour, vec3(0.33, 0.47, 0.43), contact * 0.32);
	ALBEDO = colour;
	ROUGHNESS = 0.48;
	METALLIC = 0.0;
	SPECULAR = 0.30;
	// Match the courtyard water-to-painted-distance transition; no opaque horizon.
	ALPHA = 1.0 - smoothstep(13.0, 23.0, length(world_position.xz));
}
