extends SceneTree
# 2026-10-10 (PD-SABLE): re-pinned for the Hoberman mecha. The C07 glass-pod checks (one glass
# surface, the pod-silhouette bounds, the petrol band patches and ring wear islands) described the
# retired glass ball and are gone; the shell is now shell_base.hoberman() plus Sable's machinery
# (P-UNITS PD-SABLE, ROSTER-LOOK sections 0 to 6, pilots/sable.md section 5). The pod ceiling
# keeps 16,000 T / 15,000 V; draws rise from 15 to 19 (shell 14 by its registry exception, rig 5).
# The rig checks are unchanged. The run must make EXPECTED_CHECKS checks.
# Fix round 2 (PD-0b base, docs/decisions.tsv 2026-10-10): shell cap 16 draws, class III layer 2,
# every other layer 1, checked per layer. Class V is the doubled coil alone (one copper surface,
# no Replace_ node, the base mint tip stays); its three top panels moved into c4.
# 2026-10-22: shell 16 after the SpoolKit split and rubber fold (baked-bracket card; docs/decisions.tsv 2026-10-22T18:42).
# 2026-11-23 (E1-10, ruling ek, wave 46 blueprint 2.3): the twin coils at 11 and 1 became one twin-prong emitter
# at twelve o'clock under the ring band, on E1-03's closed lattice. Emitter_L and Emitter_R sit on the prong
# points, mirrored, inside the 1.35 m weapon reach; the ring is closed; the heft layers stay clear of it; draws
# in play stay within 16 and shell triangles under 6,500.
# 2026-11-23 (E1-10b, ruling en): the cutaway hero pass. The emitter became a crown arc on the WeaponRing:
# two yoke arms carry two emitter heads over the ball, Emitter_L and Emitter_R in their fork mouths, and the
# ChargeHalo's volume between them stays clear; the ring reaches at most 1.70 m. Two ribbed coil masts stand
# on the upper flanks at 11 and 1 o'clock as SpoolKit geometry (banked with the ring), the left one under the
# CoilMast tip, and every crown vertex stays clear of them in (horizontal radius, height), so no aim clips
# them; nothing outboard is baked into the level Pod mesh. Class V's doubled coil is a banked CoilMast node
# wound round the left mast.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ChargeHalo := preload("res://src/presentation/charge_halo.gd")
const Palette := preload("res://src/core/palette.gd")

