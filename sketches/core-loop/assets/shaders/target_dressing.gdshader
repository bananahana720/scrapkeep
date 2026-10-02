shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_prepass_alpha;
#include "res://assets/shaders/target_protection.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.5, 0.4, 0.3, 1.0);
void fragment() {
	ALBEDO = base_color.rgb * COLOR.r;
	ROUGHNESS = 0.95;
	ALPHA = dressing_protected(SCREEN_UV) ? 0.0 : 1.0;
}
