extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Palette := preload("res://src/core/palette.gd")

# C07 Sable pod limits (artifacts/asset-sheet/ASSETS.md): the world-one shell plus the
# unchanged pilot rig stay under the no-growth pod ceiling, the pod keeps its old
# silhouette, and the rig, clips and node names the game reads are intact.
# BASE_* were measured on the shipped shell_sable.glb at base 69cb3c4 after import.

const SHELL := "res://assets/models/world_one/shell_sable.glb"
const RIG := "res://assets/models/pilot_sable_anim.glb"
const MAX_V := 15000
const MAX_T := 16000
const MAX_DRAWS := 15
const CLIPS := ["drop_land", "big_cheer", "wince", "slump", "phew"]
const NODES := ["Core", "Pod", "Dome", "Pilot", "Gyro", "RopeExit"]
const GROW := 0.002
# Petrol band (r 0.86 to 0.92 at z -0.29): the 16 regular pale arcs the judge read as fittings
# are replaced by two to four broad, unequal patches; the 16 bolts stay.
const BAND_R := Vector2(0.86, 0.93)
const BAND_Z := Vector2(-0.37, -0.2)
const PATCH_MIN := 2
const PATCH_MAX := 4
const PATCH_MIN_AREA := 0.02
const PATCH_UNEQUAL := 1.5
const BOLTS := 16
# Pod kit mesh bounds of the base shell in shell space.
const BASE_POD_MIN := Vector3(-0.94, -0.7735, -0.94)
const BASE_POD_MAX := Vector3(0.94, 0.16555, 0.94)

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


static func _key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))


# Shell space is Godot's (y up), so the band height is y. Connected islands (welded by position) of the Pod triangles in one slot whose centroid is in
# the band zone; `bone_only` also needs every vertex colour to be the bone paint. Each entry is
# the island's summed triangle area.
static func band_islands(shell: Node, slot: String, bone_only: bool, r_lo: float, r_hi: float) -> Array:
	var sand: Color = Palette.SAND.srgb_to_linear()
	var parent := {}
	var tris := []
	for mi in meshes(shell):
		if String(mi.name) != "Pod":
			continue
		var t := to_root(mi, shell)
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) != slot:
				continue
			var arrays := (mi.mesh as Mesh).surface_get_arrays(i)
			var vs := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var cs = arrays[Mesh.ARRAY_COLOR]
			var index = arrays[Mesh.ARRAY_INDEX]
			var n: int = index.size() if index != null else vs.size()
			for k in range(0, n, 3):
				var ids := [k, k + 1, k + 2]
				if index != null:
					ids = [index[k], index[k + 1], index[k + 2]]
				var p := [t * vs[ids[0]], t * vs[ids[1]], t * vs[ids[2]]]
				var c: Vector3 = (p[0] + p[1] + p[2]) / 3.0
				var r := Vector2(c.x, c.z).length()
				if r < r_lo or r > r_hi or c.y < BAND_Z.x or c.y > BAND_Z.y:
					continue
				if bone_only:
					var pale := true
					for id in ids:
						var col: Color = cs[id]
						pale = pale and absf(col.r - sand.r) < 0.01 and absf(col.g - sand.g) < 0.01 and absf(col.b - sand.b) < 0.01
					if not pale:
						continue
				tris.append(p)
	var find := func(x: Vector3i):
		var y: Vector3i = x
		while parent.get(y, y) != y:
			y = parent[y]
		return y
	for p in tris:
		for q in p:
			if not parent.has(_key(q)):
				parent[_key(q)] = _key(q)
		var root0: Vector3i = find.call(_key(p[0]))
		for m in [1, 2]:
			var rm: Vector3i = find.call(_key(p[m]))
			if rm != root0:
				parent[rm] = root0
	var area := {}
	for p in tris:
		var root: Vector3i = find.call(_key(p[0]))
		area[root] = area.get(root, 0.0) + ((p[1] - p[0]).cross(p[2] - p[0]) as Vector3).length() * 0.5
	return area.values()


func _initialize() -> void:
	var shell: Node = (load(SHELL) as PackedScene).instantiate()
	var rig: Node = (load(RIG) as PackedScene).instantiate()
	var a := counts(shell)
	var b := counts(rig)
	_report("sable pod V", a.v + b.v <= MAX_V, "%d + %d = %d vertices, ceiling %d" % [a.v, b.v, a.v + b.v, MAX_V])
	_report("sable pod T", a.t + b.t <= MAX_T, "%d + %d = %d triangles, ceiling %d" % [a.t, b.t, a.t + b.t, MAX_T])
	_report("sable pod draws", a.s + b.s <= MAX_DRAWS, "%d + %d = %d surfaces, ceiling %d" % [a.s, b.s, a.s + b.s, MAX_DRAWS])
	_report("sable glass", a.alpha == 1 and b.alpha == 0, "one glass surface (%d shell, %d rig)" % [a.alpha, b.alpha])
	var missing := NODES.filter(func(n): return shell.find_child(n, true, false) == null)
	_report("sable nodes", missing.is_empty(), "Core, Pod, Dome, Pilot, Gyro, RopeExit (missing %s)" % [missing])
	var slots := []
	for mi in meshes(shell):
		for i in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, i)
			if not HeroAssets.SLOTS.has(slot):
				slots.append(slot)
	_report("sable slots", slots.is_empty(), "every surface is a section 9 slot %s" % [slots])
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
	_report("sable paint", off == 0, "paint vertex colours are petrol, iron oxide or bone (%d off)" % off)
	var core := shell.find_child("Core", true, false) as MeshInstance3D
	var far := 0.0
	for v in (core.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		far = maxf(far, (core.transform * v).length())
	_report("sable core", far <= 0.981, "glass hull radius %.4f, collider 1.0" % far)
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
	_report("sable silhouette", not grew, "pod bounds %s..%s within base %s..%s +%.3f" % [lo, hi, BASE_POD_MIN, BASE_POD_MAX, GROW])
	var pale := band_islands(shell, "paint", true, BAND_R.x, BAND_R.y)
	var lo_a := INF
	var hi_a := 0.0
	for area in pale:
		lo_a = minf(lo_a, area)
		hi_a = maxf(hi_a, area)
	_report("sable band count", pale.size() >= PATCH_MIN and pale.size() <= PATCH_MAX,
		"%d pale wear islands in the band, want %d to %d" % [pale.size(), PATCH_MIN, PATCH_MAX])
	_report("sable band size", not pale.is_empty() and lo_a >= PATCH_MIN_AREA and hi_a >= lo_a * PATCH_UNEQUAL,
		"island areas %s m2, each at least %.3f and largest at least %.1fx smallest" % [pale.map(func(a): return snappedf(a, 0.001)), PATCH_MIN_AREA, PATCH_UNEQUAL])
	var bolts := band_islands(shell, "bare_metal", false, 0.92, 0.945)
	_report("sable band bolts", bolts.size() == BOLTS, "%d bolts on the band, want %d" % [bolts.size(), BOLTS])
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.filter(func(c): return not (c in clips))
	_report("sable rig clips", player != null and lost.is_empty(), "five pilot clips present (missing %s)" % [lost])
	shell.free()
	rig.free()
	print("world_one_shell_sable_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
