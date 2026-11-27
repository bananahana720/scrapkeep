// Shared World 1 weathered salvage & value-hierarchy shader helpers.
// Keeps background terrain, poured concrete, dam masonry, and salvage clutter in a
// cohesive, desaturated mid-tone value band with grounded contact occlusion and
// anti-aliased micro-grain so high-saturation combat actors, pickups, and telegraphs pop.

float env_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Compresses background albedo toward a calm weathered mid-tone band:
// - desat pulls chroma toward luminance so backgrounds never fight combat accents
// - compress gently reins in extreme bright/dark noise peaks around linear pivot
vec3 env_compress_midtone(vec3 c, float desat, float pivot, float compress) {
	float l = env_luma(c);
	vec3 muted = mix(c, vec3(l), clamp(desat, 0.0, 1.0));
	float target_l = mix(l, pivot, clamp(compress, 0.0, 1.0));
	float scale = target_l / max(l, 0.001);
	return max(muted * mix(1.0, scale, smoothstep(0.02, 0.12, l)), vec3(0.0));
}

float env_hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float env_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(env_hash2(i), env_hash2(i + vec2(1.0, 0.0)), f.x),
		mix(env_hash2(i + vec2(0.0, 1.0)), env_hash2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float env_hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float env_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(env_hash3(i), env_hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(env_hash3(i + vec3(0.0, 1.0, 0.0)), env_hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(env_hash3(i + vec3(0.0, 0.0, 1.0)), env_hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(env_hash3(i + vec3(0.0, 1.0, 1.0)), env_hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z
	);
}

// Anti-aliased micro-grain centered around 0.0; fades smoothly below pixel footprint.
float env_micro_grain(vec3 p, float freq) {
	vec3 q = p * freq;
	float footprint = length(fwidth(q));
	float fade = 1.0 - smoothstep(0.35, 1.35, footprint);
	return (env_noise3(q) - 0.5) * fade;
}

// Grounded dual-stage contact darkening for props, clutter, and dressing bases.
float env_contact_ao(float height_m, float span_m, float floor_val) {
	float t = smoothstep(0.0, max(span_m, 0.001), height_m);
	float root = smoothstep(0.0, max(span_m * 0.35, 0.001), height_m);
	float curve = mix(root * root, t, 0.55);
	return mix(floor_val, 1.0, curve);
}

// Anisotropic vertical rainwater/silt runoff streaks on vertical masonry & concrete.
float env_rain_streak(vec2 plane, float x_freq, float y_freq) {
	float col_a = env_noise2(vec2(plane.x * x_freq, plane.y * y_freq));
	float col_b = env_noise2(vec2(plane.x * (x_freq * 2.3) + 5.7, plane.y * (y_freq * 0.65) + 1.9));
	return smoothstep(0.46, 0.84, col_a * 0.62 + col_b * 0.38);
}

// High-contrast architectural runoff plumes for distant monolithic concrete/dam faces.
// Keeps clean concrete near 0.0 while concentrated mineral/rain curtains reach 0.7-1.0
// so weathering survives aerial haze at 150-250 m approach distance.
float env_dam_plume(vec2 plane, float x_freq, float y_freq) {
	float warp = (env_noise2(vec2(plane.x * (x_freq * 0.55) + 2.1, plane.y * (y_freq * 1.6))) - 0.5) * 0.65;
	float broad = smoothstep(0.36, 0.72, env_noise2(vec2(plane.x * x_freq + warp, plane.y * y_freq)));
	float fine = smoothstep(0.40, 0.76, env_noise2(vec2(plane.x * (x_freq * 2.6) + 3.7, plane.y * (y_freq * 1.5) + 7.1)));
	return clamp(broad * 0.76 + fine * (0.22 + 0.42 * broad), 0.0, 1.0);
}

// Shifts weathered dam concrete into a calmer sun-bleached mid-tone with cooler dark
// mineral/moisture patina where runoff, eaves shadow, and lower seepage collect.
vec3 env_concrete_patina(vec3 c, float stain_amt, float bleach_amt) {
	float l = env_luma(c);
	vec3 silt_dark = mix(c * 0.56, vec3(l * 0.48, l * 0.50, l * 0.54), 0.58);
	vec3 calc_light = mix(c * 1.08, vec3(l * 1.14 + 0.014, l * 1.12 + 0.012, l * 1.08 + 0.010), 0.42);
	vec3 out_c = mix(c, calc_light, clamp(bleach_amt, 0.0, 1.0));
	return mix(out_c, silt_dark, clamp(stain_amt, 0.0, 1.0));
}

// Subtle top-face sun-fade & dust settling (VISUAL-LANGUAGE "Weathered").
vec3 env_top_dust(vec3 c, float up_dot, float strength) {
	float top = smoothstep(0.45, 0.92, up_dot) * clamp(strength, 0.0, 1.0);
	float l = env_luma(c);
	vec3 faded = mix(c, vec3(l * 1.08 + 0.015), 0.32);
	return mix(c, faded, top);
}
