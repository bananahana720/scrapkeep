shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Scrapkeep Combat Floor Discipline Shader ("Rich Vistas, Clean Combat Lanes").
// Keeps walkable combat floors geometrically flat (zero vertex displacement) and strictly
// compressed into a desaturated mid-tone value band, while delivering rich stochastic
// anti-tiled micro-normals, subtle hairline expansion joints, and wet/oil sheen variation
// so combat telegraphs (HAZARD #ff5a3c), pickups (ARC #8bf0d3, AMBER #e5a044), and actors pop.

#include "res://assets/shaders/craft_triplanar_detail.gdshaderinc"

group_uniforms floor_palette;
// Compressed warm sandstone-concrete mid-tone derived from Palette.SANDSTONE & REDJAW_ASH.
uniform vec3 floor_albedo : source_color = vec3(0.45, 0.42, 0.37);
uniform vec3 floor_secondary_albedo : source_color = vec3(0.39, 0.38, 0.35);
uniform vec3 crack_albedo : source_color = vec3(0.21, 0.22, 0.21);
uniform vec3 oil_tint : source_color = vec3(0.24, 0.29, 0.28);
uniform float value_clamp_min : hint_range(0.12, 0.42) = 0.24;
uniform float value_clamp_max : hint_range(0.34, 0.65) = 0.49;
uniform float saturation_cap : hint_range(0.0, 0.35) = 0.16;

group_uniforms floor_detail;
uniform bool has_detail_tex = false;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_tile_metres : hint_range(1.0, 20.0) = 3.6;
uniform float detail_tex_strength : hint_range(0.0, 1.0) = 0.55;
uniform float uv_warp_strength : hint_range(0.0, 1.0) = 0.32;
uniform float macro_scale : hint_range(0.02, 0.6) = 0.11;

group_uniforms expansion_joints;
uniform float slab_metres : hint_range(1.5, 16.0) = 4.2;
uniform float joint_width : hint_range(0.004, 0.06) = 0.014;
uniform float joint_darkening : hint_range(0.0, 0.45) = 0.18;
uniform float hairline_crack_strength : hint_range(0.0, 0.5) = 0.22;

group_uniforms surface_response;
uniform float dry_roughness : hint_range(0.55, 0.98) = 0.88;
uniform float oil_roughness : hint_range(0.18, 0.65) = 0.32;
uniform float oil_patch_strength : hint_range(0.0, 0.85) = 0.42;
uniform float base_metallic : hint_range(0.0, 0.25) = 0.06;
uniform float base_specular : hint_range(0.2, 0.8) = 0.48;
uniform float normal_relief : hint_range(0.0, 1.5) = 0.45;
uniform bool use_vertex_grime = true;

varying vec3 floor_world_pos;
varying vec3 floor_world_normal;
varying vec4 floor_vcolor;

void vertex() {
	floor_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	floor_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	floor_vcolor = COLOR;
}

vec3 compress_combat_lane_color(vec3 linear_c, float min_v, float max_v, float max_sat) {
	// Operate in perceptual sRGB space so value_clamp_min/max (e.g. 0.24..0.46)
	// match human/artist mid-tone value discipline, then return linear light for ALBEDO.
	vec3 srgb = pow(max(linear_c, vec3(0.0001)), vec3(1.0 / 2.2));
	float lum = craft_luminance(srgb);
	float cmax = max(srgb.r, max(srgb.g, srgb.b));
	float cmin = min(srgb.r, min(srgb.g, srgb.b));
	float sat = cmax > 0.001 ? (cmax - cmin) / cmax : 0.0;
	if (sat > max_sat) {
		float keep = max_sat / max(sat, 0.0001);
		srgb = mix(vec3(lum), srgb, keep);
	}
	float clamped_l = clamp(lum, min_v, max_v);
	if (lum > 0.001) {
		srgb *= clamped_l / lum;
	} else {
		srgb = vec3(min_v);
	}
	srgb = clamp(srgb, vec3(min_v * 0.85), vec3(max_v * 1.05));
	return pow(max(srgb, vec3(0.0)), vec3(2.2));
}

