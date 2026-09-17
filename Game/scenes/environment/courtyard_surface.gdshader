shader_type spatial;
render_mode cull_disabled;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
#include "res://scenes/environment/terrain_surface.gdshaderinc"
uniform sampler2D painted_color : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec2 ground_contact = vec2(0.0);
instance uniform float lantern_warmth = 0.0;
varying vec3 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 paint=texture(painted_color,UV).rgb*tint.rgb;
    if(ground_contact.y>0.0) {
        float edge=ground_contact.x+ground_contact.y*(.35+.65*terrain_noise(world_point.xz*36.0));
        float contact=1.0-smoothstep(edge-.015,edge+.015,world_point.y);
        paint=mix(paint, mix(paint*.66,turf_colour(world_point.xz),.22),contact*.65);
    }
    float paper=smoothstep(.13,.33,min(paint.r,paint.g))*smoothstep(.20,.45,paint.b/max(paint.r,.001));
    ALBEDO=paint;
    EMISSION=vec3(1.0,.53,.18)*paper*lantern_warmth*1.7;
    ROUGHNESS=.95;
    SPECULAR=.08;
    FOG=vec4(courtyard_haze_color.rgb,courtyard_haze(world_point));
}
