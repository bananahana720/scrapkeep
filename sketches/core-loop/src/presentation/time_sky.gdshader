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

void sky() {
	vec3 c = min(texture(panorama, SKY_COORDS).rgb, vec3(highlight));
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 tint = mix(horizon_tint, top_tint, smoothstep(-0.05, 0.6, EYEDIR.y));
	c = mix(c, vec3(lum), recolor) * tint;
	float toward = max(dot(EYEDIR, normalize(sun_dir)), 0.0);
	float low = 1.0 - smoothstep(0.0, 0.45, EYEDIR.y);
	c += glow * (pow(toward, 4.0) * low + pow(toward, 48.0));
	COLOR = c * energy;
}
