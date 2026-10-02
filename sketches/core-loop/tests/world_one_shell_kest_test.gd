extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Palette := preload("res://src/core/palette.gd")

# C09 Kest pod limits (artifacts/asset-sheet/ASSETS.md): the world-one shell plus the
# unchanged pilot rig stay under the no-growth pod ceiling, the pod keeps its old
# silhouette and its crest, satchels, mortar mouth and open vane, and the rig, clips and
# node names the game reads are intact. BASE is the shipped shell_kest.glb (unchanged, kept
# for hero_assets_test and perf_bench); BASE_POD_* were measured on it at base bcd0a7e
# (shell 10,292 T / 10,654 V / 16 surfaces, rig 4,492 T / 3,098 V / 5, pod 14,784 T /
# 13,752 V / 21 draws).

const SHELL := "res://assets/models/world_one/shell_kest.glb"
const RIG := "res://assets/models/pilot_kest_anim.glb"
const MAX_V := 15000
const MAX_T := 16000
const MAX_DRAWS := 21
const CLIPS := {"drop_land": 2.2, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const RIG_BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "crest", "ear.L", "ear.R",
	"goggles", "jaw", "snout", "shoulder.L", "upper_arm.L", "lower_arm.L", "hand.L", "curl.L",
	"shoulder.R", "upper_arm.R", "lower_arm.R", "hand.R", "curl.R", "tool.R", "tail.01", "tail.02",
]
# The triangle range allows one percent of export variation; pod ceilings above stay fixed.
const RIG_TRIS := Vector2i(4447, 4537)
const RIG_MESHES := {"Pilot": ["pilot"], "WingFan_L": ["pilot"], "WingFan_R": ["pilot"], "WingUpper_L": ["pilot"], "WingUpper_R": ["pilot"]}
const NODES := ["Core", "Pod", "Dome", "Pilot", "Gyro", "VaneL", "VaneR"]
const BASE := "res://assets/models/shell_kest.glb"
const GROW := 0.002
# Counts at this branch's base before the correction.
const NO_GROWTH_V := 11596
const NO_GROWTH_T := 10788
# Pod kit mesh bounds of the base shell in shell space.
const BASE_POD_MIN := Vector3(-0.94, -0.7735, -0.94)
const BASE_POD_MAX := Vector3(0.94, 0.133, 0.94)

# Blade mesh bounds of the base shell (folded pose, shell space); the blades are the open vane.
const BASE_VANE := {
	"VaneL": [Vector3(-0.0402, -0.1326, 0.1474), Vector3(0.01675, 0.0818, 0.6834)],
	"VaneR": [Vector3(-0.01675, -0.1326, 0.1474), Vector3(0.0402, 0.0818, 0.6834)],
}
# Base surface count per mesh: the wear may not add a slot, so no mesh gains a draw.
const BASE_SURFACES := {"Core": 1, "Pod": 5, "Pilot": 1, "Gyro": 3, "VaneL": 3, "VaneR": 3}

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


static func occupied(scene: Node, node_names: Array) -> Dictionary:
	var out := {}
	for mi in meshes(scene):
		if not (String(mi.name) in node_names):
			continue
		var t := to_root(mi, scene)
		for i in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out[cell_of(t * v)] = true
	return out


func _outside_cells(base: Node, shell: Node, node_name: String, allowed: Array) -> int:
	var have := occupied(base, allowed)
	var n := 0
	for mi in meshes(shell):
		if String(mi.name) != node_name:
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


# C09 correction 1: the wear on the working edges. The working faces are the Pod paint
# triangles of the satchels (canvas bodies and flaps) and the mortar tube: paint triangles in
# the region whose base colour is not already bone. Over them, the share that reads as worn
# in the shell: bone on any vertex, with the original material slot intact. Triangles are matched to
# the base by centroid (the wear adds no geometry, so the centroids are identical).
const WEAR_MIN := {"satchel right": 0.4, "satchel rear": 0.4, "satchel left": 0.4, "mortar": 0.2}
const WEAR_REGIONS := {
	"satchel right": AABB(Vector3(0.376, -0.52, -0.106), Vector3(0.32, 0.32, 0.32)),
	"satchel rear": AABB(Vector3(-0.12, -0.53, 0.376), Vector3(0.32, 0.32, 0.32)),
	"satchel left": AABB(Vector3(-0.656, -0.54, -0.36), Vector3(0.32, 0.32, 0.32)),
	"mortar": AABB(Vector3(-0.56, -0.36, 0.05), Vector3(0.3, 0.45, 0.4)),
}


