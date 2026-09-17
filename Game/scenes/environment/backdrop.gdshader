shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D landscape : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atmosphere_tint : source_color = vec4(1.0);
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.36;
varying vec3 backdrop_world;

float cloud_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cloud_hash(cell), cloud_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(cloud_hash(cell + vec2(0.0, 1.0)), cloud_hash(cell + vec2(1.0)), f.x), f.y);
}
void vertex() {
	backdrop_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// The original 20..-50m ring mapped the painted village shore to y=-30m,
	// beneath the near water. Lift that part of the existing painting into view.
	vec3 ray = normalize(backdrop_world - CAMERA_POSITION_WORLD);
	vec2 forward = normalize(-INV_VIEW_MATRIX[2].xz);
	float plane_distance = 65.0 - dot(CAMERA_POSITION_WORLD.xz, forward);
	float painted_height = CAMERA_POSITION_WORLD.y + ray.y * plane_distance / max(0.05, dot(ray.xz, forward));
	// A distant vertical plane per viewing azimuth keeps the river bank horizontal,
	// avoiding the bowl-shaped shore produced by painting straight onto a cylinder.
	float picture_v = (20.0 - painted_height) / 70.0 * 2.0 - 0.42;
	vec2 uv = vec2(1.0 - abs(1.0 - mod(UV.x, 2.0)), min(picture_v, 0.985));
	vec3 picture = texture(landscape, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	// Only a separate thin cloud/mist layer moves. The mountain/village sample
	// above keeps its exact established projection and never scrolls with TIME.
	vec2 cloud_uv = vec2(uv.x * 18.0 - TIME * 0.025, picture_v * 11.0);
	float cloud = cloud_noise(cloud_uv) * 0.68 + cloud_noise(cloud_uv * 2.13 + vec2(7.2, 3.8)) * 0.32;
	cloud = smoothstep(0.40, 0.76, cloud);
	float sky_band = 1.0 - smoothstep(0.28, 0.43, picture_v);
	float mist_band = smoothstep(0.34, 0.44, picture_v) * (1.0 - smoothstep(0.59, 0.70, picture_v));
	// Dark ridge/pine pigments show through the mist, preserving their identity.
	float pale_mask = smoothstep(0.24, 0.58, dot(picture, vec3(0.2126, 0.7152, 0.0722)));
	float cloud_alpha = cloud * cloud_strength * (sky_band + mist_band * pale_mask * 0.45);
	picture = mix(picture, vec3(0.89, 0.88, 0.81), cloud_alpha);
	// The lower cylinder is only a colour bridge, never a stretched reflection wall.
	picture = mix(picture, vec3(0.60, 0.71, 0.68), smoothstep(0.80, 1.05, picture_v));
	ALBEDO = picture * atmosphere_tint.rgb;
}
