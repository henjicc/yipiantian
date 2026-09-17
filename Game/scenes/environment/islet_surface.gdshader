shader_type spatial;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D painted_color : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.84,0.87,0.81,1.0);
varying vec3 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	FOG = vec4(courtyard_haze_color.rgb, courtyard_haze(world_point));
	// Past the real-water/matte transition, submerged bases must still disappear
	// at the same horizontal waterline, not expose a floating cutaway plinth.
	if (world_point.y < -.27) { discard; }
	vec3 pigment=texture(painted_color,UV).rgb*tint.rgb;
	float wet=1.0-smoothstep(-.25,.02,world_point.y);
	ALBEDO=mix(pigment,pigment*vec3(.62,.77,.73),wet*.5);
	ROUGHNESS=.96;
	SPECULAR=.08;
	// Use the shared Environment fog; writing FOG overrides it in Forward+.
}
