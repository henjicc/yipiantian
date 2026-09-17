shader_type spatial;
render_mode cull_disabled;
uniform sampler2D painted_color : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 haze_color : source_color = vec4(.72,.73,.66,1);
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
 if(world_point.y < -.28){discard;}
 ALBEDO=texture(painted_color,UV).rgb*vec3(.70,.79,.66);
 ROUGHNESS=.97;
 SPECULAR=.05;
 FOG=vec4(haze_color.rgb,smoothstep(35.0,105.0,length(VERTEX))*.32);
}
