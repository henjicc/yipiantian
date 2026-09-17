shader_type spatial;
render_mode blend_mix, cull_disabled;

// Celadon lake: broad colour, broken moving highlights and actual shore contacts.
// Distance texture stores squared metres over world XZ [-24,24].
uniform vec4 water_color : source_color = vec4(0.59, 0.67, 0.63, 1.0);
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform bool shore_contacts_enabled = false;
uniform sampler2D painted_water : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D scene_colour : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 ripple_center = vec2(0.0);
uniform float ripple_age = 10.0;
uniform float wave_strength : hint_range(0.0, 1.5) = 1.0;
uniform vec4 reflection_tint : source_color = vec4(1.0);
uniform bool boat_mask_enabled = false;
uniform mat4 world_to_boat;
varying vec3 world_position;
varying float crest_light;

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 dots = vec4(dot(cell, vec2(127.1, 311.7)), dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7)),
		dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7)), dot(cell + vec2(1.0), vec2(127.1, 311.7)));
	vec4 values = fract(sin(dots) * 43758.5453);
	return mix(mix(values.x, values.y, f.x), mix(values.z, values.w, f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	// Fade along the view's horizontal depth, not a circle around the island.
	// A radial cutout exposed the matte lake earlier at both sides, visually
	// curling an otherwise flat water plane into a bowl when the camera orbited.
	float lake_depth = dot(p, normalize(-INV_VIEW_MATRIX[2].xz));
	// Overview retains its authored horizon. When inspecting a distant island,
	// advance the fade with the camera so its nearby water remains real water.
	lake_depth -= max(0.0, dot(CAMERA_POSITION_WORLD.xz, normalize(-INV_VIEW_MATRIX[2].xz)));
	if (lake_depth >= 72.0) {
		discard;
	}
	// An open hull is not a solid depth occluder. Exclude only its inner volume;
	// the transform follows the actual moored boat through pitch, roll and heave.
	vec3 boat_local = (world_to_boat*vec4(world_position,1.0)).xyz;
	float bow_taper = 1.0-.35*pow(clamp(abs(boat_local.x)/1.72,0.0,1.0),4.0);
	if (boat_mask_enabled && abs(boat_local.x)<1.72 && abs(boat_local.z)<.30*bow_taper && boat_local.y<.65) { discard; }
	// Fixed pigment follows world space. Only the restrained surface light moves.
	vec2 flow = vec2(dot(p, vec2(0.848, -0.530)), dot(p, vec2(0.530, 0.848)));
	vec2 mirrored = 1.0 - abs(1.0 - mod(flow * vec2(0.11, 0.14) + vec2(0.35, 0.6), 2.0));
	vec3 pigment = texture(painted_water, vec2(mirrored.x, 0.90 + mirrored.y * 0.08)).rgb;
	float distance_fade = 1.0 - smoothstep(15.0, 34.0, lake_depth);
	// Analytic slopes of centimetre-scale crossing waves. Unlike translating the
	// painted pigment, these normals change real light/view-dependent highlights.
	vec2 d1 = vec2(0.530, 0.848);
	vec2 d2 = vec2(0.287, 0.958);
	vec2 d3 = vec2(0.643, 0.766);
	vec2 d4 = vec2(0.423, 0.906);
	float phase1 = dot(p, d1) * 3.8 - TIME * 0.72;
	float phase2 = dot(p, d2) * 7.3 - TIME * 1.05 + 1.7;
	float phase3 = dot(p, d3) * 14.1 - TIME * 1.37 + 0.4;
	float phase4 = dot(p, d4) * 22.7 - TIME * 1.72 + 2.8;
	// Suppress unresolved fine waves rather than letting distant highlights crawl.
	float fine3 = 1.0 - smoothstep(0.45, 1.7, fwidth(phase3));
	float fine4 = 1.0 - smoothstep(0.45, 1.7, fwidth(phase4));
	vec2 slope = d1 * cos(phase1) * 0.085 + d2 * cos(phase2) * 0.046;
	slope += d3 * cos(phase3) * 0.017 * fine3 + d4 * cos(phase4) * 0.008 * fine4;
	float radius = length(p - ripple_center);
	float ring = sin(radius * 15.0 - ripple_age * 5.0);
	float envelope = exp(-pow((radius - ripple_age * 0.55) * 3.0, 2.0)) * max(0.0, 1.0 - ripple_age / 4.0);
	slope += (p - ripple_center) / max(radius, 0.001) * ring * envelope * 0.075;
	bool inside_shore_map = max(abs(p.x),abs(p.y)) < 24.0;
	float shore = shore_contacts_enabled && inside_shore_map ? sqrt(max(texture(shore_distance, (p + 24.0) / 48.0).r, 0.0)) : 2.4;
	// Hull-local capsule follows the same transform as the open-cabin mask.
	vec2 hull_point = boat_local.xz;
	hull_point.x -= clamp(hull_point.x, -1.24, 1.24);
	float hull_distance = max(0.0, length(hull_point) - 0.42) * 0.85;
	if (!boat_mask_enabled) { hull_distance = 10.0; }
	float contact_distance = min(shore, hull_distance);
	float shore_phase = contact_distance * 13.0 - TIME * 1.15;
	// The hull gives off quiet expanding rings; wave strength also controls them.
	if (boat_mask_enabled) {
		vec2 hull_outward = normalize(hull_point + vec2(0.0001));
		vec3 hull_world_outward = normalize(transpose(mat3(world_to_boat)) * vec3(hull_outward.x, 0.0, hull_outward.y));
		slope += hull_world_outward.xz * sin(hull_distance * 16.0 - TIME * 1.5) * exp(-hull_distance * 2.4) * 0.025;
	}
	vec3 wave_normal = normalize(vec3(-slope.x * wave_strength, 1.0, -slope.y * wave_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(wave_normal, 0.0)).xyz);
	float broad = sin(flow.y * 1.7 - TIME * 0.22 + sin(flow.x * 0.31) * 1.6);
	// Independent cross-wave patches break crests into short, irregular strokes;
	// another parallel sine would produce the previous long striped bands.
	float breakup = water_noise(vec2(flow.x * 3.0, flow.y * 0.82 - TIME * 0.10));
	float glint_phase = phase1 * 2.4 + water_noise(p * 0.62) * 2.2;
	float crest_distance = abs(fract(glint_phase / 6.283185 + 0.5) - 0.5) * 6.283185;
	// A Gaussian crest has no flat bright plateau: thin tapered strokes instead
	// of the earlier thresholded sine's broad parallelogram patches. Derivative
	// coverage keeps subpixel crests soft and proportionally dim in the distance.
	float crest_width = max(0.21, fwidth(glint_phase) * 0.65);
	float crest = exp(-pow(crest_distance / crest_width, 2.0)) * 0.21 / crest_width;
	float glint = crest * pow(smoothstep(0.38, 0.82, breakup), 2.0);
	vec3 colour = mix(water_color.rgb, pigment, 0.07);
	colour += (broad * 0.018 + glint * 0.18 * wave_strength) * distance_fade;
	crest_light = glint * distance_fade * wave_strength;
	// Reversed-Z Vulkan depth is reconstructed, never treated as linear distance.
	// Contact is the actual opaque bank/boat below this fragment, not a guessed ring.
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec4 opaque_world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 opaque_position = opaque_world.xyz / opaque_world.w;
	float water_depth = max(0.0, world_position.y - opaque_position.y);
	float depth_contact = (1.0 - smoothstep(0.02, 0.22, water_depth)) * step(0.00001, depth);
	float shallow = 1.0 - smoothstep(0.12, 1.8, contact_distance);
	float contact = max(exp(-contact_distance * 8.0), depth_contact * 0.6);
	// Broad transparent-looking shallows, a submerged dark seam, then thin arcs.
	colour = mix(colour, water_color.rgb * vec3(0.77, 1.19, 1.13), shallow * 0.58);
	colour *= 1.0 - contact * 0.32;
	float arc_phase = shore_phase + water_noise(p * 2.1) * 1.5;
	float arc_distance = abs(fract(arc_phase / 6.283185 + 0.5) - 0.5) * 6.283185;
	float arc_width = max(0.25, fwidth(arc_phase) * 0.7);
	float arcs = exp(-pow(arc_distance / arc_width, 2.0)) * 0.25 / arc_width;
	arcs *= smoothstep(0.07, 0.18, contact_distance) * (1.0 - smoothstep(0.35, 1.35, contact_distance));
	arcs *= smoothstep(0.25, 0.70, water_noise(p * 2.7 + vec2(TIME * 0.06, 0.0)));
	float ripple_light = (0.5 + 0.5 * ring) * envelope;
	colour = mix(colour, water_color.rgb * 0.6 + vec3(0.33, 0.43, 0.40), clamp((arcs * 0.62 + ripple_light * 0.35) * wave_strength, 0.0, 1.0));
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 reflected_world = reflect(-to_camera, wave_normal);
	float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(to_camera, wave_normal), 0.0), 5.0);
	// The environment fallback samples sky pigment only: mountains and villages
	// must not become a huge stretched image on the near lake.
	float sky_u = atan(reflected_world.z, reflected_world.x) / 6.283185 + 0.5;
	vec2 sky_uv = vec2(sky_u, clamp(0.29 - reflected_world.y * 0.23, 0.015, 0.29));
	vec3 sky = texture(painted_water, sky_uv).rgb;
	vec3 reflection = mix(water_color.rgb * 0.88, sky, 0.48);
	float reflection_weight = 0.16 + fresnel * 0.44;
	// Soft sky reflection is stable when orbiting. Local objects are anchored by
	// their real submerged continuation, avoiding stepped screen-ray silhouettes.
	reflection_weight *= 1.0 - smoothstep(15.0, 23.0, lake_depth);
	ALBEDO = colour * (1.0 - reflection_weight);
	// Screen/sky reflection already contains illumination. Do not light it twice.
	EMISSION = reflection * reflection_tint.rgb * reflection_weight;
	// Only geometry genuinely below this water pixel is transmitted. Absorption
	// hides the deep bank, leaving a short submerged continuation at the waterline.
	float transmission = (1.0 - smoothstep(0.02, 0.65, water_depth)) * step(0.00001, depth) * 0.30;
	vec3 submerged = textureLod(scene_colour, SCREEN_UV, 0.5).rgb * vec3(0.64, 0.88, 0.82);
	ALBEDO *= 1.0 - transmission;
	EMISSION = EMISSION * (1.0 - transmission) + submerged * transmission;
	ROUGHNESS = mix(0.28, 0.19, glint * distance_fade);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// Match the courtyard water-to-painted-distance transition; no opaque horizon.
	ALPHA = 1.0 - smoothstep(48.0, 72.0, lake_depth);
}

void light() {
	// Water retains cool depth under the warmer, brighter land key light.
	float luminance = dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722));
	vec3 diffuse_colour = mix(vec3(luminance), LIGHT_COLOR, 0.18);
	DIFFUSE_LIGHT += ALBEDO * diffuse_colour * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) * (0.66 / 3.141593);
	vec3 halfway = normalize(LIGHT + VIEW);
	float highlight = pow(max(dot(NORMAL, halfway), 0.0), 100.0);
	float broken_reflection = pow(max(dot(NORMAL, halfway), 0.0), 14.0) * crest_light;
	SPECULAR_LIGHT += mix(vec3(luminance), LIGHT_COLOR, 0.55) * ATTENUATION * (highlight * 0.22 + broken_reflection * 0.12);
}
