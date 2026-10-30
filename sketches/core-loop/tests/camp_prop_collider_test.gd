extends SceneTree
# Camp prop colliders (camp_hub.gd reach_column; clip audit, 30 Oct): a solid recipe prop's box was the bounds of its
# whole first base mesh, so a cottonwood's box spread to its canopy, about 9 m across, and the ball met an invisible wall
# 2 m short of anything drawn; a box round its roots still met the ball 1.9 m from a root between its corners. The
# collider is now a prism whose outline is the convex hull of the mesh within BALL_REACH_M of its foot, at full height.
# (a) planted: a 0.5 m column under a 6 m slab 3 m up gets the column's outline and the whole height;
# (b) a mesh with every vertex in reach (a cabinet) keeps its plain bounds;
# (c) the cottonwood: every trunk vertex within reach is inside the outline, the outline's area is under 0.8 of the
#     reach box's (the old box round the same vertices), and the prism keeps the mesh's full height.
# Evidence limit: shape data only; the felt gap is the clip audit's (tools/clip_audit.py naked).

const CampHub := preload("res://src/world/camp_hub.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("camp_prop_collider_test")


func _initialize() -> void:
	call_deferred("_run")


func _box_mesh(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: AABB in parts:
		var box := BoxMesh.new()
		box.size = part.size
		var faces := box.get_faces()
		for p in faces:
			st.add_vertex(p + part.get_center())
	return st.commit()


func _bounds(points: PackedVector3Array) -> AABB:
	var b := AABB(points[0], Vector3.ZERO)
	for p in points:
		b = b.expand(p)
	return b


func _outline(points: PackedVector3Array) -> PackedVector2Array:
	var flat := PackedVector2Array()
	for p in points:
		flat.append(Vector2(p.x, p.z))
	return Geometry2D.convex_hull(flat)


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size() - 1:
		a += poly[k].cross(poly[k + 1])
	return absf(a) * 0.5


func _run() -> void:
	var column := _box_mesh([AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 3.0, 0.5)), AABB(Vector3(-3.0, 3.0, -3.0), Vector3(6.0, 0.5, 6.0))])
	var b := _bounds(CampHub.reach_column(column, Transform3D.IDENTITY))
	_t.check("(a) planted column: outline is the column's", b.size.x < 0.51 and b.size.z < 0.51, str(b))
	_t.near("(a) planted column: full height", b.size.y, 3.5, 0.001)
	var cabinet := _box_mesh([AABB(Vector3(-1.0, 0.0, -0.5), Vector3(2.0, 1.8, 1.0))])
	var c := _bounds(CampHub.reach_column(cabinet, Transform3D.IDENTITY))
	_t.check("(b) a cabinet in reach keeps its bounds", c.is_equal_approx(cabinet.get_aabb()), str(c))
	var holder := Node3D.new()
	root.add_child(holder)
	var views := RecipeProps.base("cottonwood", holder, Transform3D.IDENTITY)
	_t.check("(c) the cottonwood has base views", not views.is_empty())
	if not views.is_empty():
		var first := views[0] as MeshInstance3D
		var whole: AABB = first.transform * first.mesh.get_aabb()
		var points := CampHub.reach_column(first.mesh, first.transform)
		var outline := _outline(points)
		var low := 0
		var out := 0
		var reach := AABB()
		for p in first.mesh.get_faces():
			var w: Vector3 = first.transform * p
			if w.y <= whole.position.y + CampHub.BALL_REACH_M:
				reach = AABB(w, Vector3.ZERO) if low == 0 else reach.expand(w)
				low += 1
				var q := Vector2(w.x, w.z)
				var inside := Geometry2D.is_point_in_polygon(q, outline)
				for k in outline.size() - 1:
					inside = inside or Geometry2D.get_closest_point_to_segment(q, outline[k], outline[k + 1]).distance_to(q) < 0.001
				out += 0 if inside else 1
		_t.check("(c) every trunk vertex in reach is inside the outline (%d)" % low, low > 0 and out == 0, "%d outside" % out)
		var box_area := reach.size.x * reach.size.z
		_t.check("(c) the outline is under 0.8 of the reach box: %.1f vs %.1f m2" % [_area(outline), box_area], _area(outline) < 0.8 * box_area)
		_t.near("(c) the prism keeps the full height", _bounds(points).size.y, whole.size.y, 0.001)
	holder.free()
	quit(_t.verdict())
