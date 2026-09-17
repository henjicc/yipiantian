// Stochastic construction is baked offline: three reads instead of nine per pixel.
// A four-metre repeat exceeds a whole bed. World UV keeps logical cell joins continuous.
uniform sampler2D loam_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D loam_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D loam_surface : repeat_enable, filter_linear_mipmap_anisotropic;

void sample_loam(vec2 world_xz, out vec3 albedo, out vec3 normal, out vec3 surface) {
	vec2 uv = world_xz*.25;
	albedo = texture(loam_albedo,uv).rgb;
	normal = normalize((texture(loam_normal,uv).rgb*2.0-1.0).xzy);
	surface = texture(loam_surface,uv).rgb;
}
