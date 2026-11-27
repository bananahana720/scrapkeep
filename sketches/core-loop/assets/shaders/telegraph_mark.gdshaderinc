// Decoupled threat telegraph shader (assets/shaders/telegraph_mark.gdshaderinc).
// Included by threat_grammar.gd Painter.mark_material() with per-look defines
// (#define STRIPES, #define DEPTH_AWARE) and stencil_mode for P6 overlap unions.
//
// Upgrades over the legacy inline material mirror:
//   1. Analytical world-space anti-aliased 45-degree HAZARD stripes (zero 32px blur/aliasing)
//      in both tape (faint red band) and classic (HAZARD + CHARCOAL) looks.
//   2. Crisp advancing leading-edge front accent on pending fills (radial & lane) so timing
//      reads instantaneously at high speed without muddying the ball inside the ring.
//   3. Clean jump-clearance top-rail emphasis on soft height fences (RR-02).
//
// Every vertex names its drive in CUSTOM1.x; per-instance `clip` carries frame numbers:
//   0 pass
//   1 radial: keep r from centre in [clip.x - grow, clip.y + grow], grow = CUSTOM1.z
//   2 lane: keep along heading in [clip.x, clip.y] and |lateral| in [clip.z, clip.w]
//   3 dots: keep a flight dot while its share s (CUSTOM0.x) >= clip.z
//   4 chevron: tip at radius clip.z along ray CUSTOM0.xy, offset CUSTOM0.zw in tip frame
//   5 curtain: on ray CUSTOM0.xy at radius clip.w, height baked
#ifdef DEPTH_AWARE
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, unshaded;
uniform float depth_pull = 0.3;
#else
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, unshaded, depth_test_disabled;
#endif

#ifdef STRIPES
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv1_blend_sharpness = 1.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float stripe_pitch = 0.5;
uniform float stripe_tape = 0.0;
uniform vec3 tape_dark : source_color = vec3(0.55);
uniform float tape_share = 0.35;
uniform vec3 hazard_col : source_color = vec3(1.0, 0.353, 0.235);
#endif
uniform vec3 ink_col : source_color = vec3(0.141, 0.165, 0.157);
uniform float is_fill = 0.0;
uniform float is_fence = 0.0;
uniform float flash_scale = 1.0;
uniform float governed = 0.0;
// Gone at lens.x metres from the eye, whole at lens.y (threat_grammar.gd LENS_CLEAR, LENS_FULL).
uniform vec2 lens = vec2(1.0, 3.0);
global uniform float threat_fill_scale;

instance uniform vec3 centre;
instance uniform vec2 heading = vec2(0.0, -1.0);
instance uniform vec4 clip = vec4(-1.0e9, 1.0e9, -1.0e9, 1.0e9);
instance uniform float alpha_scale = 1.0;

varying flat int drive;
varying flat float grow;
varying flat float scaled;
varying vec2 offset;
varying vec2 world_xz;
varying float v_rel_y;

void vertex() {
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(
				pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
				COLOR.rgb * (1.0 / 12.92),
				lessThan(COLOR.rgb, vec3(0.04045)));
	}
	drive = int(CUSTOM1.x + 0.5);
	grow = CUSTOM1.z;
	scaled = CUSTOM1.y;
	vec2 c = centre.xz;
	if (drive == 3) {
		if (CUSTOM0.x < clip.z) {
			VERTEX = centre;
		}
	} else if (drive == 4) {
		if (clip.z > CUSTOM1.z) {
			VERTEX = centre;
		} else {
			vec2 ray = CUSTOM0.xy;
			VERTEX.xz = c + ray * (clip.z + CUSTOM0.z) + vec2(ray.y, -ray.x) * CUSTOM0.w;
		}
	} else if (drive == 5) {
		VERTEX.xz = c + CUSTOM0.xy * clip.w;
	}
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	offset = world.xz - c;
	world_xz = world.xz;
	v_rel_y = world.y - centre.y;
#ifdef DEPTH_AWARE
	// Only the depth moves: the drawn position, and the perspective the fragment clip's `offset`
	// interpolates with, stay the unpulled vertex's.
	vec4 eye = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float far = length(eye.xyz);
	vec4 pulled = PROJECTION_MATRIX * vec4(eye.xyz * (max(far - depth_pull, 0.05) / max(far, 0.0001)), 1.0);
	POSITION = PROJECTION_MATRIX * eye;
	POSITION.z = pulled.z / pulled.w * POSITION.w;
