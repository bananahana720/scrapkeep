shader_type spatial;
render_mode diffuse_burley;
// The sinkhole's cinder floor (contraptions.gd _build_cinder): loose charcoal grit over a lava tube floor, with
// ember seams that smoulder at rest and blaze as the dwell grace runs out. `glow` is the heat tell, 0 cold to 1
// at the end of the grace (cinder_heat.gd); everything else is a function of the world position, so strips tile.

uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grit_dark : source_color = vec3(0.10, 0.11, 0.105);
uniform vec3 grit_light : source_color = vec3(0.24, 0.22, 0.20);
uniform vec3 ember : source_color = vec3(1.0, 0.35, 0.24);
uniform sampler2D tex_grain : source_color, repeat_enable, filter_linear_mipmap;
uniform float tile_grain = 3.0;
uniform float smoulder = 0.35;
uniform float blaze = 4.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float vn2(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(c), h12(c + vec2(1, 0)), f.x), mix(h12(c + vec2(0, 1)), h12(c + vec2(1, 1)), f.x), f.y);
}

varying vec3 surface_at;
void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = surface_at.xz;
	float grain = dot(texture(tex_grain, p / tile_grain).rgb, vec3(0.3, 0.59, 0.11));
	float clump = vn2(p * 0.9) * 0.6 + vn2(p * 3.7 + 5.1) * 0.4;
	vec3 col = mix(grit_dark, grit_light, clamp(clump * 0.7 + grain * 0.5 - 0.2, 0.0, 1.0));
	// Ember seams: thin bright lines where two noise fields cross half, breathing slowly at rest.
	float seam = 1.0 - smoothstep(0.0, 0.06, abs(vn2(p * 0.55 + 2.3) - 0.5));
	seam *= smoothstep(0.35, 0.65, vn2(p * 0.21 + 9.0));
	float breath = 0.75 + 0.25 * sin(TIME * 1.7 + vn2(p * 0.1) * 6.0);
	float heat = smoulder * breath + blaze * glow * glow;
	ALBEDO = mix(col, ember * 0.6, seam * 0.5);
	EMISSION = ember * seam * heat + ember * glow * 0.25;
	ROUGHNESS = 0.97;
}
