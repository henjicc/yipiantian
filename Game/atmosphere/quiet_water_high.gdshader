shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, ambient_light_disabled;
#define ISOLATE_WATER_GI
#include "res://atmosphere/quiet_water.gdshaderinc"
