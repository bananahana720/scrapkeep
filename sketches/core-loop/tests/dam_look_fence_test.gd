extends SceneTree

# Rule (W1-25, the dam's look): a look change to the spillway dam never moves the fight. Its collider (the
# landmark_dam-col-col mesh), its two radial gate leaves and every named empty (sight_top, beam_root, warden_anchor,
# hp_0 to hp_2, the gate hinges) stay exactly as the 10 Nov build placed them, so no route, line or posture band moves.
# The pins are the 10 Nov build's numbers, read from assets/models/park/landmark_dam.glb on stage/alpha-w40 20c3c03f. A change
# that means to move one of them is a layout change: it re-measures stage 1 and re-pins here.
# The collider node and both gate leaves are pinned by their own geometry digest too, so a gate of a new radius or width
# with the same corner count still fails.
# The face stays drawn: the base keeps its six draws and at least the 10 Nov triangle count.

const T := preload("res://tests/support/t.gd")
const PATH := "res://assets/models/park/landmark_dam.glb"
const COL_POINTS := 1980
const COL_HASH := "9e6fb364"
const GATE_POINTS := 1740
const GATE_HASH := "65f9b27c"
const EMPTIES := {
	"sight_top": Vector3(0, 141, -20), "beam_root": Vector3(0, 22, 30), "warden_anchor": Vector3(0, 22, 30),
	"hp_0": Vector3(0, 23.6, 30), "hp_1": Vector3(10, 22, 30), "hp_2": Vector3(-10, 22, 30),
	"gate_l_hinge": Vector3(-6, 44, -8), "gate_r_hinge": Vector3(6, 44, -8),
	"gate_l": Vector3(-6, 44, -8), "gate_r": Vector3(6, 44, -8),
}
const MIN_TRIS := 9816

var t := T.new("dam_look_fence_test")


func _initialize() -> void:
	_run.call_deferred()


func _points(mesh: ImporterMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays := mesh.get_surface_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			out.append_array(verts)
		else:
			for i in index:
				out.append(verts[i])
	return out


func _digest(points: PackedVector3Array) -> String:
	var text := PackedStringArray()
	for p in points:
		text.append("%.3f,%.3f,%.3f" % [p.x, p.y, p.z])
	return ";".join(text).sha256_text().substr(0, 8)


func _run() -> void:
	var state := GLTFState.new()
	var err := GLTFDocument.new().append_from_file(ProjectSettings.globalize_path(PATH), state)
	if not t.check("landmark_dam.glb loads", err == OK):
		quit(t.verdict())
		return
	var meshes := {}
	for m: GLTFMesh in state.get_meshes():
		meshes[m.original_name if m.original_name != "" else m.resource_name] = m.mesh
	var nodes := {}
	for n: GLTFNode in state.get_nodes():
		nodes[n.original_name if n.original_name != "" else n.resource_name] = n
	var col: ImporterMesh = meshes.get("landmark_dam-col-col")
	if t.check("the collider mesh is there", col != null, str(meshes.keys())):
		var pts := _points(col)
		t.eq("collider corner count", pts.size(), COL_POINTS)
		t.eq("collider geometry", _digest(pts), COL_HASH)
	for gate in ["gate_l", "gate_r"]:
		var mesh: ImporterMesh = meshes.get(gate)
		if t.check("%s is its own mesh" % gate, mesh != null):
			var pts := _points(mesh)
			t.eq("%s corner count" % gate, pts.size(), GATE_POINTS)
			t.eq("%s geometry" % gate, _digest(pts), GATE_HASH)
	for name: String in EMPTIES:
		var node: GLTFNode = nodes.get(name)
		if t.check("%s is placed" % name, node != null):
			t.check("%s stands where it stood" % name, node.position.distance_to(EMPTIES[name]) < 0.001, str(node.position))
	var tris := 0
	var draws := 0
	for key: String in meshes:
		var m: ImporterMesh = meshes[key]
		draws += m.get_surface_count()
		if key == "landmark_dam" or key == "gate_l" or key == "gate_r":
			for s in m.get_surface_count():
				var a := m.get_surface_arrays(s)
				tris += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else 0
	t.check("the base stays within six draws", draws <= 6, str(draws))
	t.check("the face stays drawn (at least the 10 Nov triangles)", tris >= MIN_TRIS, str(tris))
	quit(t.verdict())
