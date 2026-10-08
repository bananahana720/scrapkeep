shader_type spatial;
render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float finish_roughness = 0.8;
uniform float finish_metallic = 0.0;
uniform vec4 cord_tint : source_color;
uniform float fade_end = 0.5;
varying vec3 world_at;
// World X/Z, downward deflection, radius. One independent value per 32 m batch.
uniform vec4 catch_point = vec4(0.0, 0.0, 0.0, 6.0);
uniform float visual_catch_gain = 2.0;
// World X/Z, ring radius, remaining strength. Zero strength is off.
uniform vec4 ring_a = vec4(0.0);
uniform vec4 ring_b = vec4(0.0);
// World X/Z, radius, level for the reduced-motion single pulse.
uniform vec4 pulse = vec4(0.0);
uniform vec4 ring_glow : source_color = vec4(1.0);
const float RING_WIDTH = 0.8;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float reach = length(world.xz - catch_point.xy) / catch_point.w;
	float bowl = max(0.0, 1.0 - reach * reach);
	VERTEX.y -= catch_point.z * visual_catch_gain * bowl * bowl;
	vec2 slope = 4.0 * catch_point.z * visual_catch_gain * bowl
		* (world.xz - catch_point.xy) / (catch_point.w * catch_point.w);
	NORMAL = normalize(vec3(NORMAL.x - slope.x * NORMAL.y, NORMAL.y, NORMAL.z - slope.y * NORMAL.y));
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb * cord_tint.rgb;
	float footprint = max(length(dFdx(world_at)), length(dFdy(world_at)));
	ALPHA = 1.0 - smoothstep(0.10, fade_end, footprint);
	float glow = 0.0;
	float reach_a = length(world_at.xz - ring_a.xy);
	float reach_b = length(world_at.xz - ring_b.xy);
	glow += ring_a.w * (1.0 - smoothstep(0.0, RING_WIDTH, abs(reach_a - ring_a.z)));
	glow += ring_b.w * (1.0 - smoothstep(0.0, RING_WIDTH, abs(reach_b - ring_b.z)));
	glow += pulse.w * (1.0 - smoothstep(0.0, pulse.z, length(world_at.xz - pulse.xy)));
	EMISSION = ring_glow.rgb * min(glow, 1.0);
	ROUGHNESS = finish_roughness;
	METALLIC = finish_metallic;
}
