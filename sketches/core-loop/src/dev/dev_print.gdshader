shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;

uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 1.0;
uniform float posterize : hint_range(0.0, 16.0, 1.0) = 0.0;
uniform float dither : hint_range(0.0, 1.0) = 0.0;
uniform float chroma : hint_range(0.0, 6.0) = 0.0;

uniform vec3 gain = vec3(1.0);
uniform float temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float grade_saturation : hint_range(0.0, 2.0) = 1.0;
uniform float grade_contrast : hint_range(0.5, 2.0) = 1.0;

uniform float riso : hint_range(0.0, 1.0) = 0.0;
uniform float riso_shift : hint_range(0.0, 6.0) = 1.2;
uniform float riso_cell : hint_range(3.0, 16.0) = 5.0;
uniform float centre_guard : hint_range(0.0, 1.0) = 0.65;
uniform vec4 riso_a : source_color = vec4(0.937, 0.333, 0.235, 1.0);
uniform vec4 riso_b : source_color = vec4(0.137, 0.384, 0.62, 1.0);
uniform vec4 paper : source_color = vec4(0.969, 0.945, 0.890, 1.0);
uniform vec4 ink : source_color = vec4(0.141, 0.165, 0.157, 1.0);

uniform float tooth : hint_range(0.0, 0.25) = 0.0;
uniform float grain : hint_range(0.0, 0.5) = 0.0;
uniform float scanlines : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.5) = 0.0;

uniform float speed_lines : hint_range(0.0, 1.0) = 0.0;
uniform vec2 speed_centre = vec2(0.5, 0.55);
uniform float impact : hint_range(0.0, 1.0) = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i.x + i.y * 4] / 16.0 - 0.5;
}

vec2 snap_uv(vec2 uv, vec2 px) {
	if (pixel_size <= 1.0) {
		return uv;
	}
	vec2 block = px * pixel_size;
	return (floor(uv / block) + 0.5) * block;
}

vec3 fetch(vec2 uv, vec2 px) {
	vec2 at = snap_uv(uv, px);
	if (chroma <= 0.0) {
		return texture(screen, at).rgb;
	}
	vec2 away = (uv - 0.5) * px * chroma * 2.0;
	return vec3(texture(screen, at + away).r, texture(screen, at).g, texture(screen, at - away).b);
}

vec3 graded(vec3 c) {
	c += vec3(temperature * 0.08, temperature * 0.01, -temperature * 0.08);
	c = mix(vec3(luma(c)), c, grade_saturation);
	c = (c - 0.5) * grade_contrast + 0.5;
	c *= gain;
	return clamp(c, 0.0, 1.0);
}

float screen_dots(vec2 frag, float value, float angle_deg, float cell) {
	float a = radians(angle_deg);
	mat2 turn = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	vec2 local = fract(turn * frag / cell) - 0.5;
	float radius = sqrt(clamp(value, 0.0, 1.0)) * 0.62;
	return 1.0 - smoothstep(radius - 0.06, radius + 0.06, length(local));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec2 frag = uv / px;
	vec2 block = floor(frag / max(pixel_size, 1.0));
	vec3 c = graded(fetch(uv, px));

	if (posterize > 0.0) {
		c = floor(c * posterize + 0.5 + vec3(bayer4(block) * dither)) / posterize;
	} else if (dither > 0.0) {
		c += vec3(bayer4(block) * dither * 0.08);
	}

	if (riso > 0.0) {
		vec2 centred = (uv - 0.5) * vec2(px.y / max(px.x, 0.00001), 1.0);
		float guard = mix(1.0, smoothstep(0.10, 0.44, length(centred)), centre_guard);
		vec2 shift = vec2(1.0, -0.5) * riso_shift * guard;
		float la = 1.0 - luma(graded(fetch(uv + shift * px, px)));
		float lb = 1.0 - luma(c);
		float da = screen_dots(frag + shift, la, 15.0, riso_cell);
		float db = screen_dots(frag, lb, 75.0, riso_cell);
		vec3 sheet = paper.rgb;
		sheet = mix(sheet, sheet * riso_a.rgb, clamp(da * 0.9 + la * 0.25, 0.0, 1.0));
		sheet = mix(sheet, sheet * riso_b.rgb, clamp(db * 0.9 + lb * 0.25, 0.0, 1.0));
		c = mix(c, sheet, riso);
	}

	if (speed_lines > 0.0) {
		vec2 from = uv - speed_centre;
		float ang = atan(from.y, from.x);
		float streak = hash(vec2(floor(ang * 90.0), floor(TIME * 18.0)));
		float far = smoothstep(0.34, 0.78, length(from * vec2(1.6, 1.0)));
		c = mix(c, paper.rgb, step(1.0 - speed_lines * 0.16, streak) * far * 0.7);
	}

	if (impact > 0.0) {
		vec3 frame = mix(ink.rgb, paper.rgb, step(0.42, luma(c)));
		c = mix(c, frame, impact);
	}

	if (tooth > 0.0) {
		c += (hash(floor(frag * 0.5)) - 0.5) * 2.0 * tooth;
	}
	if (grain > 0.0) {
		c += (hash(frag + fract(TIME) * 91.0) - 0.5) * grain;
	}
	if (scanlines > 0.0) {
		c *= 1.0 - scanlines * 0.35 * step(0.5, fract(frag.y / max(2.0, pixel_size * 2.0)));
	}
	if (vignette > 0.0) {
		c *= 1.0 - vignette * smoothstep(0.3, 0.85, length((uv - 0.5) * vec2(1.25, 1.0)));
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
