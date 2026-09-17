shader_type spatial;
#include "res://scenes/environment/terrain_surface.gdshaderinc"
uniform vec4 soil_color : source_color = vec4(0.40,0.33,0.26,1.0);
uniform float wetness : hint_range(0.0,1.0) = 0.0;
uniform bool bank = false;
uniform sampler2D soil_detail : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
instance uniform vec2 cell_center = vec2(0.0);
instance uniform float planted = 0.0;
instance uniform float root_size = 1.0;
instance uniform float field_selected = 0.0;
instance uniform float cell_selected = 0.0;
varying vec3 soil_point;
varying vec2 bed_point;
varying vec2 patch_point;

// A broad asymmetric mound merging back into the original bed, not a separate ring.
float mound(vec2 p) {
	vec2 q = (p + vec2(.012,-.006)) / (vec2(.235,.175)*mix(.65,1.0,root_size));
	float radius = length(q);
	float envelope = 1.0 - smoothstep(.38,1.0,radius);
	float lumps = .90 + .16*sin(p.x*42.0+p.y*19.0)*sin(p.y*37.0-1.2);
	return planted * root_size * .065 * envelope * lumps;
}
float micro_height(vec2 p) {
	// Albedo luminance is only a restrained artistic micro-bump, not measured height.
	float grain = dot(textureLod(soil_detail,p*.65,1.0).rgb,vec3(.299,.587,.114));
	return grain*.004 + terrain_noise(terrain_rotate(p)*27.0)*.0007;
}
void vertex() {
	patch_point = VERTEX.xz;
	bed_point = VERTEX.xz + cell_center;
	if (!bank) {
		VERTEX.y += mound(VERTEX.xz);
		float e = .002;
		vec3 gradient = vec3((mound(VERTEX.xz+vec2(e,0))-mound(VERTEX.xz-vec2(e,0)))/(2.0*e),0,
			(mound(VERTEX.xz+vec2(0,e))-mound(VERTEX.xz-vec2(0,e)))/(2.0*e));
		NORMAL = normalize(NORMAL - gradient + NORMAL * dot(NORMAL,gradient));
	}
	soil_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = soil_point.xz;
	float patch = terrain_noise(terrain_rotate(p)*2.3);
	float clods = terrain_noise(terrain_rotate(p)*27.0);
	vec3 detail = texture(soil_detail,p*.65).rgb * vec3(.68,.77,.86);
	vec3 dirt_colour = mix(soil_color.rgb,detail,.68)*(.85+.22*patch);
	float dirt = bank ? smoothstep(.0,.76,COLOR.r+(clods-.5)*.18) : 1.0;
	float root_zone = bank ? 0.0 : 1.0-smoothstep(.025,.20,length(patch_point*vec2(1.0,1.2)));
	float moisture = bank ? 0.0 : wetness*(1.0-smoothstep(.55,1.0,length(patch_point/vec2(.32,.24))));
	dirt_colour *= 1.0 - .27*moisture - .18*planted*root_zone;
	ALBEDO = mix(turf_colour(p),dirt_colour,dirt);
	float e = .004;
	vec3 gradient = vec3((micro_height(p+vec2(e,0))-micro_height(p-vec2(e,0)))/(2.0*e),0,
		(micro_height(p+vec2(0,e))-micro_height(p-vec2(0,e)))/(2.0*e));
	// Tangent-free world-space detail, shared with the bank at the join.
	vec3 n = normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	vec3 soil_normal = normalize(n-gradient+n*dot(n,gradient));
	NORMAL = normalize((VIEW_MATRIX*vec4(normalize(mix(turf_normal(p),soil_normal,dirt)),0.0)).xyz);
	ROUGHNESS = mix(.98,.90,moisture);
	SPECULAR = .06;
	AO = 1.0-.20*planted*root_zone;
	if (!bank) {
		// Opaque ground shading: no floating geometry, transparency sorting or z-fighting.
		vec2 edge = vec2(1.2,.88)-abs(bed_point);
		float border = (1.0-smoothstep(.014,.055,min(edge.x,edge.y)))*smoothstep(0.0,.012,min(edge.x,edge.y));
		float corners = smoothstep(.72,.90,abs(bed_point.x)/1.2)*smoothstep(.64,.86,abs(bed_point.y)/.88);
		float field_mark = field_selected*border*corners*(.8+.2*clods);
		vec2 q = abs(patch_point)-vec2(.245,.165);
		float distance = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0)-.02;
		float cell_corners = smoothstep(.13,.23,abs(patch_point.x))*smoothstep(.05,.13,abs(patch_point.y));
		float cell_mark = cell_selected*(1.0-smoothstep(.004,.012,abs(distance)))*cell_corners;
		vec3 tint = vec3(.55,.43,.22);
		ALBEDO = mix(ALBEDO,tint,clamp(field_mark*.55+cell_mark*.65,0.0,.7));
		EMISSION = tint*(field_mark*.10+cell_mark*.15);
	}
}
