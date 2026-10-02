extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Palette := preload("res://src/core/palette.gd")

# C08 Rivet pod limits (artifacts/asset-sheet/ASSETS.md): the world-one shell plus the
# unchanged pilot rig stay under the no-growth pod ceiling, the pod keeps its old
# silhouette and its visor, rail, fins and twin stacks, and the rig, clips and node names
# the game reads are intact. BASE is the shipped shell_rivet.glb (unchanged, kept for
# hero_assets_test and perf_bench); BASE_POD_* were measured on it at base 4d69a55.

const SHELL := "res://assets/models/world_one/shell_rivet.glb"
const RIG := "res://assets/models/pilot_rivet_anim.glb"
const MAX_V := 15000
const MAX_T := 16000
const MAX_DRAWS := 15
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const RIG_BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "crest", "ear.L", "ear.R",
	"goggles", "jaw", "snout", "shoulder.L", "upper_arm.L", "lower_arm.L", "hand.L", "curl.L",
	"shoulder.R", "upper_arm.R", "lower_arm.R", "hand.R", "curl.R", "tool.R", "tail.01", "tail.02",
]
# The triangle range allows one percent of export variation; pod ceilings above stay fixed.
const RIG_TRIS := Vector2i(4205, 4291)
const RIG_MESHES := {"Claws_L": ["pilot"], "Claws_R": ["pilot"], "Pilot": ["pilot"]}
const NODES := ["Core", "Pod", "Dome", "Pilot", "Gyro"]
const BASE := "res://assets/models/shell_rivet.glb"
const GROW := 0.002
# Pod kit mesh bounds of the base shell in shell space.
const BASE_POD_MIN := Vector3(-0.94, -0.7735, -1.015634)
const BASE_POD_MAX := Vector3(0.94, 0.133, 0.94)

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


static func meshes(node: Node, out: Array = []) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		meshes(c, out)
	return out


