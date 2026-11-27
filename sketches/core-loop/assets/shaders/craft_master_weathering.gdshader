shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Scrapkeep Master Multi-Layer PBR Triplanar Weathering Shader.
// Shared vertex-color contract (synchronized with HeroKitbashSculptor):
//   COLOR.r = edge wear mask (drives scraped bare steel: metallic 0.9, roughness 0.25)
//   COLOR.g = cavity grime / AO dirt mask (drives matte pitted rust/oil: roughness 0.85+)
//   COLOR.b = selective HDR emissive mask (hot vents / live plasma conduits > 1.0 bloom)
//   COLOR.a = material blend weight (1.0 default)

#include "res://assets/shaders/craft_triplanar_detail.gdshaderinc"

group_uniforms projection;
uniform bool use_world_space = true;
uniform bool use_vertex_masks = true;
uniform float triplanar_sharpness : hint_range(1.0, 12.0) = 5.0;
uniform float detail_tile_metres : hint_range(0.25, 24.0) = 2.4;
uniform float macro_scale : hint_range(0.02, 2.0) = 0.22;
uniform float uv_warp_strength : hint_range(0.0, 1.0) = 0.28;
uniform int stochastic_rotation_mode : hint_range(0, 2) = 1;

group_uniforms detail_texture;
uniform bool has_detail_tex = false;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_tex_strength : hint_range(0.0, 1.0) = 0.65;
uniform float detail_chroma_keep : hint_range(0.0, 1.0) = 0.35;

group_uniforms base_surface;
// Palette-aligned defaults (Palette.RUST #9b513a, Palette.VERDIGRIS #365754).
uniform vec3 base_albedo : source_color = vec3(0.6078, 0.3176, 0.2275);
uniform vec3 secondary_albedo : source_color = vec3(0.2118, 0.3412, 0.3294);
uniform float macro_color_mix : hint_range(0.0, 0.6) = 0.16;
uniform float base_roughness : hint_range(0.05, 1.0) = 0.80;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.12;
uniform float base_specular : hint_range(0.0, 1.0) = 0.5;
uniform float oil_sheen_strength : hint_range(0.0, 1.0) = 0.0;
uniform float oil_sheen_roughness : hint_range(0.10, 0.60) = 0.24;

group_uniforms edge_wear;
// Scraped bare steel (Palette.STEEL #9aa0a0 -> metallic 0.90, roughness 0.25).
uniform vec3 edge_wear_albedo : source_color = vec3(0.6039, 0.6275, 0.6275);
uniform float edge_wear_strength : hint_range(0.0, 1.5) = 1.05;
uniform float edge_wear_metallic : hint_range(0.0, 1.0) = 0.90;
uniform float edge_wear_roughness : hint_range(0.05, 0.95) = 0.25;
uniform float auto_curvature_weight : hint_range(0.0, 1.0) = 0.28;

group_uniforms cavity_grime;
// Pitted rust/oil grime (Palette.CHARCOAL #242a28 + Palette.RUST #9b513a).
uniform vec3 grime_albedo : source_color = vec3(0.1412, 0.1647, 0.1569);
uniform vec3 rust_albedo : source_color = vec3(0.6078, 0.3176, 0.2275);
uniform float grime_strength : hint_range(0.0, 1.5) = 0.95;
uniform float grime_roughness : hint_range(0.5, 1.0) = 0.90;
uniform float grime_metallic : hint_range(0.0, 0.5) = 0.06;
uniform float rust_mix : hint_range(0.0, 1.0) = 0.42;
uniform float foot_grime_height : hint_range(0.0, 8.0) = 0.85;
uniform float foot_grime_strength : hint_range(0.0, 1.0) = 0.42;
uniform float cavity_ao_strength : hint_range(0.0, 1.0) = 0.74;

group_uniforms slope_dust;
// Upward-facing sandstone dust / patina (Palette.SANDSTONE #c6a274).
uniform vec3 dust_albedo : source_color = vec3(0.7765, 0.6353, 0.4549);
uniform float dust_strength : hint_range(0.0, 1.0) = 0.28;
uniform float dust_slope_min : hint_range(0.0, 1.0) = 0.56;
uniform float dust_roughness : hint_range(0.5, 1.0) = 0.94;

