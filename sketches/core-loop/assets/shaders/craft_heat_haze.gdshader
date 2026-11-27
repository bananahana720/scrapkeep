shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;

// Localized furnace-vent thermal distortion strictly for perimeter smelter vents.
// Never applied full-screen and never placed across combat telegraphs or reticles.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.03) = 0.0085;
uniform float rise_speed : hint_range(0.0, 4.0) = 1.4;
uniform float wave_frequency : hint_range(1.0, 24.0) = 12.0;
uniform vec3 tint_color : source_color = vec3(1.0, 0.753, 0.439);
uniform float tint_strength : hint_range(0.0, 0.35) = 0.08;
uniform float opacity : hint_range(0.0, 1.0) = 0.78;
uniform float reduced_motion : hint_range(0.0, 1.0) = 0.0;
uniform float reduce_flashes : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV * 2.0 - vec2(1.0);
	float radial = clamp(1.0 - dot(centered, centered), 0.0, 1.0);
	float vertical_fade = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float mask = smoothstep(0.0, 0.65, radial) * vertical_fade;
	if (mask < 0.01) {
		discard;
	}

	float motion_scale = mix(1.0, 0.0, reduced_motion);
	float t = TIME * rise_speed * motion_scale;
	float w1 = sin(UV.y * wave_frequency - t * 3.1 + UV.x * 5.0);
	float w2 = cos(UV.x * (wave_frequency * 0.85) + UV.y * 6.5 - t * 2.3);
	float w3 = sin((UV.x + UV.y) * (wave_frequency * 1.35) - t * 4.2);

	float strength = distortion_strength * mix(1.0, 0.18, reduced_motion);
	vec2 offset = vec2(w1 * 0.65 + w3 * 0.35, w2 * 0.55 - w3 * 0.25) * strength * mask;
	vec2 sample_uv = clamp(SCREEN_UV + offset, vec2(0.002), vec2(0.998));
	vec3 refracted = texture(screen_tex, sample_uv).rgb;

	float shimmer = 0.5 + 0.5 * (w1 * 0.5 + w2 * 0.5);
	float tint_amt = tint_strength * mask * mix(0.65, 1.0, shimmer) * mix(1.0, 0.35, reduce_flashes);
	ALBEDO = mix(refracted, refracted + tint_color * 0.45, tint_amt);
	ALPHA = mask * opacity;
}
