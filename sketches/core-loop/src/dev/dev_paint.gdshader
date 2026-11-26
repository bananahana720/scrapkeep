shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float cel_steps : hint_range(0.0, 12.0, 1.0) = 0.0;
uniform float cel_soft : hint_range(0.01, 0.45) = 0.14;
uniform float flatten : hint_range(0.0, 1.0) = 0.0;
uniform float dots : hint_range(0.0, 1.0) = 0.0;
uniform float dot_px : hint_range(2.0, 16.0) = 4.5;
uniform float shadow_cut : hint_range(0.1, 0.8) = 0.48;
uniform float hatch : hint_range(0.0, 1.0) = 0.0;
uniform float hatch_px : hint_range(3.0, 14.0) = 6.0;
uniform float lines : hint_range(0.0, 1.0) = 0.0;
uniform float line_px : hint_range(0.5, 3.0) = 1.25;
uniform float depth_cut : hint_range(0.01, 1.0) = 0.14;
uniform float normal_cut : hint_range(0.05, 1.5) = 0.5;
uniform float fade_from : hint_range(10.0, 300.0) = 80.0;
uniform float fade_to : hint_range(20.0, 600.0) = 170.0;
uniform vec4 ink : source_color = vec4(0.141, 0.165, 0.157, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float metres(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, clamp(uv, vec2(0.0), vec2(1.0))).r;
	if (d <= 0.00001) {
		return 100000.0;
	}
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 facing(vec2 uv) {
	vec3 n = texture(normal_tex, clamp(uv, vec2(0.0), vec2(1.0))).xyz * 2.0 - 1.0;
	float len = length(n);
	return len > 0.0001 ? n / len : vec3(0.0, 0.0, 1.0);
}

float display_luma(vec3 c) {
	float lin = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
	return pow(lin / (1.0 + lin), 0.4545);
}

vec3 relit(vec3 c, float target) {
	float lin = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
	float comp = pow(clamp(target, 0.0, 0.992), 2.2);
	float want = comp / max(1.0 - comp, 0.02);
	return c * clamp(want / lin, 0.25, 2.2);
}

float pen(float along, float pitch, float weight) {
	return 1.0 - smoothstep(weight, weight + 0.12, abs(fract(along / pitch) - 0.5) * 2.0);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float here = metres(SCREEN_UV, INV_PROJECTION_MATRIX);
	if (here > 50000.0 || strength <= 0.0) {
		ALBEDO = col;
	} else {
		float near = 1.0 - smoothstep(fade_from, max(fade_to, fade_from + 1.0), here);
		float lum = display_luma(col);
		vec3 styled = col;

		if (cel_steps > 0.0) {
			float scaled = lum * cel_steps;
			float banded = (floor(scaled) + smoothstep(0.5 - cel_soft, 0.5 + cel_soft, fract(scaled))) / cel_steps;
			styled = relit(col, banded);
		}
		if (flatten > 0.0) {
			float steps = max(cel_steps, 6.0);
			styled = mix(styled, relit(col, (floor(lum * steps) + 0.5) / steps), flatten);
		}

		float shade = clamp((shadow_cut - lum) / max(shadow_cut, 0.01), 0.0, 1.0);
		if (dots > 0.0) {
			mat2 turn = mat2(vec2(0.8660254, -0.5), vec2(0.5, 0.8660254));
			vec2 cell = fract((turn * FRAGCOORD.xy) / dot_px) - 0.5;
			float radius = sqrt(shade) * 0.44;
			float dot_mask = 1.0 - smoothstep(radius - 0.08, radius + 0.08, length(cell));
			styled = mix(styled, ink.rgb, dot_mask * dots * shade);
		}
		if (hatch > 0.0) {
			vec2 p = FRAGCOORD.xy;
			float a1 = (p.x * 0.93969 - p.y * 0.34202) + sin(p.y * 0.07) * 0.9;
			float a2 = (p.x * 0.34202 + p.y * 0.93969) + sin(p.x * 0.07) * 0.9;
			float mid = smoothstep(shadow_cut, shadow_cut - 0.12, lum);
			float deep = smoothstep(shadow_cut * 0.5, shadow_cut * 0.5 - 0.1, lum);
			float strokes = max(pen(a1, hatch_px, 0.22) * mid * 0.65, pen(a2, hatch_px, 0.22) * deep * 0.85);
			styled = mix(styled, ink.rgb, clamp(strokes * hatch, 0.0, 1.0));
		}
		if (lines > 0.0) {
			vec2 o = line_px / VIEWPORT_SIZE;
			vec2 u0 = SCREEN_UV + vec2(-o.x, -o.y);
			vec2 u1 = SCREEN_UV + vec2(o.x, o.y);
			vec2 u2 = SCREEN_UV + vec2(o.x, -o.y);
			vec2 u3 = SCREEN_UV + vec2(-o.x, o.y);
			float d0 = metres(u0, INV_PROJECTION_MATRIX);
			float d1 = metres(u1, INV_PROJECTION_MATRIX);
			float d2 = metres(u2, INV_PROJECTION_MATRIX);
			float d3 = metres(u3, INV_PROJECTION_MATRIX);
			float nearest = min(min(d0, d1), min(d2, d3));
			vec3 n = facing(SCREEN_UV);
			float graze = 1.0 + 3.5 * pow(1.0 - clamp(abs(n.z), 0.0, 1.0), 2.0);
			float step_depth = (abs(min(d0, 5000.0) - min(d1, 5000.0)) + abs(min(d2, 5000.0) - min(d3, 5000.0))) / max(nearest, 0.5);
			float depth_edge = smoothstep(depth_cut * graze, depth_cut * graze * 2.0, step_depth);
			float turn_edge = smoothstep(normal_cut, normal_cut * 1.8, length(facing(u0) - facing(u1)) + length(facing(u2) - facing(u3)));
			styled = mix(styled, ink.rgb, max(depth_edge, turn_edge) * lines * ink.a);
		}
		ALBEDO = mix(col, styled, strength * near);
	}
}
