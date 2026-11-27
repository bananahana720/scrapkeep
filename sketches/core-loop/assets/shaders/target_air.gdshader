shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
#include "res://assets/shaders/target_protection.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.824, 0.773, 0.647, 1.0);
uniform float opacity : hint_range(0.0, 0.03) = 0.024;
uniform float effect_clock = 0.0;
uniform bool ground_streak = false;
varying float life_fade;
void vertex() {
	float phase = fract(effect_clock * (ground_streak ? 0.18 : 0.10) + INSTANCE_CUSTOM.r);
	life_fade = sin(phase * 3.141593);
	if (ground_streak) {
		VERTEX.x += phase * 3.0;
	} else {
		VERTEX.x += phase * 0.45;
		VERTEX.y += sin(effect_clock * 0.5 + INSTANCE_CUSTOM.r * 6.283185) * 0.06;
	}
}
void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	// Taper ground streaks cleanly along travel direction; keep airborne motes wispy and subtle
	// so they never read as distracting grey bokeh dots mid-screen.
	float shape = ground_streak
		? pow(max(1.0 - point.y * point.y, 0.0), 2.8) * pow(max(1.0 - point.x * point.x, 0.0), 1.8)
		: pow(max(1.0 - dot(point, point), 0.0), 4.5);
	float dist = length(VERTEX);
	float near_lens = ground_streak ? smoothstep(2.5, 6.0, dist) : smoothstep(6.0, 13.0, dist);
	float far_fade = 1.0 - smoothstep(20.0, 29.0, dist);
	float air_scale = ground_streak ? 0.90 : 0.45;
	ALBEDO = base_color.rgb;
	ALPHA = dressing_protected(SCREEN_UV) ? 0.0 : shape * opacity * air_scale * life_fade * near_lens * far_fade;
}