const SHELL := "res://assets/models/world_one/shell_sable.glb"
const FELT := "res://assets/models/world_one/shell_sable_felt.glb"
const LAYER := "res://assets/models/world_one/shell_sable_c%d.glb"
const RIG := "res://assets/models/pilot_sable_anim.glb"
const EXPECTED_CHECKS := 79
const MAX_V := 15000
const MAX_T := 16000
# 2026-10-22: SpoolKit (the winch spool, copper and paint, its rubber folded into paint in charcoal) is its
# own mesh so the carrier bank tilts it (baked-bracket bank split): shell 16 by its registry exception,
# inside the 16-draw Hoberman pilot mecha cap (docs/decisions.tsv w13-PD).
const MAX_DRAWS := 21
const SHELL_DRAWS := 16
# SpoolKit's charcoal paint vertices: the spool's 4 parts (rod, bracket beam, hatch box, fairlead beam) x 24
# loops each, and each mast's boot (6 sides and its bottom cap) x 2 masts.
const SPOOL_DARK_LOOPS := 96 + 2 * 30
const SHELL_TRIS := 6500        # hero_assets_test's world-one shell band, pilot excluded
const LAYER_TRIS := 1500
const CORE_LIMIT := 0.985
const LATTICE_OUT := 0.975
const SPOOL_PAST := 0.12
const TOL := 0.01
# The masts: vertical columns on X -/+MAST_X (Z 0) from inside the plating; the tips top out at MAST_TOP.
const MAST_X := 0.48
const MAST_TOP := 1.18
const MAST_WIDE := 0.115
# The visual reach cap (ruling en): no weapon part past 1.70 m from the ball's centre. The crown stays bold:
# it reaches CROWN_BOLD or more, and its fork mouths sit CROWN_ABOVE or more over the centre.
const CROWN_REACH := 1.70
const CROWN_BOLD := 1.60
const CROWN_ABOVE := 1.30
# Crown vertices are the ring's above the band (Godot Y CROWN_FROM); they keep CROWN_CLEAR from the masts,
# the heft layers and the halo, and stay outside the plating (CORE_LIMIT).
const CROWN_FROM := 0.12
const CROWN_CLEAR := 0.03
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const RIG_BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "crest", "ear.L", "ear.R",
	"goggles", "jaw", "snout", "shoulder.L", "upper_arm.L", "lower_arm.L", "hand.L", "curl.L",
	"shoulder.R", "upper_arm.R", "lower_arm.R", "hand.R", "curl.R", "tool.R", "tail.01", "tail.02",
]
# The triangle range allows one percent of export variation; pod ceilings above stay fixed.
const RIG_TRIS := Vector2i(9714, 9910)
const RIG_MESHES := {"Pilot": ["pilot"], "TailBase": ["pilot"], "TailTip": ["pilot"], "Tool": ["bare_metal", "class_accent"]}
# Godot names of the nodes the kit, the clips and the loader read (Blender dots become underscores).
const POD_NODES := ["Gyro", "WeaponRing", "Dome", "CoilMast", "WrenchRack", "RopeExit", "DecalPlate",
	"Control_Grip_L", "Control_Grip_R", "Control_Trigger", "Control_GaugeLever", "Control_SpoolBrake",
	"Control_LapBar", "Control_Pedal_L", "Control_Pedal_R"]
const BAD_SLOTS := ["glass", "requisition_tag", "fleet_paint"]

var _failures := 0
var _checks := 0


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
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
	var n := node.get_parent()
	while n != null:
		if String(n.name) == name:
			return true
		n = n.get_parent()
	return false


# Vertex, triangle and surface counts; skip names meshes left out.
static func counts(scene: Node, skip: Array = []) -> Dictionary:
	var out := {"v": 0, "t": 0, "s": 0}
	for mi in meshes(scene):
		if String(mi.name) in skip:
			continue
		for i in mi.mesh.get_surface_count():
			var arrays := (mi.mesh as Mesh).surface_get_arrays(i)
			out.v += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var index = arrays[Mesh.ARRAY_INDEX]
			out.t += (index.size() if index != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			out.s += 1
	return out


# Shell-space points of every surface of mi in the given slot ("" for all).
static func points(mi: MeshInstance3D, root: Node, slot := "") -> PackedVector3Array:
	var t := to_root(mi, root)
	var out := PackedVector3Array()
	for i in mi.mesh.get_surface_count():
		if slot != "" and HeroAssets.slot_of(mi.mesh, i) != slot:
			continue
		for v in (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(t * v)
	return out


static func far(pts: PackedVector3Array) -> float:
	var r := 0.0
	for p in pts:
		r = maxf(r, p.length())
	return r


# Clock position seen from the chase camera behind the ball: 12 up, 3 to the right (+X).
static func clock(p: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(p.x, p.y)) / 30.0, 12.0)


static func near_any(c: Color, set: Array) -> bool:
	for p in set:
		var lin: Color = (p as Color).srgb_to_linear()
		if absf(c.r - lin.r) < 0.01 and absf(c.g - lin.g) < 0.01 and absf(c.b - lin.b) < 0.01:
			return true
	return false


# Glass, Fleet or requisition slots, lights and material overrides anywhere under root.
static func problems(root: Node) -> Array:
	var out := []
	for n in root.find_children("*", "Light3D", true, false):
		out.append("light " + String(n.name))
	for mi in meshes(root):
		if mi.material_override != null:
			out.append("material_override on " + String(mi.name))
		for i in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, i)
			if slot in BAD_SLOTS or not HeroAssets.SLOTS.has(slot):
				out.append("%s slot %s" % [mi.name, slot])
	return out


