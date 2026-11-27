shader_type spatial;
render_mode diffuse_burley;

uniform vec4 glow_color : source_color;
uniform float face_energy = 0.06;
uniform float rim_energy = 1.25;
uniform float emission_ceiling = 1.35;
uniform float metal_boost = 0.32;
uniform float ink_strength = 0.86;
uniform float glint_strength = 0.28;
uniform float body_tone = 1.0;
uniform float flash_scale = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float hemi = smoothstep(-0.6, 0.45, world_n.y);
	// Bold charcoal silhouette ink, cool machined-steel body depth, and underside grounding
	// separate steel cogs and mint scrap decisively against sunlit sandstone.
	float edge_ink = 1.0 - smoothstep(0.24, 0.56, facing);
	float direct_ink = clamp(edge_ink * ink_strength * 0.94, 0.0, 0.94);
	vec3 cool_tint = mix(vec3(1.0), vec3(0.84, 0.90, 0.96), clamp(metal_boost, 0.0, 1.0));
	vec3 base_col = ALBEDO * body_tone * cool_tint * mix(0.40, 1.04, hemi);
	ALBEDO = mix(base_col, vec3(0.045, 0.055, 0.052), direct_ink);
	AO = mix(0.10, 1.0, hemi) * (1.0 - edge_ink * ink_strength);
	AO_LIGHT_AFFECT = 0.96;
	vec3 glint_dir = normalize(vec3(0.36, 0.82, 0.44));
	vec3 half_vec = normalize(v + glint_dir);
	float spec_glint = pow(max(0.0, dot(n, half_vec)), 12.0) * glint_strength;
	ROUGHNESS = mix(0.36, 0.14, clamp(spec_glint * 3.0, 0.0, 1.0));
	METALLIC = clamp(0.32 + metal_boost * (1.0 - facing * 0.30), 0.0, 0.86);
	SPECULAR = 0.82;
	float rim = pow(1.0 - facing, 1.55) + smoothstep(0.36, 0.84, 1.0 - facing) * 0.72;
	float pulse = 0.9 + 0.1 * sin(TIME * 2.0);
	float flare = (rim_energy * rim + spec_glint) * mix(0.55, 1.0, clamp(flash_scale, 0.0, 1.0));
	EMISSION = glow_color.rgb * min(face_energy + flare * pulse, emission_ceiling);
}
