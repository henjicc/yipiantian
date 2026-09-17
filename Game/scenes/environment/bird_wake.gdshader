shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
varying vec3 world_point;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
void vertex(){ world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
    ALBEDO=vec3(.58,.72,.66)*courtyard_haze_color.rgb*1.6;
    ALPHA=strength*sin(UV.y*3.14159)*(.10+.035*sin(TIME*1.4-UV.x*5.0));
    FOG=vec4(courtyard_haze_color.rgb,courtyard_haze(world_point));
}
