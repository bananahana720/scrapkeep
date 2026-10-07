shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color;
uniform vec4 secondary_color : source_color;
uniform vec3 half_extents;
// 0 recessed lens, 1 directional safety paint, 2 copper/charcoal grate, 3 cracked castwork.
uniform int finish_kind = 0;
uniform float emission_energy = 0.0;
varying vec3 local_at;
varying vec3 local_normal;

float groove(float at, float pitch, float width) {
	float d = abs(fract(at / pitch + 0.5) - 0.5) * pitch;
	return 1.0 - smoothstep(width, width + max(fwidth(at), 0.005), d);
}

void vertex() {
	local_at = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 p = local_at;
	vec3 weights = pow(abs(local_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	float grain = sin(p.x * 21.0 + sin(p.y * 17.0)) * sin(p.z * 19.0 + p.y * 13.0);
	vec3 finish = base_color.rgb;
	float glow = 0.0;
	if (finish_kind == 0) {
		// Dark seals frame each blue seam; ribbed glass keeps the blue continuous and legible.
		vec3 edges = max(half_extents - abs(p), vec3(0.0));
		float border = dot(weights, vec3(min(edges.y, edges.z), min(edges.x, edges.z), min(edges.x, edges.y)));
		float lens = smoothstep(0.015, 0.055, border);
		float ribs = groove(p.y, 0.5, 0.015);
		finish = mix(secondary_color.rgb, base_color.rgb * (0.93 - ribs * 0.13), lens);
		glow = lens * (1.0 - ribs * 0.13);
		ROUGHNESS = 0.32;
		METALLIC = 0.08;
	} else if (finish_kind == 1) {
		// Broad diagonal amber/charcoal bands read as an industrial landing, never a checker.
		float line = p.x + p.z + p.y;
		float bands = groove(line, 2.0, 0.48);
		float wear = 0.92 + grain * 0.035;
		finish = mix(base_color.rgb, secondary_color.rgb, bands) * wear;
		ROUGHNESS = 0.84;
		METALLIC = 0.16;
	} else if (finish_kind == 2) {
		float bars = max(groove(p.x, 0.65, 0.09), groove(p.z, 1.3, 0.09));
		finish = mix(secondary_color.rgb * 0.40, base_color.rgb * (0.94 + grain * 0.04), bars);
		ROUGHNESS = mix(0.96, 0.48, bars);
		METALLIC = bars * 0.55;
	} else {
		float joints = max(groove(p.y, 1.5, 0.025), groove(p.x + floor(p.y / 1.5) * 1.2, 2.4, 0.018));
		float mineral = groove(p.y + sin(p.x * 0.48) * 0.14, 3.2, 0.15);
		finish = mix(base_color.rgb, secondary_color.rgb, mineral * 0.28) * (0.91 + grain * 0.035 - joints * 0.22);
		ROUGHNESS = 0.96;
		METALLIC = 0.0;
	}
	ALBEDO = finish;
	EMISSION = base_color.rgb * emission_energy * glow;
}
