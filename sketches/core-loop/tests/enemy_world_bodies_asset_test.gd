extends SceneTree
# World 2 and 3 bodies (WORLD-ROSTERS.md "Who builds what", Bodies): pit jaw, prop crew,
# gap net (strung, and the mid-gap curtain cut) and ballast heavy. Asset only: their combat scripts land from the roster threads, so
# this checks the imported files the wiring will read. Enemy budget, opaque vertex-colour
# surfaces with no baked glow, unit-scale nodes, the named meshes and sockets each recipe
# promises, the floor, and the one moving part each behaviour poses.

const T := preload("res://tests/support/t.gd")
const PIT_JAW := "res://assets/models/world_two/enemy_pit_jaw.glb"
const PROP_CREW := "res://assets/models/world_two/enemy_prop_crew.glb"
const GAP_NET := "res://assets/models/world_three/enemy_gap_net.glb"
const GAP_NET_CURTAIN := "res://assets/models/world_three/enemy_gap_net_curtain.glb"
const BALLAST := "res://assets/models/world_three/enemy_ballast_heavy.glb"
const FLOOR := -1.1

var t := T.new("enemy_world_bodies_asset_test")


func _initialize() -> void:
	_run.call_deferred()


func _load(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	t.check(path.get_file() + " loads", packed != null)
	if packed == null:
		return null
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	return scene


# Vertices in the scene root's space for one named mesh.
func _points(scene: Node3D, name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mi := scene.find_child(name, true, false) as MeshInstance3D
	if mi == null:
		return out
	var xf := scene.global_transform.affine_inverse() * mi.global_transform
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


func _all_points(scene: Node3D, names: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for name in names:
		out.append_array(_points(scene, name))
	return out


func _budget(label: String, scene: Node3D, slots: Array) -> void:
	var tris := 0
	var verts := 0
	var surfaces := 0
	var seen := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			surfaces += 1
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			t.check(label + " opaque surface", mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			t.check(label + " no baked glow", mat != null and not mat.emission_enabled)
			t.check(label + " vertex colours", arrays[Mesh.ARRAY_COLOR] != null)
			if mat != null:
				seen.append(mat.resource_name)
	print("%s: %d V / %d T / %d D" % [label, verts, tris, surfaces])
	t.check(label + " enemy budget", verts <= 2100 and tris <= 1100 and surfaces == 3, "%d V %d T %d D" % [verts, tris, surfaces])
	for slot in slots:
		t.check(label + " slot " + slot, slot in seen)


func _named(label: String, scene: Node3D, names: Array) -> void:
	for name in names:
		t.check(label + " has " + name, scene.find_child(name, true, false) != null)
	for node: Node3D in scene.find_children("*", "Node3D", true, false):
		t.check(label + " unit scale " + node.name, node.scale.is_equal_approx(Vector3.ONE))


func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func _socket(scene: Node3D, name: String) -> Vector3:
	var node := scene.find_child(name, true, false) as Node3D
	return scene.global_transform.affine_inverse() * node.global_position if node != null else Vector3.INF


func _pit_jaw() -> void:
	var scene := _load(PIT_JAW)
	if scene == null:
		return
	_budget("pit jaw", scene, ["fleet_paint", "working_tool"])
	_named("pit jaw", scene, ["PitJawFrame", "PitJawA", "PitJawB", "press_plate", "catch_centre", "crew_head", "trip_lever"])
	var all := _all_points(scene, ["PitJawFrame", "PitJawA", "PitJawB"])
	t.near("pit jaw floor", _bounds(all).position.y, FLOOR, 0.01)
	# Open, the jaws lie flush: teeth and all within 0.6 m of the floor, an oval 2.6 by 4.1 m
	# (4.3 m with the latch tabs at the crowns).
	var jaws := _all_points(scene, ["PitJawA", "PitJawB"])
	var open := _bounds(jaws)
	t.check("pit jaw lies flush", open.end.y <= FLOOR + 0.6, str(open))
	t.check("pit jaw oval", absf(open.size.x - 2.6) < 0.05 and absf(open.size.z - 4.28) < 0.05, str(open.size))
	t.check("pit jaw A on +Z, B on -Z", _bounds(_points(scene, "PitJawA")).position.z > -0.01
		and _bounds(_points(scene, "PitJawB")).end.z < 0.01)
	# Shut (A -90, B +90 about X), they stand up round a ball held at catch_centre.
	var a := scene.find_child("PitJawA", true, false) as Node3D
	var b := scene.find_child("PitJawB", true, false) as Node3D
	a.rotation.x = -PI / 2.0
	b.rotation.x = PI / 2.0
	var shut := _bounds(_all_points(scene, ["PitJawA", "PitJawB"]))
	var held := _socket(scene, "catch_centre")
	t.check("pit jaw shuts upright round the ball", shut.end.y > held.y + 0.9 and shut.size.z < 1.0, str(shut))
	t.near("held ball sits on the floor", held.y, FLOOR + 1.0, 0.01)
	t.check("press plate in the middle", Vector2(_socket(scene, "press_plate").x, _socket(scene, "press_plate").z).length() < 0.01)
	scene.queue_free()


func _prop_crew() -> void:
	var scene := _load(PROP_CREW)
	if scene == null:
		return
	_budget("prop crew", scene, ["fleet_paint", "working_tool", "part_state"])
	_named("prop crew", scene, ["PropCrewBody", "PropShore", "PropCanopy", "prop_hit", "canopy_centre", "crew_head"])
	var all := _all_points(scene, ["PropCrewBody", "PropShore", "PropCanopy"])
	t.near("prop crew floor", _bounds(all).position.y, FLOOR, 0.01)
	var canopy := _bounds(_points(scene, "PropCanopy"))
	t.check("roof clears a ball and a pack (>= 3.2 m)", canopy.position.y - FLOOR >= 3.2, str(canopy))
	t.check("roof spans a pack (>= 5 x 4 m)", canopy.size.x >= 5.0 and canopy.size.z >= 4.0, str(canopy.size))
	var shore := scene.find_child("PropShore", true, false) as Node3D
	t.near("prop pivots at its foot", shore.position.y, FLOOR, 0.01)
	var hit := _socket(scene, "prop_hit")
	t.check("ram target on the prop at ball height", Vector2(hit.x - shore.position.x, hit.z - shore.position.z).length() < 0.01
		and hit.y > FLOOR + 0.5 and hit.y < FLOOR + 2.0, str(hit))
	t.check("roof falls under its own centre", canopy.has_point(Vector3(_socket(scene, "canopy_centre").x, canopy.get_center().y,
		_socket(scene, "canopy_centre").z)))
	scene.queue_free()


func _gap_net() -> void:
	var scene := _load(GAP_NET)
	if scene == null:
		return
	_budget("gap net", scene, ["fleet_paint", "working_tool", "requisition_tag"])
	_named("gap net", scene, ["GapNetPost", "GapNetBatten", "GapNetSpan", "net_high", "net_low", "post_cut", "sign", "crew_head"])
	var all := _all_points(scene, ["GapNetPost", "GapNetBatten", "GapNetSpan"])
	t.near("gap net floor", _bounds(all).position.y, FLOOR, 0.01)
	# The span is one 2 m tile starting at the batten, so the runtime can repeat it along +X.
	var span := _bounds(_points(scene, "GapNetSpan"))
	var batten := scene.find_child("GapNetBatten", true, false) as Node3D
	var tile := scene.find_child("GapNetSpan", true, false) as Node3D
	t.check("span origin on the batten", tile.position.is_equal_approx(batten.position))
	t.near("span is one 2 m tile", span.size.x, 2.0, 0.05)
	var high := _socket(scene, "net_high")
	var low := _socket(scene, "net_low")
	t.check("net taller than the ball", high.y - low.y >= 3.0, str(high.y - low.y))
	t.check("net hangs over the gap (+X)", span.position.x >= low.x - 0.05 and low.x > 0.8)
	scene.queue_free()


# The curtain cut: the same nodes and sockets, for a net the runtime hangs mid-gap from the
# span tile's mesh bounds alone (gap_net.gd _hang: tiles laid along X, stretched over Y).
func _gap_net_curtain() -> void:
	var scene := _load(GAP_NET_CURTAIN)
	if scene == null:
		return
	_budget("gap net curtain", scene, ["fleet_paint", "working_tool", "requisition_tag"])
	_named("gap net curtain", scene, ["GapNetPost", "GapNetBatten", "GapNetSpan", "net_high", "net_low", "post_cut", "sign", "crew_head"])
	var gear := _all_points(scene, ["GapNetPost", "GapNetBatten"])
	var stand := _bounds(gear)
	t.near("curtain post floor", stand.position.y, FLOOR, 0.01)
	t.check("curtain post stands upright on its rim plate", stand.end.x <= 1.15 and stand.end.y <= 4.3, str(stand))
	var mi := scene.find_child("GapNetSpan", true, false) as MeshInstance3D
	var box := mi.mesh.get_aabb()
	t.near("curtain tile starts at x 0", box.position.x, 0.0, 0.005)
	t.near("curtain tile is 2 m wide", box.size.x, 2.0, 0.005)
	t.check("curtain tile drops about 16 m", box.size.y >= 15.5 and box.size.y <= 16.5, str(box.size.y))
	t.check("curtain tile is pleated, not flat", box.size.z >= 0.4 and box.size.z <= 1.6, str(box.size.z))
	# Seam: the tile's two edges meet the same pleat, so repeats read as one curtain.
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y > box.end.y - 0.4:
			if v.x < 0.01:
				left.append(v.z)
			elif v.x > box.end.x - 0.01:
				right.append(v.z)
	left.sort()
	right.sort()
	t.check("headrope meets itself at the seam", left.size() > 0 and left.size() == right.size()
		and absf(left[0] - right[0]) < 0.02 and absf(left[-1] - right[-1]) < 0.02, "%s %s" % [left, right])
	var high := _socket(scene, "net_high")
	var low := _socket(scene, "net_low")
	t.check("sockets mark the headrope and hem", high.y - low.y >= 15.0 and absf(high.y - box.end.y) < 0.3, str([high, low]))
	scene.queue_free()


func _ballast() -> void:
	var scene := _load(BALLAST)
	if scene == null:
		return
	_budget("ballast heavy", scene, ["fleet_paint", "working_tool"])
	_named("ballast heavy", scene, ["BallastBody", "BallastBrakes", "cable_anchor", "brace_lever", "crew_head", "push_face"])
	var body := _points(scene, "BallastBody")
	t.near("ballast floor (castors)", _bounds(body).position.y, FLOOR, 0.01)
	var footprint := _bounds(body)
	t.check("ballast is wide and low", footprint.size.x >= 2.6 and footprint.size.z >= 2.0, str(footprint.size))
	# At rest the claws hang clear of the deck; the brace moves them down 0.3 m to bite.
	var brakes := scene.find_child("BallastBrakes", true, false) as Node3D
	var rest := _bounds(_points(scene, "BallastBrakes"))
	t.check("claws clear the deck at rest", rest.position.y > FLOOR + 0.15, str(rest.position.y))
	brakes.position.y -= 0.3
	var braced := _bounds(_points(scene, "BallastBrakes"))
	t.check("braced claws bite the deck", braced.position.y <= FLOOR + 0.01 and braced.position.y > FLOOR - 0.15, str(braced.position.y))
	t.check("braced claws widen the footprint", braced.size.x > footprint.size.x, str(braced.size))
	t.check("cable anchor at the back", _socket(scene, "cable_anchor").z < -0.8)
	scene.queue_free()


func _run() -> void:
	_pit_jaw()
	_prop_crew()
	_gap_net()
	_gap_net_curtain()
	_ballast()
	quit(t.verdict())
