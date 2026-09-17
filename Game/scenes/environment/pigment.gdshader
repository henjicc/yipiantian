shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.5,0.55,0.4,1.0);
uniform float wash_scale = 3.0;
uniform float stone_treatment : hint_range(0.0,1.0) = 0.0;
uniform float ground_treatment : hint_range(0.0,1.0) = 0.0;
varying vec3 world_point;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float wash(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float broad=wash(world_point*wash_scale);
	float fine=wash(world_point*wash_scale*5.0);
	vec3 painted=base_color.rgb*(0.82+0.27*broad+0.055*fine);
	// Broad pigment islands remain legible from the overview. The finer layer
	// provides restrained mineral flecks without turning the stone into noise.
	float mineral=wash(world_point*vec3(2.7,4.1,2.7));
	float vein=smoothstep(.43,.51,mineral)*(1.0-smoothstep(.53,.61,mineral));
	painted=mix(painted,painted*mix(vec3(.74,.81,.84),vec3(1.18,1.11,.94),broad),stone_treatment*.75);
	painted=mix(painted,painted*1.22,vein*stone_treatment*.28);
	float ground_patch=wash(world_point*vec3(.72,.34,.72));
	painted=mix(painted,painted*mix(vec3(.68,.82,.65),vec3(1.04,.94,.73),ground_patch),ground_treatment*.7);
	float turf=wash(world_point*vec3(35.0,1.0,35.0));
	painted*=1.0+(turf-.5)*.14*ground_treatment;
	// Centimetre-scale turf relief catches grazing light without moving gameplay.
	if (ground_treatment>.5) {
		float dx=wash((world_point+vec3(.008,0,0))*vec3(35,1,35))-turf;
		float dz=wash((world_point+vec3(0,0,.008))*vec3(35,1,35))-turf;
		vec3 turf_normal=normalize((VIEW_MATRIX*vec4(-dx*.32,1.0,-dz*.32,0.0)).xyz);
		vec3 world_normal=(INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
		NORMAL=normalize(mix(NORMAL,turf_normal,smoothstep(.6,.95,world_normal.y)));
	}
	float wet=(1.0-smoothstep(-.23,.06,world_point.y+.06*(broad-.5)))*stone_treatment;
	float moss=smoothstep(.46,.70,wash(world_point*vec3(3.3,1.7,3.3)))*smoothstep(-.15,.18,world_point.y)*(1.0-smoothstep(.45,.9,world_point.y))*stone_treatment;
	ALBEDO=mix(painted,painted*vec3(.70,.78,.75),wet*.48);
	ALBEDO=mix(ALBEDO,ALBEDO*vec3(.78,.94,.62),moss*.42);
	ROUGHNESS=mix(.93+.06*fine,.73,wet);
	SPECULAR=mix(.08,.15,wet);
}
