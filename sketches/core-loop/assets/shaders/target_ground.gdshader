shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float grain_fade = 1.0 - smoothstep(0.012, 0.055, footprint);
	float broad = surface_noise(p.xz * 0.24);
	float grain = surface_noise(p.xz * 38.0) * grain_fade;
	float ripple = sin(p.x * 15.0 + sin(p.z * 0.65) * 1.5);
	float variation = (broad - 0.5) * 0.18 + (grain - grain_fade * 0.5) * 0.055;
	float slope = 1.0 - smoothstep(0.55, 0.90, abs(surface_normal.y));
	float bed = p.y * 1.05 + surface_noise(p.xz * 0.11) * 0.65;
	float groove = 1.0 - smoothstep(0.035, 0.10 + fwidth(bed), abs(fract(bed) - 0.5));
	float tone = 0.97 + variation - groove * slope * 0.10;
	ALBEDO = COLOR.rgb * mix(1.0, clamp(tone, 0.84, 1.08), detail_enabled ? detail_strength : 0.0);
	ROUGHNESS = 0.94;
	if (relief_enabled) {
		float height = ripple * grain_fade * 0.002 + grain * 0.004 - groove * slope * 0.012;
		NORMAL = surface_bump(VERTEX, NORMAL, height);
	}
}
