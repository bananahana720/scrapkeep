shader_type spatial;
render_mode diffuse_burley;

uniform bool lens = false;
uniform bool spent = false;
uniform vec4 spent_tint : source_color = vec4(0.380392, 0.454902, 0.505882, 1.0);
instance uniform float fx_time = 0.0;
instance uniform bool motion_enabled = true;
varying float lamp_energy;

void vertex() {
    float phase = INSTANCE_CUSTOM.y;
    float wave = sin(fx_time * 1.7 + phase);
    float angle = motion_enabled ? wave * 0.018 : 0.0;
    // The rail stays on its wall sockets; the hanging bracket and lens deflect together.
    float hang = max(0.0, -VERTEX.y - 0.18);
    VERTEX.x += sin(angle) * hang;
    VERTEX.y += (1.0 - cos(angle)) * hang;
    float flutter = pow(max(0.0, sin(fx_time * 8.3 + phase)), 16.0);
    lamp_energy = 1.0 - (motion_enabled ? INSTANCE_CUSTOM.x * 0.22 * flutter : 0.0);
}

void fragment() {
    vec3 paint = spent ? spent_tint.rgb * mix(0.75, 1.0, COLOR.r) : COLOR.rgb;
    ALBEDO = paint * (lens ? lamp_energy : 1.0);
    METALLIC = lens ? 0.0 : 0.22;
    ROUGHNESS = lens ? 0.38 : 0.82;
    EMISSION = lens ? vec3(1.0, 0.93, 0.82) * 0.12 * lamp_energy : vec3(0.0);
}
