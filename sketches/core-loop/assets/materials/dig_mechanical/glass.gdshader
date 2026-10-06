shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_burley;
instance uniform float frosted : hint_range(0.0, 1.0) = 1.0;
void fragment() {
    ALBEDO = mix(vec3(0.94, 0.97, 0.96), COLOR.rgb, frosted);
    ROUGHNESS = mix(0.05, 0.38, frosted);
    ALPHA = mix(0.12, 1.0, frosted);
}
