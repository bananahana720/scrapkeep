shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D floor_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stone_tint : source_color;
uniform vec4 cord_tint : source_color;
uniform vec4 deck_tint : source_color;
uniform float net_height = 10.0;
uniform float net_pitch = 4.0;
varying vec3 local_at;
varying vec3 local_normal;

void vertex() {
	local_at = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 wear = texture(floor_map, local_at.xz / 8.0).rgb;
	vec3 stone = stone_tint.rgb * wear;
	vec2 cell = local_at.xz / net_pitch;
	vec2 width = max(fwidth(cell), vec2(0.0001));
	vec2 edge = abs(fract(cell - 0.5) - 0.5);
	vec2 line = 1.0 - smoothstep(vec2(0.025) - width, vec2(0.025) + width, edge);
	float resolved = 1.0 - smoothstep(0.15, 0.5, max(width.x, width.y));
	float weave = mix(0.0975, max(line.x, line.y), resolved);
	vec3 net = mix(deck_tint.rgb, cord_tint.rgb, weave);
	float catch_floor = (1.0 - smoothstep(net_height + 0.01, net_height + 0.10, local_at.y)) * smoothstep(0.9, 0.99, local_normal.y);
	ALBEDO = mix(stone, net, catch_floor);
	ROUGHNESS = 0.95;
}
