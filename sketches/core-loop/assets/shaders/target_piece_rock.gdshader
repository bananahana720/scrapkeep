shader_type spatial;
render_mode diffuse_burley, cull_disabled;
#include "res://assets/shaders/target_surface.gdshaderinc"
#include "res://assets/shaders/target_bed4.gdshaderinc"
// Unit LKP2: the sculpted sandstone pieces coloured by the ground's own beds. Colour comes from
// the world position through bed4_eval (the include `--ground=4` uses), so a cliff's beds continue
// the wall beside it. Steep faces take the bed colours; faces within about 55 degrees of straight
// up take the ground's warm flat colour. The piece's own maps keep only the normal map and the
// ambient-occlusion and cavity terms, multiplied in; the baked colour beds are not read.
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D tex_ao : filter_linear_mipmap;
uniform sampler2D tex_cavity : filter_linear_mipmap;
uniform float normal_depth = 1.0;
uniform float ao_dark = 0.65;
uniform float cavity_amp = 1.0;
uniform float up_lo = 0.50;
uniform float up_hi = 0.66;
// A hollow piece (the alcove): its vault is dark. hollow = (half width, front z, depth strength, top y),
// in the piece's own units; strength 0 turns it off. Anything behind the front lip, under the vault top.
uniform vec4 hollow = vec4(0.0);
uniform float hollow_floor = 0.3;
varying vec3 local_at;

void vertex() {
	surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_at = VERTEX;
}

void fragment() {
	vec3 p = surface_at;
	vec3 n = normalize(surface_normal);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float edge_fade = 1.0 - smoothstep(0.03, 0.14, footprint);
	float varn_w = 1.0 - smoothstep(0.30, 0.55, n.y);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	Bed4 bed = bed4_eval(p, n, length(p - cam), edge_fade, varn_w);
	// Up-facing: the ground's flat colour, so ledges catch sand.
	float flat_w = smoothstep(up_lo, up_hi, n.y);
	vec3 col = mix(bed.wall, bed.flat_c, flat_w);
	// The piece's own occlusion and cavity. The atlas background is black; read it as no occlusion.
	float ao = texture(tex_ao, UV).r;
	ao = mix(1.0, ao, step(0.03, ao));
	float cav = texture(tex_cavity, UV).r;
	float cav_k = clamp(1.0 + (cav - 0.5) * 2.0 * cavity_amp, 0.55, 1.2);
	col *= mix(1.0, ao, ao_dark) * cav_k;
	if (hollow.z > 0.0) {
		vec3 q = local_at;
		float in_x = 1.0 - smoothstep(hollow.x * 0.8, hollow.x, abs(q.x));
		float in_y = 1.0 - smoothstep(hollow.w * 0.8, hollow.w, q.y);
		float behind = smoothstep(hollow.y + 0.8, hollow.y + 2.0, q.z);
		float inner = 1.0;
		float deep = 0.6 + 0.4 * smoothstep(hollow.y, hollow.y * -1.0, q.z);
		float dark = in_x * in_y * behind * inner * deep;
		col *= mix(1.0, hollow_floor, dark * hollow.z);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	AO = ao;
	NORMAL_MAP = texture(tex_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
