shader_type spatial;
render_mode blend_mix, cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=vec3(0.70,0.79,0.75);ROUGHNESS=.7;SPECULAR=.1;ALPHA=1.0-smoothstep(22.0,35.0,length(world_position.xz));}
