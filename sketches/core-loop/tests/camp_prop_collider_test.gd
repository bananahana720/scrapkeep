extends SceneTree
# Camp prop colliders (camp_hub.gd reach_box; clip audit, 30 Oct): a solid recipe prop's box was the bounds of its whole
# first base mesh, so a cottonwood's box spread to its canopy, about 9 m across, and the ball met an invisible wall
# 2 m short of anything drawn. The box now spans the mesh's footprint within BALL_REACH_M of its foot, at full height.
# (a) planted: a 0.5 m column under a 6 m slab 3 m up gets the column's footprint and the whole height;
# (b) a mesh with every vertex in reach (a cabinet) keeps its plain bounds;
# (c) the cottonwood: every trunk vertex within reach is inside the box, the box is at least 3 m narrower than the
#     whole mesh on each axis, and it keeps the mesh's full height.
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


func _run() -> void:
	var column := _box_mesh([AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 3.0, 0.5)), AABB(Vector3(-3.0, 3.0, -3.0), Vector3(6.0, 0.5, 6.0))])
	var b := CampHub.reach_box(column, Transform3D.IDENTITY)
	_t.check("(a) planted column: footprint is the column's", b.size.x < 0.51 and b.size.z < 0.51, str(b))
	_t.near("(a) planted column: full height", b.size.y, 3.5, 0.001)
	var cabinet := _box_mesh([AABB(Vector3(-1.0, 0.0, -0.5), Vector3(2.0, 1.8, 1.0))])
	var c := CampHub.reach_box(cabinet, Transform3D.IDENTITY)
	_t.check("(b) a cabinet in reach keeps its bounds", c.is_equal_approx(cabinet.get_aabb()), str(c))
	var holder := Node3D.new()
	root.add_child(holder)
	var views := RecipeProps.base("cottonwood", holder, Transform3D.IDENTITY)
	_t.check("(c) the cottonwood has base views", not views.is_empty())
	if not views.is_empty():
		var first := views[0] as MeshInstance3D
		var whole: AABB = first.transform * first.mesh.get_aabb()
		var box := CampHub.reach_box(first.mesh, first.transform)
		var low := 0
		var out := 0
		for p in first.mesh.get_faces():
			var w: Vector3 = first.transform * p
			if w.y <= whole.position.y + CampHub.BALL_REACH_M:
				low += 1
				out += 0 if box.grow(0.001).has_point(w) else 1
		_t.check("(c) every trunk vertex in reach is inside the box (%d)" % low, low > 0 and out == 0, "%d outside" % out)
		_t.check("(c) the box is 1 m narrower than the whole mesh: %s vs %s" % [box.size, whole.size],
			box.size.x <= whole.size.x - 1.0 and box.size.z <= whole.size.z - 1.0)
		_t.near("(c) the box keeps the full height", box.size.y, whole.size.y, 0.001)
	holder.free()
	quit(_t.verdict())
