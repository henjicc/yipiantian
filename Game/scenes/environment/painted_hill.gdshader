shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, fog_disabled;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
uniform sampler2D pigment : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atmosphere_tint : source_color = vec4(1.0);
uniform vec4 horizon_color : source_color = vec4(0.72,0.72,0.65,1.0);
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec4 paint = texture(pigment,UV);
 float coverage = smoothstep(0.08,0.8,paint.a);
 if (coverage < 0.01 || world_point.y < -0.25) { discard; }
 // Preserve painted folds; low shore feet dissolve into the shared lake mist.
 float mist = 0.18 + courtyard_haze(world_point)*0.42;
 mist = mix(mist,0.97,1.0-smoothstep(-0.25,2.5,world_point.y));
 ALBEDO = mix(paint.rgb*atmosphere_tint.rgb,horizon_color.rgb,mist);
 ALPHA = coverage;
}
