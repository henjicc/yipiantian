shader_type spatial;
#include "res://scenes/environment/terrain_surface.gdshaderinc"
#include "res://scenes/environment/loam_surface.gdshaderinc"
uniform float wetness : hint_range(0.0,1.0) = 0.0;
uniform bool bank = false;
instance uniform vec2 cell_center = vec2(0.0);
instance uniform vec2 cell_half_span = vec2(.30,.22);
instance uniform vec2 field_half_extent = vec2(1.2,.88);
instance uniform float planted = 0.0;
instance uniform float root_size = 1.0;
instance uniform float field_selected = 0.0;
instance uniform float cell_selected = 0.0;
instance uniform float uncultivated = 0.0;
instance uniform vec2 root_radius = vec2(.075,.060);
varying vec3 soil_point;
varying vec2 bed_point;
varying vec2 patch_point;

// GPU counterpart of TilledSoil.height_at: relocated crumbs follow the same bed.
float bed_height(vec2 p) {
	vec2 edge = field_half_extent-abs(p);
	float fade = smoothstep(0.0,.13,min(edge.x,edge.y));
	float furrow = sin((p.y+field_half_extent.y)*TAU/(cell_half_span.y*2.0)+sin(p.x*5.0)*.16);
	float lumps = sin(p.x*17.0+p.y*8.0)*sin(p.y*21.0-p.x*6.0);
	return fade*(.010*furrow+.008*lumps+.004*sin(p.x*37.0+p.y*29.0));
}

// Pressed root pocket with broken, low shoulders. Support ends inside each cell.
float mound(vec2 p) {
	float r = length(p/root_radius);
	float irregular = .65+.6*terrain_noise(p*39.0+cell_center*21.0);
	// pow(negative, 2.0) can produce NaN on D3D12, punching out the root pocket.
	float shoulder_distance = (r-.95)*1.35;
	float shoulder = exp(-shoulder_distance*shoulder_distance)*.038*irregular;
	float fade = 1.0-smoothstep(1.5,2.1,r);
	float height_scale = min(1.0,min(root_radius.x/.075,root_radius.y/.060));
	return planted*root_size*height_scale*fade*(shoulder-.004*exp(-r*r*3.0));
}
void vertex() {
	// Red vertices are planted contact crumbs; hidden below the bed when empty.
	if (!bank && COLOR.r > .5) {
		vec2 scale_xz = root_radius/vec2(.075,.060);
		float scale_y = min(1.0,min(scale_xz.x,scale_xz.y));
		float above_bed = VERTEX.y-bed_height(VERTEX.xz+cell_center);
		VERTEX.xz *= scale_xz;
		VERTEX.y = bed_height(VERTEX.xz+cell_center)+above_bed*scale_y;
		NORMAL = normalize(NORMAL/vec3(scale_xz.x,scale_y,scale_xz.y));
		VERTEX.y -= (1.0-planted)*.10;
	}
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
	vec3 detail, grain_normal, surface;
	sample_loam(p,detail,grain_normal,surface);
	vec3 dirt_colour = detail*(.82+.32*patch);
	float dirt = bank ? smoothstep(.0,.76,COLOR.r+(clods-.5)*.18) : 1.0;
	float root_zone = bank ? 0.0 : 1.0-smoothstep(.025,.20,length(patch_point*vec2(1.0,1.2)));
	float moisture = bank ? 0.0 : wetness*(1.0-smoothstep(.55,1.0,length(patch_point/(cell_half_span+vec2(.02)))));
	dirt_colour *= 1.0 - .23*moisture - .08*planted*root_zone;
	vec2 patch_edge=cell_half_span-abs(patch_point);
	float ground_blend=smoothstep(0.0,.055,min(patch_edge.x,patch_edge.y));
	vec3 packed_earth=mix(dirt_colour,vec3(.20,.15,.075),.32)*(.9+.18*clods);
	vec3 untended_colour=mix(packed_earth,turf_colour(p)*(.8+.3*patch),smoothstep(.65,.95,uncultivated));
	vec3 ground_colour=mix(dirt_colour,untended_colour,uncultivated*ground_blend);
	ALBEDO = mix(turf_colour(p),ground_colour,dirt);
	// Tangent-free world-space detail, shared with the bank at the join.
	vec3 n = normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	vec3 perturbation = vec3(grain_normal.x,0,grain_normal.z)/max(grain_normal.y,.15);
	vec3 soil_normal = normalize(n+perturbation-n*dot(n,perturbation));
	NORMAL = normalize((VIEW_MATRIX*vec4(normalize(mix(turf_normal(p),soil_normal,dirt)),0.0)).xyz);
	ROUGHNESS = mix(surface.g,.85,moisture);
	SPECULAR = .06;
	AO = mix(1.0,surface.r,dirt)*(1.0-.13*planted*root_zone);
	if (!bank) {
		// Opaque ground shading: no floating geometry, transparency sorting or z-fighting.
		vec2 edge = field_half_extent-abs(bed_point);
		float border = (1.0-smoothstep(.014,.055,min(edge.x,edge.y)))*smoothstep(0.0,.012,min(edge.x,edge.y));
		float corners = smoothstep(.72,.90,abs(bed_point.x)/field_half_extent.x)*smoothstep(.64,.86,abs(bed_point.y)/field_half_extent.y);
		float field_mark = field_selected*border*corners*(.8+.2*clods);
		vec2 q = abs(patch_point)-(cell_half_span-vec2(.055));
		float distance = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0)-.02;
		float cell_corners = smoothstep(.433,.767,abs(patch_point.x)/cell_half_span.x)*smoothstep(.227,.591,abs(patch_point.y)/cell_half_span.y);
		float cell_mark = cell_selected*(1.0-smoothstep(.004,.012,abs(distance)))*cell_corners;
		vec3 tint = vec3(.55,.43,.22);
		ALBEDO = mix(ALBEDO,tint,clamp(field_mark*.55+cell_mark*.65,0.0,.7));
		EMISSION = tint*(field_mark*.10+cell_mark*.15);
	}
}
