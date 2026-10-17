extends SceneTree
# Kill-first bodies (ENEMY-PRIORITY.md 4a): Splitter, its loose piece and Linker. Asset only:
# no combat script loads these yet (Splitter wave 18, Linker wave 19), so this checks the
# imported files the wiring will read. Enemy budget, opaque vertex-colour surfaces with no
# baked glow, the named meshes and sockets the behaviour is promised, and the floor and core
# each recipe documents.

const T := preload("res://tests/support/t.gd")
const SPLITTER := "res://assets/models/world_one/enemy_splitter.glb"
const PIECE := "res://assets/models/world_one/enemy_splitter_piece.glb"
const LINKER := "res://assets/models/world_one/enemy_linker.glb"

var t := T.new("enemy_kill_first_asset_test")


func _initialize() -> void:
	_run.call_deferred()


func _load(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	t.check(path.get_file() + " loads", packed != null)
	return packed.instantiate() as Node3D if packed != null else null


# Vertices in the scene root's space, per mesh name.
func _points(scene: Node3D, name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mi := scene.find_child(name, true, false) as MeshInstance3D
	if mi == null:
		return out
	var xf := scene.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else mi.transform
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


func _budget(label: String, scene: Node3D, draws: int, slots: Array) -> void:
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
	t.check(label + " enemy budget", verts <= 2100 and tris <= 1100 and surfaces == draws)
	for slot in slots:
		t.check(label + " slot " + slot, slot in seen)


func _named(label: String, scene: Node3D, names: Array) -> void:
	for name in names:
		t.check(label + " has " + name, scene.find_child(name, true, false) != null)
	for node: Node3D in scene.find_children("*", "Node3D", true, false):
		t.check(label + " unit scale " + node.name, node.scale.is_equal_approx(Vector3.ONE))


func _floor(points: PackedVector3Array) -> float:
	var lo := INF
	for p in points:
		lo = minf(lo, p.y)
	return lo


func _splitter() -> void:
	var scene := _load(SPLITTER)
	if scene == null:
		return
	root.add_child(scene)
	_budget("splitter", scene, 2, ["fleet_paint", "requisition_tag"])
	_named("splitter", scene, ["SplitterBody", "SplitterSeams", "FuseLamp", "pod_a", "pod_b", "pod_c",
		"snout_a", "snout_b", "snout_c"])
	var all := _points(scene, "SplitterBody")
	all.append_array(_points(scene, "SplitterSeams"))
	t.near("splitter floor", _floor(all), -1.35, 0.01)
	var core := 0.0
	for p in _points(scene, "SplitterSeams"):
		core = maxf(core, Vector2(p.x, p.z).length())
	var top := -INF
	var reach := 0.0
	for p in all:
		top = maxf(top, p.y)
		reach = maxf(reach, Vector2(p.x, p.z).length())
	t.check("splitter shell within 1.25", core <= 1.25, str(core))
	t.check("splitter legs and snouts within 1.65", reach <= 1.65, str(reach))
	t.check("splitter lamp top within 1.7", top <= 1.7, str(top))
	# Three pods round the axis 120 degrees apart, pod a leading along -Z like the chaser.
	var a := (scene.find_child("pod_a", true, false) as Node3D).position
	var b := (scene.find_child("pod_b", true, false) as Node3D).position
	var c := (scene.find_child("pod_c", true, false) as Node3D).position
	t.check("pod a leads along -Z", a.z < -0.3 and absf(a.x) < 0.01)
	t.near("pods 120 degrees apart", Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)), deg_to_rad(120.0), 0.01)
	t.near("pods evenly spaced", absf(Vector2(b.x, b.z).angle_to(Vector2(c.x, c.z))), deg_to_rad(120.0), 0.01)
	scene.queue_free()


func _piece() -> void:
	var scene := _load(PIECE)
	if scene == null:
		return
	root.add_child(scene)
	_budget("piece", scene, 2, ["fleet_paint", "requisition_tag"])
	_named("piece", scene, ["SplitterPieceBody", "SplitterPieceGlow", "snout"])
	var all := _points(scene, "SplitterPieceBody")
	all.append_array(_points(scene, "SplitterPieceGlow"))
	t.near("piece floor", _floor(all), -0.91875, 0.01)
	var top := -INF
	var reach := 0.0
	for p in all:
		top = maxf(top, p.y)
		reach = maxf(reach, Vector2(p.x, p.z).length())
	t.check("piece 0.6 chaser height (<= 1.8 m)", top - _floor(all) <= 1.8, str(top - _floor(all)))
	t.check("piece reach within 1 m", reach <= 1.0, str(reach))
	var snout := (scene.find_child("snout", true, false) as Node3D).position
	t.check("piece snout leads along -Z", snout.z < -0.8 and absf(snout.x) < 0.01)
	scene.queue_free()


func _linker() -> void:
	var scene := _load(LINKER)
	if scene == null:
		return
	root.add_child(scene)
	_budget("linker", scene, 3, ["fleet_paint", "working_tool", "requisition_tag"])
	_named("linker", scene, ["LinkerBody", "LinkerDish", "LinkerCable", "LinkerHinge", "boom_tip",
		"cable_base", "cable_dish", "cable_cut", "partner_spot", "LinkerCab"])
	var body := _points(scene, "LinkerBody")
	t.near("linker floor", _floor(body), -1.1, 0.01)
	var core := 0.0
	var reach := 0.0
	for p in body:
		reach = maxf(reach, p.x)
		if p.y < 0.6:
			core = maxf(core, Vector2(p.x, p.z).length())
	t.check("linker post core within 1.1", core <= 1.1, str(core))
	t.check("linker boom breaks the outline sideways (>= 3.5 m)", reach >= 3.5, str(reach))
	var dish := scene.find_child("LinkerDish", true, false) as Node3D
	var hinge := (scene.find_child("LinkerHinge", true, false) as Node3D).position
	t.check("dish pivots at the hinge", dish.position.is_equal_approx(hinge))
	var partner := (scene.find_child("partner_spot", true, false) as Node3D).position
	var dish_points := _points(scene, "LinkerDish")
	var centre := Vector3.ZERO
	for p in dish_points:
		centre += p
	centre /= maxf(1.0, dish_points.size())
	t.check("dish hangs over the partner", absf(centre.x - partner.x) < 0.5 and centre.y > 1.0, str(centre))
	var cut := (scene.find_child("cable_cut", true, false) as Node3D).position
	var base := (scene.find_child("cable_base", true, false) as Node3D).position
	var tip := (scene.find_child("cable_dish", true, false) as Node3D).position
	t.check("cable sags below its chord", cut.y < (base.y + tip.y) * 0.5 - 0.5)
	scene.queue_free()


func _run() -> void:
	_splitter()
	_piece()
	_linker()
	quit(t.verdict())
