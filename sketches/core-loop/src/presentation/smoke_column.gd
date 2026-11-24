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
#
# The far card (W46 E1-15, design-v3/WAYFINDING.md section 2.1): where the park's approach row also names a far_card, the
# next stage stands on the horizon as one flat painted card outside the play rect: terracotta walls and one turquoise
# ribbon of flume water on its trestle, so the ride's next place is in view before the Warden falls. It is drawn the way
# the column is (scaled about the eye, unshaded, fog off, one draw), its foot sunk under the map's edge so the rim hides
# its base. Dressing only: no collider, and never reachable.

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
# The far card: its default size, how much of it sinks under the map's edge ground, its columns of wall profile, and
# the haze its colours lean to (the dawn district fog), more on the far ridge than the near wall.
const CARD_SIZE := Vector2(420.0, 120.0)
const CARD_SINK := 0.12
const CARD_COLS := 24
const CARD_HAZE := Color("d8c8dc")
const TERRACOTTA := Color("b8664a")
const FLUME_WATER := Color("4fa9a6")
const TRESTLE := Color("4a3a30")
# The far card is drawn as the column is: at the far plane's depth, first of the see-through pass (it is opaque in
# fact), so everything drawn stands in front of it and it covers only sky. Vertex colours are linear.
const CARD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	POSITION.z = POSITION.w * 0.999999;
#else
	POSITION.z = 0.0;
