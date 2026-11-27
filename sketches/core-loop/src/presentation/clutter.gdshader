shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_prepass_alpha;
#include "res://assets/shaders/target_protection.gdshaderinc"
#include "res://assets/shaders/env_weathering.gdshaderinc"
// The clutter kit's paint: the slot's albedo times the mesh's vertex colour, weathered into
// the background mid-tone band. Actors and telegraphs hide it through the shared screen-space
// protection, like all dressing. A dual-stage contact shade darkens the foot of each piece so
// it sits grounded on the terrain it casts no shadow on.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float contact_height = 0.12;
uniform float contact_floor = 0.7;
uniform float value_desat : hint_range(0.0, 0.5) = 0.22;
uniform float value_compress : hint_range(0.0, 0.5) = 0.22;
varying float rise;
varying vec3 world_at;
varying vec3 world_normal;

void vertex() {
	rise = VERTEX.y;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float foot = env_contact_ao(rise, contact_height * 2.0, contact_floor * 0.78);
	float micro = env_micro_grain(world_at, 3.2);
	float grime = env_noise3(world_at * 0.45);
	vec3 tone = albedo.rgb * COLOR.rgb;
	tone = env_top_dust(tone, world_normal.y, 0.35);
	tone = env_compress_midtone(tone, value_desat, 0.26, value_compress);
	tone *= foot * (0.94 + grime * 0.10 + micro * 0.06);
	ALBEDO = tone;
	ROUGHNESS = clamp(0.93 - (1.0 - foot) * 0.05 + micro * 0.05, 0.84, 0.98);
	AO = mix(0.68, 1.0, smoothstep(0.0, contact_height * 1.6, rise));
	AO_LIGHT_AFFECT = 0.25;
	ALPHA = dressing_protected(SCREEN_UV) ? 0.0 : 1.0;
}
