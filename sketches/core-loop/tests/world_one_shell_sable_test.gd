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
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const RIG_BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "crest", "ear.L", "ear.R",
	"goggles", "jaw", "snout", "shoulder.L", "upper_arm.L", "lower_arm.L", "hand.L", "curl.L",
	"shoulder.R", "upper_arm.R", "lower_arm.R", "hand.R", "curl.R", "tool.R", "tail.01", "tail.02",
]
# The triangle range allows one percent of export variation; pod ceilings above stay fixed.
const RIG_TRIS := Vector2i(4546, 4638)
const RIG_MESHES := {"Pilot": ["pilot"], "TailBase": ["pilot"], "TailTip": ["pilot"], "Tool": ["bare_metal", "class_accent"]}
const NODES := ["Core", "Pod", "Dome", "Pilot", "Gyro", "RopeExit"]
const GROW := 0.002
# Petrol band (r 0.86 to 0.92 at z -0.29): the 16 regular pale arcs the judge read as fittings
# are replaced by three broad, unequal patches; the 16 bolts stay.
const BAND_R := Vector2(0.86, 0.93)
const BAND_Z := Vector2(-0.37, -0.2)
const PATCH_MIN := 3
const PATCH_MAX := 3
const PATCH_MIN_AREA := 0.02
const PATCH_UNEQUAL := 1.5
const BOLTS := 16
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
const WEAR_MAX_ISLANDS := 3
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
				for j in 2:
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


# Scratch GLBs are read directly, so a red run never overwrites a delivered asset or its import.
func _load_asset(path: String, environment: String) -> Node:
	var scratch := OS.get_environment(environment)
	if not scratch.is_empty():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(scratch, state)
		_report("sable scratch load", error == OK, "GLTF load error %d" % error)
		return document.generate_scene(state) if error == OK else Node.new()
	return (load(path) as PackedScene).instantiate()


func _check_rig(rig: Node) -> void:
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	var names := []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
	_report("sable rig bones", skeletons.size() == 1 and names == RIG_BONES,
		"%d skeleton, %d bones; expected 1 skeleton and 25 ordered names, got %s" % [skeletons.size(), names.size(), names])
	var actual := {}
	for mi in meshes(rig):
		var materials := []
		for i in mi.mesh.get_surface_count():
			var material: Material = mi.mesh.surface_get_material(i)
			materials.append(material.resource_name if material != null else "<missing>")
		actual[String(mi.name)] = materials
	_report("sable rig meshes", actual == RIG_MESHES, "mesh material names %s, expected %s" % [actual, RIG_MESHES])
	var triangles: int = counts(rig).t
	_report("sable rig triangles", triangles >= RIG_TRIS.x and triangles <= RIG_TRIS.y,
		"%d triangles, range %d..%d (1 percent around delivered geometry)" % [triangles, RIG_TRIS.x, RIG_TRIS.y])
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.keys().filter(func(c): return not (c in clips))
	_report("sable rig clips", player != null and lost.is_empty(), "seven pilot clips present (missing %s)" % [lost])
	for clip in CLIPS:
		var length := player.get_animation(clip).length if clip in clips else -1.0
		_report("sable rig length " + clip, absf(length - CLIPS[clip]) <= 0.001,
			"%.6f seconds, expected %.6f +/-0.001" % [length, CLIPS[clip]])


func _initialize() -> void:
	var shell: Node = _load_asset(SHELL, "SCRAPKEEP_TEST_SHELL")
	var rig: Node = _load_asset(RIG, "SCRAPKEEP_TEST_RIG")
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
	_check_rig(rig)
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
