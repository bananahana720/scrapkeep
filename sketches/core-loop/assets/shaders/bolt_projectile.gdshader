shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// Sculpted 24-segment fluted energy-dart player projectile shader (Bolts.gd):
// - Converts sRGB MultiMesh instance tint to linear consistently across Metal and Vulkan
//   (matching StandardMaterial3D vertex_color_is_srgb = true).
// - Paired with a pixel-constant inverted-hull dark oil-charcoal outline next_pass in Bolts.gd
//   so EVERY dart carries a crisp, perfectly symmetric 360-degree comic silhouette border at
//   every camera angle without ever darkening grazing noses or tails.
// - Encodes 8 circumferential sculpted plasma flutes + recessed machined collar groove +
//   focused luminous central spine + animated axial plasma chevrons via INSTANCE_CUSTOM
//   (r: phase, g: boost, b: flair, a: FlashGuard).
// - Preserves exact crowd_alpha in COLOR.a and renders at Bolts.PRIORITY (0), below telegraphs.

uniform vec3 collar_ink : source_color = vec3(0.05, 0.058, 0.068);
uniform vec3 core_warm : source_color = vec3(1.0, 0.99, 0.94);

varying vec4 inst_custom;
varying vec3 local_pos;
varying vec3 dart_right_v;
varying vec3 dart_up_v;
varying vec3 dart_fwd_v;

vec3 srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

void vertex() {
	inst_custom = INSTANCE_CUSTOM;
	local_pos = VERTEX;
	dart_right_v = normalize(MODELVIEW_MATRIX[0].xyz);
	dart_up_v = normalize(MODELVIEW_MATRIX[1].xyz);
	dart_fwd_v = normalize(MODELVIEW_MATRIX[2].xyz);
}

void fragment() {
	// UV.x: 0.0 at spear nose tip -> 1.0 at wake tail tip; UV.y: circumferential angle [0..1].
	float axial = clamp(UV.x, 0.0, 1.0);
	float flow_phase = inst_custom.r;
	float bit_boost = clamp(inst_custom.g, 0.0, 1.0);
	float bit_flair = clamp(inst_custom.b, 0.0, 1.0);
	float flash_scale = clamp(inst_custom.a > 0.01 ? inst_custom.a : 1.0, 0.40, 1.0);

	// Boost ShotBits colour saturation so vivid hues survive AgX roll-off over warm sandstone.
	vec3 tint = srgb_to_linear(clamp(COLOR.rgb, vec3(0.0), vec3(1.0)));
	float luma = dot(tint, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid_tint = max(mix(vec3(luma), tint, 1.52), vec3(0.0));

	// Cylindrical radial alignment perpendicular to the flight axis: stays 1.0 strictly down the
	// FULL longitudinal center spine from nose to tail (never breaking into transverse rings!).
	vec3 view_dir = normalize(VIEW);
	vec3 fwd = normalize(dart_fwd_v);
	vec3 right_v = normalize(dart_right_v);
	vec3 up_v = normalize(dart_up_v);
	vec2 xy = local_pos.xy;
	float xy_len = length(xy);
	vec3 radial_v = xy_len > 0.0005 ? normalize(right_v * (xy.x / xy_len) + up_v * (xy.y / xy_len)) : normalize(NORMAL);
	vec3 view_perp = view_dir - fwd * dot(view_dir, fwd);
	float vp_len = length(view_perp);
	float spine_align = vp_len > 0.001
		? clamp(dot(radial_v, view_perp / vp_len), 0.0, 1.0)
		: clamp(abs(dot(normalize(NORMAL), view_dir)), 0.0, 1.0);

	float circum_angle = xy_len > 0.0005 ? atan(xy.y, xy.x) : 0.0;
	float flutes = 0.5 + 0.5 * cos(circum_angle * 8.0);
	float flute_ridge = smoothstep(0.34, 0.68, flutes);
	float flute_shade = mix(0.46, 1.32, flute_ridge);
	float collar_groove = smoothstep(0.026, 0.016, abs(axial - 0.315));
	float collar_bevel = smoothstep(0.022, 0.012, abs(axial - 0.275)) + smoothstep(0.022, 0.012, abs(axial - 0.355));
	float plasma_wave = 0.5 + 0.5 * sin(axial * 24.0 - flow_phase * 14.0);
	float fin_energy = flute_ridge * mix(0.18, 0.55, plasma_wave) * smoothstep(0.96, 0.06, axial);

	// Continuous blazing longitudinal central energy spine running full nose-to-tail, flanked by
	// rich vivid fluted ShotBits body and a razor-sharp machined collar ring.
	float spine = smoothstep(0.72, 0.90, spine_align) * smoothstep(0.99, 0.02, axial);
	float nose_hot = smoothstep(0.16, 0.01, axial) * smoothstep(0.40, 0.80, spine_align);
	float core_mix = clamp((spine * 0.92 + nose_hot * 0.45 + fin_energy * 0.18 + collar_bevel * 0.14) * flash_scale, 0.0, 0.94);
	float hdr_gain = mix(1.15, 2.75, clamp(spine * 0.85 + nose_hot * 0.25, 0.0, 1.0)) * (1.0 + bit_boost * 0.26) * flash_scale;
	vec3 body_col = mix(vivid_tint * flute_shade * (1.35 + bit_flair * 0.22), core_warm, core_mix) * hdr_gain;
	// Crisp machined dark steel collar ring cleanly separating spearhead from fluted shaft.
	body_col = mix(body_col, collar_ink, collar_groove * 0.94);

	// Solid readable silhouette full length; inverted-hull next_pass frames the bold dark charcoal outline.
	float tail_fade = smoothstep(1.0, 0.93, axial);
	float alpha = clamp(COLOR.a * mix(0.78, 1.0, tail_fade), 0.0, 1.0);
	if (alpha < 0.01) {
		discard;
	}
	ALBEDO = body_col;
	ALPHA = alpha;
}
