shader_type canvas_item;
// The launch take's comic swipe (launch_take.gd): a sand panel with amber speed lines that sweeps in
// from the bottom left and on out through the top right, ink on both edges, so the cut between the
// menu or camp and the dam happens under one continuous swipe. progress 0 to 1 covers, 1 to 2 uncovers.
uniform float progress = 0.0;
uniform float aspect = 1.7778;
uniform float spin = 0.0;
uniform float lines = 1.0;
uniform vec4 base : source_color = vec4(0.824, 0.773, 0.647, 1.0);
uniform vec4 streak : source_color = vec4(0.898, 0.627, 0.267, 1.0);
uniform vec4 ink : source_color = vec4(0.141, 0.165, 0.157, 1.0);
const float SLANT = 0.08;
const float EDGE = 0.012;

void fragment() {
	float d = (UV.x + 1.0 - UV.y) * 0.5;
	float front = clamp(progress, 0.0, 1.0) * (1.0 + 2.0 * SLANT + EDGE) - SLANT;
	float tail = clamp(progress - 1.0, 0.0, 1.0) * (1.0 + 2.0 * SLANT + EDGE) - SLANT;
	float covered = step(d, front) * step(tail, d);
	float edge = max(step(abs(d - front), EDGE) * step(0.001, front), step(abs(d - tail), EDGE) * step(0.001, tail));
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - 0.5);
	float angle = atan(p.y, p.x) + spin;
	float ray = floor(angle * 9.0);
	float pick = fract(sin(ray * 91.37) * 437.58);
	float speed = step(0.62, pick) * smoothstep(0.12, 0.42, length(p)) * lines;
	vec4 fill = mix(base, streak, speed);
	COLOR = mix(fill, ink, edge);
	COLOR.a = max(covered, edge);
}
