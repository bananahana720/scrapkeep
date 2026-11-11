shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, depth_draw_opaque;

// One layer of the ancient beam: flat uranium colour at layer_alpha, its silhouette edge softened by edge (0 = hard as
// before, 1 = fully soft) where the surface turns side-on to the eye. landmark_beam.gd sets both per frame.
uniform vec4 tint : source_color = vec4(0.6, 1.0, 0.2, 1.0);
uniform float layer_alpha = 1.0;
uniform float edge = 0.0;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = tint.rgb;
	ALPHA = layer_alpha * mix(1.0, smoothstep(0.0, 0.7, facing), edge);
}
