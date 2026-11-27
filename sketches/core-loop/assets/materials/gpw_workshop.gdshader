shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/env_weathering.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.212, 0.341, 0.329, 1.0);
// 0 cast concrete, 1 painted metal, 2 shutter ribs, 3 inset interaction pad.
uniform int surface_kind = 0;
uniform vec3 half_extents = vec3(0.0);
uniform float chip_width = 0.065;
const float CONCRETE_VALUE_GAIN = 1.65;
const float ENV_VALUE_DESAT = 0.26;
const float ENV_VALUE_COMPRESS = 0.24;
varying vec3 local_at;
varying vec3 local_normal;
varying vec3 world_at;
varying vec3 world_normal;

float groove(float x, float pitch, float width) {
	float d = abs(fract(x / pitch + 0.5) - 0.5) * pitch;
	float aa = max(fwidth(x), 0.003);
	return 1.0 - smoothstep(width, width + aa, d);
}

void vertex() {
	local_at = VERTEX;
	local_normal = NORMAL;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = local_at;
	vec3 wp = world_at;
	vec3 weights = pow(abs(local_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	float aggregate = dot(weights, vec3(env_noise3(vec3(p.yz * 9.0, 0.0)), env_noise3(vec3(p.xz * 9.0, 0.0)), env_noise3(vec3(p.xy * 9.0, 0.0))));
	float wash = env_noise3(wp * 0.45);
	float micro = env_micro_grain(wp, 3.5);
	vec3 paint = base_color.rgb * COLOR.rgb;
	float relief = 0.0;
	float ao_val = 1.0;
	vec3 finish;

	if (surface_kind == 0) {
		float seams = max(groove(p.y, 1.8, 0.05), groove(p.x, 3.6, 0.045));
		float plank_seam = groove(wp.y, 0.45, 0.016) * (1.0 - weights.y);
		float board_grain = (env_noise2(vec2((wp.x + wp.z) * 1.4, wp.y * 8.5)) - 0.5) * (1.0 - weights.y) * 0.14;
		vec2 tie_uv = vec2(mod(p.x + 0.9, 1.8) - 0.9, mod(p.y + 0.45, 0.9) - 0.45);
		float tie = length(tie_uv);
		float holes = (1.0 - smoothstep(0.025, 0.045 + fwidth(tie), tie)) * (1.0 - weights.y);
		float tie_drip = (1.0 - smoothstep(0.015, 0.08, abs(tie_uv.x))) * smoothstep(-0.42, 0.0, tie_uv.y) * (1.0 - smoothstep(-0.02, 0.04, tie_uv.y)) * (1.0 - weights.y);
		vec3 edge_distance = max(half_extents - abs(p), vec3(0.0));
		float edge = dot(weights, vec3(min(edge_distance.y, edge_distance.z), min(edge_distance.x, edge_distance.z), min(edge_distance.x, edge_distance.y)));
		float chips = (1.0 - smoothstep(0.0, chip_width, edge)) * smoothstep(0.42, 0.68, env_noise3(p * 13.0));
		float streaks = env_rain_streak(vec2(wp.x + wp.z, wp.y), 0.85, 0.22) * (1.0 - weights.y);
		float foot_height = half_extents.y > 0.1 ? (p.y + half_extents.y) : 10.0;
		float foot_ao = env_contact_ao(foot_height, 1.6, 0.72);
		float silt_blotch = smoothstep(0.35, 0.78, env_noise3(wp * 0.85)) * (1.0 - weights.y);

		finish = paint * (0.86 + wash * 0.19 + aggregate * 0.08 - seams * 0.17 - holes * 0.30);
		finish = mix(finish, vec3(0.37, 0.39, 0.35), chips * 0.72);
		finish *= CONCRETE_VALUE_GAIN;
		// Weathered industrial concrete pass: formwork planks, rainwater streaks, base dampness, and mid-tone compression.
		finish *= foot_ao * (0.82 + board_grain + micro * 0.07 - plank_seam * 0.14 - tie_drip * 0.15 - streaks * 0.18 - silt_blotch * 0.09);
		finish = env_top_dust(finish, world_normal.y, 0.36);
		finish = env_compress_midtone(finish, ENV_VALUE_DESAT, 0.25, ENV_VALUE_COMPRESS);
		relief = aggregate * 0.017 - seams * 0.028 - plank_seam * 0.014 - holes * 0.036 - chips * 0.014 - streaks * 0.005 + micro * 0.004;
		ao_val = clamp((1.0 - seams * 0.22 - plank_seam * 0.12 - holes * 0.28 - streaks * 0.12) * mix(0.74, 1.0, foot_ao), 0.52, 1.0);
		ROUGHNESS = clamp(0.95 - streaks * 0.10 - (1.0 - foot_ao) * 0.10 + micro * 0.04, 0.76, 0.98);
		METALLIC = 0.0;
	} else {
		float panel_seam = max(groove(p.x, 2.4, 0.012), groove(p.z, 2.4, 0.012)) * weights.y;
		float scuff = smoothstep(0.58, 0.78, env_noise3(p * vec3(12.0, 2.0, 1.6))) * 0.14;
		float ribs = surface_kind == 2 ? groove(p.y, 0.32, 0.028) : panel_seam;
		float streaks = env_rain_streak(vec2(wp.x + wp.z, wp.y), 0.9, 0.22) * (1.0 - weights.y);
		float rim = 0.0;
		if (surface_kind == 3) {
			// Cylinder pads have equal x/z radii; rectangles follow their own bounds.
			float border = half_extents.y > 0.055 ? half_extents.x - length(p.xz) : min(half_extents.x - abs(p.x), half_extents.z - abs(p.z));
			rim = 1.0 - smoothstep(0.08, 0.15, border);
		}
		finish = paint * (0.87 + wash * 0.15 + aggregate * 0.05 + micro * 0.04 - ribs * 0.22 - scuff - streaks * 0.10);
		finish = env_top_dust(finish, world_normal.y, 0.28);
		finish = env_compress_midtone(finish, ENV_VALUE_DESAT * 0.75, 0.26, ENV_VALUE_COMPRESS * 0.75);
		finish = mix(finish, vec3(0.018, 0.023, 0.021), rim * 0.85);
		relief = aggregate * 0.004 - ribs * 0.016 + micro * 0.002;
		ao_val = clamp(1.0 - ribs * 0.24 - streaks * 0.06, 0.65, 1.0);
		ROUGHNESS = clamp(0.84 - scuff * 1.1 + streaks * 0.06 + micro * 0.04, 0.62, 0.95);
		METALLIC = clamp(0.16 + scuff * 1.2 - streaks * 0.06, 0.05, 0.38);
	}
	ALBEDO = finish;
	AO = ao_val;
	AO_LIGHT_AFFECT = 0.25;
	// Relief stays in shading; silhouette and all physics geometry remain untouched.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	NORMAL = normalize(NORMAL - normalize(dx) * dFdx(relief) * 2.2 - normalize(dy) * dFdy(relief) * 2.2);
}
