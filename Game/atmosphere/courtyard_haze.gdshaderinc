// One world-anchored atmospheric field for islands, water, vegetation and matte.
// Its clear ellipse encloses all six beds; camera motion never moves the fog.
global uniform float courtyard_haze_strength;
global uniform vec4 courtyard_haze_color : source_color;
global uniform vec4 courtyard_haze_region;
// A deliberately opened neighbour view gets its own world-anchored clear area.
// Ordinary overview/field zoom leaves w at zero and preserves the original fog.
global uniform vec4 courtyard_haze_visit;
float courtyard_haze(vec3 point) {
    float radius = length((point.xz - courtyard_haze_region.xy) / courtyard_haze_region.zw);
    float outside = max(0.0, radius - 1.0);
    float optical_depth = outside * outside / (outside + 0.45);
    // Low lake mist thins above the water: distant hills keep readable ridges
    // while their feet and the inhabited islands share the same atmosphere.
    optical_depth *= exp(-max(point.y, 0.0) * 0.35);
    float local_clear = 1.0 - smoothstep(5.6, 10.6, length(point.xz - courtyard_haze_visit.xy));
    float haze = min(0.97, 1.0 - exp(-courtyard_haze_strength * optical_depth * 2.0));
    return haze * (1.0 - local_clear * courtyard_haze_visit.w * 0.90);
}
