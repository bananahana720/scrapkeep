shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/env_weathering.gdshaderinc"
uniform bool cliff_only = false;
// Anchor the pattern in the mesh's own metres (Moss's carried shelter) instead of world metres.
uniform bool local_pattern = false;
uniform sampler2D strata_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float strata_metres = 6.0;
uniform float floor_metres = 5.0;
uniform float value_desat : hint_range(0.0, 0.5) = 0.28;
uniform float value_compress : hint_range(0.0, 0.5) = 0.30;
varying vec3 world_at;
varying vec3 world_normal;

// World-space triplanar: each axis projects the map, weighted by how squarely the surface faces it.
vec3 triplanar(sampler2D map, vec3 p, vec3 w, float metres) {
	vec3 q = p / metres;
	return texture(map, q.zy).rgb * w.x + texture(map, q.xz).rgb * w.y + texture(map, q.xy).rgb * w.z;
}

void vertex() {
	world_at = local_pattern ? VERTEX : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = local_pattern ? normalize(NORMAL) : normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_at;
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	// Macro variation: two octaves of broad noise, tens of metres across, so no tile repeats evenly.
	float macro = env_noise3(p * 0.031) * 0.65 + env_noise3(p * 0.11 + vec3(7.3, 1.9, 4.1)) * 0.35;
	float swap = smoothstep(0.38, 0.62, env_noise3(p * 0.047 + vec3(3.1, 0.0, 5.7)));
	float micro = env_micro_grain(p, 1.65);

	// Organic geological bedding planes: domain-warped noise shelves of irregular 2-7 m thickness
	// with bold mineral colour/value shifts so Southwest strata read cleanly at gameplay distance.
	float bed_warp = (env_noise3(vec3(p.x * 0.014, p.y * 0.01, p.z * 0.014)) - 0.5) * 4.8
		+ (env_noise3(vec3(p.x * 0.052, 0.0, p.z * 0.052)) - 0.5) * 1.1;
	float bed_y = p.y + bed_warp;
	float course_a = env_noise2(vec2(bed_y * 0.28, (p.x - p.z) * 0.006));
	float course_b = env_noise2(vec2(bed_y * 0.72 + 3.7, (p.x + p.z) * 0.010));
	float course = smoothstep(0.22, 0.78, course_a * 0.65 + course_b * 0.35);
	// Crisp shadowed undercut ledges along geological bedding boundaries.
	float shelf_a = 1.0 - smoothstep(0.0, 0.11, abs(fract(bed_y * 0.21 + course_a * 0.75) - 0.5));
	float shelf_b = (1.0 - smoothstep(0.0, 0.08, abs(fract(bed_y * 0.49 + course_b * 0.65) - 0.5))) * 0.6;
	float bed_seam = clamp(max(shelf_a, shelf_b) * (0.45 + 0.55 * env_noise3(p * 0.055 + vec3(2.1))), 0.0, 1.0);
	float lamina_fade = 1.0 - smoothstep(0.10, 0.42, fwidth(bed_y));
	float lamina = env_noise2(vec2(bed_y * 2.6, (p.x + p.z) * 0.08)) * lamina_fade;
	float cliff_streaks = env_rain_streak(vec2(p.x + p.z, p.y), 0.12, 0.03) * 0.35;

	// Rock: the palette-quantised CC0 map at two scales, modulated by sedimentary stratification and weathering.
	vec3 rock_near = triplanar(strata_map, p, weights, strata_metres);
	vec3 rock_far = triplanar(strata_map, p + vec3(13.1, 7.7, 3.3), weights, strata_metres * 2.7);
	vec3 rock_mean = textureLod(strata_map, vec2(0.5), 10.0).rgb;
	vec3 rock = mix(rock_near, rock_far, swap);
	rock = mix(rock_mean, rock, 0.78) * (vec3(0.54, 0.37, 0.22) / max(rock_mean, vec3(0.02)));
	// Alternate iron-oxide beds, ochre ledges, and pale mineral bands; deepen recessed undercut seams.
	vec3 bed_tint = mix(vec3(0.84, 0.80, 0.78), vec3(1.14, 1.02, 0.90), course);
	rock *= bed_tint * (0.85 + macro * 0.20 + (lamina - 0.5) * 0.10 + micro * 0.07 - bed_seam * 0.32 - cliff_streaks * 0.08);
	rock = env_top_dust(rock, world_normal.y, 0.45);
	rock = env_compress_midtone(rock, value_desat, 0.27, value_compress);

	float strata = cliff_only ? 1.0 : 1.0 - smoothstep(0.58, 0.93, abs(world_normal.y));
	// Concave slope-to-floor talus transition band: grounds cliffs cleanly into flat sand.
	float crevice = 4.0 * strata * (1.0 - strata);

	// A broad, irregular abrasion field suggests repeated rolling without drawing new routes.
	float track = sin(p.z * 0.065 + p.x * 0.026) * 9.0;
	float ruts = pow(0.5 + 0.5 * sin((p.x + track) * 4.2), 18.0);
	float worn = smoothstep(0.40, 0.68, env_noise3(vec3(p.x * 0.026, 0.0, p.z * 0.009)));
	vec3 floor_near = texture(floor_map, p.xz / floor_metres).rgb;
	vec3 floor_far = texture(floor_map, p.zx / (floor_metres * 3.1) + vec2(0.37, 0.61)).rgb;
	vec3 floor_tex = mix(floor_near, floor_far, swap * 0.6);
	vec3 sand = floor_tex * (COLOR.rgb / vec3(0.82, 0.77, 0.65)) * (0.94 + macro * 0.08 + micro * 0.05 - worn * ruts * 0.09);
	sand = env_compress_midtone(sand, value_desat, 0.33, value_compress);

	float damp = smoothstep(200.0, 214.0, p.z) * (1.0 - smoothstep(29.0, 39.0, p.y));
	vec3 surface = mix(sand, rock, strata) * (1.0 - crevice * 0.14) * (1.0 - damp * 0.26);
	ALBEDO = surface;
	ROUGHNESS = clamp(0.95 - strata * (1.0 - bed_seam) * 0.05 - (1.0 - strata) * worn * ruts * 0.04 - damp * 0.16 + micro * 0.04, 0.72, 0.98);
	AO = clamp(1.0 - crevice * 0.22 - strata * (bed_seam * 0.20 + cliff_streaks * 0.07), 0.55, 1.0);
	AO_LIGHT_AFFECT = 0.25;

	// Normal relief only: vertex positions and physics stay identical.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	float rock_relief = dot(rock_near, vec3(0.3, 0.59, 0.11)) * 0.055 - bed_seam * 0.024 + lamina * 0.007;
	float floor_relief = ruts * worn * 0.009 + micro * 0.003;
	float relief = mix(floor_relief, rock_relief, strata);
	NORMAL = normalize(NORMAL - normalize(dx) * dFdx(relief) * 3.0 - normalize(dy) * dFdy(relief) * 3.0);
}
