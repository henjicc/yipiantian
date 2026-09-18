shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
void vertex() { VERTEX += NORMAL * 0.008; }
void fragment() { ALBEDO = vec3(0.88, 0.79, 0.48); }
