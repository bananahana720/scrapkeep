shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.776, 0.635, 0.455, 1.0);
uniform float strata_metres = 1.2;
uniform float grain_metres = 0.083;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	vec2 plane = surface_plane(p, surface_normal);
	float erosion = surface_macro(plane * 6.283185 / 8.0) - 0.5;
	float bed = p.y / strata_metres + sin(p.x * 6.283185 / 24.0) * 0.14 + sin(p.z * 6.283185 / 18.0) * 0.12;
	float phase = bed * 6.283185;
	float cavity = pow(0.5 + 0.5 * cos(phase), 12.0);
	float lip = pow(0.5 + 0.5 * cos(phase - 0.75), 16.0);
	float grain_fade = 1.0 - smoothstep(0.02, 0.09, max(length(dFdx(p)), length(dFdy(p))));
	float grain = (surface_noise(plane / grain_metres) - 0.5) * grain_fade;
	float tone = 1.0 + erosion * 0.12 + sin(phase) * 0.075 - cavity * 0.20 + lip * 0.08 + grain * 0.025;
	ALBEDO = base_color.rgb * surface_value(tone);
	ROUGHNESS = 0.94;
	AO = 1.0 - cavity * 0.12 * (detail_enabled ? detail_strength : 0.0);
	AO_LIGHT_AFFECT = 0.05;
	if (relief_enabled) {
		NORMAL = surface_bump(VERTEX, NORMAL, -cavity * 0.025 + lip * 0.008);
	}
}
