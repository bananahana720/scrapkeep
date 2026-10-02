shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_prepass_alpha;
#include "res://assets/shaders/target_protection.gdshaderinc"
// The clutter kit's paint: the slot's albedo times the mesh's vertex colour, fully rough.
// Actors and telegraphs hide it through the shared screen-space protection, like all
// dressing. A contact shade darkens the foot of each piece so it sits on the ground it
// casts no shadow on.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float contact_height = 0.12;
uniform float contact_floor = 0.7;
varying float rise;
void vertex() {
	rise = VERTEX.y;
}
void fragment() {
	float contact = mix(contact_floor, 1.0, smoothstep(0.0, contact_height, rise));
	ALBEDO = albedo.rgb * COLOR.rgb * contact;
	ROUGHNESS = 0.95;
	ALPHA = dressing_protected(SCREEN_UV) ? 0.0 : 1.0;
}
