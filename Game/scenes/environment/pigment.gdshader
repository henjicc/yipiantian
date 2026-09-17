shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.5,0.55,0.4,1.0);
uniform float wash_scale = 3.0;
uniform float stone_treatment : hint_range(0.0,1.0) = 0.0;
varying vec3 world_point;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float wash(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float broad=wash(world_point*wash_scale);
	float fine=wash(world_point*wash_scale*5.0);
	vec3 painted=base_color.rgb*(0.87+0.20*broad+0.045*fine);
	float wet=(1.0-smoothstep(-.23,.06,world_point.y+.06*(broad-.5)))*stone_treatment;
	float moss=smoothstep(.46,.70,wash(world_point*vec3(3.3,1.7,3.3)))*smoothstep(-.15,.18,world_point.y)*(1.0-smoothstep(.45,.9,world_point.y))*stone_treatment;
	ALBEDO=mix(painted,painted*vec3(.70,.78,.75),wet*.48);
	ALBEDO=mix(ALBEDO,ALBEDO*vec3(.78,.94,.62),moss*.42);
	ROUGHNESS=mix(.98,.78,wet);
	SPECULAR=mix(.08,.15,wet);
}
