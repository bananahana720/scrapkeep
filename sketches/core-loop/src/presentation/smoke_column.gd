extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Impostor := preload("res://src/presentation/landmark_impostor.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

# Brindle's furnace smoke on the flume's east horizon (transitions-audit T6, rulings cv and ct): the world plays as one
# ride, so the next stage's sign stands in view before the launch, where the launch rail aims (the park file's
# approach.smoke). It is a stand-in, not a simulation: three crossed ribbons, one ArrayMesh, one unshaded material,
# amber at the foot where the furnace glows and charcoal smoke leaning away above it. It is about 1.4 km from the
# drop-in and past the chase camera's 700 m far plane from almost all of the flume, so each drawn frame it is scaled
# about the eye (landmark_impostor.gd's about_eye): it covers the same pixels and stays inside the far plane. Nothing
# collides, nothing is marked, and bowl_approach.gd's furnace (behind --approach=on) is a separate thing.

const RIBBONS := 3
const ROWS := 14
const RISE_M := 330.0
const FOOT_W := 34.0
const TOP_W := 120.0
# The smoke leans east and a little north as it climbs, away from the flume.
const LEAN := Vector3(110.0, 0.0, -30.0)
# How much of the column is the furnace's glow, from the foot.
const GLOW_SHARE := 0.16
# The point a sight ray aims at: the column's middle, the part that reads as smoke over the horizon.
const SIGHT_M := 150.0
# The foot stands level with the map's ground nearest it: the furnace stands off the 1.6 km square.
const EDGE_IN_M := 10.0
const DRIFT_S := 30.0

# No fog: drawn at a fraction of its distance, the depth fog would wash it to the sky's colour (bowl_approach.gd's
# soot does the same).
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float drift_s = 30.0;
void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	float puff = 0.82 + 0.18 * sin(UV.y * 19.0 - TIME * 6.2831 / drift_s + UV.x * 5.0);
	ALBEDO = COLOR.rgb * (0.9 + 0.1 * puff);
	ALPHA = COLOR.a * smoothstep(0.0, 0.55, edge) * puff;
}
"""

# The column's foot on the ground (the stand-in is drawn about the eye from here).
var home := Vector3.ZERO
# The farthest vertex from the foot, for the far-plane reach.
var radius := 0.0
var view: MeshInstance3D


# The column under parent for map (a ParkMap), or null when the map names no approach. height is the map's ground at
# (x, z) as a Vector2 (park_sites.gd height). Visual only.
static func place(parent: Node3D, map, height: Callable) -> Node3D:
	if not "approach" in map or map.approach.is_empty() or not map.approach.has("smoke"):
		return null
	var smoke: Vector2 = map.approach["smoke"]
	var edge := ParkTerrain.HALF - EDGE_IN_M
	var column := new()
	column.name = "SmokeColumn"
	column.home = Vector3(smoke.x, float(height.call(Vector2(clampf(smoke.x, -edge, edge), clampf(smoke.y, -edge, edge)))), smoke.y)
	column._build()
	parent.add_child(column)
	return column


# Where a sight ray aims: the column's middle above its foot.
func sight_point() -> Vector3:
	return home + Vector3.UP * SIGHT_M + LEAN * pow(SIGHT_M / RISE_M, 2.0)


func _build() -> void:
	view = MeshInstance3D.new()
	view.name = "Column"
	view.top_level = true
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.mesh = column_mesh()
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADER
	material.set_shader_parameter("drift_s", DRIFT_S)
	view.material_override = material
	add_child(view)
	for v: Vector3 in view.mesh.get_faces():
		radius = maxf(radius, v.length())
	view.transform = Transform3D(Basis.IDENTITY, home)


# The ribbons about the foot: each a strip of ROWS quads that widens and leans as it climbs, amber at the foot.
static func column_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := Palette.AMBER.lightened(0.15)
	var smoke := Palette.CHARCOAL.lightened(0.28)
	for r in RIBBONS:
		var yaw := PI * float(r) / RIBBONS
		var across := Vector3(cos(yaw), 0.0, sin(yaw))
		for k in ROWS:
			var quad := []
			for corner: Vector2 in [Vector2(0, k), Vector2(1, k), Vector2(1, k + 1), Vector2(0, k + 1)]:
				var t: float = corner.y / ROWS
				var width := lerpf(FOOT_W, TOP_W, pow(t, 0.8))
				var centre := Vector3.UP * RISE_M * t + LEAN * t * t
				var colour: Color = glow.lerp(smoke, smoothstep(GLOW_SHARE * 0.5, GLOW_SHARE * 1.6, t))
				colour.a = lerpf(0.95, 0.8, t) * (1.0 - smoothstep(0.7, 1.0, t))
				# The shader reads COLOR as linear; the palette is sRGB.
				colour = Color(colour.srgb_to_linear(), colour.a)
				quad.append([centre + across * width * (corner.x - 0.5), Vector2(corner.x, t), colour])
			for tri: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				for corner: Array in tri:
					st.set_color(corner[2])
					st.set_uv(corner[1])
					st.add_vertex(corner[0])
	return st.commit()


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		show_for(camera.global_position, camera.far)


# Puts the drawn column about this eye for a far plane far; returns its world transform.
func show_for(eye: Vector3, far: float) -> Transform3D:
	var at := Impostor.about_eye(Transform3D(Basis.IDENTITY, home), radius, eye, far)
	view.global_transform = at
	return at
