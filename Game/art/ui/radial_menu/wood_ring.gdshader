shader_type canvas_item;

uniform float inner_radius : hint_range(0.0, 1.0) = 0.84;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.94;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	float radius = length(point);
	float feather = max(fwidth(radius) * 1.35, 0.0015);
	float ring = smoothstep(inner_radius - feather, inner_radius + feather, radius)
		* (1.0 - smoothstep(outer_radius - feather, outer_radius + feather, radius));

	float across = clamp((radius - inner_radius) / max(outer_radius - inner_radius, 0.001), 0.0, 1.0);
	// Keep the source wood in planar coordinates. Polar remapping compresses the
	// grain across a narrow band and turns natural variation into record-like
	// concentric stripes.
	vec3 wood = texture(TEXTURE, UV).rgb;

	// Shallow waxed-wood bevel: light catches the inner shoulder while the
	// outer rim remains darker, without baking a fixed-size frame into the art.
	float inner_light = 1.0 - smoothstep(0.05, 0.24, across);
	float outer_dark = smoothstep(0.72, 1.0, across);
	float edge_key = (1.0 - smoothstep(0.0, 0.045, across)) + smoothstep(0.94, 1.0, across);
	float carved_shoulder = 1.0 - smoothstep(0.0, 0.035, abs(across - 0.16));
	float top_light = clamp(-point.y * 0.035, -0.025, 0.025);
	wood *= 0.91 + inner_light * 0.13 - outer_dark * 0.10 - edge_key * 0.16 + top_light;
	wood += vec3(0.055, 0.032, 0.018) * carved_shoulder;

	vec2 shadow_point = point - vec2(0.0, 0.018);
	float shadow_radius = length(shadow_point);
	float shadow = (1.0 - smoothstep(outer_radius + 0.004, outer_radius + 0.055, shadow_radius))
		* smoothstep(outer_radius - feather, outer_radius + feather, radius) * 0.24;
	float alpha = max(ring, shadow);
	vec3 color = mix(vec3(0.14, 0.095, 0.055), wood, ring);
	COLOR = vec4(color, alpha);
}
