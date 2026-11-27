shader_type spatial;
render_mode unshaded, cull_back;

// Riveted armour-class badge (ArmourMarks.icon_material): oil-charcoal keyline for value
// separation over sandstone and shadow (VISUAL-LANGUAGE.md §2), slate plate face, and worn-bone
// inner bevel with four corner rivets matching cat_defense icon grammar.
uniform vec4 badge_color : source_color;
uniform vec4 keyline_color : source_color;
uniform vec4 rivet_color : source_color;

void fragment() {
	vec2 uv = fract(UV);
	vec2 edge_d = min(uv, 1.0 - uv);
	float border = min(edge_d.x, edge_d.y);
	float aa = max(fwidth(border) * 1.4, 0.015);
	float plate_mask = smoothstep(0.11 - aa, 0.11 + aa, border);
	float bevel_mask = smoothstep(0.11 - aa, 0.11 + aa, border) * (1.0 - smoothstep(0.18 - aa, 0.18 + aa, border));
	vec2 corner = abs(uv - 0.5);
	float rivet_dist = length(corner - vec2(0.24, 0.24));
	float rivet = 1.0 - smoothstep(0.055 - aa, 0.055 + aa, rivet_dist);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.2) * 0.22;
	vec3 face = mix(badge_color.rgb, rivet_color.rgb, clamp(bevel_mask * 0.55 + rivet * 0.85 + rim, 0.0, 1.0));
	ALBEDO = mix(keyline_color.rgb, face, plate_mask);
}
