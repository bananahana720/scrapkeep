shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Dropped grey panel and rib cache signal beacon: luminous bone core with a charcoal
// grounding collar at the foot, subtle dark edge framing for sunlit sand readability,
// and slow rising scan bands (<= 1.5 Hz).
uniform vec4 beam_color : source_color = vec4(0.824, 0.773, 0.647, 1.0);
uniform vec3 ink_colour : source_color = vec3(0.141, 0.165, 0.157);
uniform float flash_scale = 1.0;

varying float v_height;
varying float v_cap;

void vertex() {
	// Godot CylinderMesh maps side-wall UV.y from 0.0 (top) to 0.5 (bottom); caps have |NORMAL.y| > 0.5.
	v_height = clamp(1.0 - UV.y * 2.0, 0.0, 1.0);
	v_cap = step(0.5, abs(NORMAL.y));
}

void fragment() {
	if (v_cap > 0.5) {
		discard;
	}
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(clamp(facing, 0.0, 1.0), 0.65);
	float foot_collar = 1.0 - smoothstep(0.02, 0.085, v_height);
	float tip_fade = smoothstep(1.0, 0.80, v_height);
	float scan = smoothstep(0.62, 0.94, fract(v_height * 3.5 - TIME * 1.15));
	float pulse = 0.92 + 0.08 * sin(TIME * 2.2);
	float side_ink = 1.0 - smoothstep(0.30, 0.56, facing);
	float lift = (0.34 + 0.36 * scan + 0.22 * core) * clamp(flash_scale, 0.0, 1.0);
	vec3 col = mix(beam_color.rgb, vec3(1.22, 1.19, 1.10), clamp(lift, 0.0, 0.78));
	col = mix(col, ink_colour, clamp(side_ink * 0.92 + foot_collar * 0.94, 0.0, 0.96));
	float body_alpha = mix(0.84, 0.96, max(core, side_ink)) * tip_fade * pulse;
	float final_alpha = max(body_alpha, foot_collar * 0.96);
	ALBEDO = col;
	ALPHA = clamp(final_alpha * beam_color.a, 0.0, 0.96);
}
