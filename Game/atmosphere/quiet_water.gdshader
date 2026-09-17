shader_type spatial;
render_mode blend_mix, cull_disabled;

// The river is the composition's pale negative space, not a saturated slab;
// the clock supplies the actual value so it can warm and darken with the light.
uniform vec4 water_color : source_color = vec4(0.59, 0.67, 0.63, 1.0);
uniform sampler2D painted_water : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D scene_colour : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 ripple_center = vec2(0.0);
uniform float ripple_age = 10.0;
uniform float wave_strength : hint_range(0.0, 1.5) = 1.0;
uniform float shore_reflection_strength : hint_range(0.0, 0.6) = 0.32;
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
	float water_radius = length(p);
	if (water_radius >= 23.0) {
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
	float distance_fade = 1.0 - smoothstep(15.0, 34.0, length(p));
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
	vec2 slope = d1 * cos(phase1) * 0.050 + d2 * cos(phase2) * 0.029;
	slope += d3 * cos(phase3) * 0.017 * fine3 + d4 * cos(phase4) * 0.008 * fine4;
	float radius = length(p - ripple_center);
	float ring = sin(radius * 15.0 - ripple_age * 5.0);
	float envelope = exp(-pow((radius - ripple_age * 0.55) * 3.0, 2.0)) * max(0.0, 1.0 - ripple_age / 4.0);
	slope += (p - ripple_center) / max(radius, 0.001) * ring * envelope * 0.075;
	vec3 wave_normal = normalize(vec3(-slope.x * wave_strength, 1.0, -slope.y * wave_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(wave_normal, 0.0)).xyz);
	float broad = sin(flow.y * 1.7 + sin(flow.x * 0.31) * 1.6);
	// Independent cross-wave patches break crests into short, irregular strokes;
	// another parallel sine would produce the previous long striped bands.
	float breakup = water_noise(vec2(flow.x * 1.7, flow.y * 0.82 - TIME * 0.10));
	float glint_phase = phase1 * 2.4 + water_noise(p * 0.62) * 2.2;
	float crest_distance = abs(fract(glint_phase / 6.283185 + 0.5) - 0.5) * 6.283185;
	// A Gaussian crest has no flat bright plateau: thin tapered strokes instead
	// of the earlier thresholded sine's broad parallelogram patches. Derivative
	// coverage keeps subpixel crests soft and proportionally dim in the distance.
	float crest_width = max(0.11, fwidth(glint_phase) * 0.65);
	float crest = exp(-pow(crest_distance / crest_width, 2.0)) * 0.11 / crest_width;
	float glint = crest * pow(smoothstep(0.25, 0.85, breakup), 2.0);
	vec3 colour = mix(water_color.rgb, pigment, 0.07);
	colour += (broad * 0.015 + (glint - 0.16) * 0.042 * wave_strength) * distance_fade;
	crest_light = glint * distance_fade * wave_strength;
	// Reversed-Z Vulkan depth is reconstructed, never treated as linear distance.
	// Contact is the actual opaque bank/boat below this fragment, not a guessed ring.
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec4 opaque_world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 opaque_position = opaque_world.xyz / opaque_world.w;
	float water_depth = max(0.0, world_position.y - opaque_position.y);
	float contact = (1.0 - smoothstep(0.02, 0.38, water_depth)) * step(0.00001, depth);
	colour = mix(colour, water_color.rgb * vec3(0.74, 0.80, 0.78), contact * 0.38);
	// A narrow, discontinuous wet edge follows actual depth at rocks and hulls.
	float wet_edge = exp(-water_depth * 15.0) * step(0.00001, depth);
	colour += vec3(0.035, 0.044, 0.038) * wet_edge * (0.45 + 0.55 * glint);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 reflected_world = reflect(-to_camera, wave_normal);
	float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(to_camera, wave_normal), 0.0), 5.0);
	// The environment fallback samples sky pigment only: mountains and villages
	// must not become a huge stretched image on the near lake.
	float sky_u = atan(reflected_world.z, reflected_world.x) / 6.283185 + 0.5;
	vec2 sky_uv = vec2(sky_u, clamp(0.29 - reflected_world.y * 0.23, 0.015, 0.29));
	vec3 sky = texture(painted_water, sky_uv).rgb;
	vec3 reflection = mix(water_color.rgb * 0.88, sky, 0.30);
	float reflection_weight = 0.08 + fresnel * 0.35;
	// Bounded local screen reflection catches actual opaque rocks and boat hulls.
	// It cannot see off-screen surfaces; those fall back to the soft sky pigment.
	// These envelopes only cull reflection work around the fixed courtyard and
	// opposite bridge bank; the actual hit/depth still determines any reflection.
	float island_region = 1.0 - smoothstep(8.8, 11.0, water_radius);
	vec2 bridge_outside = max(abs(p - vec2(11.0, -1.5)) - vec2(4.5, 4.5), vec2(0.0));
	float bridge_region = 1.0 - smoothstep(0.0, 1.2, length(bridge_outside));
	float reflection_region = max(island_region, bridge_region);
	if (shore_reflection_strength > 0.0 && reflection_region > 0.01) {
		vec3 ray_direction = reflect(normalize(VERTEX), NORMAL);
		vec3 origin = VERTEX + NORMAL * 0.035;
		float travelled = 0.08;
		float previous_travel = 0.0;
		for (int i = 0; i < 24; i++) {
			vec3 ray_position = origin + ray_direction * travelled;
			vec4 clip = PROJECTION_MATRIX * vec4(ray_position, 1.0);
			vec2 hit_uv = clip.xy / clip.w * 0.5 + 0.5;
			if (clip.w <= 0.0 || any(lessThan(hit_uv, vec2(0.002))) || any(greaterThan(hit_uv, vec2(0.998)))) {
				break;
			}
			float hit_depth = textureLod(scene_depth, hit_uv, 0.0).r;
			vec4 surface = INV_PROJECTION_MATRIX * vec4(hit_uv * 2.0 - 1.0, hit_depth, 1.0);
			float separation = -ray_position.z + surface.z / surface.w;
			if (hit_depth > 0.00001 && separation > 0.0 && separation < 0.12) {
				vec2 edge = min(hit_uv, vec2(1.0) - hit_uv);
				float confidence = smoothstep(0.0, 0.07, min(edge.x, edge.y));
				confidence *= 1.0 - smoothstep(0.025, 0.12, separation);
				confidence *= (1.0 - smoothstep(.4, 3.5, travelled)) * reflection_region;
				vec3 local_reflection = textureLod(scene_colour, hit_uv, 5.0).rgb;
				// Broad reflected silhouettes stay submerged in water colour instead
				// of reading as a second solid bank or pale stones beside the hull.
				local_reflection = mix(colour, local_reflection, 0.38);
				// A hit changes reflected colour, never the surface's Fresnel weight.
				// Adding weight only on hits silhouettes the depth buffer in the lake.
				reflection = mix(reflection, local_reflection, confidence * shore_reflection_strength);
				break;
			}
			previous_travel = travelled;
			travelled = previous_travel + 0.14;
		}
	}
	reflection_weight *= 1.0 - smoothstep(15.0, 23.0, water_radius);
	ALBEDO = colour * (1.0 - reflection_weight);
	// Screen/sky reflection already contains illumination. Do not light it twice.
	EMISSION = reflection * reflection_tint.rgb * reflection_weight;
	ROUGHNESS = mix(0.34, 0.23, glint * distance_fade);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	// Match the courtyard water-to-painted-distance transition; no opaque horizon.
	ALPHA = 1.0 - smoothstep(13.0, 23.0, length(world_position.xz));
}

void light() {
	// Water retains cool depth under the warmer, brighter land key light.
	float luminance = dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722));
	vec3 diffuse_colour = mix(vec3(luminance), LIGHT_COLOR, 0.18);
	DIFFUSE_LIGHT += ALBEDO * diffuse_colour * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) * (0.78 / 3.141593);
	vec3 halfway = normalize(LIGHT + VIEW);
	float highlight = pow(max(dot(NORMAL, halfway), 0.0), 100.0);
	float broken_reflection = pow(max(dot(NORMAL, halfway), 0.0), 14.0) * crest_light;
	SPECULAR_LIGHT += mix(vec3(luminance), LIGHT_COLOR, 0.55) * ATTENUATION * (highlight * 0.10 + broken_reflection * 0.045);
}