#endif
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = 1.0;
}
"""
const CARD_PRIORITY := -2
const COLUMN_PRIORITY := -1

# No fog: drawn at a fraction of its distance, the depth fog would wash it to the sky's colour (bowl_approach.gd's
# soot does the same). Its depth is the far plane's: it stands past everything the camera draws, so anything drawn,
# however near its scaled stand-in comes, stands in front of it (the Dam's own wall between the crest and the plume).
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float drift_s = 30.0;
void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	POSITION.z = POSITION.w * 0.999999;
#else
	POSITION.z = 0.0;
#endif
}
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
# The far card (null when the approach names none), its own place on the horizon and its reach.
var card: MeshInstance3D
var card_home := Transform3D.IDENTITY
var card_radius := 0.0


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
	column._build_card(map, height, edge)
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
	material.render_priority = COLUMN_PRIORITY
	view.material_override = material
	add_child(view)
	for v: Vector3 in view.mesh.get_faces():
		radius = maxf(radius, v.length())
	view.transform = Transform3D(Basis.IDENTITY, home)


# The far card for map's approach.far_card ({at, to, size?, yaw_deg?}), or nothing when it names none.
func _build_card(map, height: Callable, edge: float) -> void:
	var park = map.get("park") if map is Object else null
	var approach = park.get("approach", {}) if park is Dictionary else {}
	var row = approach.get("far_card") if approach is Dictionary else null
	if not row is Dictionary:
		return
	var at := Vector2(float(row["at"][0]), float(row["at"][1]))
	var size := CARD_SIZE
	if row.has("size"):
		size = Vector2(float(row["size"][0]), float(row["size"][1]))
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	var foot := float(height.call(Vector2(clampf(at.x, -edge, edge), clampf(at.y, -edge, edge))))
	card = MeshInstance3D.new()
	card.name = "FarCard"
	card.top_level = true
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.mesh = far_card_mesh(size)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = CARD_SHADER
	material.render_priority = CARD_PRIORITY
	card.material_override = material
	add_child(card)
	for v: Vector3 in card.mesh.get_faces():
		card_radius = maxf(card_radius, v.length())
	card_home = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, foot - size.y * CARD_SINK, at.y))
	card.transform = card_home


# The far card's painting in its own plane (x across, y up from its foot at 0, facing +z): a hazed far ridge, the
# terracotta wall with its stepped mesa tops and shaded foot, and the flume, a turquoise ribbon with a pale lip running
# down the wall on dark trestle legs. Vertex colours only.
static func far_card_mesh(size: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := size.x
	var h := size.y
	var ridge := TERRACOTTA.lightened(0.18).lerp(CARD_HAZE, 0.72)
	var wall := TERRACOTTA.lerp(CARD_HAZE, 0.42)
	var shade := TERRACOTTA.darkened(0.3).lerp(CARD_HAZE, 0.38)
	_profile(st, w, h, func(t: float) -> float: return h * (0.86 + 0.08 * sin(t * 7.0 + 1.3) + 0.04 * sin(t * 19.0)), ridge, ridge, -2.0)
	_profile(st, w, h, func(t: float) -> float: return h * (0.62 + 0.1 * _step(sin(t * 5.0 + 0.4)) + 0.05 * _step(sin(t * 13.0))), shade, wall, 0.0)
	var water := FLUME_WATER.lerp(CARD_HAZE, 0.3)
	var lip := Palette.TURQUOISE.lightened(0.15).lerp(CARD_HAZE, 0.3)
	var chute := [Vector2(-0.3, 0.6), Vector2(-0.14, 0.53), Vector2(0.03, 0.48), Vector2(0.17, 0.38), Vector2(0.27, 0.24), Vector2(0.33, 0.14)]
	for i in range(chute.size() - 1):
		var a: Vector2 = chute[i] * Vector2(w, h)
		var b: Vector2 = chute[i + 1] * Vector2(w, h)
		_quad(st, Vector3(a.x, a.y - h * 0.055, 1.0), Vector3(b.x, b.y - h * 0.055, 1.0), Vector3(b.x, b.y, 1.0), Vector3(a.x, a.y, 1.0), water)
		_quad(st, Vector3(a.x, a.y, 1.2), Vector3(b.x, b.y, 1.2), Vector3(b.x, b.y + h * 0.012, 1.2), Vector3(a.x, a.y + h * 0.012, 1.2), lip)
		if i > 0:
			var x := a.x
			_quad(st, Vector3(x - w * 0.004, 0.0, 0.6), Vector3(x + w * 0.004, 0.0, 0.6), Vector3(x + w * 0.004, a.y - h * 0.05, 0.6), Vector3(x - w * 0.004, a.y - h * 0.05, 0.6), TRESTLE)
	return st.commit()


# A squared mesa step: sharpens a sine to flat tops with short ledges.
static func _step(x: float) -> float:
	return clampf(x * 3.0, -1.0, 1.0)


# A band from y 0 up to top(t) across the card (t 0..1 left to right), coloured low at its foot and high at its top.
static func _profile(st: SurfaceTool, w: float, h: float, top: Callable, low: Color, high: Color, z: float) -> void:
	for k in CARD_COLS:
		var t0 := float(k) / CARD_COLS
		var t1 := float(k + 1) / CARD_COLS
		var x0 := (t0 - 0.5) * w
		var x1 := (t1 - 0.5) * w
		# Both ends taper down under the horizon, so the card reads as a range, not a board's square edge.
		var e0 := _taper(t0)
		var e1 := _taper(t1)
		var y0: float = float(top.call(t0)) * e0
		var y1: float = float(top.call(t1)) * e1
		var mid := high.lerp(low, 0.35)
		_quad(st, Vector3(x0, 0.0, z), Vector3(x1, 0.0, z), Vector3(x1, h * 0.3 * e1, z), Vector3(x0, h * 0.3 * e0, z), low)
		_quad(st, Vector3(x0, h * 0.3 * e0, z), Vector3(x1, h * 0.3 * e1, z), Vector3(x1, y1, z), Vector3(x0, y0, z), mid if k % 2 == 0 else high)


static func _taper(t: float) -> float:
	return smoothstep(0.0, 1.0, clampf(minf(t, 1.0 - t) * 4.0, 0.0, 1.0))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	# The shader reads COLOR as linear; the palette is sRGB.
	st.set_color(Color(color.srgb_to_linear(), 1.0))
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


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
	# A parked stage hides its root; nothing to place until the flume shows again.
	if not is_visible_in_tree():
		return
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		show_for(camera.global_position, camera.far)


# Puts the drawn column (and the far card, where there is one) about this eye for a far plane far; returns the
# column's world transform.
func show_for(eye: Vector3, far: float) -> Transform3D:
	var at := Impostor.about_eye(Transform3D(Basis.IDENTITY, home), radius, eye, far)
	view.global_transform = at
	if card != null:
		card.global_transform = Impostor.about_eye(card_home, card_radius, eye, far)
	return at
