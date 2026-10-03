shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/target_surface.gdshaderinc"
// Unit LKM probe: ground that reads as layered sandstone. Everything is a function of the
// world position (3D value noise, no projection), so no patch joins can show. Beds are
// discrete: a small thickness table, one tone per bed, boundary warped by low-frequency
// noise. Slope picks the material: sand flats, rock faces, varnish on the steepest.
// variant 1 = baseline reading, 2 = thin high-contrast beds, 3 = hard and soft beds with joints.
uniform int variant = 1;
uniform float bed_seed = 3.0;
uniform int debug = 0;
uniform vec3 sand_color : source_color = vec3(0.824, 0.773, 0.647);
uniform vec3 stone_light : source_color = vec3(0.776, 0.635, 0.455);
uniform vec3 stone_dark : source_color = vec3(0.62, 0.40, 0.27);
uniform vec3 iron_color : source_color = vec3(0.61, 0.32, 0.23);
uniform vec3 varnish_color : source_color = vec3(0.30, 0.20, 0.17);

uniform sampler2D tex_tone : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_grain : source_color, repeat_enable, filter_linear_mipmap;
uniform vec3 flat_color : source_color = vec3(0.75, 0.59, 0.39);
uniform vec3 bed_orange : source_color = vec3(0.70, 0.41, 0.23);
uniform vec3 bed_tan : source_color = vec3(0.84, 0.64, 0.42);
uniform vec3 bed_cream : source_color = vec3(0.93, 0.83, 0.67);
uniform vec3 bed_rust : source_color = vec3(0.56, 0.29, 0.19);
uniform float fade_near = 45.0;
uniform float fade_far = 130.0;
uniform float far_keep = 0.5;
uniform float bed_widen = 1.6;
uniform float tone_amp = 0.4;
uniform float tile_tone = 11.0;
uniform float tile_grain = 4.0;