group_uniforms relief;
uniform float normal_relief : hint_range(0.0, 2.0) = 0.52;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.16;

group_uniforms selective_emissive;
// Selective HDR emissive channel (Palette.ARC #8bf0d3 / Palette.AMBER #e5a044).
// Bounded by reduce_flashes so FlashGuard (<= 3 Hz, 30% spike) stays respected.
uniform vec3 emissive_color : source_color = vec3(0.5451, 0.9412, 0.8275);
uniform vec3 emissive_secondary_color : source_color = vec3(0.8980, 0.6275, 0.2667);
uniform float emissive_gradient_mix : hint_range(0.0, 1.0) = 0.0;
uniform float emissive_energy : hint_range(0.0, 6.0) = 1.8;
uniform float emissive_pulse_speed : hint_range(0.0, 6.0) = 1.5;
uniform float emissive_pulse_amount : hint_range(0.0, 0.6) = 0.16;
uniform bool reduce_flashes = false;

varying vec3 craft_world_pos;
varying vec3 craft_world_normal;
varying vec3 craft_local_pos;
varying vec3 craft_local_normal;
varying vec4 craft_vcolor;

void vertex() {
	craft_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	craft_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	craft_local_pos = VERTEX;
	craft_local_normal = normalize(NORMAL);
	craft_vcolor = COLOR;
}

