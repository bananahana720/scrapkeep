shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
uniform vec4 stone_color : source_color = vec4(0.737, 0.639, 0.510, 1.0);
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	vec2 plane = surface_plane(p, surface_normal);
	float erosion = surface_noise(plane * 0.31);
	float bed = p.y * 1.15 + surface_noise(p.xz * 0.09) * 0.75;
	float phase = fract(bed);
	float edge_width = max(fwidth(bed), 0.008);
	float cavity = 1.0 - smoothstep(0.02, 0.07 + edge_width, abs(phase - 0.50));
	float edge = smoothstep(0.55 - edge_width, 0.58, phase) * (1.0 - smoothstep(0.63, 0.68 + edge_width, phase));
	float grain_fade = 1.0 - smoothstep(0.02, 0.09, max(length(dFdx(p)), length(dFdy(p))));
	float grain = surface_noise(plane * 12.0) * grain_fade;
	float layer = 0.5 + 0.5 * sin(bed * 2.1);
	float value = 0.92 + (erosion - 0.5) * 0.16 + layer * 0.08 - cavity * 0.16 + edge * 0.07;
	float strength = detail_enabled ? detail_strength : 0.0;
	ALBEDO = stone_color.rgb * mix(1.0, clamp(value, 0.78, 1.08), strength);
	ROUGHNESS = clamp(0.94 - edge * 0.07 * strength, 0.85, 1.0);
	AO = 1.0 - cavity * 0.13 * strength;
	AO_LIGHT_AFFECT = 0.05;
	if (relief_enabled) {
		NORMAL = surface_bump(VERTEX, NORMAL, -cavity * 0.018 + edge * 0.006 + grain * 0.003);
	}
}