const float BEDS[8] = float[8](1.7, 0.8, 2.6, 1.1, 0.6, 2.1, 1.4, 0.9);

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float h11(float n) {
	n = fract(n * 0.1031);
	n *= n + 33.33;
	n *= n + n;
	return fract(n);
}
float vn3(vec3 p) {
	vec3 c = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(c), h13(c + vec3(1, 0, 0)), f.x), mix(h13(c + vec3(0, 1, 0)), h13(c + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(c + vec3(0, 0, 1)), h13(c + vec3(1, 0, 1)), f.x), mix(h13(c + vec3(0, 1, 1)), h13(c + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm3(vec3 p) {
	return vn3(p) * 0.55 + vn3(p * 2.03 + 11.7) * 0.3 + vn3(p * 4.1 + 3.1) * 0.15;
}

// Variant 4: seam-safe tone. Two samples at different scales and offsets, blended by a low-frequency mask,
// so no tile repeats evenly and no join shows. Returns luminance relative to the texture's mean.
float seam_lum(sampler2D t, vec2 uv, float mean_l) {
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, uv * 0.713 + vec2(0.37, 0.61)).rgb;
	float m = smoothstep(0.3, 0.7, vn3(vec3(uv * 0.23, 1.7)));
	vec3 c = mix(a, b, m);
	return dot(c, vec3(0.3, 0.59, 0.11)) / mean_l;
}
float tri_lum(sampler2D t, vec3 p, vec3 n, float tile, float mean_l) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 q = p / tile;
	return seam_lum(t, q.zy, mean_l) * w.x + seam_lum(t, q.xz, mean_l) * w.y + seam_lum(t, q.xy, mean_l) * w.z;
}
vec3 bed4_color(float id, float thick, vec3 tan_c, vec3 orange_c, vec3 cream_c, vec3 rust_c) {
	float h = h11(id);
	float g = h11(id + 91.0);
	vec3 c = mix(orange_c, tan_c, h);
	c = mix(c, cream_c, step(0.82, g) * step(thick, 1.8) * 0.4);
	c = mix(c, rust_c, step(g, 0.12) * 0.7);
	return c;
}

void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = surface_at;
	vec3 n = normalize(surface_normal);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float fine_fade = 1.0 - smoothstep(0.012, 0.06, footprint);
	float edge_fade = 1.0 - smoothstep(0.03, 0.14, footprint);

	// Slope weights: sand under about 25 degrees, rock above about 35, varnish on the steepest.
	float rock_w = 1.0 - smoothstep(0.819, 0.906, n.y);
	float varn_w = 1.0 - smoothstep(0.30, 0.55, n.y);

	// Slickrock mask from the vertex alpha (alpha 0 in the domes), undoing the terrain's pylon tint.
	float lerp_w = clamp((0.866 - n.y) * 6.0, 0.0, 0.8);
	float slick = clamp((1.0 - COLOR.a) / (1.0 - lerp_w), 0.0, 1.0);


	if (variant == 4) {
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		float dist = length(p - cam);
		float far_w = smoothstep(fade_near, fade_far, dist);
		float tmean_a = dot(textureLod(tex_tone, vec2(0.5), 10.0).rgb, vec3(0.3, 0.59, 0.11));
		float tmean_d = dot(textureLod(tex_grain, vec2(0.5), 10.0).rgb, vec3(0.3, 0.59, 0.11));
		// Band position: LKM bed table in world height. Thickness drifts slowly over the ground plane.
		float thick_var = 1.0 + (fbm3(vec3(p.x, 0.0, p.z) * 0.011 + 5.0) - 0.5) * 0.7;
		float w4 = (fbm3(vec3(p.x, p.y * 0.3, p.z) * 0.021) - 0.5) * 7.0 + (vn3(vec3(p.x, p.y * 0.5, p.z) * 0.07) - 0.5) * 1.6;
		float sc = bed_widen * thick_var;
		float u4 = (p.y + w4 + p.x * 0.011) / sc;
		float cyc4 = floor(u4 / 11.2);
		float r4 = u4 - cyc4 * 11.2;
		float lower4 = 0.0;
		int ki = 0;
		int pi = 7;
		float th4 = BEDS[0];
		for (int i = 0; i < 8; i++) {
			int idx = (i + int(bed_seed)) % 8;
			float t = BEDS[idx];
			if (r4 < lower4 + t || i == 7) {
				ki = idx;
				th4 = t;
				pi = (i + 7 + int(bed_seed)) % 8;
				break;
			}
			lower4 += t;
		}
		float id4 = cyc4 * 8.0 + float(ki) + bed_seed * 17.0;
		float pid4 = (ki == int(bed_seed) % 8 ? (cyc4 - 1.0) : cyc4) * 8.0 + float(pi) + bed_seed * 17.0;
		vec3 tan_c = bed_tan;
		vec3 orange_c = bed_orange;
		vec3 cream_c = bed_cream;
		vec3 rust_c = bed_rust;
		float abv = (r4 - lower4) * sc;
		float soft = smoothstep(0.0, max(0.5, 0.45 * th4 * sc), abv);
		vec3 bed_c = mix(bed4_color(pid4, th4, tan_c, orange_c, cream_c, rust_c), bed4_color(id4, th4, tan_c, orange_c, cream_c, rust_c), soft);
		vec3 wall_tone = mix(bed_orange, bed_tan, 0.55);
		vec3 wall_c = mix(bed_c, wall_tone, (1.0 - far_keep) * far_w);
		float tone_t = tri_lum(tex_tone, p, n, tile_tone, tmean_a);
		wall_c *= 1.0 + (tone_t - 1.0) * tone_amp * (1.0 - 0.6 * far_w);
		float foot4 = 1.0 - smoothstep(0.0, 0.35, abv);
		wall_c *= 1.0 - foot4 * 0.12 * edge_fade * (1.0 - far_w);
		float streak4 = smoothstep(0.55, 0.8, vn3(vec3(p.x * 1.5, p.y * 0.05, p.z * 1.5)) * 0.7 + vn3(vec3(p.x * 4.5, p.y * 0.2, p.z * 4.5) + 3.0) * 0.3);
		wall_c = mix(wall_c, varnish_color, varn_w * (0.12 + 0.25 * streak4) * (1.0 - 0.7 * far_w));
		// Flats: warm packed tan, grain only from the sand texture.
		float g_l = seam_lum(tex_grain, p.xz / tile_grain, tmean_d);
		float broad4 = fbm3(vec3(p.x, 0.0, p.z) * 0.06);
		vec3 flat_c = flat_color * (1.0 + (g_l - 1.0) * 0.45 * (1.0 - 0.5 * far_w) + (broad4 - 0.5) * 0.12);
		// Slickrock: faint warm cross-bed arcs over the flat tan.
		float ramp4 = dot(p.xz, vec2(0.83, 0.56)) + p.y * 1.4 + (fbm3(vec3(p.x, p.y * 0.6, p.z) * 0.028) - 0.5) * 11.0;
		float sl_tone = 0.5 + 0.5 * sin(ramp4 * 2.4 + (fbm3(vec3(p.x, p.y, p.z) * 0.13 + 4.0) - 0.5) * 6.0);
		vec3 slick4 = mix(flat_c, mix(orange_c, tan_c, sl_tone), 0.35 * (1.0 - far_w * 0.6));
		vec3 c4 = mix(flat_c, wall_c, rock_w);
		c4 = mix(c4, slick4, slick * (1.0 - rock_w));
		float grain4 = vn3(p / 0.05) - 0.5;
		c4 *= 1.0 + grain4 * 0.05 * fine_fade;
		ALBEDO = c4;
		ROUGHNESS = 0.95;
		AO = 1.0 - rock_w * foot4 * 0.10 * edge_fade;
		if (relief_enabled) {
			float proj4 = 0.04 * smoothstep(0.0, 0.5, abv) * (1.0 - smoothstep(th4 * sc - 0.3, th4 * sc, abv)) * (1.0 - far_w);
			NORMAL = surface_bump(VERTEX, NORMAL, proj4 * rock_w * edge_fade + grain4 * 0.008 * fine_fade);
		}
	} else {
	// Beds.
	float bed_scale = variant == 2 ? 0.55 : 1.0;
	float warp = (fbm3(vec3(p.x, p.y * 0.3, p.z) * 0.021) - 0.5) * 7.0 + (vn3(vec3(p.x, p.y * 0.5, p.z) * 0.07) - 0.5) * 1.6;
	float u = (p.y + warp + p.x * 0.011) / bed_scale;
	float period = 11.2;
	float cyc = floor(u / period);
	float r = u - cyc * period;
	float lower = 0.0;
	float thick = BEDS[0];
	int k = 0;
	for (int i = 0; i < 8; i++) {
		int idx = (i + int(bed_seed)) % 8;
		float t = BEDS[idx];
		if (r >= lower && r < lower + t) {
			thick = t;
			k = idx;
			break;
		}
		lower += t;
	}
	float bed_id = cyc * 8.0 + float(k) + bed_seed * 17.0;
	float a_hash = h11(bed_id);
	float b_hash = h11(bed_id + 91.0);
	float above = (r - lower) * bed_scale;
	float bed_t = thick * bed_scale;
	vec3 stone = mix(stone_dark, stone_light, a_hash);
	stone = mix(stone, sand_color, step(0.78, b_hash) * 0.55);
	stone = mix(stone, iron_color, step(b_hash, 0.14) * 0.45);
	float contrast = variant == 2 ? 1.5 : 1.0;
	stone *= 1.0 + (a_hash - 0.5) * 0.10 * (contrast - 1.0);
	float hard = variant == 3 ? step(0.5, h11(bed_id + 33.0)) : 0.5;
	if (variant == 3) {
		stone = mix(stone, stone * vec3(1.10, 1.05, 0.98), hard);
		stone = mix(stone * vec3(0.86, 0.84, 0.86), stone, hard);
	}
	// Ledge: undercut shade at the bed foot, a lit lip at the top, a thin dark line at the boundary.
	float amp = variant == 2 ? 0.10 : (variant == 3 ? mix(0.03, 0.14, hard) : 0.06);
	float proj = amp * smoothstep(0.0, 0.4, above) * (1.0 - smoothstep(bed_t - 0.16, bed_t, above));
	float foot = 1.0 - smoothstep(0.0, 0.22, above);
	float lip = smoothstep(bed_t - 0.26, bed_t - 0.08, above) * (1.0 - smoothstep(bed_t - 0.08, bed_t, above));
	float shade_w = variant == 2 ? 0.42 : 0.30;
	stone *= 1.0 - foot * shade_w * edge_fade - (1.0 - edge_fade) * 0.04 + lip * 0.10 * edge_fade;
	stone *= 1.0 + (fbm3(p * vec3(0.25, 0.5, 0.25)) - 0.5) * 0.22 * (variant == 2 ? 1.4 : 1.0);
	float joint = 0.0;
	if (variant == 3) {
		float jn = abs(vn3(vec3(p.x * 0.8, p.y * 0.025, p.z * 0.8)) - 0.5);
		joint = (1.0 - smoothstep(0.0, 0.018, jn)) * edge_fade * rock_w * 0.5;
		stone *= 1.0 - joint * 0.4;
	}

	// Varnish: dark vertical streaks on the steepest faces.
	float streak = smoothstep(0.55, 0.8, vn3(vec3(p.x * 1.5, p.y * 0.05, p.z * 1.5)) * 0.7 + vn3(vec3(p.x * 4.5, p.y * 0.2, p.z * 4.5) + 3.0) * 0.3);
	vec3 rock = mix(stone, varnish_color, varn_w * (0.35 + 0.6 * streak) * 0.85);

	// Slickrock: domain-warped thin cross-bed bands, one or two tones apart.
	float swirl = fbm3(vec3(p.x * 0.05, p.y * 0.22, p.z * 0.05) + 7.0);
	// Flowing arcs, not closed islands: a directional ramp bent by two warps (broad, then fine).
	float ramp = dot(p.xz, vec2(0.83, 0.56)) + p.y * 1.4 + (fbm3(vec3(p.x, p.y * 0.6, p.z) * 0.028) - 0.5) * 11.0 + (fbm3(vec3(p.x, p.y, p.z) * 0.13 + 4.0) - 0.5) * 2.2;
	float cb = ramp / 0.5;
	float cb_id = floor(cb);
	float cb_f = fract(cb);
	float cb_tone = mix(1.0, mix(0.86, 1.08, h11(cb_id + 5.0)), 1.0 - smoothstep(0.1, 0.4, footprint));
	float cb_line = (1.0 - smoothstep(0.0, 0.1, cb_f)) * edge_fade * 0.5;
	vec3 slick_col = mix(mix(stone_light, stone_dark, 0.3), sand_color, 0.2) * cb_tone * (1.0 - cb_line * 0.3);
	slick_col = mix(slick_col, iron_color, step(0.8, h11(cb_id + 41.0)) * 0.3);
	slick_col = mix(slick_col, stone_dark, smoothstep(0.55, 0.75, swirl) * 0.35);

	// Sand: broad weathering patches and wind ripples, both faded with distance.
	float ripple_c = (p.x * 0.9 + p.z * 0.42 + (fbm3(vec3(p.x, 0.0, p.z) * 0.09) - 0.5) * 3.0) / 0.5;
	float ripple = sin(ripple_c * 6.283185);
	float rip_fade = 1.0 - smoothstep(0.06, 0.22, footprint);
	vec3 sand = sand_color * (0.94 + (fbm3(vec3(p.x, 0.0, p.z) * 0.16) - 0.5) * 0.18 + ripple * 0.035 * rip_fade);
	sand = mix(sand, mix(sand_color, stone_light, 0.55), smoothstep(0.62, 0.8, fbm3(vec3(p.x * 0.05, 3.0, p.z * 0.05))) * 0.6);

	// Coarse weathering patches over everything.
	float patch = fbm3(p * 0.33 + 20.0);
	float pocket = smoothstep(0.62, 0.78, fbm3(vec3(p.x * 0.045, 9.0, p.z * 0.045))) * 0.75;
	vec3 col = mix(sand, rock, rock_w);
	col = mix(col, slick_col, slick * (1.0 - pocket));
	col *= 1.0 - smoothstep(0.55, 0.8, patch) * 0.14 + (patch - 0.5) * 0.06;

	// Fine grain: tone and a detail normal, fading before it can shimmer.
	float grain = vn3(p / 0.05) - 0.5;
	col *= 1.0 + grain * 0.07 * fine_fade;

	if (debug == 1) { col = vec3(slick); }
	if (debug == 2) { col = vec3(rock_w, varn_w, 0.0); }
	ALBEDO = col;
	ROUGHNESS = 0.95;
	AO = 1.0 - rock_w * foot * 0.12 * edge_fade;
	if (relief_enabled) {
		float bed_h = proj * rock_w * edge_fade;
		float flats = (1.0 - rock_w) * (ripple * 0.012 * rip_fade);
		float g = grain * 0.010 * fine_fade;
		NORMAL = surface_bump(VERTEX, NORMAL, bed_h + flats + g);
	}
	}
}
