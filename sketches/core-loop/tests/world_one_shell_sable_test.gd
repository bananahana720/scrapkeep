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
# Pod kit mesh bounds of the base shell in shell space.
const BASE_POD_MIN := Vector3(-0.94, -0.7735, -0.94)
const BASE_POD_MAX := Vector3(0.94, 0.16555, 0.94)

# Ring wear (C07 correction): the cosmetic wear on the plate ring is a few unequal contact
# patches, not many small regular marks. An island is a connected bare_metal or paint piece
# in the ring zone (shell space, y up, ring at y about -0.36) that is neither a plate
# (longest side 0.165 or more) nor a bolt (under 0.065). The flank spool sector (within 0.5 rad
# of +x) and the class_accent tops are outside the zone or slots counted.
const WEAR_SLOTS := ["bare_metal", "paint"]
const WEAR_R := Vector2(0.45, 0.60)
const WEAR_Y := Vector2(-0.46, -0.30)
const WEAR_MIN_ANGLE := 0.5
const BOLT_EXTENT := 0.065
const PLATE_EXTENT := 0.165
const WEAR_MAX_ISLANDS := 4
const WEAR_MIN_ISLANDS := 3
const WEAR_MIN_AREA := 0.010
const WEAR_UNEQUAL := 1.5

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


# Connected pieces (by welded position) of every wear-slot surface of the Pod mesh, kept when
# they sit in the ring zone and are neither bolts nor plates. Each entry is {area, centre}.
static func wear_islands(shell: Node) -> Array:
	var out := []
	for mi in meshes(shell):
		if String(mi.name) != "Pod":
			continue
		var t := to_root(mi, shell)
		for si in mi.mesh.get_surface_count():
			if not (HeroAssets.slot_of(mi.mesh, si) in WEAR_SLOTS):
				continue
			var arrays := (mi.mesh as Mesh).surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			var ids := {}
			var parent := []
			var vid := PackedInt32Array()
			for v in verts:
				var w := t * v
				var key := Vector3i((w * 10000.0).round())
				if not ids.has(key):
					ids[key] = parent.size()
					parent.append(parent.size())
				vid.append(ids[key])
			var tri_count: int = (index.size() if index != null else verts.size()) / 3
			for f in tri_count:
				var a: int = vid[index[f * 3] if index != null else f * 3]
				for j in 1 + 1:
					var b: int = vid[index[f * 3 + 1 + j] if index != null else f * 3 + 1 + j]
					var ra := a
					while parent[ra] != ra:
						ra = parent[ra]
					var rb := b
					while parent[rb] != rb:
						rb = parent[rb]
					if ra != rb:
						parent[rb] = ra
			var boxes := {}
			for i in verts.size():
				var r: int = vid[i]
				while parent[r] != r:
					r = parent[r]
				var w := t * verts[i]
				if not boxes.has(r):
					boxes[r] = AABB(w, Vector3.ZERO)
				else:
					boxes[r] = (boxes[r] as AABB).expand(w)
			for r in boxes:
				var bb: AABB = boxes[r]
				var c := bb.get_center()
				var rad := Vector2(c.x, c.z).length()
				var ang := absf(atan2(c.z, c.x))
				var ext := bb.size
				var dims := [ext.x, ext.y, ext.z]
				dims.sort()
				var area: float = dims[1] * dims[2]
				if rad < WEAR_R.x or rad > WEAR_R.y or c.y < WEAR_Y.x or c.y > WEAR_Y.y or ang < WEAR_MIN_ANGLE:
					continue
				if dims[2] < BOLT_EXTENT or dims[2] >= PLATE_EXTENT:
					continue
				out.append({"area": area, "centre": c})
	return out


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
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.filter(func(c): return not (c in clips))
	_report("sable rig clips", player != null and lost.is_empty(), "five pilot clips present (missing %s)" % [lost])
	var islands := wear_islands(shell)
	var areas := []
	for isl in islands:
		areas.append(isl.area)
		print("wear island area %.4f m2 at %s" % [isl.area, isl.centre])
	areas.sort()
	var few: bool = islands.size() >= WEAR_MIN_ISLANDS and islands.size() <= WEAR_MAX_ISLANDS
	_report("sable wear count", few, "%d ring wear islands, want %d to %d" % [islands.size(), WEAR_MIN_ISLANDS, WEAR_MAX_ISLANDS])
	_report("sable wear size", not areas.is_empty() and areas[0] >= WEAR_MIN_AREA, "smallest island %.4f m2, want at least %.3f" % [areas[0] if not areas.is_empty() else 0.0, WEAR_MIN_AREA])
	_report("sable wear unequal", areas.size() >= 2 and areas[-1] >= areas[0] * WEAR_UNEQUAL, "largest %.4f over smallest %.4f, want ratio %.1f" % [areas[-1] if not areas.is_empty() else 0.0, areas[0] if not areas.is_empty() else 0.0, WEAR_UNEQUAL])
	shell.free()
	rig.free()
	print("world_one_shell_sable_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
