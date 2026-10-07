shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float fx_time = 0.0;
uniform float column_height = 40.0;
uniform float column_radius = 5.0;
uniform float occupied = 0.0;
varying float fade;

void vertex() {
	// Occupancy changes density and opacity without teleporting the existing rise phases.
	float speed = 3.2 * mix(0.8, 1.2, INSTANCE_CUSTOM.w);
	float y = mod(INSTANCE_CUSTOM.x * column_height + fx_time * speed, column_height);
	float rise = y / column_height;
	float angle = INSTANCE_CUSTOM.y * 6.283185 + fx_time * 0.15;
	float radius = INSTANCE_CUSTOM.z * column_radius * mix(0.35, 0.95, rise);
	VERTEX += vec3(cos(angle) * radius, y, sin(angle) * radius);
	fade = smoothstep(0.0, 0.08, rise) * (1.0 - smoothstep(0.85, 1.0, rise));
}

void fragment() {
	ALBEDO = vec3(0.925, 0.906, 0.855);
	ALPHA = fade * mix(0.24, 0.40, occupied);
}
