shader_type spatial;
render_mode diffuse_burley;
instance uniform vec4 state_tint : source_color = vec4(0.545098, 0.941176, 0.827451, 1.0);
void fragment() {
    vec3 mint = vec3(0.258183, 0.871367, 0.651406);
    float state_mask = 1.0 - step(0.02, distance(COLOR.rgb, mint));
    ALBEDO = mix(COLOR.rgb, state_tint.rgb, state_mask);
    METALLIC = 0.22;
    ROUGHNESS = 0.82;
}
