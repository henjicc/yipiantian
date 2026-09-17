// One world-anchored atmospheric field for islands, water, vegetation and matte.
// Its clear ellipse encloses all six beds; camera motion never moves the fog.
global uniform float courtyard_haze_strength;
global uniform vec4 courtyard_haze_color : source_color;
global uniform vec4 courtyard_haze_region;
float courtyard_haze(vec3 point) {
    float radius = length((point.xz - courtyard_haze_region.xy) / courtyard_haze_region.zw);
    float outside = max(0.0, radius - 1.0);
    float optical_depth = outside * outside / (outside + 0.45);
    return min(0.97, 1.0 - exp(-courtyard_haze_strength * optical_depth * 2.0));
}
