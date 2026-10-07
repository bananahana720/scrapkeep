shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D tex_tone : source_color, repeat_enable;
uniform sampler2D tex_grain : source_color, repeat_enable;
uniform vec4 base_color : source_color;
uniform vec4 seam_color : source_color;
uniform float panel_pitch = 8.0;
uniform float seam_width = 0.10;
varying vec3 local_at;

void vertex() {
	local_at = VERTEX;
}

void fragment() {
	vec2 p = local_at.xz;
	float radius = length(p);
	float ring = abs(mod(radius + panel_pitch * 0.5, panel_pitch) - panel_pitch * 0.5);
	float angle = atan(p.y, p.x);
	float spoke = abs(sin(angle * 6.0)) * radius / 6.0;
	float distance_to_seam = min(ring, spoke);
	float aa = max(fwidth(distance_to_seam), 0.025);
	float seam = 1.0 - smoothstep(seam_width, seam_width + aa, distance_to_seam);
	float tone = texture(tex_tone, p * 0.035).r;
	float grain = texture(tex_grain, p * 0.4).r;
	vec3 stone = base_color.rgb * (0.78 + tone * 0.18 + grain * 0.08);
	ALBEDO = mix(stone, seam_color.rgb, seam * 0.72);
	ROUGHNESS = 0.92;
}
