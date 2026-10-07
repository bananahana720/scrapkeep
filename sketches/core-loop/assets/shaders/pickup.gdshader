shader_type spatial;
render_mode diffuse_burley;

uniform vec4 glow_color : source_color;
uniform float face_energy = 0.06;
uniform float rim_energy = 1.25;
uniform float emission_ceiling = 1.35;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.72;
	METALLIC = 0.15;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 1.6);
	float pulse = 0.9 + 0.1 * sin(TIME * 2.0);
	EMISSION = glow_color.rgb * min(face_energy + rim_energy * rim * pulse, emission_ceiling);
}
