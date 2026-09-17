shader_type spatial;
render_mode cull_disabled;
varying vec3 world_point;
varying float tip;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tip = UV.y;
	float gust = sin(dot(world_point.xz, vec2(.71,.43)) + TIME*.72)*.68;
	gust += sin(dot(world_point.xz, vec2(.31,.73)) + TIME*1.13)*.32;
	vec3 offset = vec3(.86,.04,.51)*gust*.027*tip*tip;
	VERTEX += (inverse(MODEL_MATRIX)*vec4(offset,0.0)).xyz;
}
void fragment() {
	// Opaque curved blades, darker at their rooted base; no alpha-card sorting.
	vec3 root_color = vec3(.18,.24,.075);
	vec3 tip_color = vec3(.29,.38,.135);
	NORMAL = normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
	ALBEDO = mix(root_color,tip_color,smoothstep(0.0,1.0,tip))*COLOR.rgb;
	ROUGHNESS = .96;
	SPECULAR = .05;
	BACKLIGHT = ALBEDO*.18*tip;
}
