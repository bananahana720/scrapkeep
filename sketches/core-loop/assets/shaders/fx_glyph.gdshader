shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Decoupled combat glyph & chain-pip shader (vfx.gd).
// Draws inked comic shapes (charcoal keyline framing saturated class/event hues) so
// hit bursts, slam rings, deflects and kill-chain pips pop cleanly over sunlit sandstone
// and dark shadow while rendering strictly beneath hostile telegraphs (render_priority < 39).
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 ink_colour : source_color = vec3(0.141, 0.165, 0.157);
uniform float alpha = 1.0;
uniform float heat = 0.0;
// 0 = UV-inked tapered comic spoke/ribbon (hit burst, star, cross, arc)
// 1 = Fresnel-inked 3D silhouette (ring, wave, diamond, chevron, pip)
uniform int mode = 0;

void fragment() {
	vec3 body = tint.rgb;
	float ink = 0.0;
	if (mode == 0) {
		float across = abs(UV.x * 2.0 - 1.0);
		float along = abs(UV.y * 2.0 - 1.0);
		// Taper each spoke into a sharp kinetic spark wedge toward both tips.
		float half_w = mix(0.86, 0.14, along);
		if (across > half_w) {
			discard;
		}
		float edge_d = half_w - across;
		float hub_mask = smoothstep(0.16, 0.34, along);
		float side_ink = (1.0 - smoothstep(0.08, 0.24, edge_d)) * hub_mask;
		float tip_ink = smoothstep(0.84, 0.95, along);
		ink = max(side_ink, tip_ink);
		float center_hot = (1.0 - smoothstep(0.0, 0.46, along)) * (1.0 - smoothstep(0.0, half_w * 0.80, across));
		vec3 vibrant = min(tint.rgb * 1.32 + vec3(0.05), vec3(1.18));
		vec3 safe_hub = mix(vibrant, min(tint.rgb * 1.45 + vec3(0.32), vec3(1.18)), center_hot * 0.65);
		body = mix(safe_hub, vec3(1.44, 1.38, 1.24), clamp(heat * (0.28 + 0.72 * center_hot), 0.0, 1.0));
	} else {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		vec3 vibrant = min(tint.rgb * 1.22 + vec3(0.04), vec3(1.15));
		body = mix(vibrant, vec3(1.36, 1.32, 1.22), clamp(heat * facing, 0.0, 1.0));
		ink = 1.0 - smoothstep(0.28, 0.48, facing);
	}
	ALBEDO = mix(body, ink_colour, ink * 0.96);
	ALPHA = clamp(alpha * (mode == 0 ? 1.22 : 1.0), 0.0, 0.96);
}
