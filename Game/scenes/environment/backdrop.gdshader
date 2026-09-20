shader_type spatial;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
render_mode unshaded, cull_disabled, fog_disabled, depth_prepass_alpha;
uniform sampler2D far_mountains : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mid_hills : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D near_bank : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atmosphere_tint : source_color = vec4(1.0);
uniform vec4 sky_top : source_color = vec4(0.40, 0.53, 0.62, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.72, 0.72, 0.65, 1.0);
uniform vec4 lake_horizon : source_color = vec4(0.43, 0.59, 0.59, 1.0);
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.22;
instance uniform int landscape_layer = 0;
varying vec2 stage_point;
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 vec4 h = fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void vertex() { stage_point = VERTEX.xy; }
void fragment() {
 if (landscape_layer == 0) {
  vec3 sky = mix(sky_horizon.rgb, sky_top.rgb, smoothstep(58.0, 180.0, stage_point.y));
  // Reconstruct the virtual lake surface behind the real-water fade, so the
  // matte and 3D water share distance/fog instead of unrelated vertical bands.
  vec3 ray = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
  float water_distance = ray.y < -0.00001 ? max(0.0, (-0.25-CAMERA_POSITION_WORLD.y)/ray.y) : 10000.0;
  float haze = courtyard_haze(CAMERA_POSITION_WORLD + ray * water_distance);
  vec3 river = mix(lake_horizon.rgb, sky_horizon.rgb, haze);
  ALBEDO = mix(river, sky, smoothstep(90.0, 125.0, stage_point.y));
  ALPHA = 1.0;
 } else if (landscape_layer == 4) {
  float mist = noise(vec2(stage_point.x*0.09-TIME*0.024,stage_point.y*0.22));
  float band = exp(-pow(stage_point.y / 3.2, 2.0));
  ALBEDO = sky_horizon.rgb;
  ALPHA = band * smoothstep(0.2,0.8,mist) * cloud_strength;
 } else {
  vec4 painted;
  if (landscape_layer == 1) { painted = texture(far_mountains, UV); }
  else if (landscape_layer == 2) { painted = texture(mid_hills, UV); }
  else { painted = texture(near_bank, UV); }
  // The authored cutouts end mid-pigment. Orbit can expose those edges;
  // feather into the shared mist instead of revealing a rectangular card.
  float edge_fade = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
  // Near-zero-alpha RGB in generated cutouts is not meaningful pigment.
  if (painted.a < 0.025) { discard; }
  float base_haze = landscape_layer == 1 ? 0.40 : (landscape_layer == 2 ? 0.25 : 0.12);
  float haze = mix(base_haze,0.94,courtyard_haze_strength);
  ALBEDO = mix(painted.rgb * atmosphere_tint.rgb, sky_horizon.rgb, haze);
  ALPHA = smoothstep(0.025, 0.985, painted.a) * edge_fade;
 }
}