func _load(path: String) -> Node:
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else Node.new()


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


func _check_budget(shell: Node, rig: Node) -> void:
	var a := counts(shell)
	var b := counts(rig)
	var body := counts(shell, ["Pilot"])
	_report("sable shell tris", body.t < SHELL_TRIS, "%d triangles without the placeholder pilot, under %d" % [body.t, SHELL_TRIS])
	_report("sable shell draws", a.s == SHELL_DRAWS, "%d surfaces, registry exception %d" % [a.s, SHELL_DRAWS])
	_report("sable draws in play", body.s <= SHELL_DRAWS, "%d surfaces without the placeholder pilot, cap %d" % [body.s, SHELL_DRAWS])
	_report("sable pod V", a.v + b.v <= MAX_V, "%d + %d = %d vertices, ceiling %d" % [a.v, b.v, a.v + b.v, MAX_V])
	_report("sable pod T", a.t + b.t <= MAX_T, "%d + %d = %d triangles, ceiling %d" % [a.t, b.t, a.t + b.t, MAX_T])
	_report("sable pod draws", a.s + b.s <= MAX_DRAWS, "%d + %d = %d surfaces, ceiling %d" % [a.s, b.s, a.s + b.s, MAX_DRAWS])


func _check_tree(shell: Node) -> void:
	var core := shell.find_child("Core", true, false) as MeshInstance3D
	var pod := shell.find_child("Pod", true, false) as MeshInstance3D
	_report("sable core and pod", core != null and pod != null, "Core and Pod meshes under the root")
	if core == null or pod == null:
		return
	var missing := POD_NODES.filter(func(n): return pod.find_child(n, true, false) == null)
	_report("sable pod nodes", missing.is_empty(), "%d kit, control and loader nodes under Pod (missing %s)" % [POD_NODES.size(), missing])
	var hand_points := ["LapBar_L", "LapBar_R"].filter(func(n): return pod.find_child("Control_LapBar", true, false) == null \
		or pod.find_child("Control_LapBar", true, false).get_node_or_null(n) == null)
	_report("sable lap bar hands", hand_points.is_empty(), "LapBar_L and LapBar_R under Control_LapBar (missing %s)" % [hand_points])
	var hubs := 0
	for c in core.get_children():
		if String(c.name).begins_with("Hub_"):
			hubs += 1
	_report("sable lattice hubs", hubs == 32, "%d Hub_NN empties on Core, want 32" % hubs)
	var r := far(points(core, shell))
	_report("sable core radius", r <= CORE_LIMIT + 0.0001 and r >= 0.95, "lattice reaches %.4f, limit %.3f" % [r, CORE_LIMIT])
	var ring := pod.find_child("WeaponRing", true, false)
	var el := ring.get_node_or_null("Emitter_L") as Node3D if ring != null else null
	var er := ring.get_node_or_null("Emitter_R") as Node3D if ring != null else null
	_report("sable emitter mounts", el != null and er != null and el.position.y >= CROWN_ABOVE and absf(el.position.y - er.position.y) < 0.001
		and el.position.x < -0.15 and absf(el.position.x + er.position.x) < 0.001 and absf(el.position.z) < 0.001 and absf(er.position.z) < 0.001,
		"Emitter_L and Emitter_R in the crown's fork mouths over the ball, mirrored in x (%s, %s)"
		% [el.position if el != null else null, er.position if er != null else null])
	_check_crown(shell, ring as MeshInstance3D, el, er)
	var slots := []
	if ring is MeshInstance3D:
		for i in (ring as MeshInstance3D).mesh.get_surface_count():
			slots.append(HeroAssets.slot_of((ring as MeshInstance3D).mesh, i))
	slots.sort()
	_report("sable ring slots", slots == ["copper", "paint", "rubber"], "WeaponRing surfaces %s: bone band and collars, dark collar and shoe, copper winding, prongs and studs" % [slots])


