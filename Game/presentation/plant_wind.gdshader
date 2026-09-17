shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D color_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool textured = false;
uniform float base_roughness = 0.95;
uniform float base_specular = 0.08;
uniform float base_metallic = 0.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform bool pigment = false;
uniform float wash_scale = 8.0;

// Local bounds and world displacement limits are per mesh; source mesh/LOD stays intact.
instance uniform vec4 wind_bounds = vec4(0.0, 1.0, 0.0, 0.0); // bottom, height, centre x/z
instance uniform vec4 wind_motion = vec4(0.018, 0.20, 0.0, 0.005); // metres, root lock, crown profile, flutter
instance uniform float wind_leaf_texture_mask = 0.0;
instance uniform float frame_enabled = 0.0;
instance uniform vec4 frame_safe_rect = vec4(0.15, 0.14, 0.85, 0.90);
varying vec3 world_point;

float pigment_hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float pigment_wash(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(pigment_hash(i), pigment_hash(i+vec3(1,0,0)), f.x), mix(pigment_hash(i+vec3(0,1,0)), pigment_hash(i+vec3(1,1,0)), f.x), f.y), mix(mix(pigment_hash(i+vec3(0,0,1)), pigment_hash(i+vec3(1,0,1)), f.x), mix(pigment_hash(i+vec3(0,1,1)), pigment_hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 original_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(wind_bounds.y, 0.001);
	float relative_height = (VERTEX.y - wind_bounds.x) / height;
	float anchored = smoothstep(wind_motion.y, 1.0, relative_height);
	// Tree trunk and branch core stay still: motion grows outward within the crown.
	float radial = length(VERTEX.xz - wind_bounds.zw) / height;
	float crown = mix(1.0, smoothstep(0.035, 0.24, radial), wind_motion.z);
	float mask = anchored * crown;
	// The mixed trellis atlas contains green leaves, brown timber and yellow gourds.
	// Explicit mip 0 works in vertex stage without fragment derivatives; only the
	// green texels may move. Height still anchors the bottom of climbing foliage.
	if (wind_leaf_texture_mask > 0.5 && textured) {
		vec3 leaf = textureLod(color_texture, UV * uv_scale.xy + uv_offset.xy, 0.0).rgb;
		float green = smoothstep(1.03, 1.12, leaf.g / max(leaf.r, 0.001));
		green *= smoothstep(1.25, 1.55, leaf.g / max(leaf.b, 0.001));
		mask *= green;
	}
	float phase = dot(NODE_POSITION_WORLD.xz, vec2(0.71, 0.43));
	float breeze = sin(TIME * 0.72 + phase) * 0.68 + sin(TIME * 1.13 + phase * 1.7) * 0.32;
	float ripple = sin(dot(original_world, vec3(4.1, 2.7, 3.6)) + TIME * 2.2);
	vec3 offset_world = vec3(0.86, 0.04, 0.51) * breeze * wind_motion.x * mask;
	offset_world += vec3(0.35, 0.12, -0.75) * ripple * wind_motion.w * mask * mask;
	// Convert a direction, not a point. Scaling a plant never increases its world wind limit.
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
	world_point = original_world;
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	if (frame_enabled > 0.5) {
		bool centre = SCREEN_UV.x > 0.16 && SCREEN_UV.x < 0.84 && SCREEN_UV.y > 0.12 && SCREEN_UV.y < 0.91;
		bool operation = SCREEN_UV.x > frame_safe_rect.x && SCREEN_UV.x < frame_safe_rect.z && SCREEN_UV.y > frame_safe_rect.y && SCREEN_UV.y < frame_safe_rect.w;
		if (centre || operation) { discard; }
	}
	vec3 color = base_color.rgb;
	if (textured) { color *= texture(color_texture, UV).rgb; }
	if (pigment) { color *= 0.87 + 0.20 * pigment_wash(world_point * wash_scale) + 0.045 * pigment_wash(world_point * wash_scale * 5.0); }
	// Separate foliage from ochre timber and earth under the afternoon light.
	// White radish shoulders, flowers and yellow gourds remain their own colour.
	float leaf_pigment = smoothstep(0.98, 1.13, color.g / max(color.r, 0.001));
	leaf_pigment *= smoothstep(1.06, 1.35, color.g / max(color.b, 0.001));
	color *= mix(vec3(1.0), vec3(0.85, 1.14, 0.94), leaf_pigment);
	ALBEDO = color;
	BACKLIGHT = color * leaf_pigment * .16;
	ROUGHNESS = base_roughness;
	SPECULAR = base_specular;
	METALLIC = base_metallic;
}
