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
uniform float visual_catch_gain = 8.0;

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
	ROUGHNESS = finish_roughness;
	METALLIC = finish_metallic;
}
