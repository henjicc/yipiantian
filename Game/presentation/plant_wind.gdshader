shader_type spatial;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
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
instance uniform float wind_authored = 0.0;
// Crown bend amplitude in metres for authored meshes; per-plant scale set by the caller.
instance uniform float wind_authored_bend = 0.07;
instance uniform float leaf_paint_strength = 1.0;
instance uniform float preserve_painted_color = 0.0;
instance uniform float leaf_roughness_variation = 0.0;
instance uniform vec2 root_soil = vec2(-1000.0,0.0); // world soil height / contact band; crops only
instance uniform float frame_enabled = 0.0;
instance uniform float haze_exempt = 0.0;
instance uniform vec4 frame_safe_rect = vec4(0.15, 0.14, 0.85, 0.90);
varying vec3 world_point;
varying vec3 surface_point;

float pigment_hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float pigment_wash(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(pigment_hash(i), pigment_hash(i+vec3(1,0,0)), f.x), mix(pigment_hash(i+vec3(0,1,0)), pigment_hash(i+vec3(1,1,0)), f.x), f.y), mix(mix(pigment_hash(i+vec3(0,0,1)), pigment_hash(i+vec3(1,0,1)), f.x), mix(pigment_hash(i+vec3(0,1,1)), pigment_hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	surface_point = VERTEX;
	vec3 original_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(wind_bounds.y, 0.001);
	float relative_height = (VERTEX.y - wind_bounds.x) / height;
	float anchored = smoothstep(wind_motion.y, 1.0, relative_height);
	// Tree trunk and branch core stay still: motion grows outward within the crown.
	float radial = length(VERTEX.xz - wind_bounds.zw) / height;
	float crown = mix(1.0, smoothstep(0.035, 0.24, radial), wind_motion.z);
	float mask = anchored * crown;
	if (wind_authored > 0.5) { mask = COLOR.r; }
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
	offset_world += vec3(0.35, 0.12, -0.75) * ripple * wind_motion.w * (wind_authored > 0.5 ? COLOR.g : mask * mask);
	if (wind_authored > 0.5) {
		// One continuous bend through all branch junctions; only leaves flutter.
		offset_world += vec3(-0.20, 0.10, 0.42) * sin(TIME * 1.05 + COLOR.b * 3.0 + phase) * wind_authored_bend * mask;
		offset_world += vec3(0.5, 0.25, -0.4) * sin(TIME * 3.1 + COLOR.b * 11.0 + phase) * wind_motion.w * COLOR.g;
	}
	// Convert a direction, not a point. Scaling a plant never increases its world wind limit.
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
	world_point = original_world;
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	FOG = vec4(courtyard_haze_color.rgb, haze_exempt > 0.5 ? 0.0 : courtyard_haze(world_point));
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
	// The new autumn atlases already contain strong greens; only older pale maps
	// need this boost. Keep the new leaves closer to the muted reference palette.
	if (preserve_painted_color < 0.5) {
		float source_value = dot(color, vec3(0.2126, 0.7152, 0.0722));
		color = mix(vec3(source_value), color, mix(.78, 1.0, leaf_paint_strength));
		color *= mix(vec3(1.0), vec3(0.74, 1.20, 0.83), leaf_pigment * leaf_paint_strength);
		// Legacy maps need deeper midtones; approved painted maps bypass this block.
		float leaf_value = dot(color, vec3(0.2126, 0.7152, 0.0722));
		color = mix(color, color * (0.72 + 0.46 * leaf_value), leaf_pigment * leaf_paint_strength);
	}
	float contact = 0.0;
	if (root_soil.y > 0.0) {
		float dirt_edge = root_soil.x + root_soil.y*(.25+.75*pigment_wash(world_point*87.0));
		contact = (1.0-smoothstep(dirt_edge-.009,dirt_edge+.003,world_point.y))*(1.0-leaf_pigment);
		color = mix(color,vec3(.100,.060,.029)*(.8+.4*pigment_wash(world_point*145.0)),contact*.90);
	}
	ALBEDO = color;
	BACKLIGHT = color * leaf_pigment * .16;
	ROUGHNESS = mix(base_roughness,.97,contact);
	if (leaf_roughness_variation > 0.5) {
		// Object-space variation stays attached during wind and plant rotation.
		// Broad, matte patches only: pigment colour is not interpreted as height.
		float patches = pigment_wash(surface_point * 65.0);
		float grain = pigment_wash(surface_point * 220.0);
		float leaf_roughness = mix(.70, .98, smoothstep(.20, .80, patches * .8 + grain * .2));
		ROUGHNESS = mix(ROUGHNESS, leaf_roughness, leaf_pigment * (1.0 - contact));
	}
	SPECULAR = base_specular;
	METALLIC = base_metallic;
}
