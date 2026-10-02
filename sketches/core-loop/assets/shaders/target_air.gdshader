shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
#include "res://assets/shaders/target_protection.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.824, 0.773, 0.647, 1.0);
uniform float opacity : hint_range(0.0, 0.03) = 0.025;
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
	float soft = pow(max(1.0 - dot(point, point), 0.0), 3.0);
	float near_camera = 1.0 - smoothstep(24.0, 30.0, length(VERTEX));
	ALBEDO = base_color.rgb;
	ALPHA = dressing_protected(SCREEN_UV) ? 0.0 : soft * opacity * life_fade * near_camera;
}
