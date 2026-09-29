extends SceneTree

const Game := preload("res://src/game.gd")

# Moss's sandstone shelter (look pass 4 geometry): a carried, visual-only stone shell.
# Every vertex stays inside the cabin collider's volume below the cap, or inside the cap
# envelope (X -19.5..-11.5, Z -6.3..6.3, Y 7.35..9.2) above it; none sits at ground level
# outside the cabin footprint, so LANDING, PAD, MOSS, the bell, jukebox, practice yard and
# banked lap get no new geometry. One mesh, one surface, one shared sandstone material,
# no collision, and it rides the barge's transforms. Round 2 adds the cap's front lip, measured
# as upper minus lower surface at the same X/Z by vertical rays, the cliff rock material, and
# `--mutate=thin-lip|outside|entry` self-tests that must each make the run fail.

const CAP_LOW := 7.35
const CAP_HIGH := 9.2
const CAP_X := Vector2(-19.5, -11.5)
const CAP_Z := 6.3
const EPS := 0.002
const LIP_MIN := 1.10
const LIP_TARGET := Vector2(1.30, 1.60)
const FRONT_X := -13.0

var _game
var _ticks := 0
var _failures := 0
var _mutate := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mutate="):
			_mutate = arg.trim_prefix("--mutate=")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
		printerr("moss_shelter_test FAIL: %s %s" % [label, detail])


