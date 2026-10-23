shader_type sky;

// A panorama under the stage's time of day (world_look.gd TIME_ROWS "sky" values). The zenith and
// horizon tints grade it, recolor pulls it toward the tints' own hue, highlight caps the painted
// sun so a noon disc never shows at dusk, and the glow warms the horizon under the day's sun.
// The defaults (white tints, no recolor, no glow, no cap) draw the panorama unchanged, exactly as
// a PanoramaSkyMaterial does. No TIME or POSITION: the radiance map re-renders only on a change.
uniform sampler2D panorama : filter_linear, source_color, hint_default_black;
uniform vec3 top_tint : source_color = vec3(1.0);
uniform vec3 horizon_tint : source_color = vec3(1.0);
uniform float recolor = 0.0;
uniform float highlight = 65504.0;
uniform vec3 glow : source_color = vec3(0.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float energy = 1.0;
// Lifts the sky below about 45 degrees on the side away from the sun (80 degrees or more off its bearing, fading out by 53), in the drawn
// background only: the radiance pass skips it, so the ambient and reflections the ground takes from the sky do not rise with it.
uniform float away_lift = 0.0;

void sky() {
	vec3 c = min(texture(panorama, SKY_COORDS).rgb, vec3(highlight));
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 tint = mix(horizon_tint, top_tint, smoothstep(-0.05, 0.6, EYEDIR.y));
	c = mix(c, vec3(lum), recolor) * tint;
	float toward = max(dot(EYEDIR, normalize(sun_dir)), 0.0);
	float low = 1.0 - smoothstep(0.0, 0.45, EYEDIR.y);
	c += glow * (pow(toward, 4.0) * low + pow(toward, 48.0));
	if (!AT_CUBEMAP_PASS && away_lift > 0.0) {
		vec2 eye_h = normalize(EYEDIR.xz + vec2(1e-5));
		vec2 sun_h = normalize(sun_dir.xz + vec2(1e-5));
		float away = 1.0 - smoothstep(0.17, 0.6, dot(eye_h, sun_h));
		c *= 1.0 + away_lift * away * (1.0 - smoothstep(0.0, 0.8, EYEDIR.y));
	}
	COLOR = c * energy;
}
