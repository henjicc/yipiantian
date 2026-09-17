shader_type spatial;
render_mode cull_disabled;
uniform sampler2D house_color : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 color_tint : source_color = vec4(1.0);
uniform float warmth : hint_range(0.0,1.0) = .16;
varying vec3 object_point;
varying vec3 object_normal;
void vertex(){object_point=VERTEX;object_normal=NORMAL;}
void fragment(){
	vec4 original=texture(house_color,UV)*color_tint;
	ALBEDO=original.rgb;
	ROUGHNESS=.97;
	SPECULAR=.08;
	// The light is on the original paper texture, never a floating plane over lattice.
	vec2 pane=vec2(abs(object_point.x)-1.95,object_point.y-1.51);
	float bounds=(1.0-smoothstep(.36,.44,abs(pane.x)))*(1.0-smoothstep(.40,.51,abs(pane.y)));
	float front=smoothstep(1.32,1.46,object_point.z)*smoothstep(.60,.88,object_normal.z);
	float paper=smoothstep(.28,.57,dot(original.rgb,vec3(.2126,.7152,.0722)));
	EMISSION=vec3(1.0,.55,.19)*bounds*front*paper*warmth*.95;
}
