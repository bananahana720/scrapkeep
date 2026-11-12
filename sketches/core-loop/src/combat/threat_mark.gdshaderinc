// Threat marks drawn once and driven per frame (E1-DENSITY.md section 1). The colour and
// stripe code is StandardMaterial3D's generated code for the Painter's materials (Godot
// 4.7.2 BaseMaterial3D::_update_shader: unshaded, alpha, no depth test, cull disabled,
// sRGB vertex colour as albedo; STRIPES adds the world-triplanar stripe texture), so a
// mark looks the same whichever path drew it.
//
// Every vertex names its drive in CUSTOM1.x; the per-instance `clip` carries the frame's
// numbers, read per drive:
//   0 pass
//   1 radial: keep r from centre in [clip.x - grow, clip.y + grow], grow = CUSTOM1.z
//   2 lane: keep along heading in [clip.x, clip.y] and |lateral| in [clip.z, clip.w]
//   3 dots: keep a flight dot while its share s (CUSTOM0.x) >= clip.z
//   4 chevron: tip at radius clip.z along ray CUSTOM0.xy, offset CUSTOM0.zw in the tip's
//     (forward, side) frame; hidden past r_out (CUSTOM1.z)
//   5 curtain: on ray CUSTOM0.xy at radius clip.w, height baked
// CUSTOM1.y = 1 scales the vertex alpha by alpha_scale (a wave's hot ramp, a lane going
// live). `governed` fills also take the density governor's threat_fill_scale.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, unshaded, depth_test_disabled;

#ifdef STRIPES
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv1_blend_sharpness = 1.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;
#endif
uniform float governed = 0.0;
// Gone at lens.x metres from the eye, whole at lens.y (threat_grammar.gd LENS_CLEAR, LENS_FULL),
// as StandardMaterial3D's pixel distance fade does for the static marks.
uniform vec2 lens = vec2(1.5, 4.0);
global uniform float threat_fill_scale;

instance uniform vec3 centre;
instance uniform vec2 heading = vec2(0.0, -1.0);
instance uniform vec4 clip = vec4(-1.0e9, 1.0e9, -1.0e9, 1.0e9);
instance uniform float alpha_scale = 1.0;

varying flat int drive;
varying flat float grow;
varying flat float scaled;
varying vec2 offset;

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
#ifdef STRIPES
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);
	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);
	uv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = world * uv1_scale + uv1_offset;
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
#endif
}

#ifdef STRIPES
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}
#endif

void fragment() {
	if (drive == 1) {
		float r = length(offset);
		if (r < clip.x - grow || r > clip.y + grow) {
			discard;
		}
	} else if (drive == 2) {
		float along = dot(offset, heading);
		float lateral = abs(dot(offset, vec2(heading.y, -heading.x)));
		if (along < clip.x || along > clip.y || lateral < clip.z || lateral > clip.w) {
			discard;
		}
	}
#ifdef STRIPES
	vec4 albedo_tex = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);
#else
	vec4 albedo_tex = vec4(1.0);
#endif
	albedo_tex *= COLOR;
	ALBEDO = albedo_tex.rgb;
	ALPHA *= albedo_tex.a * mix(1.0, alpha_scale, scaled) * mix(1.0, threat_fill_scale, governed)
			* smoothstep(lens.x, lens.y, length(VERTEX));
}
