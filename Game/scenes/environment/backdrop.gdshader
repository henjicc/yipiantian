shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D landscape : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 mist_color : source_color = vec4(0.70,0.79,0.75,1);
uniform vec4 atmosphere_tint : source_color = vec4(1.0);
void fragment(){vec2 uv=vec2(1.0-abs(1.0-mod(UV.x,2.0)),UV.y);vec3 picture=texture(landscape,uv).rgb;float edge=smoothstep(0.78,1.0,UV.y);ALBEDO=mix(picture,mist_color.rgb,edge)*atmosphere_tint.rgb;}
