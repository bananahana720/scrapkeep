shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
#include "res://assets/shaders/env_weathering.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform float base_roughness = 0.8;
uniform bool has_base_map = false;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float panel_metres = 3.0;
uniform float streak_metres = 0.8;
uniform float value_desat : hint_range(0.0, 0.6) = 0.38;
uniform float value_compress : hint_range(0.0, 0.6) = 0.32;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	vec2 plane = surface_plane(p, surface_normal);
	// Cover both the main dam face and the lower spillway apron so the apron never reads flat.
	float dam = step(215.0, p.z) * (1.0 - step(146.0, abs(p.x)));
	// These vertex tints were baked in linear space by the existing scenery merge.
	// Its source map also supplies the rust hue; keep it on the dam, not only outside.
	vec3 original = base_color.rgb * COLOR.rgb;
	if (has_base_map) {
		vec3 weights = abs(surface_normal) * abs(surface_normal) * abs(surface_normal) * abs(surface_normal);
		weights /= max(weights.x + weights.y + weights.z, 0.001);
		original *= texture(base_map, p.zy / 6.0).rgb * weights.x
			+ texture(base_map, p.xz / 6.0).rgb * weights.y
			+ texture(base_map, p.xy / 6.0).rgb * weights.z;
	}
	float upright = 1.0 - abs(surface_normal.y);
	vec2 panels = plane / panel_metres;
	vec2 cell = fract(panels);
	vec2 edge_distance = min(cell, 1.0 - cell);
	vec2 seam_width = max(fwidth(panels), vec2(0.003));
	float seam = 1.0 - min(smoothstep(0.008, 0.028 + seam_width.x, edge_distance.x), smoothstep(0.008, 0.028 + seam_width.y, edge_distance.y));
	float worn_edge = 1.0 - min(smoothstep(0.028, 0.068 + seam_width.x, edge_distance.x), smoothstep(0.028, 0.068 + seam_width.y, edge_distance.y));
	// Architectural cast-concrete lift courses (12 m pours) + staggered slab batch variation
	// so distant dam bays read as weathered monolithic pours rather than a uniform grid.
	float lift_span = panel_metres * 4.0;
	float lift_row = floor(plane.y / lift_span);
	float lift_cell = fract(plane.y / lift_span);
	float lift_w = max(fwidth(plane.y / lift_span), 0.010);
	float lift_groove = (1.0 - smoothstep(0.020, 0.068 + lift_w, min(lift_cell, 1.0 - lift_cell))) * upright;
	float lift_lip = smoothstep(0.055, 0.095, lift_cell) * (1.0 - smoothstep(0.095, 0.175, lift_cell)) * upright;
	float lift_seep = smoothstep(0.70, 0.96, lift_cell) * upright;
	float stagger = mod(lift_row, 2.0) * 0.5;
	vec2 pour_id = vec2(floor(plane.x / (panel_metres * 2.5) + stagger), lift_row);
	float pour_var = (env_hash2(pour_id) - 0.5) * 0.22;
	// High-contrast vertical rainwater/mineral runoff plumes + architecturally anchored
	// crest/eave drips below the dam parapet (y~120) and valve-tower caps (y~155).
	float macro_plume = env_dam_plume(plane, 0.075, 0.016) * upright;
	float med_plume = env_dam_plume(plane, 0.24 / max(streak_metres, 0.1), 0.045) * upright;
	float crest_curtain = smoothstep(74.0, 118.0, p.y) * (1.0 - smoothstep(119.5, 123.0, p.y)) * upright;
	float tower_curtain = smoothstep(126.0, 154.0, p.y) * (1.0 - smoothstep(155.5, 158.5, p.y)) * upright;
	float eave_shadow = (smoothstep(112.0, 119.5, p.y) * (1.0 - smoothstep(119.8, 122.0, p.y))
		+ smoothstep(149.0, 155.0, p.y) * (1.0 - smoothstep(155.2, 157.5, p.y))) * upright;
	float runoff = clamp(macro_plume * (0.58 + 0.52 * max(crest_curtain, tower_curtain)) + med_plume * (0.28 + 0.36 * lift_seep), 0.0, 1.0);
	float dirt = surface_macro(vec2(plane.x * 6.283185 / (streak_metres * 4.0), plane.y * 6.283185 / 14.0));
	float chips = smoothstep(0.56, 0.78, surface_noise(plane * 9.0)) * worn_edge;
	float micro = env_micro_grain(p, 2.2);
	// Undulating lower-course spillway splash & damp mineral line above the canyon rim & mist.
	float tide_wave = (env_noise2(vec2(p.x * 0.045, 1.7)) - 0.5) * 16.0;
	float base_damp = (1.0 - smoothstep(54.0, 110.0, p.y + tide_wave)) * dam;
	float tone = 0.98 + pour_var + (dirt - 0.5) * 0.18 - seam * 0.11 - lift_groove * 0.38 + lift_lip * 0.14 + worn_edge * 0.05 - chips * 0.06 - runoff * 0.36 - eave_shadow * 0.26 - base_damp * 0.24 + micro * 0.06;
	float detail_amt = detail_enabled ? clamp(detail_strength, 0.0, 1.0) : 0.0;
	float patina_stain = clamp((runoff * 0.50 + lift_seep * macro_plume * 0.26 + eave_shadow * 0.34 + base_damp * 0.40) * dam * detail_amt, 0.0, 0.76);
	float patina_bleach = clamp((lift_lip * 0.52 + smoothstep(118.0, 168.0, p.y) * 0.16 * (1.0 - runoff)) * dam * detail_amt, 0.0, 0.48);
	vec3 weathered = env_top_dust(original, surface_normal.y, 0.42 * detail_amt);
	weathered = env_compress_midtone(weathered, value_desat * detail_amt, 0.21, value_compress * detail_amt);
	weathered = env_concrete_patina(weathered, patina_stain, patina_bleach);
	ALBEDO = mix(original, weathered, mix(0.72, 1.0, dam)) * mix(1.0, surface_value(tone), dam);
	ROUGHNESS = clamp(base_roughness + seam * 0.08 + lift_groove * 0.14 - runoff * 0.16 - base_damp * 0.14 + micro * 0.05, 0.58, 0.98);
	AO = clamp(1.0 - (seam * 0.11 + lift_groove * 0.38 + runoff * 0.26 + eave_shadow * 0.28 + base_damp * 0.18) * dam * detail_amt, 0.36, 1.0);
	AO_LIGHT_AFFECT = 0.38;
	if (relief_enabled) {
		NORMAL = surface_bump(VERTEX, NORMAL, dam * (-seam * 0.008 - lift_groove * 0.036 + lift_lip * 0.010 - chips * 0.003 - runoff * 0.006 + micro * 0.002));
	}
}
