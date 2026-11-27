shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_prepass_alpha;
#include "res://assets/shaders/target_protection.gdshaderinc"
#include "res://assets/shaders/env_weathering.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.5, 0.4, 0.3, 1.0);
uniform float contact_span = 0.45;
uniform float contact_floor = 0.64;
uniform float value_desat : hint_range(0.0, 0.5) = 0.22;
uniform float value_compress : hint_range(0.0, 0.5) = 0.24;
varying float local_rise;
varying vec3 world_at;
varying vec3 world_normal;

void vertex() {
	// Pebbles and tuft meshes sit around [-0.5, 0.5] in local Y; shift root to 0.0.
	local_rise = VERTEX.y + 0.45;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float foot = env_contact_ao(local_rise, contact_span, contact_floor);
	float micro = env_micro_grain(world_at, 4.0);
	vec3 tone = base_color.rgb * COLOR.r;
	tone = env_top_dust(tone, world_normal.y, 0.35);
	tone = env_compress_midtone(tone, value_desat, 0.27, value_compress);
	ALBEDO = tone * foot * (1.0 + micro * 0.08);
	ROUGHNESS = clamp(0.95 + micro * 0.04, 0.88, 0.99);
	AO = mix(0.68, 1.0, smoothstep(0.0, contact_span, local_rise));
	AO_LIGHT_AFFECT = 0.22;
	ALPHA = dressing_protected(SCREEN_UV) ? 0.0 : 1.0;
}
