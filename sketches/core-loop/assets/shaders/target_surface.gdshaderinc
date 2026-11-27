// Patterns stay in world metres; no vertex displacement, time input or texture file.
uniform bool detail_enabled = true;
uniform bool relief_enabled = true;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float relief_strength : hint_range(0.0, 1.0) = 1.0;
varying vec3 surface_at;
varying vec3 surface_normal;
float surface_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float surface_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(surface_hash(cell), surface_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(surface_hash(cell + vec2(0.0, 1.0)), surface_hash(cell + vec2(1.0)), f.x), f.y);
}
vec2 surface_plane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) { return p.xz; }
	if (a.x > a.z) { return p.zy; }
	return p.xy;
}
vec3 surface_bump(vec3 position, vec3 normal, float height) {
	vec3 dx = dFdx(position);
	vec3 dy = dFdy(position);
	vec3 across_x = cross(dy, normal);
	vec3 across_y = cross(normal, dx);
	float determinant = dot(dx, across_x);
	float divisor = sign(determinant) * max(abs(determinant), 0.000001);
	vec3 gradient = (across_x * dFdx(height) + across_y * dFdy(height)) / (divisor + 0.00000001);
	return normalize(normal - gradient * relief_strength);
}

// Continuous macro field: no cell edges in broad albedo or relief. Fine grain
// alone uses the interpolated lattice above and fades below the pixel footprint.
float surface_macro(vec2 p) {
	return 0.5 + 0.25 * sin(p.x + sin(p.y * 0.73)) + 0.25 * sin(p.y * 0.81 + sin(p.x * 0.61));
}
float surface_value(float tone) {
	return mix(1.0, clamp(tone, 0.38, 1.24), detail_enabled ? clamp(detail_strength, 0.0, 1.0) : 0.0);
}
