shader_type spatial;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D painted_color : source_color, filter_linear_mipmap, repeat_disable;
uniform bool floating = false;
varying vec3 world_point;
void vertex(){
 vec3 point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 float phase=TIME*.85+point.x*.6+point.z*.37;
 float height=max(VERTEX.y,0.0);
 if(floating){VERTEX.y+=sin(phase)*.014;}
 else{VERTEX.x+=sin(phase)*height*height*.035;}
 world_point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment(){
	FOG = vec4(courtyard_haze_color.rgb, courtyard_haze(world_point));
 if(world_point.y < -.28){discard;}
 ALBEDO=texture(painted_color,UV).rgb*vec3(.70,.79,.66);
 ROUGHNESS=.97;
 SPECULAR=.05;
}