static func to_root(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func under(node: Node, name: String) -> bool:
	var n := node
	while n != null:
		if String(n.name) == name:
			return true
		n = n.get_parent()
	return false


# Vertex, triangle, surface counts, and the count of alpha surfaces.
static func counts(scene: Node) -> Dictionary:
	var out := {"v": 0, "t": 0, "s": 0, "alpha": 0}
	for mi in meshes(scene):
		for i in mi.mesh.get_surface_count():
			var arrays := (mi.mesh as Mesh).surface_get_arrays(i)
			out.v += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var index = arrays[Mesh.ARRAY_INDEX]
			out.t += (index.size() if index != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			out.s += 1
			if HeroAssets.slot_of(mi.mesh, i) == "glass":
				out.alpha += 1
	return out


# Every base vertex of a mesh node inside a region (shell space, Godot axes) must still
# exist in the new shell, so a preserved feature cannot be dropped or reshaped.
static func verts_in(scene: Node, node_name: String, region: AABB) -> Dictionary:
	var out := {}
	for mi in meshes(scene):
		if String(mi.name) != node_name:
			continue
		var t := to_root(mi, scene)
		for i in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var w := t * v
				if region.has_point(w):
					out[Vector3i((w * 1000.0).round())] = true
	return out


# Per-feature extent: bin Pod vertices into CELL-metre cells; every shell vertex must sit in
# a cell the base also occupies, so a fin or stack cannot grow into empty space inside the
# overall bounds. Returns the count of shell vertices in cells the base leaves empty.
const CELL := 0.12


static func cell_of(w: Vector3) -> Vector3i:
	return Vector3i((w / CELL).floor())


static func occupied(scene: Node, node_name: String) -> Dictionary:
	var out := {}
	for mi in meshes(scene):
		if String(mi.name) != node_name:
			continue
		var t := to_root(mi, scene)
		for i in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out[cell_of(t * v)] = true
	return out


func _outside_cells(base: Node, shell: Node) -> int:
	var have := occupied(base, "Pod")
	var n := 0
	for mi in meshes(shell):
		if String(mi.name) != "Pod":
			continue
		var t := to_root(mi, shell)
		for i in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var w := t * v
				var ok := false
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							ok = ok or have.has(cell_of(w) + Vector3i(dx, dy, dz))
				if not ok:
					n += 1
	return n


func _kept(base: Node, shell: Node, node_name: String, region: AABB) -> String:
	var want := verts_in(base, node_name, region)
	var have := verts_in(shell, node_name, region.grow(0.002))
	var lost := 0
	for k in want:
		var hit := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					hit = hit or have.has(k + Vector3i(dx, dy, dz))
		if not hit:
			lost += 1
	return "%d of %d base vertices" % [lost, want.size()] if lost > 0 or want.is_empty() else ""


# Scratch GLBs are read directly, so a red run never overwrites a delivered asset or its import.
func _load_asset(path: String, environment: String) -> Node:
	var scratch := OS.get_environment(environment)
	if not scratch.is_empty():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(scratch, state)
		_report("rivet scratch load", error == OK, "GLTF load error %d" % error)
		return document.generate_scene(state) if error == OK else Node.new()
	return (load(path) as PackedScene).instantiate()


func _check_rig(rig: Node) -> void:
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	var names := []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
	_report("rivet rig bones", skeletons.size() == 1 and names == RIG_BONES,
		"%d skeleton, %d bones; expected 1 skeleton and 25 ordered names, got %s" % [skeletons.size(), names.size(), names])
	var actual := {}
	for mi in meshes(rig):
		var materials := []
		for i in mi.mesh.get_surface_count():
			var material: Material = mi.mesh.surface_get_material(i)
			materials.append(material.resource_name if material != null else "<missing>")
		actual[String(mi.name)] = materials
	_report("rivet rig meshes", actual == RIG_MESHES, "mesh material names %s, expected %s" % [actual, RIG_MESHES])
	var triangles: int = counts(rig).t
	_report("rivet rig triangles", triangles >= RIG_TRIS.x and triangles <= RIG_TRIS.y,
		"%d triangles, range %d..%d (1 percent around delivered geometry)" % [triangles, RIG_TRIS.x, RIG_TRIS.y])
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.keys().filter(func(c): return not (c in clips))
	_report("rivet rig clips", player != null and lost.is_empty(), "seven pilot clips present (missing %s)" % [lost])
	for clip in CLIPS:
		var length := player.get_animation(clip).length if clip in clips else -1.0
		_report("rivet rig length " + clip, absf(length - CLIPS[clip]) <= 0.001,
			"%.6f seconds, expected %.6f +/-0.001" % [length, CLIPS[clip]])


func _initialize() -> void:
	var shell: Node = _load_asset(SHELL, "SCRAPKEEP_TEST_SHELL")
	var rig: Node = _load_asset(RIG, "SCRAPKEEP_TEST_RIG")
	var a := counts(shell)
	var b := counts(rig)
	_report("rivet pod V", a.v + b.v <= MAX_V, "%d + %d = %d vertices, ceiling %d" % [a.v, b.v, a.v + b.v, MAX_V])
	_report("rivet pod T", a.t + b.t <= MAX_T, "%d + %d = %d triangles, ceiling %d" % [a.t, b.t, a.t + b.t, MAX_T])
	_report("rivet pod draws", a.s + b.s <= MAX_DRAWS, "%d + %d = %d surfaces, ceiling %d" % [a.s, b.s, a.s + b.s, MAX_DRAWS])
	_report("rivet glass", a.alpha == 1 and b.alpha == 0, "one glass surface (%d shell, %d rig)" % [a.alpha, b.alpha])
	var missing := NODES.filter(func(n): return shell.find_child(n, true, false) == null)
	_report("rivet nodes", missing.is_empty(), "Core, Pod, Dome, Pilot, Gyro (missing %s)" % [missing])
	var slots := []
	for mi in meshes(shell):
		for i in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, i)
			if not HeroAssets.SLOTS.has(slot):
				slots.append(slot)
	_report("rivet slots", slots.is_empty(), "every surface is a section 9 slot %s" % [slots])
	var paint_set := [Palette.VERDIGRIS, Palette.RUST, Palette.SAND]
	var off := 0
	for mi in meshes(shell):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == "paint":
				for c in Array(mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]):
					var near := false
					for p in paint_set:
						var lin: Color = (p as Color).srgb_to_linear()
						near = near or (absf(c.r - lin.r) < 0.01 and absf(c.g - lin.g) < 0.01 and absf(c.b - lin.b) < 0.01)
					if not near:
						off += 1
	_report("rivet paint", off == 0, "paint vertex colours are petrol, iron oxide or bone (%d off)" % off)
	var core := shell.find_child("Core", true, false) as MeshInstance3D
	var far := 0.0
	for v in (core.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		far = maxf(far, (core.transform * v).length())
	_report("rivet core", far <= 0.981, "glass hull radius %.4f, collider 1.0" % far)
	# Silhouette: the Pod kit mesh (plates, spool, mast, saddle) may not extend past the base
	# shell's bounds. The gyro ring, glass and pilot are unchanged and fixed by other checks.
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in meshes(shell):
		if String(mi.name) != "Pod":
			continue
		var t := to_root(mi, shell)
		for i in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var w := t * v
				lo = lo.min(w)
				hi = hi.max(w)
	var grew := (lo - BASE_POD_MIN).x < -GROW or (lo - BASE_POD_MIN).y < -GROW or (lo - BASE_POD_MIN).z < -GROW \
		or (hi - BASE_POD_MAX).x > GROW or (hi - BASE_POD_MAX).y > GROW or (hi - BASE_POD_MAX).z > GROW
	_report("rivet silhouette", not grew, "pod bounds %s..%s within base %s..%s +%.3f" % [lo, hi, BASE_POD_MIN, BASE_POD_MAX, GROW])
	# Preserved features, by region of the base shell: raked fins, twin stacks, optical rail,
	# and the pilot with its visor and goggles (the Pilot mesh is not edited at all).
	var base: Node = (load(BASE) as PackedScene).instantiate()
	var everything := AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var features := {
		"fins": ["Pod", AABB(Vector3(0.36, -3, -3), Vector3(3, 6, 6))],
		"fins left": ["Pod", AABB(Vector3(-3.36, -3, -3), Vector3(3, 6, 6))],
		"stacks": ["Pod", AABB(Vector3(-0.3, -0.3, 0.3), Vector3(0.6, 1, 1))],
		"rail": ["Pod", AABB(Vector3(-0.3, -0.8, -1.2), Vector3(0.6, 1.2, 0.9))],
		"pilot": ["Pilot", everything],
		"gyro": ["Gyro", everything],
	}
	for key in features:
		var lost := _kept(base, shell, features[key][0], features[key][1])
		_report("rivet keeps " + key, lost == "", "base vertices still present (%s)" % lost)
	var stray := _outside_cells(base, shell)
	_report("rivet extent", stray == 0, "%d Pod vertices sit in space the base shell leaves empty (fins, stacks, rail cannot grow)" % stray)
	base.free()
	_check_rig(rig)

	shell.free()
	rig.free()
	print("world_one_shell_rivet_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
