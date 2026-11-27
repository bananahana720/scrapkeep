shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// 2010 custom-vinyl Fleet finish (SIGHT-PERSONA.md sections 5-6, BakeLook.edge_lift):
// - Convex bevels (UV2.y < 0.5, above `from`) wear cleanly to warm brushed worn bone with subtle
//   satin bare-metal gleam right along the ridge and localized hand-brushed paint breakup (zero
//   chalky airbrush bleed on flat faces).
// - Grazing silhouettes just inside the InkOutline stroke carry a crisp cool desert-dawn sky
//   Fresnel rim compensated for blend_mix alpha attenuation so iron-oxide Fleet hulls pop off
//   dark dawn floors without washing out flat head-on faces.
// - Neutral faces (UV2.y == 0.5, as on Old Works edge=0 castings) draw nothing head-on.
uniform vec4 bone : source_color;
uniform vec4 sky : source_color;
uniform float lift = 0.64;
uniform float from = 0.68;
uniform float rim = 0.70;
uniform float rim_power = 3.0;
uniform float glow = 1.18;

varying vec3 local_pos;
varying vec3 world_pos;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float brush_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// UV2.y is the bake's wear with glTF's flipped V: 0.5 neutral, 0 the most worn convex edge, 1 the deepest crease.
	float worn = clamp((0.5 - UV2.y) * 2.0, 0.0, 1.0);
	float worn_brushed = worn;
	if (worn > 0.45) {
		float broad = brush_noise(local_pos * vec3(9.0, 16.0, 9.0));
		float stroke = brush_noise(local_pos * vec3(26.0, 38.0, 26.0));
		float chip = (broad * 0.55 + stroke * 0.45) - 0.5;
		float chip_band = smoothstep(0.54, 0.80, worn) * (1.0 - smoothstep(0.92, 1.0, worn));
		worn_brushed = clamp(worn + chip * 0.15 * chip_band, 0.0, 1.0);
	}
	// Distance-adaptive silhouette readability: tight custom-vinyl detail up close (<8 m), broader crisp
	// desert-dawn sky rim & bevel lift at gameplay camera distance (>14 m) so shaded hulls stay legible.
	float view_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float far_read = smoothstep(8.5, 18.0, view_dist);
	float eff_from = mix(from, max(from - 0.10, 0.52), far_read);
	float eff_power = mix(rim_power, 2.25, far_read);
	float eff_rim = min(rim * mix(1.0, 1.18, far_read), 0.92);
	float edge = lift * smoothstep(eff_from, 1.0, worn_brushed);
	float crest = smoothstep(0.80, 0.98, worn_brushed);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Damp grazing Fresnel across upward-facing decks and domed caps (foreman/lobber/miniboss roofs viewed from
	// elevated cameras) while preserving full crisp cool-sky Fresnel on vertical/curved silhouette walls.
	float flat_deck = smoothstep(0.60, 0.84, world_normal.y) * smoothstep(0.02, 0.14, ndv);
	float side = eff_rim * pow(1.0 - ndv, eff_power) * mix(1.0, 0.12, flat_deck);
	float a = max(edge, side);
	if (a < 0.004) {
		discard;
	}
	float rim_weight = clamp(side / max(a, 0.001), 0.0, 1.0) * (1.0 - crest * 0.85);
	// Sky glow arrives from the desert-dawn sky/horizon, not from below the hull, and stays tightly on the grazing rim.
	float sky_hemisphere = smoothstep(-0.30, 0.12, world_normal.y);
	float rim_band = smoothstep(mix(0.18, 0.11, far_read), mix(0.46, 0.34, far_read), side);
	// Warm parchment-bone bevel wear vs crisp cool desert-dawn sky rim (never clipped stark white).
	vec3 warm_bone = bone.rgb * vec3(1.05, 0.99, 0.90);
	vec3 worn_albedo = warm_bone * (1.0 + crest * 0.08);
	vec3 rim_albedo = mix(bone.rgb, sky.rgb, 0.82);
	ALBEDO = mix(worn_albedo, rim_albedo, rim_weight);
	ROUGHNESS = mix(0.64, 0.40, crest * (1.0 - rim_weight));
	METALLIC = 0.22 * crest * (1.0 - rim_weight);
	SPECULAR = 0.48;
	// Warm bevel self-lift keeps worn ridges legible in dawn shadow; cool sky glow punches the shaded outer contour.
	vec3 edge_emit = warm_bone * (mix(0.30, 0.56, far_read) * smoothstep(0.10, 0.52, edge) * (1.0 - rim_weight));
	vec3 rim_emit = sky.rgb * (glow * mix(1.0, 2.25, far_read) * rim_band * rim_weight * sky_hemisphere);
	EMISSION = edge_emit + rim_emit;
	ALPHA = a;
}