func _physics_process(_delta: float) -> bool:
	_ticks += 1
	if _ticks < 10:
		return false
	var bay: Node = _game.find_child("MossBay", true, false)
	_check("bay exists", bay != null)
	if bay != null:
		_run(bay)
	print("moss_shelter_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


func _run(bay: Node) -> void:
	var barge: Node3D = bay.find_child("Barge", true, false)
	var cabin: Node3D = bay.find_child("MossCabin", true, false)
	var shelter: Node3D = barge.get_node_or_null("HeroShelter")
	_check("shelter attached to Barge", shelter != null)
	if shelter == null:
		return
	# One mesh, one surface, one shared material, no collision.
	var meshes := shelter.find_children("*", "MeshInstance3D", true, false)
	_check("one mesh instance", meshes.size() == 1, str(meshes.size()))
	_check("no collision under shelter", shelter.find_children("*", "CollisionObject3D", true, false).is_empty())
	var mi: MeshInstance3D = meshes[0]
	_check("one surface", mi.mesh.get_surface_count() == 1)
	var stone := mi.material_override as ShaderMaterial
	_check("cliff rock material", stone != null and stone.shader.resource_path.ends_with("sandstone.gdshader") \
			and stone.get_shader_parameter("cliff_only") == true and stone.get_shader_parameter("local_pattern") == true)
	_check("mesh sits at the barge origin", (barge.global_transform.affine_inverse() * mi.global_transform).is_equal_approx(Transform3D.IDENTITY))
	_check("cast shadows unchanged (default)", mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	# Envelope, from the live cabin collider (Barge space).
	var box: BoxShape3D = (cabin.find_child("*", true, false) as CollisionShape3D).shape
	var lo: Vector3 = cabin.position - box.size * 0.5
	var hi: Vector3 = cabin.position + box.size * 0.5
	_check("collider is the specced 5x6x8", box.size.is_equal_approx(Vector3(5, 6, 8)))
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var to_barge: Transform3D = barge.global_transform.affine_inverse() * mi.global_transform
	verts = _mutated(verts)
	var bad := 0
	var entry := 0
	var above := 0
	var top := -INF
	for v in verts:
		var g: Vector3 = to_barge * v
		top = maxf(top, g.y)
		if g.y < CAP_LOW - EPS:
			if g.x < lo.x - EPS or g.x > hi.x + EPS or g.z < lo.z - EPS or g.z > hi.z + EPS or g.y < lo.y - EPS:
				bad += 1
		else:
			above += 1
			if g.x < CAP_X.x - EPS or g.x > CAP_X.y + EPS or absf(g.z) > CAP_Z + EPS or g.y > CAP_HIGH + EPS:
				bad += 1
		# Entry path: nothing ahead of the cabin front below the cap, at any Z.
		if g.y < CAP_LOW - EPS and g.x > hi.x + EPS:
			entry += 1
	_check("stone vertices leave the envelope", bad == 0, str(bad))
	_check("stone on the entry path", entry == 0, str(entry))
	_check("cap exists and crests at or under 9.2", above > 40 and top <= CAP_HIGH + EPS and top > 8.9, "%s %s" % [above, top])
	_check("vertex budget", verts.size() <= 2400, str(verts.size()))
	_check("triangle budget", (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 <= 1600)
	_check_lip(verts, arrays[Mesh.ARRAY_INDEX])
	# LANDING (4,0), PAD (14,0) and MOSS (-13,0) all lie ahead of the cabin front (X -14.5), so the
	# entry check above is also their clearance check.
	# Rides the barge: move it and the stone follows exactly.
	var before: Vector3 = mi.global_position
	var moved := barge.position
	barge.position += Vector3(3.5, 1.25, -2.0)
	_check("rides the barge", mi.global_position.is_equal_approx(before + Vector3(3.5, 1.25, -2.0)))
	barge.position = moved
	# The workshop dressing survives and is a separate sibling; stone never follows the shutter.
	_check("workshop sibling kept", barge.has_node("HeroWorkshop"))


func _mutated(verts: PackedVector3Array) -> PackedVector3Array:
	var out := verts.duplicate()
	for i in out.size():
		var v := out[i]
		match _mutate:
			"thin-lip":
				if v.y > CAP_LOW + 0.5:
					v.y = CAP_LOW + (v.y - CAP_LOW) * 0.7
			"outside":
				if v.y > CAP_LOW and v.x > CAP_X.y - 0.5:
					v.x += 0.3
			"entry":
				if v.y < 1.0 and v.x < -14.6:
					v.x = -13.5
		out[i] = v
	return out


## Vertical rays through the cap triangles (Barge space): upper minus lower surface at the same X/Z.
func _check_lip(verts: PackedVector3Array, indices: PackedInt32Array) -> void:
	var tris: Array = []
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		if minf(a.y, minf(b.y, c.y)) >= CAP_LOW - EPS:
			tris.append([a, b, c])
	var columns: Array = []
	var z := -6.2
	while z <= 6.2 + 0.001:
		var edge := INF
		var x := -11.3
		while x > CAP_X.x:
			if not _hits(tris, x, z).is_empty():
				edge = x
				break
			x -= 0.02
		if edge != INF and edge > FRONT_X:
			var ys := _hits(tris, edge - 0.15, z)
			if not ys.is_empty():
				columns.append([z, ys.max() - ys.min()])
		z += 0.1
	_check("front lip has columns", columns.size() >= 60, str(columns.size()))
	if columns.is_empty():
		return
	var z_lo: float = columns[0][0]
	var z_hi: float = columns[-1][0]
	var inside := 0
	var thin := 0
	var least := INF
	for col in columns:
		var span: float = col[1]
		least = minf(least, span)
		if span >= LIP_TARGET.x - 1e-4 and span <= LIP_TARGET.y + 1e-4:
			inside += 1
		var corner: bool = col[0] < z_lo + 0.3 or col[0] > z_hi - 0.3
		if span < LIP_MIN and not corner:
			thin += 1
	print("moss_shelter_test: lip columns %d, in 1.30..1.60 %d%%, thinnest %.3f, thin outside corners %d" \
			% [columns.size(), int(100.0 * inside / columns.size()), least, thin])
	_check("lip 1.30..1.60 m across 70% of the front", inside >= 0.7 * columns.size(), "%d of %d" % [inside, columns.size()])
	_check("lip at least 1.10 m elsewhere", thin == 0, str(thin))


func _hits(tris: Array, x: float, z: float) -> Array:
	var ys := []
	for tri in tris:
		var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 30.0, z), Vector3.DOWN, tri[0], tri[1], tri[2])
		if hit != null:
			ys.append(hit.y)
	return ys
