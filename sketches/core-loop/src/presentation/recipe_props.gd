extends RefCounted

const MaterialSlots := preload("res://src/presentation/material_slots.gd")

const META_FADE := "recipe_fade"
const ROWS := {
	"ore_cart": {"base": ["res://assets/models/ore_cart_body.glb", "res://assets/models/ore_cart_wheel.glb"], "shells": [["res://assets/models/ore_cart_detail1.glb", 40.0, 4.0], ["res://assets/models/ore_cart_detail2.glb", 15.0, 3.0]]},
	"lantern_beacon": {"base": ["res://assets/models/lantern_beacon_frame.glb", "res://assets/models/lantern_beacon_lens.glb"], "shells": [["res://assets/models/lantern_beacon_detail1.glb", 60.0, 8.0], ["res://assets/models/lantern_beacon_detail2.glb", 35.0, 5.0]]},
	"valve_wheel": {"base": ["res://assets/models/valve_wheel_wheel.glb", "res://assets/models/valve_wheel_band.glb"], "shells": [["res://assets/models/valve_wheel_detail1.glb", 32.0, 4.0], ["res://assets/models/valve_wheel_detail2.glb", 18.0, 3.0]]},
	"valve_wheel_mount": {"base": ["res://assets/models/valve_wheel_mount.glb"], "shells": [["res://assets/models/valve_wheel_detail1m.glb", 32.0, 4.0]]},
	"barge": {"base": ["res://assets/models/barge.glb", "res://assets/models/barge_fenders.glb"], "shells": [["res://assets/models/barge_detail1.glb", 60.0, 8.0], ["res://assets/models/barge_detail2.glb", 35.0, 5.0]]},
	"kicker_wedge": {"base": ["res://assets/models/kicker_wedge.glb", "res://assets/models/kicker_wedge_stripes.glb"], "shells": [["res://assets/models/kicker_wedge_detail1.glb", 45.0, 10.0], ["res://assets/models/kicker_wedge_detail2.glb", 24.0, 6.0]]},
	"moss_jukebox": {"base": ["res://assets/models/moss_jukebox_cabinet.glb", "res://assets/models/moss_jukebox_trim.glb", "res://assets/models/moss_jukebox_feet.glb"], "shells": [["res://assets/models/moss_jukebox_detail1.glb", 30.0, 8.0], ["res://assets/models/moss_jukebox_detail2.glb", 14.0, 3.0]]},
	"moss_hover_barge": {"base": ["res://assets/models/moss_hover_barge.glb", "res://assets/models/moss_hover_barge_thrusters.glb"], "shells": [["res://assets/models/moss_hover_barge_detail1.glb", 130.0, 15.0], ["res://assets/models/moss_hover_barge_detail2.glb", 95.0, 10.0]]},
	"fabricator_hoop": {"base": ["res://assets/models/fabricator_hoop.glb"], "shells": [["res://assets/models/fabricator_hoop_detail1.glb", 45.0, 6.0], ["res://assets/models/fabricator_hoop_detail2.glb", 25.0, 4.0]]},
	"cottonwood": {"base": ["res://assets/models/cottonwood_trunk.glb", "res://assets/models/cottonwood_crown.glb"], "shells": [["res://assets/models/cottonwood_detail1.glb", 50.0, 10.0], ["res://assets/models/cottonwood_detail2.glb", 30.0, 4.0]]},
}


static func slot_material(slot_name: String) -> Material:
	if not is_slot_role(slot_name):
		push_error("recipe_props: '%s' is not a material slot role" % slot_name)
		return null
	return load(String(MaterialSlots.row(slot_name)["path"])) as Material


static func is_slot_role(slot_name: String) -> bool:
	return MaterialSlots.row(slot_name).get("kind", "") == "resource"


static func shell_rows(key: String) -> Array:
	return ROWS.get(key, {}).get("shells", [])


static func base_paths(key: String) -> Array:
	return ROWS.get(key, {}).get("base", [])


static func base(key: String, parent: Node3D, xform: Transform3D) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for path: String in base_paths(key):
		for view in _place(path, parent, xform, key + "_"):
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			out.append(view)
	return out


static func shells(key: String, parent: Node3D, xform: Transform3D) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for shell: Array in shell_rows(key):
		for view in _place(shell[0], parent, xform, ""):
			view.visibility_range_end = shell[1]
			view.visibility_range_end_margin = shell[2]
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.set_meta(META_FADE, true)
			out.append(view)
	return out