# Points of every mesh under node (node included) above min_y, in root's frame.
static func points_above(node: Node, root: Node, min_y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in meshes(node):
		for p in points(mi, root):
			if p.y > min_y:
				out.append(p)
	return out


# Nearest pair of points in (horizontal radius, height): the ring yaws about Y against the banked masts and
# layers, so two parts can meet only where both coordinates agree.
static func yaw_gap(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var gap := INF
	for p in a:
		var pr := Vector2(p.x, p.z).length()
		for q in b:
			gap = minf(gap, Vector2(pr - Vector2(q.x, q.z).length(), p.y - q.y).length())
	return gap


# The crown: each fork has copper prong points above and below its marker; no ring vertex enters the
# ChargeHalo's volume at the markers' midpoint (its widest hoop, the hoops' and sleeve's run along +Z);
# the ring reaches between CROWN_BOLD and CROWN_REACH, stays off the plating above the band, clears the
# masts in (horizontal radius, height), and is closed.
func _check_crown(shell: Node, ring: MeshInstance3D, el: Node3D, er: Node3D) -> void:
	var prongs := {"L": [0, 0], "R": [0, 0]}
	var pts := PackedVector3Array()
	if ring != null:
		pts = points(ring, ring.get_parent())
		for v in points(ring, ring.get_parent(), "copper"):
			for pair in [["L", el], ["R", er]]:
				var m := pair[1] as Node3D
				if m != null and absf(v.x - m.position.x) < 0.001 and absf(v.y - m.position.y) < 0.11 and absf(v.z) < 0.06:
					prongs[pair[0]][0 if v.y > m.position.y else 1] += 1
	_report("sable crown forks", prongs.L[0] >= 4 and prongs.L[1] >= 4 and prongs.R[0] >= 4 and prongs.R[1] >= 4,
		"copper prong points above/below each fork mouth: L %s, R %s" % [prongs.L, prongs.R])
	var mid := (el.position + er.position) * 0.5 if el != null and er != null else Vector3.ZERO
	var wide := ChargeHalo.RADIUS_START + CROWN_CLEAR
	var back := maxf(ChargeHalo.HOOP_PITCH * (ChargeHalo.HOOPS - 1), ChargeHalo.SLEEVE_TO) + CROWN_CLEAR
	var inside := 0
	var reach := 0.0
	var plating := INF
	for p in pts:
		reach = maxf(reach, p.length())
		var d := p - mid
		if Vector2(d.x, d.y).length() < wide and d.z > ChargeHalo.SLEEVE_FROM - CROWN_CLEAR and d.z < back:
			inside += 1
		if p.y > CROWN_FROM:
			plating = minf(plating, p.length())
	_report("sable crown gap clear", el != null and inside == 0,
		"%d ring vertices inside the halo's %.2f m hoop and %.2f m run at %s" % [inside, wide, back, mid])
	var mark_reach := maxf(el.position.length(), er.position.length()) if el != null and er != null else INF
	_report("sable crown reach", not pts.is_empty() and reach >= CROWN_BOLD and reach <= CROWN_REACH and mark_reach <= CROWN_REACH,
		"ring reaches %.4f m (bold %.2f, cap %.2f), fork mouths %.4f m" % [reach, CROWN_BOLD, CROWN_REACH, mark_reach])
	_report("sable crown off the plating", plating >= CORE_LIMIT, "nearest crown vertex %.4f m from the centre, plating %.3f" % [plating, CORE_LIMIT])
	var masts := PackedVector3Array()
	for n in ["SpoolKit", "CoilMast"]:
		var node := shell.find_child(n, true, false)
		if node != null:
			masts.append_array(points_above(node, shell, 0.5))
	var crown := PackedVector3Array()
	for p in pts:
		if p.y > CROWN_FROM:
			crown.append(p)
	var gap := yaw_gap(crown, masts)
	_report("sable crown clears the masts", not masts.is_empty() and gap >= CROWN_CLEAR,
		"nearest crown-to-mast distance in (horizontal radius, height) %.4f m, want %.2f at any aim" % [gap, CROWN_CLEAR])
	var edges := open_edges(ring) if ring != null else Vector2i(-1, -1)
	_report("sable ring closed", edges == Vector2i.ZERO, "WeaponRing welded: %d open, %d non-manifold edges" % [edges.x, edges.y])


# Open (one triangle) and non-manifold (three or more) edges of a mesh's triangles over every surface,
# welded by position (check_manifold.py's rule, POLISH.md "Watertight"). Godot's import compresses each
# surface's positions on its own, so a seam between two surfaces lands a few hundredths of a millimetre
# apart: vertices within WELD of an earlier one take its key.
const WELD := 0.0002
const WELD_CELL := 0.001


static func open_edges(mi: MeshInstance3D) -> Vector2i:
	var grid := {}
	var canon: Array[Vector3] = []
	var count := {}
	for i in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var keys := PackedInt32Array()
		for v in verts:
			keys.append(_weld(v, grid, canon))
		var index = arrays[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array = index if index != null else PackedInt32Array(range(verts.size()))
		for t in range(0, idx.size() - 2, 3):
			var tri := [keys[idx[t]], keys[idx[t + 1]], keys[idx[t + 2]]]
			if tri[0] == tri[1] or tri[1] == tri[2] or tri[0] == tri[2]:
				continue
			for k in 3:
				var e := Vector2i(mini(tri[k], tri[(k + 1) % 3]), maxi(tri[k], tri[(k + 1) % 3]))
				count[e] = int(count.get(e, 0)) + 1
	var out := Vector2i.ZERO
	for n in count.values():
		if n == 1:
			out.x += 1
		elif n >= 3:
			out.y += 1
	return out


static func _weld(v: Vector3, grid: Dictionary, canon: Array[Vector3]) -> int:
	var c := Vector3i((v / WELD_CELL).floor())
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for k in grid.get(c + Vector3i(dx, dy, dz), []):
					if canon[k].distance_to(v) <= WELD:
						return k
	canon.append(v)
	if not grid.has(c):
		grid[c] = []
	(grid[c] as Array).append(canon.size() - 1)
	return canon.size() - 1


func _check_machinery(shell: Node) -> void:
	var pod := shell.find_child("Pod", true, false) as MeshInstance3D
	var mast := shell.find_child("CoilMast", true, false) as MeshInstance3D
	var rack := shell.find_child("WrenchRack", true, false) as MeshInstance3D
	_report("sable mast and rack meshes", mast != null and rack != null and pod != null, "CoilMast and WrenchRack are mesh nodes")
	if mast == null or rack == null or pod == null:
		return
	_report("sable mast parent", mast.get_parent() == pod and rack.get_parent() == pod, "CoilMast and WrenchRack ride the upright Pod")
	var tip := points(mast, shell)
	var top := Vector3.ZERO
	for p in tip:
		if p.y > top.y:
			top = p
	_report("sable mast height", absf(top.y - MAST_TOP) <= TOL and Vector2(top.x + MAST_X, top.z).length() <= 0.015,
		"mint tip's point at %s, want X %.2f Y %.2f on the left mast" % [top, -MAST_X, MAST_TOP])
	_report("sable mast clock", clock(top) >= 10.5 and clock(top) <= 11.5, "mast at %.2f o'clock from behind, want 11" % clock(top))
	# Nothing outboard stands level: the Pod mesh stays inside the plating, everything past it banks.
	var baked := far(points(pod, shell))
	_report("sable pod inside", baked <= CORE_LIMIT, "the level Pod mesh reaches %.4f m, plating %.3f" % [baked, CORE_LIMIT])
	# Accent surfaces: the mast tip and the rack, nothing else on the shell.
	var accents := []
	for mi in meshes(shell):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == "class_accent":
				accents.append(String(mi.name))
	accents.sort()
	_report("sable accent surfaces", accents == ["CoilMast", "WrenchRack"], "class_accent only on the mast tip and the rack: %s" % [accents])
	_report("sable mast surface", mast.mesh.get_surface_count() == 1 and HeroAssets.slot_of(mast.mesh, 0) == "class_accent",
		"the mint tip is the CoilMast node's one class_accent surface")
	# Spool: the Pod's reach at 3 o'clock; the masts mirrored at 11 and 1.
	var spool_r := 0.0
	var one_r := 0.0
	var eleven_r := 0.0
	var all_pod := points(pod, shell)
	all_pod.append_array(tip)
	# The spool is its own mesh under the Pod (SpoolKit, so the carrier bank tilts it), still part of the Pod's reach.
	var spool := shell.find_child("SpoolKit", true, false) as MeshInstance3D
	_report("sable spool kit parent", spool != null and spool.get_parent() == pod, "SpoolKit is a direct child of the Pod")
	if spool != null:
		all_pod.append_array(points(spool, shell))
	for p in all_pod:
		var c := clock(p)
		if c >= 2.5 and c <= 3.75:
			spool_r = maxf(spool_r, p.length())
		if c >= 0.5 and c <= 1.5:
			one_r = maxf(one_r, p.length())
		if c >= 10.5 and c <= 11.5:
			eleven_r = maxf(eleven_r, p.length())
	_report("sable spool bulge", absf(spool_r - (LATTICE_OUT + SPOOL_PAST)) <= TOL,
		"Pod reaches %.3f at 3 o'clock, want %.3f (0.12 m past the lattice)" % [spool_r, LATTICE_OUT + SPOOL_PAST])
	_report("sable masts mirrored", one_r > 1.2 and absf(one_r - eleven_r) <= 0.001,
		"Pod reaches %.3f at 1 o'clock and %.3f at 11: one mast each side" % [one_r, eleven_r])
	var column := 0
	var stray := 0
	if spool != null:
		for p in points(spool, shell):
			if p.y < 0.75:
				continue
			if Vector2(absf(p.x) - MAST_X, p.z).length() <= MAST_WIDE:
				column += 1
			else:
				stray += 1
	_report("sable mast columns", column > 0 and stray == 0,
		"%d SpoolKit vertices above Y 0.75 within %.3f m of the X -/+%.2f axes, %d outside" % [column, MAST_WIDE, MAST_X, stray])
	# Rope: the fairlead carriage (MOTION-SPEC swing row) carries RopeExit round the collar at 1.06,
	# outside the 1.0 collider, so the rope never leaves the centre. Fitted on a fresh load.
	var fitted := _load(SHELL)
	var fitted_pod := fitted.find_child("Pod", true, false) as Node3D
	HeroAssets.add_fairlead(fitted_pod)
	var rope := fitted_pod.find_child("RopeExit", true, false) as Node3D
	var rope_at := to_root(rope, fitted).origin if rope != null else Vector3.ZERO
	_report("sable rope exit", rope != null and rope.get_parent().name == "Fairlead" and absf(rope_at.length() - 1.06) <= 0.001
		and absf(rope_at.y) <= 0.001, "RopeExit rides the Fairlead carriage at radius 1.06 on the flat, %s" % rope_at)
	fitted.free()
	# Rack: one mesh, one class_accent surface, five index bands in COLOR.r (rail, four wrenches).
	_report("sable rack surface", rack.mesh.get_surface_count() == 1 and HeroAssets.slot_of(rack.mesh, 0) == "class_accent",
		"WrenchRack is one class_accent surface")
	var bands := {}
	var cols = rack.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	if cols != null:
		for c in cols:
			bands[snappedf((c as Color).r, 0.05)] = true
	var keys := bands.keys()
	keys.sort()
	_report("sable rack index", keys == [0.0, 0.25, 0.5, 0.75, 1.0], "COLOR.r index bands %s, want rail 0 and wrenches 0.25 to 1.0" % [keys])
	var rack_pts := points(rack, shell)
	var behind := true
	for p in rack_pts:
		behind = behind and p.z > 0.24 and p.y < -0.04
	_report("sable rack on seat back", behind and not rack_pts.is_empty(), "rack behind the seat back, below the sight cone")


func _check_materials(shell: Node) -> void:
	var bad := problems(shell)
	_report("sable contract", bad.is_empty(), "no glass, Fleet or requisition slot, light or material_override (%s)" % [bad])
	var enamels := [Palette.VERDIGRIS, Palette.RUST, Palette.SAND, Palette.CHARCOAL]
	var off := 0
	var seat_off := 0
	for mi in meshes(shell):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) != "paint":
				continue
			var cols = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			for c in Array(cols if cols != null else []):
				if not near_any(c, enamels):
					off += 1
				if String(mi.name) == "Pod" and not near_any(c, [Palette.SAND]):
					seat_off += 1
	_report("sable paint", off == 0, "paint vertex colours are section 6 enamels (%d off)" % off)
	_report_mask("sable", shell)
	# A string check on the shader source, not a render: the mask is step(0.05, alpha) on paint_take, fed from COLOR.a.
	var src: String = HeroAssets.PAINT_SHADER
	_report("sable paint shader mask", src.contains("paint_take * step(0.05, mask)"),
		"PAINT_SHADER masks paint_take with step(0.05, COLOR.a) (string check)")
	_report("sable seat bone", seat_off == 0, "every Pod paint face (seat, decal plate, rope drum) is bone (%d off)" % seat_off)


# SpoolKit's charcoal paint vertices carry alpha 0 (no paint takes them); every other paint vertex has alpha 1.
func _report_mask(label: String, root: Node) -> void:
	var dark := 0
	var spool_off := 0
	var other_off := 0
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) != "paint":
				continue
			var cols = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			for c in Array(cols if cols != null else []):
				if String(mi.name) == "SpoolKit" and near_any(c, [Palette.CHARCOAL]):
					dark += 1
					if c.a != 0.0:
						spool_off += 1
				elif c.a != 1.0:
					other_off += 1
	_report("%s spool paint mask" % label, dark == SPOOL_DARK_LOOPS and spool_off == 0,
		"%d SpoolKit charcoal paint vertices, %d with alpha not 0 (alpha 0 keeps them charcoal under any paint)" % [dark, spool_off])
	_report("%s other paint alpha" % label, other_off == 0, "every other paint vertex has alpha 1 (%d off)" % other_off)


func _check_layers(shell: Node) -> void:
	# The crown: ring vertices above the band.
	var crown := PackedVector3Array()
	var ring := shell.find_child("WeaponRing", true, false) as MeshInstance3D
	if ring != null:
		crown = points_above(ring, shell, CROWN_FROM)
	for n in [2, 3, 4, 5]:
		var layer := _load(LAYER % n)
		var core := layer.find_child("Core", true, false)
		var pod := layer.find_child("Pod", true, false) as Node3D
		var c := counts(layer)
		_report("sable c%d split" % n, core != null and pod != null, "Core and Pod at the top, panels on the Pod")
		_report("sable c%d budget" % n, c.t <= LAYER_TRIS and problems(layer).is_empty(),
			"%d triangles within %d, clean slots and no overrides" % [c.t, LAYER_TRIS])
		var cap := 2 if n == 3 else 1
		_report("sable c%d draws" % n, c.s <= cap, "%d surfaces, layer cap %d (class III 2, others 1)" % [c.s, cap])
		if pod is MeshInstance3D:
			var pod_slots := []
			for i in (pod as MeshInstance3D).mesh.get_surface_count():
				pod_slots.append(HeroAssets.slot_of((pod as MeshInstance3D).mesh, i))
			var pts := points(pod as MeshInstance3D, layer)
			var top := -INF
			var out_r := 0.0
			for p in pts:
				top = maxf(top, p.y)
				out_r = maxf(out_r, p.length())
			if n == 2:
				_report("sable c2 low", top < -0.35, "class II panels top out at Y %.3f, below -0.35" % top)
			_report("sable c%d panels" % n, pod_slots == ["paint"] and out_r <= 0.93, "one paint surface inside the lattice (%s, reach %.3f)" % [pod_slots, out_r])
		elif n == 5:
			# The doubled coil is a banked bracket part (CoilMast) under the layer's empty Pod, wound round the left mast.
			var coil := pod.get_node_or_null("CoilMast") as MeshInstance3D if pod != null else null
			var coil_slots := []
			var off_axis := Vector2(INF, 0.0)
			var lo := INF
			var hi := -INF
			if coil != null:
				for i in coil.mesh.get_surface_count():
					coil_slots.append(HeroAssets.slot_of(coil.mesh, i))
				for p in points(coil, layer):
					var r := Vector2(p.x + MAST_X, p.z).length()
					off_axis = Vector2(minf(off_axis.x, r), maxf(off_axis.y, r))
					lo = minf(lo, p.y)
					hi = maxf(hi, p.y)
			_report("sable c5 heavy coil", coil_slots == ["copper"] and off_axis.x >= 0.1 and off_axis.y <= 0.16 and lo >= 0.9 and hi <= 1.09,
				"the doubled coil is a banked CoilMast with one copper surface (%s) wound %.3f..%.3f m round the left mast from Y %.3f to %.3f"
				% [coil_slots, off_axis.x, off_axis.y, lo, hi])
		var gap := yaw_gap(crown, points_above(layer, layer, -INF))
		_report("sable c%d clears the crown" % n, not crown.is_empty() and gap >= CROWN_CLEAR,
			"nearest layer vertex %.3f m from the crown in (horizontal radius, height) (%d crown vertices), want %.2f at any aim"
			% [gap, crown.size(), CROWN_CLEAR])
		if n == 3:
			var caps := far(points(core as MeshInstance3D, layer)) if core is MeshInstance3D else INF
			_report("sable c3 caps", caps <= CORE_LIMIT + 0.0001, "thicker tread caps reach %.4f, limit %.3f" % [caps, CORE_LIMIT])
		if n == 5:
			# The winding replaces nothing: the base CoilMast mint tip stays the mast's class_accent.
			var replaces := layer.find_children("Replace_*", "", true, false)
			_report("sable c5 keeps the tip", replaces.is_empty(), "no Replace_ node in c5 (%d), so the base mint tip shows" % replaces.size())
		layer.free()


func _check_felt(shell: Node) -> void:
	var felt := _load(FELT)
	var same := true
	for n in ["CoilMast", "RopeExit", "WrenchRack", "Control_GaugeLever"]:
		var a := shell.find_child(n, true, false) as Node3D
		var b := felt.find_child(n, true, false) as Node3D
		same = same and a != null and b != null and to_root(a, shell).origin.distance_to(to_root(b, felt).origin) < 0.001
	_report("sable felt machinery", same, "Felt Rig keeps the mast, rope exit, rack and bank where the default has them")
	var core := felt.find_child("Core", true, false) as MeshInstance3D
	var r := far(points(core, felt)) if core != null else INF
	_report("sable felt lattice", r <= CORE_LIMIT + 0.0001 and problems(felt).is_empty(), "Felt Rig lattice reaches %.4f, clean slots" % r)
	_report_mask("sable felt", felt)
	felt.free()


func _initialize() -> void:
	var shell := _load(SHELL)
	var rig := _load(RIG)
	_check_budget(shell, rig)
	_check_tree(shell)
	_check_machinery(shell)
	_check_materials(shell)
	_check_layers(shell)
	_check_felt(shell)
	_check_rig(rig)
	shell.free()
	rig.free()
	_report("sable check count", _checks + 1 == EXPECTED_CHECKS, "%d checks, want %d" % [_checks + 1, EXPECTED_CHECKS])
	print("world_one_shell_sable_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
