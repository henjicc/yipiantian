shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.008;
uniform vec3 tint = vec3(0.88, 0.79, 0.48);
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = tint; }
