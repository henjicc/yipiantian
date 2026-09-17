shader_type spatial;
render_mode cull_disabled;
// Analytic render-time motion: one fixed MultiMesh upload, no transform streaming
// or particle fixed-FPS stepping. Reset happens only at zero visible size.
void vertex() {
    float age = mod(TIME + INSTANCE_CUSTOM.x * 15.0, 15.0);
    float phase = INSTANCE_CUSTOM.z * 6.283185;
    float fall = clamp(age / 11.0, 0.0, 1.0);
    float airborne = 1.0 - smoothstep(.9, 1.0, fall);
    float visibility = smoothstep(0.0,.8,age) * (1.0-smoothstep(12.0,15.0,age));
    bool petal = COLOR.r > .8;
    VERTEX *= visibility * (petal ? .27 : .50);
    float angle = sin(age*.8+phase)*.55*airborne;
    mat2 turn = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
    VERTEX.xy = turn * VERTEX.xy;
    NORMAL.xy = turn * NORMAL.xy;
    VERTEX += vec3(.25*fall+sin(age*.85+phase)*.07*sin(3.14159*fall),
        (.15-INSTANCE_CUSTOM.y)*pow(fall,1.08),
        .18*fall+cos(age*.7+phase)*.055*sin(3.14159*fall));
}
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = .96;
    SPECULAR = .08;
}
