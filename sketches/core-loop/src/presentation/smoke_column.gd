extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Impostor := preload("res://src/presentation/landmark_impostor.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")


const RIBBONS := 3
const ROWS := 14
const RISE_M := 330.0
const FOOT_W := 34.0
const TOP_W := 120.0
const LEAN := Vector3(110.0, 0.0, -30.0)
const GLOW_SHARE := 0.16
const SIGHT_M := 150.0
const EDGE_IN_M := 10.0
const DRIFT_S := 30.0
const CARD_SIZE := Vector2(420.0, 120.0)
const CARD_SINK := 0.12
const CARD_COLS := 24
const CARD_HAZE := Color("d8c8dc")
const TERRACOTTA := Color("b8664a")
const FLUME_WATER := Color("4fa9a6")
const TRESTLE := Color("4a3a30")
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

var home := Vector3.ZERO
var radius := 0.0
var view: MeshInstance3D
var card: MeshInstance3D
var card_home := Transform3D.IDENTITY
var card_radius := 0.0


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


static func _step(x: float) -> float:
	return clampf(x * 3.0, -1.0, 1.0)


static func _profile(st: SurfaceTool, w: float, h: float, top: Callable, low: Color, high: Color, z: float) -> void:
	for k in CARD_COLS:
		var t0 := float(k) / CARD_COLS
		var t1 := float(k + 1) / CARD_COLS
		var x0 := (t0 - 0.5) * w
		var x1 := (t1 - 0.5) * w
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
	st.set_color(Color(color.srgb_to_linear(), 1.0))
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


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
				colour = Color(colour.srgb_to_linear(), colour.a)
				quad.append([centre + across * width * (corner.x - 0.5), Vector2(corner.x, t), colour])
			for tri: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				for corner: Array in tri:
					st.set_color(corner[2])
					st.set_uv(corner[1])
					st.add_vertex(corner[0])
	return st.commit()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		show_for(camera.global_position, camera.far)


func show_for(eye: Vector3, far: float) -> Transform3D:
	var at := Impostor.about_eye(Transform3D(Basis.IDENTITY, home), radius, eye, far)
	view.global_transform = at
	if card != null:
		card.global_transform = Impostor.about_eye(card_home, card_radius, eye, far)
	return at
