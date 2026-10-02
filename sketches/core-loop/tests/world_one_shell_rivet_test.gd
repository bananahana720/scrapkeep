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
const CLIPS := ["drop_land", "big_cheer", "wince", "slump", "phew"]
const NODES := ["Core", "Pod", "Dome", "Pilot", "Gyro"]
const BASE := "res://assets/models/shell_rivet.glb"
const RIG_SHA := "90b2044887a45f33be14bb3552f2a2dea5dd54c9b8b5dfbf591222978057f14f"
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


func _initialize() -> void:
	var shell: Node = (load(SHELL) as PackedScene).instantiate()
	var rig: Node = (load(RIG) as PackedScene).instantiate()
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
	var rig_sha := FileAccess.get_sha256(RIG)
	_report("rivet rig file", rig_sha == RIG_SHA, "pilot_rivet_anim.glb sha256 %s" % rig_sha.substr(0, 12))
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.filter(func(c): return not (c in clips))
	_report("rivet rig clips", player != null and lost.is_empty(), "five pilot clips present (missing %s)" % [lost])
	shell.free()
	rig.free()
	print("world_one_shell_rivet_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
