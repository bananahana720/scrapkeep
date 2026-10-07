shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.212, 0.341, 0.329, 1.0);
// 0 cast concrete, 1 painted metal, 2 shutter ribs, 3 inset interaction pad.
uniform int surface_kind = 0;
uniform vec3 half_extents = vec3(0.0);
uniform float chip_width = 0.065;
const float CONCRETE_VALUE_GAIN = 1.65;
varying vec3 local_at;
varying vec3 local_normal;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float grain(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y), mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float groove(float x, float pitch, float width) {
	float d = abs(fract(x / pitch + 0.5) - 0.5) * pitch;
	float aa = max(fwidth(x), 0.003);
	return 1.0 - smoothstep(width, width + aa, d);
}
void vertex() {
	local_at = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 p = local_at;
	vec3 weights = pow(abs(local_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	float aggregate = dot(weights, vec3(grain(vec3(p.yz * 9.0, 0.0)), grain(vec3(p.xz * 9.0, 0.0)), grain(vec3(p.xy * 9.0, 0.0))));
	float wash = grain(p * 0.65);
	vec3 paint = base_color.rgb * COLOR.rgb;
	float relief = 0.0;
	vec3 finish;
	if (surface_kind == 0) {
		float seams = max(groove(p.y, 1.8, 0.05), groove(p.x, 3.6, 0.045));
		float tie = length(vec2(mod(p.x + 0.9, 1.8) - 0.9, mod(p.y + 0.45, 0.9) - 0.45));
		float holes = (1.0 - smoothstep(0.025, 0.045 + fwidth(tie), tie)) * (1.0 - weights.y);
		vec3 edge_distance = max(half_extents - abs(p), vec3(0.0));
		float edge = dot(weights, vec3(min(edge_distance.y, edge_distance.z), min(edge_distance.x, edge_distance.z), min(edge_distance.x, edge_distance.y)));
		float chips = (1.0 - smoothstep(0.0, chip_width, edge)) * smoothstep(0.42, 0.68, grain(p * 13.0));
		finish = paint * (0.86 + wash * 0.19 + aggregate * 0.08 - seams * 0.17 - holes * 0.30);
		finish = mix(finish, vec3(0.37, 0.39, 0.35), chips * 0.72);
		finish *= CONCRETE_VALUE_GAIN;
		relief = aggregate * 0.014 - seams * 0.025 - holes * 0.035 - chips * 0.012;
		ROUGHNESS = 0.94;
		METALLIC = 0.0;
	} else {
		float panel_seam = max(groove(p.x, 2.4, 0.012), groove(p.z, 2.4, 0.012)) * weights.y;
		float scuff = smoothstep(0.60, 0.78, grain(p * vec3(12.0, 2.0, 1.6))) * 0.12;
		float ribs = surface_kind == 2 ? groove(p.y, 0.32, 0.028) : panel_seam;
		float rim = 0.0;
		if (surface_kind == 3) {
			// Cylinder pads have equal x/z radii; rectangles follow their own bounds.
			float border = half_extents.y > 0.055 ? half_extents.x - length(p.xz) : min(half_extents.x - abs(p.x), half_extents.z - abs(p.z));
			rim = 1.0 - smoothstep(0.08, 0.15, border);
		}
		finish = paint * (0.88 + wash * 0.14 + aggregate * 0.04 - ribs * 0.18 - scuff);
		finish = mix(finish, vec3(0.018, 0.023, 0.021), rim * 0.83);
		relief = aggregate * 0.003 - ribs * 0.012;
		ROUGHNESS = 0.82 - scuff;
		METALLIC = 0.18 + scuff;
	}
	ALBEDO = finish;
	// Relief stays in shading; silhouette and all physics geometry remain untouched.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	NORMAL = normalize(NORMAL - normalize(dx) * dFdx(relief) * 2.0 - normalize(dy) * dFdy(relief) * 2.0);
}
