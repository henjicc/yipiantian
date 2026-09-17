shader_type spatial;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
#include "res://scenes/environment/terrain_surface.gdshaderinc"
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.5,0.55,0.4,1.0);
uniform float wash_scale = 3.0;
uniform float stone_treatment : hint_range(0.0,1.0) = 0.0;
uniform float ground_treatment : hint_range(0.0,1.0) = 0.0;
uniform float foundation_treatment : hint_range(0.0,1.0) = 0.0;
uniform bool painted_rock = false;
uniform sampler2D rock_color : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 world_point;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float wash(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	FOG = vec4(courtyard_haze_color.rgb, courtyard_haze(world_point));
	float broad=wash(world_point*wash_scale);
	float fine=wash(world_point*wash_scale*5.0);
	vec3 painted=base_color.rgb*(0.82+0.27*broad+0.055*fine);
	// Broad pigment islands remain legible from the overview. The finer layer
	// provides restrained mineral flecks without turning the stone into noise.
	float mineral=wash(world_point*vec3(2.7,4.1,2.7));
	float vein=smoothstep(.43,.51,mineral)*(1.0-smoothstep(.53,.61,mineral));
	painted=mix(painted,painted*mix(vec3(.74,.81,.84),vec3(1.18,1.11,.94),broad),stone_treatment*.75);
	painted=mix(painted,painted*1.22,vein*stone_treatment*.28);
	// Retain the image-guided rock washes; instance tint integrates them with
	// the shore or path. Procedural stone shading still serves bridge and mill.
	if (painted_rock) {
		vec3 pigment=texture(rock_color,UV).rgb;
		float value=dot(pigment,vec3(.2126,.7152,.0722));
		vec3 tint=mix(vec3(dot(base_color.rgb,vec3(.2126,.7152,.0722))),base_color.rgb,.45);
		painted=mix(vec3(value),pigment,.45)*tint*2.6;
	}
	float ground_patch=wash(world_point*vec3(.72,.34,.72));
	painted=mix(painted,painted*mix(vec3(.68,.82,.65),vec3(1.04,.94,.73),ground_patch),ground_treatment*.7);
	// Match both sides of the grass/soil seam in the same coordinate space.
	if (ground_treatment>.5) {
		vec3 world_normal=(INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
		float top=smoothstep(.6,.95,world_normal.y);
		float turf=top*smoothstep(-.16,.12,world_point.y+(ground_patch-.5)*.19);
		painted=mix(painted,turf_colour(world_point.xz),turf);
		// Keep the rounded bank's geometric normal. The former replacement with
		// an upward turf normal flattened the light across its entire shoulder.
		NORMAL=normalize(NORMAL+(VIEW_MATRIX*vec4(turf_normal(world_point.xz)-vec3(0,1,0),0.0)).xyz*top);
	}
	float foot=(1.0-smoothstep(.13,.23+terrain_noise(world_point.xz*11.0)*.035,world_point.y))*foundation_treatment;
	painted=mix(painted,mix(painted*.65,turf_colour(world_point.xz),.28),foot);
	float wet=(1.0-smoothstep(-.25,-.12,world_point.y+.025*(broad-.5)))*max(stone_treatment,ground_treatment);
	float moss=smoothstep(.46,.70,wash(world_point*vec3(3.3,1.7,3.3)))*smoothstep(-.15,.18,world_point.y)*(1.0-smoothstep(.45,.9,world_point.y))*stone_treatment;
	ALBEDO=mix(painted,painted*vec3(.49,.66,.65),wet*.75);
	ALBEDO=mix(ALBEDO,ALBEDO*vec3(.78,.94,.62),moss*(painted_rock ? .14 : .42));
	ROUGHNESS=mix(.93+.06*fine,.73,wet);
	SPECULAR=mix(.08,.15,wet);
}