#endif
}

void fragment() {
	float lead = 0.0;
	float back_ink = 0.0;
	if (drive == 1) {
		float r = length(offset);
		if (r < clip.x - grow || r > clip.y + grow) {
			discard;
		}
		if (is_fill > 0.5 && clip.y > 0.25 && clip.y < 1.0e8) {
			float dist_out = clip.y - r;
			float aa = clamp(fwidth(r) * 1.5, 0.02, 0.14);
			lead = 1.0 - smoothstep(0.05, 0.17 + aa, dist_out);
			back_ink = smoothstep(0.14, 0.20 + aa, dist_out) * (1.0 - smoothstep(0.22 + aa, 0.30 + aa * 2.0, dist_out));
			if (clip.x > 0.25) {
				float dist_in = r - clip.x;
				lead = max(lead, 1.0 - smoothstep(0.05, 0.17 + aa, dist_in));
				back_ink = max(back_ink, smoothstep(0.14, 0.20 + aa, dist_in) * (1.0 - smoothstep(0.22 + aa, 0.30 + aa * 2.0, dist_in)));
			}
		}
	} else if (drive == 2) {
		float along = dot(offset, heading);
		float lateral = abs(dot(offset, vec2(heading.y, -heading.x)));
		if (along < clip.x || along > clip.y || lateral < clip.z || lateral > clip.w) {
			discard;
		}
		if (is_fill > 0.5 && clip.w > 0.2 && clip.w < 1.0e8) {
			float dist_lat = clip.w - lateral;
			float aa = clamp(fwidth(lateral) * 1.5, 0.02, 0.14);
			lead = 1.0 - smoothstep(0.05, 0.17 + aa, dist_lat);
			back_ink = smoothstep(0.14, 0.20 + aa, dist_lat) * (1.0 - smoothstep(0.22 + aa, 0.30 + aa * 2.0, dist_lat));
		}
	}
#ifdef STRIPES
	// Analytical world-locked diagonal hazard stripes foreshortening-compensated for ~20-35 deg
	// gameplay camera pitch so stripes project as bold, crisp ~45-degree warning bars at speed.
	float diag = (world_xz.x * 0.90 - world_xz.y * 0.44) / (stripe_pitch * 1.65);
	float saw = abs(fract(diag) - 0.5) * 2.0;
	float dark_w = stripe_tape > 0.5 ? clamp(tape_share + 0.12, 0.25, 0.62) : 0.48;
	float fw = clamp(fwidth(diag) * 2.0, 0.004, 0.28);
	float is_light = smoothstep(dark_w - fw, dark_w + fw, saw);
	vec3 stripe_rgb = stripe_tape > 0.5
			? mix(tape_dark * 0.56, vec3(1.18), is_light)
			: mix(ink_col, hazard_col, is_light);
	vec4 albedo_tex = vec4(stripe_rgb, 1.0);
#else
	vec4 albedo_tex = vec4(1.0);
#endif
	albedo_tex *= COLOR;
	vec3 col = albedo_tex.rgb;
	float a = albedo_tex.a * mix(1.0, alpha_scale, scaled) * mix(1.0, threat_fill_scale, governed);
	if (lead > 0.001 || back_ink > 0.001) {
		vec3 lead_col = mix(col, vec3(1.0, 0.86, 0.66), 0.52 * clamp(flash_scale, 0.0, 1.0));
		col = mix(col, ink_col, back_ink * 0.48);
		col = mix(col, lead_col, lead * 0.88);
		a = clamp(a + lead * 0.32 * clamp(flash_scale, 0.0, 1.0) + back_ink * 0.14, 0.0, 0.94);
	}
	if (is_fence > 0.5) {
		float rail_lift = smoothstep(1.2, 3.0, v_rel_y);
		col = mix(col, min(col * 1.18, vec3(1.0)), rail_lift * 0.4);
	}
	ALBEDO = col;
	ALPHA *= a * smoothstep(lens.x, lens.y, length(VERTEX));
}