void fragment() {
	vec3 p = floor_world_pos;
	vec3 n = normalize(floor_world_normal);
	vec2 xz = p.xz;
	vec3 weights = craft_triplanar_weights(n, 5.0);

	// 1. Broad anti-tiled macro zones (zero visible repetition across wide arenas).
	float macro_broad = craft_fbm2(xz * macro_scale);
	float macro_mid = craft_fbm2(xz * (macro_scale * 2.7) + vec2(14.3, 6.1));
	float proc_grain = craft_procedural_detail(p, weights, detail_tile_metres);

	// 2. Stochastic detail sample (free rotation, mipmap-safe textureGrad).
	float tex_lum = 1.0 + (proc_grain - 0.5) * 0.14;
	float micro_h = proc_grain;
	if (has_detail_tex) {
		vec3 s = craft_stochastic_sample(detail_tex, xz / max(detail_tile_metres, 0.25), uv_warp_strength, 0).rgb;
		float mean_l = max(craft_luminance(textureLod(detail_tex, vec2(0.5), 9.0).rgb), 0.08);
		float sl = craft_luminance(s);
		float ratio = clamp(sl / mean_l, 0.72, 1.28);
		tex_lum = mix(tex_lum, ratio, detail_tex_strength);
		micro_h = mix(proc_grain, clamp(sl, 0.0, 1.0), detail_tex_strength * 0.75);
	}

	// 3. Subtle hairline expansion joints + subtle spalled joint wear (zero iso-contour loops on slab interiors).
	vec2 jitter = (vec2(craft_noise2(xz * 3.1), craft_noise2(xz * 3.1 + vec2(11.7, 4.3))) - 0.5) * 0.018;
	vec2 slab_uv = (xz + jitter) / max(slab_metres, 0.5);
	vec2 slab_d = min(fract(slab_uv), 1.0 - fract(slab_uv)) * slab_metres;
	vec2 aa = max(fwidth(xz), vec2(0.004));
	float jx = 1.0 - smoothstep(joint_width, joint_width + aa.x * 1.5, slab_d.x);
	float jy = 1.0 - smoothstep(joint_width, joint_width + aa.y * 1.5, slab_d.y);
	// Break joint continuity subtly with macro wear so seams feel aged, not grid-stamped.
	float joint_mask = max(jx, jy) * smoothstep(0.18, 0.68, macro_mid);

	// Fine chipped spall strictly hugging expansion joints (no closed topographic rings).
	float spall_noise = craft_noise2(xz * 9.5 + vec2(4.1, 8.3));
	float near_joint = 1.0 - smoothstep(joint_width, joint_width + 0.055 + length(aa), min(slab_d.x, slab_d.y));
	float hairline = near_joint * smoothstep(0.58, 0.82, spall_noise) * hairline_crack_strength;
	float groove = clamp(max(joint_mask, hairline), 0.0, 1.0);

	// 4. Subtle wet/oil specular sheen variation (broken up by fine grit so no smooth plastic hotspot forms).
	float oil_noise = craft_fbm2(xz * (macro_scale * 2.1) + vec2(31.7, 12.4));
	float oil_grit = craft_noise2(xz * 3.8 + vec2(7.3, 19.1));
	float oil_mask = smoothstep(0.50, 0.74, oil_noise) * mix(0.65, 1.0, oil_grit) * oil_patch_strength;

	// 5. Optional perimeter/cavity grime from vertex COLOR.g.
	float v_grime = use_vertex_grime ? clamp(floor_vcolor.g, 0.0, 1.0) : 0.0;
	// Guard against default uncolored white vertex color (1,1,1): only treat G as grime when not pure white.
	float is_uncolored_white = step(0.99, floor_vcolor.r) * step(0.99, floor_vcolor.g) * step(0.99, floor_vcolor.b);
	v_grime *= (1.0 - is_uncolored_white);

	// 6. Combine and strictly compress into clean mid-tone combat-lane discipline.
	vec3 col = mix(floor_albedo, floor_secondary_albedo, smoothstep(0.25, 0.75, macro_broad));
	col *= mix(1.0, tex_lum, 0.48);
	col = mix(col, oil_tint, oil_mask * 0.24);
	col = mix(col, crack_albedo, groove * joint_darkening);
	col = mix(col, crack_albedo, v_grime * 0.32);
	col = compress_combat_lane_color(col, value_clamp_min, value_clamp_max, saturation_cap);

	// 7. Roughness & normal relief (rich specular micro-contrast on a visually calm floor).
	float rough = dry_roughness + (0.5 - micro_h) * 0.18 + groove * 0.08 + v_grime * 0.06;
	rough = mix(rough, oil_roughness, oil_mask);
	float fp_fade = craft_footprint_fade(p, 0.025, 0.22);
	float relief_h = (micro_h - 0.5) * 0.024 - joint_mask * 0.030 - hairline * 0.016;
	NORMAL = craft_bump_normal(VERTEX, NORMAL, relief_h, normal_relief * fp_fade);

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.22, 0.96);
	METALLIC = clamp(base_metallic + oil_mask * 0.08, 0.0, 0.25);
	SPECULAR = base_specular;
	AO = clamp(1.0 - groove * 0.18 - v_grime * 0.28, 0.55, 1.0);
	AO_LIGHT_AFFECT = 0.35;
}
