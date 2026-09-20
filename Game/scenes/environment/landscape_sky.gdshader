shader_type sky;
// Direction-mapped silhouettes, without a finite or camera-tilted sky card.
uniform sampler2D western_ridge : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D eastern_ridge : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D rolling_ridge : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 sky_top : source_color = vec4(0.4, 0.53, 0.62, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.72, 0.72, 0.65, 1.0);
uniform vec4 ground_horizon : source_color = vec4(0.5, 0.45, 0.35, 1.0);
uniform vec4 ground_bottom : source_color = vec4(0.2, 0.18, 0.15, 1.0);
uniform vec4 atmosphere_tint : source_color = vec4(1.0);
uniform float cloud_offset = 0.0;
global uniform float courtyard_haze_strength;

float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 vec4 h = fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
vec4 ridge(sampler2D image, float heading, float elevation, float center, float width, float height) {
 float angle = atan(sin(heading-center), cos(heading-center));
 vec2 uv = vec2(angle/width+0.5, 0.80-elevation/height);
 if (uv.x<=0.0 || uv.x>=1.0 || uv.y<=0.0 || uv.y>=1.0) { return vec4(0.0); }
 vec4 pigment = texture(image,uv);
 pigment.a = smoothstep(0.04,0.98,pigment.a);
 pigment.a *= smoothstep(-0.015,0.018,elevation);
 return pigment;
}
void sky() {
 float elevation = asin(clamp(EYEDIR.y,-1.0,1.0));
 float heading = atan(EYEDIR.x,-EYEDIR.z);
 vec3 colour = mix(sky_horizon.rgb,sky_top.rgb,smoothstep(0.0,0.8,max(elevation,0.0)));
 vec2 cloud_point = EYEDIR.xz/max(0.16,EYEDIR.y+0.25)*2.6 + vec2(cloud_offset,0.0);
 float cloud = noise(cloud_point)*0.7+noise(cloud_point*2.1)*0.3;
 colour = mix(colour,sky_horizon.rgb*1.08,smoothstep(0.53,0.76,cloud)*0.22*smoothstep(0.01,0.12,elevation));
 float veil = clamp(0.32+courtyard_haze_strength*0.7,0.32,0.92);
 vec4 west = ridge(western_ridge,heading,elevation,-1.05,2.3,0.24);
 vec4 east = ridge(eastern_ridge,heading,elevation,0.60,2.2,0.21);
 vec4 back = ridge(rolling_ridge,heading,elevation,2.9,2.8,0.18);
 colour = mix(colour,mix(west.rgb*atmosphere_tint.rgb,sky_horizon.rgb,veil),west.a);
 colour = mix(colour,mix(east.rgb*atmosphere_tint.rgb,sky_horizon.rgb,veil+0.04),east.a);
 colour = mix(colour,mix(back.rgb*atmosphere_tint.rgb,sky_horizon.rgb,veil+0.07),back.a);
 if (AT_CUBEMAP_PASS) {
  vec3 ground = mix(ground_horizon.rgb,ground_bottom.rgb,smoothstep(0.0,0.8,-elevation));
  colour = mix(colour*0.85,ground*0.48,smoothstep(-0.005,0.015,-elevation));
 }
 COLOR = colour;
}
