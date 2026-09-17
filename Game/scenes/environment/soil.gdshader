shader_type spatial;
#include "res://scenes/environment/terrain_surface.gdshaderinc"
uniform vec4 soil_color : source_color = vec4(0.40,0.30,0.19,1.0);
uniform float wetness : hint_range(0.0,1.0) = 0.0;
uniform bool bank = false;
varying vec3 soil_point;
float soil_height(vec2 p) {
	return terrain_noise(terrain_rotate(p)*17.0)*.0020 + terrain_noise(p*41.0)*.00035;
}
void vertex() { soil_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = soil_point.xz;
	float patch = terrain_noise(terrain_rotate(p)*2.3);
	float clods = terrain_noise(terrain_rotate(p*1.73+vec2(7.1,2.8))*7.0);
	float grain = terrain_noise(p*43.0);
	vec3 dirt_colour = soil_color.rgb*(.87+.13*patch+.12*clods+.05*grain);
	float dirt = bank ? smoothstep(.0,.76,COLOR.r+(clods-.5)*.18) : 1.0;
	ALBEDO = mix(turf_colour(p),dirt_colour,dirt);
	if (!bank) {
		float furrow = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
		ALBEDO *= .98+.02*smoothstep(0.0,.08,furrow);
	}
	// World-space height gradients avoid a dependency on missing mesh tangents.
	float e = .006;
	vec3 gradient = vec3((soil_height(p+vec2(e,0))-soil_height(p-vec2(e,0)))/(2.0*e),0,
		(soil_height(p+vec2(0,e))-soil_height(p-vec2(0,e)))/(2.0*e));
	vec3 n = normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	vec3 soil_normal = normalize(n-gradient+n*dot(n,gradient));
	NORMAL = normalize((VIEW_MATRIX*vec4(normalize(mix(turf_normal(p),soil_normal,dirt)),0.0)).xyz);
	ROUGHNESS = mix(.97,.87,wetness);
	SPECULAR = mix(.06,.12,wetness);
}