static func steel_views(views: Array[GeometryInstance3D]) -> Array[GeometryInstance3D]:
	var steel := slot_material("steel")
	var out: Array[GeometryInstance3D] = []
	for view in views:
		var mesh := (view as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			if (view as MeshInstance3D).get_surface_override_material(i) == steel:
				out.append(view)
				break
	return out


static func _place(path: String, parent: Node3D, xform: Transform3D, prefix: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		push_warning("recipe_props: %s missing, it stays out" % path)
		return out
	var scene := packed.instantiate()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null:
			continue
		var view := MeshInstance3D.new()
		view.name = prefix + source.name
		view.mesh = source.mesh
		for i in source.mesh.get_surface_count():
			var original := source.mesh.surface_get_material(i)
			var material := slot_material(String(original.resource_name) if original != null else "")
			if material != null:
				view.set_surface_override_material(i, material)
		parent.add_child(view)
		view.transform = xform * _relative(source, scene)
		out.append(view)
	scene.free()
	return out


static var _pieces := {}


static func piece(key: String, build: Callable) -> ArrayMesh:
	var mesh: ArrayMesh = _pieces.get(key)
	if mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		build.call(st)
		mesh = st.commit()
		mesh.resource_name = key
		_pieces[key] = mesh
	return mesh


static func add_hull(st: SurfaceTool, planes: Array[Plane], color := Color.WHITE, xf := Transform3D.IDENTITY) -> void:
	var points := Geometry3D.compute_convex_mesh_points(planes)
	for plane in planes:
		var on: Array[Vector3] = []
		for p in points:
			if absf(plane.distance_to(p)) < 0.0005 and not on.any(func(q: Vector3): return q.is_equal_approx(p)):
				on.append(p)
		if on.size() < 3:
			continue
		var centre := Vector3.ZERO
		for p in on:
			centre += p
		centre /= on.size()
		var u := (on[0] - centre).normalized()
		var v := plane.normal.cross(u)
		on.sort_custom(func(a: Vector3, b: Vector3): return atan2((a - centre).dot(v), (a - centre).dot(u)) > atan2((b - centre).dot(v), (b - centre).dot(u)))
		var normal := (xf.basis * plane.normal).normalized()
		for i in range(1, on.size() - 1):
			for p in [on[0], on[i], on[i + 1]]:
				st.set_color(color)
				st.set_normal(normal)
				st.add_vertex(xf * p)


static func bevel_box(low: Vector3, high: Vector3, bevel: float, taper := 0.0) -> Array[Plane]:
	var c := (low + high) * 0.5
	var h := (high - low) * 0.5
	var planes: Array[Plane] = [Plane(Vector3.UP, high.y), Plane(Vector3.DOWN, -low.y)]
	var rise := high.y - low.y
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var half: float = h.x if side.x != 0.0 else h.z
		var lean: Vector3 = Vector3(side.x, taper / rise, side.z).normalized() if taper > 0.0 else side
		var foot: Vector3 = Vector3(c.x, low.y, c.z) + side * half
		planes.append(Plane(lean, foot))
	if bevel <= 0.0:
		return planes
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var n := Vector3(sx, 2.0 * taper / rise, sz).normalized()
			planes.append(Plane(n, Vector3(c.x, low.y, c.z) + Vector3(sx * (h.x - bevel), 0.0, sz * h.z)))
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var half: float = h.x if side.x != 0.0 else h.z
		var inset := half - taper
		for up: float in [1.0, -1.0]:
			var y: float = high.y if up > 0.0 else low.y
			var reach: float = inset if up > 0.0 else half
			var n: Vector3 = (side + Vector3.UP * up).normalized()
			planes.append(Plane(n, Vector3(c.x, y, c.z) + side * (reach - bevel)))
	return planes


static func prism(at: Vector3, sides: int, r0: float, r1: float, y0: float, y1: float, bevel := 0.0) -> Array[Plane]:
	var planes: Array[Plane] = [Plane(Vector3.UP, y1), Plane(Vector3.DOWN, -y0)]
	var rise := y1 - y0
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var out := Vector3(cos(a), 0.0, sin(a))
		var face := out * cos(PI / sides)
		var n := Vector3(out.x * rise, (r0 - r1) * cos(PI / sides), out.z * rise).normalized()
		planes.append(Plane(n, Vector3(at.x, y0, at.z) + face * r0))
		if bevel > 0.0:
			var nb := (out + Vector3.UP).normalized()
			planes.append(Plane(nb, Vector3(at.x, y1, at.z) + face * (r1 - bevel)))
	return planes


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
