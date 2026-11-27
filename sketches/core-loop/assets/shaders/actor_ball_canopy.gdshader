shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_never;

// Comic glass canopy (BallLooks._canopy): crystal-clear face-on so the pilot's colours and
// face stay unmistakable, framed by a crisp cool-sky Fresnel rim and anti-aliased slanted glints.
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - ndv, 2.5);
	float slant = local_pos.x * 0.8 + local_pos.y * 0.6;
	float aa = max(fwidth(slant) * 1.4, 0.008);
	float band_a = 1.0 - smoothstep(0.034 - aa, 0.034 + aa, abs(slant - 0.34));
	float band_b = 1.0 - smoothstep(0.015 - aa, 0.015 + aa, abs(slant - 0.21));
	float mask_y = smoothstep(0.08, 0.15, local_pos.y) * (1.0 - smoothstep(0.58, 0.66, local_pos.y));
	float glint = clamp((band_a + band_b * 0.85) * mask_y, 0.0, 1.0);
	vec3 glass_tint = vec3(0.82, 0.94, 1.0);
	ALBEDO = mix(glass_tint, vec3(1.0), glint);
	EMISSION = glass_tint * (rim * 0.14) + vec3(0.95, 0.98, 1.0) * (glint * 0.12);
	ALPHA = clamp(0.045 + rim * 0.52 + glint * 0.30, 0.0, 1.0);
	ROUGHNESS = 0.18;
	SPECULAR = 0.14 + rim * 0.56;
}
