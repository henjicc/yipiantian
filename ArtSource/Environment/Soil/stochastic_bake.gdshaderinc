// Aligned maps baked from one periodic Blender material, at a 64cm physical scale.
uniform sampler2D loam_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D loam_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D loam_surface : repeat_enable, filter_linear_mipmap_anisotropic;

// Triangular lattice with deterministic rotation/offset and height-assisted blending.
// Explicit gradients retain correct mip selection across stochastic cell boundaries.
void sample_loam(vec2 world_xz, out vec3 albedo, out vec3 normal, out vec3 surface) {
	vec2 p = world_xz / .64;
	// Periodic 8x8 lattice: a 4m material tile, larger than an entire 2.4m bed.
	vec2 lattice = world_xz*2.0;
	vec2 id = floor(lattice), f = fract(lattice);
	vec3 weights;
	vec2 a = id, b = id+vec2(1,0), c = id+vec2(0,1);
	if (f.x+f.y > 1.0) {
		a += vec2(1); weights = vec3(f.x+f.y-1.0,1.0-f.y,1.0-f.x);
	} else { weights = vec3(1.0-f.x-f.y,f.x,f.y); }
	vec2 ids[3] = {a,b,c};
	vec2 dx = dFdx(p), dy = dFdy(p);
	albedo = vec3(0); normal = vec3(0); surface = vec3(0);
	float total = 0.0;
	for (int i=0;i<3;i++) {
		vec2 seed = mod(ids[i],vec2(8));
		float angle = terrain_hash(seed+vec2(83,19))*6.2831853;
		mat2 rotation = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
		vec2 offset = vec2(terrain_hash(seed+vec2(17,91)),terrain_hash(seed+vec2(113,3)));
		vec2 uv = rotation*(p-ids[i]*(.5/.64))+offset;
		vec3 data = textureGrad(loam_surface,uv,rotation*dx,rotation*dy).rgb;
		float weight = pow(weights[i],5.0)*exp2(data.b*4.0);
		vec3 sampled_normal = textureGrad(loam_normal,uv,rotation*dx,rotation*dy).rgb*2.0-1.0;
		// Source is Blender tangent +Y; this custom world-XZ sampler uses image-row V.
		// Flip before rotating slopes. Height/normal gradient audit catches the sign.
		sampled_normal.y = -sampled_normal.y;
		vec2 slope = transpose(rotation)*(sampled_normal.xy/max(sampled_normal.z,.15));
		albedo += textureGrad(loam_albedo,uv,rotation*dx,rotation*dy).rgb*weight;
		normal += vec3(slope.x,1.0,slope.y)*weight;
		surface += data*weight;
		total += weight;
	}
	albedo /= total;
	normal = normalize(normal);
	surface /= total;
}
