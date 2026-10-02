shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform float base_roughness = 0.8;
uniform bool has_base_map = false;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = surface_at;
	vec2 plane = surface_plane(p, surface_normal);
	// The shared dressing batch also carries trees, cables and ledges. Detail only
	// the authored dam envelope; material slots and all geometry stay in their batch.
	float dam = step(215.0, p.z) * step(60.0, p.y) * (1.0 - step(146.0, abs(p.x)));
	vec3 original = base_color.rgb * COLOR.rgb;
	if (has_base_map) {
		vec3 weights = pow(abs(surface_normal), vec3(4.0));
		weights /= max(dot(weights, vec3(1.0)), 0.001);
		vec3 tex = texture(base_map, p.zy / 6.0).rgb * weights.x
			+ texture(base_map, p.xz / 6.0).rgb * weights.y
			+ texture(base_map, p.xy / 6.0).rgb * weights.z;
		original *= mix(tex, vec3(1.0), dam);
	}
	vec2 panels = plane / vec2(3.0, 2.0);
	vec2 edge_distance = min(fract(panels), 1.0 - fract(panels));
	vec2 seam_width = max(fwidth(panels), vec2(0.003));
	float seam = 1.0 - min(smoothstep(0.004, 0.014 + seam_width.x, edge_distance.x), smoothstep(0.004, 0.014 + seam_width.y, edge_distance.y));
	float worn_edge = 1.0 - min(smoothstep(0.020, 0.055 + seam_width.x, edge_distance.x), smoothstep(0.020, 0.055 + seam_width.y, edge_distance.y));
	float dirt = surface_noise(vec2(plane.x * 1.7, plane.y * 0.16));
	float chips = smoothstep(0.62, 0.83, surface_noise(plane * 9.0)) * worn_edge;
	float tone = 0.96 + (dirt - 0.5) * 0.10 - seam * 0.22 + worn_edge * 0.04 - chips * 0.07;
	float strength = dam * (detail_enabled ? detail_strength : 0.0);
	ALBEDO = original * mix(1.0, clamp(tone, 0.74, 1.04), strength);
	ROUGHNESS = clamp(base_roughness + (dirt - 0.5) * 0.08 * strength, 0.35, 1.0);
	AO = 1.0 - seam * 0.12 * strength;
	AO_LIGHT_AFFECT = 0.05;
	if (relief_enabled) {
		NORMAL = surface_bump(VERTEX, NORMAL, dam * (-seam * 0.006 - chips * 0.002));
	}
}