# Pod triangles by rounded centroid: {key: [slot, has_bone_vertex, centroid]}.
static func pod_tris(scene: Node) -> Dictionary:
	var bone: Color = Palette.SAND.srgb_to_linear()
	var out := {}
	for mi in meshes(scene):
		if String(mi.name) != "Pod":
			continue
		var t := to_root(mi, scene)
		for i in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, i)
			var arrays := (mi.mesh as Mesh).surface_get_arrays(i)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var cs = arrays[Mesh.ARRAY_COLOR]
			var index = arrays[Mesh.ARRAY_INDEX]
			var n: int = index.size() if index != null else vs.size()
			for k in range(0, n, 3):
				var ids: Array = [index[k], index[k + 1], index[k + 2]] if index != null else [k, k + 1, k + 2]
				var centre: Vector3 = t * ((vs[ids[0]] + vs[ids[1]] + vs[ids[2]]) / 3.0)
				var has_bone := false
				if cs != null:
					for id in ids:
						var c: Color = cs[id]
						has_bone = has_bone or (absf(c.r - bone.r) < 0.01 and absf(c.g - bone.g) < 0.01 and absf(c.b - bone.b) < 0.01)
				out[Vector3i((centre * 1000.0).round())] = [slot, has_bone, centre]
	return out


# [worn, working, missing]: working = base paint triangles in the region with no bone vertex.
static func wear_share(base_tris: Dictionary, shell_tris: Dictionary, region: AABB) -> Array:
	var worn := 0
	var working := 0
	var missing := 0
	for key in base_tris:
		var b: Array = base_tris[key]
		if b[0] != "paint" or b[1] or not region.has_point(b[2]):
			continue
		working += 1
		if not shell_tris.has(key):
			missing += 1
			continue
		var s: Array = shell_tris[key]
		if s[0] == "paint" and s[1]:
			worn += 1
	return [worn, working, missing]


# Scratch GLBs are read directly, so a red run never overwrites a delivered asset or its import.
func _load_asset(path: String, environment: String) -> Node:
	var scratch := OS.get_environment(environment)
	if not scratch.is_empty():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(scratch, state)
		_report("kest scratch load", error == OK, "GLTF load error %d" % error)
		return document.generate_scene(state) if error == OK else Node.new()
	return (load(path) as PackedScene).instantiate()


func _check_rig(rig: Node) -> void:
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	var names := []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
	_report("kest rig bones", skeletons.size() == 1 and names == RIG_BONES,
		"%d skeleton, %d bones; expected 1 skeleton and 25 ordered names, got %s" % [skeletons.size(), names.size(), names])
	var actual := {}
	for mi in meshes(rig):
		var materials := []
		for i in mi.mesh.get_surface_count():
			var material: Material = mi.mesh.surface_get_material(i)
			materials.append(material.resource_name if material != null else "<missing>")
		actual[String(mi.name)] = materials
	_report("kest rig meshes", actual == RIG_MESHES, "mesh material names %s, expected %s" % [actual, RIG_MESHES])
	var triangles: int = counts(rig).t
	_report("kest rig triangles", triangles >= RIG_TRIS.x and triangles <= RIG_TRIS.y,
		"%d triangles, range %d..%d (1 percent around delivered geometry)" % [triangles, RIG_TRIS.x, RIG_TRIS.y])
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.keys().filter(func(c): return not (c in clips))
	_report("kest rig clips", player != null and lost.is_empty(), "seven pilot clips present (missing %s)" % [lost])
	for clip in CLIPS:
		var length := player.get_animation(clip).length if clip in clips else -1.0
		_report("kest rig length " + clip, absf(length - CLIPS[clip]) <= 0.001,
			"%.6f seconds, expected %.6f +/-0.001" % [length, CLIPS[clip]])


