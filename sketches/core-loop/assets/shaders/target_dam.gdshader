shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform float base_roughness = 0.8;
uniform bool has_base_map = false;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float panel_metres = 3.0;
uniform float streak_metres = 0.8;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	vec2 plane = surface_plane(p, surface_normal);
	float dam = step(215.0, p.z) * step(60.0, p.y) * (1.0 - step(146.0, abs(p.x)));
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
	vec2 panels = plane / panel_metres;
	vec2 edge_distance = min(fract(panels), 1.0 - fract(panels));
	vec2 seam_width = max(fwidth(panels), vec2(0.003));
	float seam = 1.0 - min(smoothstep(0.009, 0.028 + seam_width.x, edge_distance.x), smoothstep(0.009, 0.028 + seam_width.y, edge_distance.y));
	float worn_edge = 1.0 - min(smoothstep(0.030, 0.060 + seam_width.x, edge_distance.x), smoothstep(0.030, 0.060 + seam_width.y, edge_distance.y));
	float dirt = surface_macro(vec2(plane.x * 6.283185 / streak_metres, plane.y * 6.283185 / 8.0));
	float chips = smoothstep(0.62, 0.83, surface_noise(plane * 9.0)) * worn_edge;
	float tone = 1.0 + (dirt - 0.5) * 0.12 - seam * 0.23 + worn_edge * 0.07 - chips * 0.05;
	ALBEDO = original * mix(1.0, surface_value(tone), dam);
	ROUGHNESS = base_roughness;
	AO = 1.0 - seam * 0.12 * dam * (detail_enabled ? detail_strength : 0.0);
	AO_LIGHT_AFFECT = 0.05;
	if (relief_enabled) {
		NORMAL = surface_bump(VERTEX, NORMAL, dam * (-seam * 0.009 - chips * 0.002));
	}
}
