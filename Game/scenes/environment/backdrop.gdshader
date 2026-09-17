shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D landscape : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atmosphere_tint : source_color = vec4(1.0);
varying vec3 backdrop_world;
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
	// The lower cylinder is only a colour bridge, never a stretched reflection wall.
	picture = mix(picture, vec3(0.60, 0.71, 0.68), smoothstep(0.80, 1.05, picture_v));
	ALBEDO = picture * atmosphere_tint.rgb;
}