func _initialize() -> void:
	var shell: Node = _load_asset(SHELL, "SCRAPKEEP_TEST_SHELL")
	var rig: Node = _load_asset(RIG, "SCRAPKEEP_TEST_RIG")
	var a := counts(shell)
	var b := counts(rig)
	_report("kest no growth", a.v <= NO_GROWTH_V and a.t <= NO_GROWTH_T, "shell %d V and %d T, no more than %d V and %d T before the wear correction" % [a.v, a.t, NO_GROWTH_V, NO_GROWTH_T])
	_report("kest pod V", a.v + b.v <= MAX_V, "%d + %d = %d vertices, ceiling %d" % [a.v, b.v, a.v + b.v, MAX_V])
	_report("kest pod T", a.t + b.t <= MAX_T, "%d + %d = %d triangles, ceiling %d" % [a.t, b.t, a.t + b.t, MAX_T])
	_report("kest pod draws", a.s + b.s <= MAX_DRAWS, "%d + %d = %d surfaces, ceiling %d" % [a.s, b.s, a.s + b.s, MAX_DRAWS])
	_report("kest glass", a.alpha == 1 and b.alpha == 0, "one glass surface (%d shell, %d rig)" % [a.alpha, b.alpha])
	var missing := NODES.filter(func(n): return shell.find_child(n, true, false) == null)
	_report("kest nodes", missing.is_empty(), "Core, Pod, Dome, Pilot, Gyro, VaneL, VaneR (missing %s)" % [missing])
	var slots := []
	for mi in meshes(shell):
		for i in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, i)
			if not HeroAssets.SLOTS.has(slot):
				slots.append(slot)
	_report("kest slots", slots.is_empty(), "every surface is a section 9 slot %s" % [slots])
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
	_report("kest paint", off == 0, "paint vertex colours are petrol, iron oxide or bone (%d off)" % off)
	var core := shell.find_child("Core", true, false) as MeshInstance3D
	var far := 0.0
	for v in (core.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		far = maxf(far, (core.transform * v).length())
	_report("kest core", far <= 0.981, "glass hull radius %.4f, collider 1.0" % far)
	# Silhouette: the Pod kit mesh (satchels, mortar, saddle, vane spine) and each blade may not
	# extend past the base bounds. The gyro ring, glass and pilot are fixed by other checks.
	var bounds := {"Pod": [BASE_POD_MIN, BASE_POD_MAX], "VaneL": BASE_VANE["VaneL"], "VaneR": BASE_VANE["VaneR"]}
	for name in bounds:
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for mi in meshes(shell):
			if String(mi.name) != name:
				continue
			var t := to_root(mi, shell)
			for i in mi.mesh.get_surface_count():
				for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					var w := t * v
					lo = lo.min(w)
					hi = hi.max(w)
		var bmin: Vector3 = bounds[name][0]
		var bmax: Vector3 = bounds[name][1]
		var grew := (lo - bmin).x < -GROW or (lo - bmin).y < -GROW or (lo - bmin).z < -GROW \
			or (hi - bmax).x > GROW or (hi - bmax).y > GROW or (hi - bmax).z > GROW
		_report("kest silhouette " + name, not grew, "bounds %s..%s within base %s..%s +%.3f" % [lo, hi, bmin, bmax, GROW])
	# No mesh gains a surface, so the wear costs no draw.
	var gained := []
	for mi in meshes(shell):
		if int(BASE_SURFACES.get(String(mi.name), -1)) != mi.mesh.get_surface_count():
			gained.append("%s %d" % [mi.name, mi.mesh.get_surface_count()])
	_report("kest surfaces", gained.is_empty(), "each mesh keeps its base surface count (differs: %s)" % [gained])
	# Preserved features, by region of the base shell (Godot axes, after the 0.67 kit refit):
	# the three satchels, the mortar and its mouth, the vane spine and blades, the saddle, and
	# the pilot with its crest (the Pilot mesh is not edited at all). Every base vertex in a
	# region must still exist in the new shell.
	var base: Node = (load(BASE) as PackedScene).instantiate()
	var base_tris := pod_tris(base)
	var shell_tris := pod_tris(shell)
	for key in WEAR_REGIONS:
		var w := wear_share(base_tris, shell_tris, WEAR_REGIONS[key])
		var share := float(w[0]) / maxf(1.0, float(w[1]))
		_report("kest wear " + key, w[1] > 0 and w[2] == 0 and share >= WEAR_MIN[key], "%d of %d working paint triangles read as worn = %.2f, minimum %.2f (%d not matched to base)" % [w[0], w[1], share, WEAR_MIN[key], w[2]])
	var moved := 0
	for key in base_tris:
		if shell_tris.has(key) and base_tris[key][0] != shell_tris[key][0]:
			moved += 1
	_report("kest working slots", moved == 0, "%d base triangles changed material slot, want 0" % moved)
	var everything := AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var features := {
		"satchel right": ["Pod", AABB(Vector3(0.376, -0.52, -0.106), Vector3(0.32, 0.32, 0.32))],
		"satchel rear": ["Pod", AABB(Vector3(-0.12, -0.53, 0.376), Vector3(0.32, 0.32, 0.32))],
		"satchel left": ["Pod", AABB(Vector3(-0.656, -0.54, -0.36), Vector3(0.32, 0.32, 0.32))],
		"mortar": ["Pod", AABB(Vector3(-0.56, -0.36, 0.05), Vector3(0.3, 0.45, 0.4))],
		"mortar mouth": ["Pod", AABB(Vector3(-0.56, -0.12, 0.05), Vector3(0.24, 0.24, 0.24))],
		"vane spine": ["Pod", AABB(Vector3(-0.06, -0.26, 0.1), Vector3(0.12, 0.1, 0.55))],
		"saddle": ["Pod", AABB(Vector3(-0.45, -0.15, -0.4), Vector3(0.9, 0.3, 0.9))],
		"vane left": ["VaneL", everything],
		"vane right": ["VaneR", everything],
		"pilot crest": ["Pilot", everything],
		"gyro": ["Gyro", everything],
		"pod all": ["Pod", everything],
	}
	for key in features:
		var lost := _kept(base, shell, features[key][0], features[key][1])
		_report("kest keeps " + key, lost == "", "base vertices still present (%s)" % lost)
	# Per-cell extent: a piece cannot sit in space the base leaves empty inside its bounds.
	var vane_names := ["Pod", "VaneL", "VaneR"]
	var stray := {
		"Pod": _outside_cells(base, shell, "Pod", vane_names),
		"VaneL": _outside_cells(base, shell, "VaneL", ["VaneL"]),
		"VaneR": _outside_cells(base, shell, "VaneR", ["VaneR"]),
	}
	for name in stray:
		_report("kest extent " + name, stray[name] == 0, "%d %s vertices sit in space the base shell leaves empty" % [stray[name], name])
	base.free()
	_check_rig(rig)

	shell.free()
	rig.free()
	print("world_one_shell_kest_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
