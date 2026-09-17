// Shared world-space colour and normals across independently generated meshes.
float terrain_hash(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	return float((h ^ (h >> 13u)) & 16777215u) / 16777215.0;
}
float terrain_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*f*(f*(f*6.0-15.0)+10.0);
	return mix(mix(terrain_hash(i),terrain_hash(i+vec2(1,0)),f.x),
		mix(terrain_hash(i+vec2(0,1)),terrain_hash(i+vec2(1,1)),f.x),f.y);
}
vec2 terrain_rotate(vec2 p) { return vec2(.8*p.x-.6*p.y,.6*p.x+.8*p.y); }
vec3 turf_colour(vec2 p) {
	float patch = terrain_noise(terrain_rotate(p)*1.3)*.65 + terrain_noise(p*3.7)*.35;
	return mix(vec3(.159,.199,.076),vec3(.204,.252,.108),patch);
}
float turf_height(vec2 p) {
	return terrain_noise(terrain_rotate(p)*20.0)*.0007 + terrain_noise(p*49.0)*.0002;
}
vec3 turf_normal(vec2 p) {
	float e = .006;
	return normalize(vec3(-(turf_height(p+vec2(e,0))-turf_height(p-vec2(e,0)))/(2.0*e),
		1.0,-(turf_height(p+vec2(0,e))-turf_height(p-vec2(0,e)))/(2.0*e)));
}
