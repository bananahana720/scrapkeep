shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.824, 0.773, 0.647, 1.0);
uniform vec4 rock_color : source_color = vec4(0.776, 0.635, 0.455, 1.0);
uniform float ripple_metres = 0.6;
uniform float drift_metres = 4.0;
uniform float grain_metres = 0.026;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float grain_fade = 1.0 - smoothstep(0.012, 0.055, footprint);
	float grain = (surface_noise(p.xz / grain_metres) - 0.5) * grain_fade;
	float bend = sin(p.z * 6.283185 / 12.0) * 0.15;
	float ripple = sin((p.x + bend) * 6.283185 / ripple_metres);
	float drift = sin((p.x + sin(p.z * 6.283185 / 18.0) * 0.8) * 6.283185 / drift_metres);
	float broad = surface_macro(p.xz * 6.283185 / 16.0) - 0.5;
	float slope = 1.0 - smoothstep(0.55, 0.90, abs(surface_normal.y));
	float bed = p.y / 1.2 + sin(p.x * 6.283185 / 24.0) * 0.14 + sin(p.z * 6.283185 / 18.0) * 0.12;
	float cavity = pow(0.5 + 0.5 * cos(bed * 6.283185), 12.0);
	float tone = 1.0 + broad * 0.12 + ripple * 0.085 + drift * 0.055 + grain * 0.035 - cavity * slope * 0.16;
	ALBEDO = mix(base_color.rgb, rock_color.rgb, slope) * surface_value(tone);
	ROUGHNESS = 0.94;
	if (relief_enabled) {
		float height = (ripple * 0.009 + drift * 0.006) * (1.0 - slope) - cavity * slope * 0.020;
		NORMAL = surface_bump(VERTEX, NORMAL, height);
	}
}