void fragment() {
	vec3 p = use_world_space ? craft_world_pos : craft_local_pos;
	vec3 n = normalize(use_world_space ? craft_world_normal : craft_local_normal);
	vec3 weights = craft_triplanar_weights(n, triplanar_sharpness);

	// 1. Macro anti-tiling & procedural micro-detail fields.
	float macro_a = craft_fbm3(p * macro_scale);
	float macro_b = craft_fbm3(p * (macro_scale * 2.35) + vec3(9.7, 3.3, 14.1));
	float proc_detail = craft_procedural_detail(p, weights, detail_tile_metres);
	float fine_scuff = craft_noise3(p * (5.2 / max(detail_tile_metres, 0.25)) + vec3(4.1, 8.7, 1.9));

	// 2. Stochastic anti-tiled detail texture (with clean procedural fallback when unset).
	float detail_lum = 1.0 + (proc_detail - 0.5) * 0.26;
	float micro_height = proc_detail;
	vec3 detail_rgb = vec3(detail_lum);
	if (has_detail_tex) {
		vec3 tex_sample = craft_triplanar_stochastic(detail_tex, p, weights, detail_tile_metres, uv_warp_strength, stochastic_rotation_mode);
		float tex_mean = max(craft_luminance(textureLod(detail_tex, vec2(0.5), 9.0).rgb), 0.08);
		float tex_l = craft_luminance(tex_sample);
		float norm_l = clamp(tex_l / tex_mean, 0.45, 1.55);
		vec3 tinted_tex = mix(vec3(norm_l), tex_sample / tex_mean, detail_chroma_keep);
		detail_rgb = mix(vec3(detail_lum), tinted_tex, detail_tex_strength);
		detail_lum = mix(detail_lum, norm_l, detail_tex_strength);
		micro_height = mix(proc_detail, clamp(tex_l, 0.0, 1.0), detail_tex_strength * 0.8);
	}

	// 3. Base PBR layer with broad macro colour modulation and optional oil-slick sheen contrast.
	float macro_blend = smoothstep(0.28, 0.74, macro_a) * macro_color_mix;
	vec3 col = mix(base_albedo, secondary_albedo, macro_blend) * mix(vec3(1.0), detail_rgb, 0.78);
	col *= 0.90 + macro_b * 0.20;
	float rough = clamp(base_roughness + (0.5 - micro_height) * roughness_variation * 2.0 + (macro_b - 0.5) * 0.12, 0.08, 0.98);
	float metal = base_metallic;

	float oil_mask = 0.0;
	if (oil_sheen_strength > 0.001) {
		// Sharp localized oil pools and gravity drip streaks contrasting against dry matte soot/iron.
		float oil_blotch = craft_fbm3(p * (macro_scale * 4.4) + vec3(21.4, 2.7, 6.3));
		float oil_drip = craft_fbm3(vec3(p.x * 4.2, p.y * 0.85, p.z * 4.2) * (macro_scale * 3.8) + vec3(4.2, 1.1, 8.8));
		float oil_field = oil_blotch * 0.56 + oil_drip * 0.44;
		oil_mask = smoothstep(0.49, 0.60, oil_field) * oil_sheen_strength;
		col = mix(col, col * 0.44, oil_mask * 0.80);
		rough = mix(rough, oil_sheen_roughness, oil_mask);
		metal = mix(metal, max(metal, 0.34), oil_mask * 0.45);
	}

	// 4. Shared vertex-color masks (with clean disable switch for uncolored geometry).
	float v_edge = use_vertex_masks ? clamp(craft_vcolor.r, 0.0, 1.0) : 0.0;
	float v_grime = use_vertex_masks ? clamp(craft_vcolor.g, 0.0, 1.0) : 0.0;
	float v_emissive = use_vertex_masks ? clamp(craft_vcolor.b, 0.0, 1.0) : 0.0;

	// 5. Height-blended & slope-blended upward dust / patina accumulation.
	float slope_up = smoothstep(dust_slope_min, 0.94, craft_world_normal.y);
	float dust_breakup = smoothstep(0.28, 0.76, macro_a * 0.65 + (1.0 - micro_height) * 0.35);
	float dust_mask = clamp(slope_up * dust_breakup * dust_strength * (1.0 - v_edge * 0.6), 0.0, 1.0);
	col = mix(col, dust_albedo * (0.88 + micro_height * 0.24), dust_mask);
	rough = mix(rough, dust_roughness, dust_mask);
	metal = mix(metal, 0.02, dust_mask);

	// 6. Cavity grime, tight foot contact skirt, and pitted rust (COLOR.g + height contact).
	float foot_broad = foot_grime_height > 0.01
		? (1.0 - smoothstep(0.0, foot_grime_height, max(craft_local_pos.y, 0.0))) * foot_grime_strength * (0.55 + 0.45 * macro_b)
		: 0.0;
	float foot_skirt = foot_grime_height > 0.01
		? (1.0 - smoothstep(0.0, 0.22, max(craft_local_pos.y, 0.0))) * clamp(foot_grime_strength * 1.65, 0.0, 1.0)
		: 0.0;
	float cavity_raw = clamp(max(v_grime, max(foot_broad, foot_skirt)), 0.0, 1.0);
	float cavity_pitted = clamp(cavity_raw * (0.78 + 0.38 * (1.0 - micro_height)) * grime_strength, 0.0, 1.0);
	float rust_patch = smoothstep(0.30, 0.70, macro_a * 0.55 + fine_scuff * 0.45) * rust_mix;
	vec3 crevice_col = mix(grime_albedo * 0.52, rust_albedo * 0.54, rust_patch) * (0.68 + micro_height * 0.34);
	col = mix(col, crevice_col, cavity_pitted);
	col *= mix(1.0, 0.52, foot_skirt * 0.65);
	rough = mix(rough, max(grime_roughness, 0.90), cavity_pitted);
	metal = mix(metal, grime_metallic, cavity_pitted);
	oil_mask *= (1.0 - foot_skirt * 0.75);

	// 7. Curvature + COLOR.r edge-wear -> crisp brushed & micro-chipped bare steel strictly along bevel crests.
	float auto_curv = craft_curvature(craft_world_normal, craft_world_pos) * auto_curvature_weight;
	float raw_edge = clamp(max(v_edge, auto_curv), 0.0, 1.0);
	// Cohesive physical paint-flake scale + directional brushed grain (no high-frequency static speckle).
	float micro_chip = craft_noise3(p * 11.5 + vec3(7.1, 2.3, 11.9));
	float finer_chip = craft_noise3(p * 26.0 + vec3(13.4, 5.2, 2.7));
	float brush_x = craft_noise3(p * vec3(24.0, 6.5, 24.0));
	float brush_y = craft_noise3(p * vec3(6.5, 24.0, 6.5));
	float brush_grain = mix(brush_x, brush_y, abs(n.y));
	// Concentrate wear tightly along high-exposure bevel crests so flat painted plates stay calm & legible.
	float tightened = pow(raw_edge, 1.75) * edge_wear_strength;
	float flake_field = micro_chip * 0.56 + finer_chip * 0.24 + micro_height * 0.20;
	float chipped_edge = tightened * mix(0.45, 1.24, smoothstep(0.32, 0.72, flake_field))
		+ (brush_grain - 0.5) * 0.14;
	float edge_mask = smoothstep(0.56, 0.72, chipped_edge);
	// Suppress bare-steel gleam inside deep dirt-trapping cavities & plinth foot skirts.
	edge_mask *= (1.0 - clamp(cavity_pitted * 0.88 + foot_skirt * 0.65, 0.0, 0.96));
	vec3 steel_col = edge_wear_albedo * (0.80 + brush_grain * 0.22);
	col = mix(col, steel_col, edge_mask);
	rough = mix(rough, clamp(edge_wear_roughness + 0.03 + (1.0 - brush_grain) * 0.12, 0.26, 0.90), edge_mask);
	metal = mix(metal, edge_wear_metallic, edge_mask);
	// Confine oil sheen strictly to pooled flat/mid zones, never mirror-flaring bevels.
	oil_mask *= (1.0 - clamp(raw_edge * 0.95 + edge_mask, 0.0, 1.0));

	// 8. Selective HDR emissive channel (COLOR.b > 0.15 only; FlashGuard bounded).
	// Modulate emission with subtle internal heat-core & louver variation so vents read hot & recessed.
	float emissive_mask = smoothstep(0.18, 0.72, v_emissive);
	float safe_speed = reduce_flashes ? min(emissive_pulse_speed, 1.6) : emissive_pulse_speed;
	float safe_amp = reduce_flashes ? emissive_pulse_amount * 0.30 : emissive_pulse_amount;
	float wave = 0.5 + 0.5 * sin(TIME * safe_speed + p.y * 1.3 + p.x * 0.5);
	float pulse = 1.0 + (wave - 0.5) * 2.0 * safe_amp;
	float capped_energy = reduce_flashes
		? mix(min(emissive_energy, 1.0), emissive_energy, 0.30)
		: emissive_energy;
	// Internal plasma/heat core modulation: bright center, subtle vent-bar ribbing, warm Fresnel rim.
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float vent_ribs = 0.84 + 0.16 * sin((p.y * 28.0 + p.x * 8.0));
	float core_hot = mix(0.62, 1.28, pow(ndv, 0.75)) * vent_ribs;
	vec3 live_col = mix(emissive_color, emissive_secondary_color, emissive_gradient_mix * (0.30 + 0.70 * (1.0 - ndv)));
	col = mix(col, live_col * 0.25, emissive_mask * 0.80);
	rough = mix(rough, 0.28, emissive_mask * 0.75);
	metal = mix(metal, 0.12, emissive_mask * 0.75);

	// 9. Micro-normal relief (shading only; attenuated cleanly by pixel footprint).
	float fp_fade = craft_footprint_fade(craft_world_pos, 0.025, 0.22);
	float pit_detail = (micro_chip - 0.5) * (1.0 - edge_mask) * 0.006;
	float relief_h = (micro_height - 0.5) * 0.026 + pit_detail - cavity_pitted * 0.022 + edge_mask * 0.006;
	NORMAL = craft_bump_normal(VERTEX, NORMAL, relief_h, normal_relief * fp_fade);

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.24, 0.98);
	METALLIC = clamp(metal, 0.0, 1.0);
	SPECULAR = base_specular;
	AO = clamp(1.0 - cavity_pitted * cavity_ao_strength - foot_skirt * 0.28, 0.14, 1.0);
	AO_LIGHT_AFFECT = 0.65;
	EMISSION = live_col * capped_energy * pulse * core_hot * emissive_mask;
}
