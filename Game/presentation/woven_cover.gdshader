shader_type spatial;
#include "res://atmosphere/courtyard_haze.gdshaderinc"
varying vec3 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_point.xz*88.0;
    vec2 width=max(fwidth(p),vec2(.01));
    vec2 edge=abs(fract(p)-.5);
    vec2 strand=vec2(1.0)-smoothstep(vec2(.32)-width,vec2(.47)+width,edge);
    float detail=1.0-smoothstep(.25,.85,max(width.x,width.y));
    float weave=mix(.70,.47+.34*max(strand.x,strand.y),detail);
    float wash=sin(world_point.x*16.3+sin(world_point.z*12.0))*.035;
    ALBEDO=mix(vec3(.24,.18,.09),vec3(.57,.46,.27),weave+wash);
    ROUGHNESS=.93;
    SPECULAR=.10;
    FOG=vec4(courtyard_haze_color.rgb,courtyard_haze(world_point));
}
