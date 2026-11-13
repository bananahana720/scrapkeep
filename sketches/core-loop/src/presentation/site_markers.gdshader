shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

// One smoke plume of site_markers.gd: a quad that turns about its own vertical axis to face the eye, drawing a column of
// smoke that widens and thins as it rises. UV.y is 0 at the top and 1 at the foot (Godot's QuadMesh). site_markers.gd
// sets every uniform from its KINDS row ; near_alpha and seed are each plume's own, and near_alpha follows the eye.
uniform vec4 tint : source_color = vec4(0.92, 0.9, 0.85, 1.0);
uniform float alpha = 0.5;
uniform float near_alpha = 1.0;
// Plume half-width at the foot and at the top, as shares of the quad's half-width.
uniform float foot = 0.12;
uniform float crown = 0.9;
// How far the plume leans and curls (share of the quad's half-width) and how fast the curl travels.
uniform float sway = 0.3;
uniform float sway_hz = 0.2;
// Rise speed in quad heights a second, and the noise grain across and up the plume.
uniform float rise = 0.08;
uniform vec2 grain = vec2(3.0, 6.0);
// Puffs: 0 is one unbroken wisp; above 0, this many puffs stand in the quad at once, with gaps between them.
uniform float puffs = 0.0;
// 0 keeps the puffs evenly spaced; up to 1 bunches them into a stutter that drifts off the beat.
uniform float stutter = 0.0;
uniform float seed = 0.0;
// How dark the plume's rim goes, as a share of its tint (1 is no rim).
uniform float rim_dark = 1.0;
// A fire's light on the plume's foot (the furnace kind): its colour, and in alpha its strength; 0 is none.
uniform vec4 glow : source_color = vec4(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Turn about the model's own up axis toward the eye, keeping its scale (BaseMaterial3D's BILLBOARD_FIXED_Y).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float up = 1.0 - UV.y;
	float t = TIME + seed * 17.0;
	// The curl grows with height, so the foot stays planted on the site.
	float lean = sway * up * sin(up * 5.0 - t * sway_hz * 6.2832 + seed * 6.2832);
	float x = (UV.x - 0.5) * 2.0 - lean;
	float half_w = mix(foot, crown, sqrt(up));
	float gap = 1.0;
	if (puffs > 0.0) {
		// Each puff is a round blob that swells as it rises, with thin smoke between: a smoke signal, or a chug.
		float phase = up * puffs - t * rise * puffs;
		phase += stutter * 0.35 * sin(phase * 2.1 + t * 0.7);
		float puff = sin(fract(phase) * 3.14159);
		half_w *= mix(0.4, 1.0, puff);
		gap = mix(0.3, 1.0, smoothstep(0.0, 0.8, puff));
	}
	vec2 p = vec2(x * grain.x, (up - t * rise) * grain.y) + seed * 31.0;
	float wisp = noise(p) * 0.65 + noise(p * 2.3 + 7.0) * 0.35;
	// The noise eats the edge, not the middle, so the body stays whole and the outline billows.
	float edge = abs(x) + (wisp - 0.5) * half_w * 0.9;
	float density = (1.0 - smoothstep(half_w * 0.35, half_w, edge)) * mix(0.7, 1.0, wisp) * gap;
	// Never a hard side: the smoke thins out before the quad's own edge, whatever the lean.
	density *= 1.0 - smoothstep(0.8, 0.98, abs(UV.x - 0.5) * 2.0);
	float ends = smoothstep(0.0, 0.05, up) * pow(1.0 - up, 0.9);
	// Light from one side, so it reads as matter in the air and not as a beam of light.
	float side = smoothstep(-half_w, half_w, x + (wisp - 0.5) * 0.4);
	// A darker rim gives the plume an outline against a sky of its own shade (the flume's pale sky behind pale smoke).
	float rim = smoothstep(half_w * 0.3, half_w * 0.95, edge);
	ALBEDO = tint.rgb * mix(0.68, 1.06, side * 0.7 + wisp * 0.3) * mix(1.0, rim_dark, rim);
	// The furnace lights the column from below: strongest at the foot, gone a fifth of the way up, with a slow flicker.
	float lit = glow.a * pow(1.0 - up, 8.0) * (0.85 + 0.15 * sin(t * 2.3 + wisp * 6.0));
	ALBEDO = mix(ALBEDO, glow.rgb * 1.3, clamp(lit, 0.0, 1.0));
	ALPHA = clamp(density * ends * alpha * near_alpha, 0.0, 1.0);
}
