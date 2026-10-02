shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
// Albedo follows the high look (packed-sand floor map x baked vertex tint, strata rock
// on steep faces); target adds surface quality on top without moving the mean colour.
uniform vec4 base_color : source_color = vec4(0.824, 0.773, 0.647, 1.0);
uniform vec4 rock_color : source_color = vec4(0.776, 0.635, 0.455, 1.0);
uniform sampler2D floor_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_floor_map = false;
uniform float floor_metres = 5.0;
// Linear values, as high's sandstone shader writes them: tint divisor and strata hues.
uniform vec3 tint_reference = vec3(0.82, 0.77, 0.65);
uniform vec3 rock_dark = vec3(0.42, 0.245, 0.13);
uniform vec3 rock_light = vec3(0.72, 0.51, 0.29);
uniform float ripple_metres = 0.55;
uniform float grain_metres = 0.026;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	vec3 n = surface_normal;
	vec3 w = abs(n) * abs(n) * abs(n) * abs(n);
	w /= max(w.x + w.y + w.z, 0.001);
	float tex_grain = w.x * surface_noise(p.yz * 2.1) + w.y * surface_noise(p.xz * 2.1) + w.z * surface_noise(p.xy * 2.1);
	float erosion = 0.5 * (surface_noise(vec2(p.x + p.y, p.z) * 0.13) + surface_noise(vec2(p.z + p.y * 1.7, p.x) * 0.13));
	float slope = 1.0 - smoothstep(0.58, 0.93, abs(n.y));
	// Ripples only below about 15 degrees: the weight is zero at cos(15) and above.
	float flat_weight = smoothstep(0.966, 0.992, n.y);

	// Sand: the high floor map and tint, plus wind ripples, drift and fine grain on flat ground.
	vec3 floor_tex = has_floor_map ? texture(floor_map, p.xz / floor_metres).rgb : base_color.rgb;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float grain_fade = 1.0 - smoothstep(0.012, 0.055, footprint);
	float grain = (surface_noise(p.xz / grain_metres) - 0.5) * grain_fade;
	float bend = sin(p.z * 6.283185 / 9.0) * 0.18 + (erosion - 0.5) * 0.9;
	float ripple = sin((p.x + bend) * 6.283185 / ripple_metres);
	float drift = sin((p.x * 0.93 + p.z * 0.37 + sin(p.z * 6.283185 / 17.0) * 0.9) * 6.283185 / 3.5);
	float broad = surface_macro(p.xz * 6.283185 / 16.0) - 0.5;
	float sand_tone = 0.97 + tex_grain * 0.05 + (ripple * 0.07 + drift * 0.045 + grain * 0.05 + broad * 0.10) * flat_weight;
	vec3 sand = floor_tex * (COLOR.rgb / tint_reference) * surface_value(sand_tone);

	// Rock: high's strata hues, with ledges (bright lip over a dark undercut) and cracks that follow height.
	float bed = p.y * 0.39 + sin(p.x * 0.073 + p.z * 0.052) * 1.25 + erosion * 1.7;
	float f = fract(bed);
	float lip = smoothstep(0.68, 0.83, f) * (1.0 - smoothstep(0.88, 0.98, f));
	float shelf = smoothstep(0.88, 0.99, f) * (1.0 - smoothstep(0.99, 1.0, f));
	float crack = pow(0.5 + 0.5 * cos(bed * 6.283185 * 3.0 + erosion * 4.0), 16.0);
	vec3 rock = mix(rock_dark, rock_light, 0.5 * 0.22 + erosion * 0.78);
	rock *= surface_value(0.92 + tex_grain * 0.16 - lip * 0.20 + shelf * 0.10 - crack * 0.12);

	float damp = smoothstep(200.0, 214.0, p.z) * (1.0 - smoothstep(29.0, 39.0, p.y));
	ALBEDO = mix(sand, rock, slope) * (1.0 - damp * 0.26);
	ROUGHNESS = 0.94;
	AO = 1.0 - slope * lip * 0.10 * (detail_enabled ? detail_strength : 0.0);
	if (relief_enabled) {
		float height = (ripple * 0.010 + drift * 0.006) * flat_weight + slope * (-lip * 0.03 + shelf * 0.012 - crack * 0.01);
		NORMAL = surface_bump(VERTEX, NORMAL, height);
	}
}
