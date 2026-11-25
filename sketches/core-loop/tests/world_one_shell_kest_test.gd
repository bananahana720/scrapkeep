extends SceneTree
# 2026-11-23 (E2-03, wave 46, ruling en): the launchers become two heroic mortar pods flanking the
# cutaway ball (heroic-cutaway concept 05): olive housings, flared steel bells forward, brass
# canisters, hazard stripes, the glow on the fuse caps and in the bell throats. They ride Mortar
# under WeaponRing (the carrier bank tilts them off walls), pivoting on a trunnion line under the
# pods (MORTAR_PIVOT moves). Mortar answers to its own reach (MORTAR_REACH, 1.70) and the Pod
# subtree keeps REACH; each pose (rest, the throw kick, ready, riding) stays outside the plating,
# above Y -0.55 and clear of the open vents. The vents become hinges carrying their slats as
# VaneL_Blade / VaneR_Blade, so a throw can flick the blade while hero_assets steers the hinge.
# Paint gains the Mortar's olive, steel, brass and stripe; the lattice pins go (the cutaway hides
# them), and every mesh is closed. EXPECTED_CHECKS 67 -> 70.
# 2026-10-10 (PD-KEST fix round): the gate's findings. Mortar is its own mesh under WeaponRing
# with its origin on the cradle line, so the tubes and fuse tips pitch and recoil (pilots/kest.md
# section 5): surfaces 14 -> 15, the one glow moves from WeaponRing to Mortar, and a new check
# turns Mortar and watches the tubes move. The satchel bands are ochre (kest/hero.png) and carry
# their index in UV2.x (1 to 3; 4 on the class IV satchel, whose faces carry UV2.y = 4); the class
# IV satchel moved from the c4 layer (it hung on the Pod, which does not follow the ring's aim)
# into the ring at 7:30, so the c4 check now wants no satchel in any layer. Two new checks: the
# band indices and the band colour. EXPECTED_CHECKS 64 -> 67.
# 2026-10-10 (PD-KEST): rewritten for the Hoberman mecha. The C09 glass-pod checks (one glass
# surface, the old pod bounds, the kept satchel, mortar and vane vertices against the old
# shell) no longer describe Kest's shell: shell_kest.py now builds on shell_base.hoberman() from
# the approved concept set (concepts/codex/kest/). The new checks follow P-UNITS PD-KEST and
# ROSTER-LOOK sections 0 to 6: node tree and controls, budget and the 14-surface draw count, the
# vents at 2 and 10 o'clock (0.10 m past the lattice folded, 0.25 m open, clear of the sight
# cone and the weapon band), the twin launchers at 11 and 1 o'clock with the only glow, the
# satchels flat on the ring, the petrol seat, the four heft layers and the Roost Frame variant.
# The pilot rig checks are unchanged (the body stays this wave, C9).
#
# What it checks, in order:
#   budget    shell surfaces 15; tris without the pilot 3,000 to 6,500; verts within the shell
#             class; shell plus rig under the 19,000 T / 18,000 V / 21 draw pod ceiling.
#   tree      named nodes and parents, no FlightStick, exactly two pedals.
#   materials section 9 slots only, no glass or requisition_tag, paint colours petrol, oxide,
#             bone or charcoal (the Mortar adds olive, steel, brass and stripe), one class_accent
#             surface (Mortar, on both fuse caps and in both bell throats), the petrol seat.
#   lattice   Core radius 0.95 to 0.985 with Hub_00..Hub_31 and Gap_00..Gap_29.
#   pod       sight cone empty (Gyro, WeaponRing and Dome skipped), no reach past 1.0 below -0.6,
#             nothing but the Mortar past 1.25.
#   vents     per vent (the hinge turns, its blade carries the slats): hinge radius, folded and open reach, folded clock, open band clearance and
#             open sight cone.
#   ring      pod mouths outboard of the plating and forward, satchels at 3, 6 and 9 hanging flat,
#             the band indices in UV2 and the ochre band colour, Mortar pitching about the trunnion
#             line, and in every pose within MORTAR_REACH, above Y -0.55, outside the plating and
#             out of the open vents at any ring yaw.
#   closed    every mesh, base and Roost Frame: no open or non-manifold edge.
#   layers    c2..c5: Core and Pod nodes, surface count, bone and charcoal paint, panels inside
#             0.92 m, sight cone and low reach; c3's rims on Core; no satchel (it rides the ring).
#   variant   the Roost Frame keeps the machinery and node tree, with its own lattice.
#   rig       the 25-bone rig, its meshes, triangles and the seven clips.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Revolvers := preload("res://tests/rivet_revolvers_test.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

const EXPECTED_CHECKS := 70
const SHELL := "res://assets/models/world_one/shell_kest.glb"
const ROOST := "res://assets/models/world_one/shell_kest_roost.glb"
const LAYER := "res://assets/models/world_one/shell_kest_c%d.glb"
const RIG := "res://assets/models/pilot_kest_anim.glb"
const SURFACES := 15
const SHELL_TRIS := Vector2i(3000, 6500)
const SHELL_VERTS := 11600
# 2026-10-18 coordinator call: polish raises the pod ceiling from 16,000 T / 15,000 V to
# 19,000 T / 18,000 V, pending the 4080 densest-fight frame check; if it misses budget,
# Kest returns unpolished.
const MAX_V := 18000
const MAX_T := 19000
const MAX_DRAWS := 21
const LATTICE_OUTER := 0.975
const CORE_LIMIT := 0.985
const REACH := 1.25
# Ruling en: the Mortar's pods reach at most 1.70 m, keep outside the 0.985 m plating (1.0 with
# margin) and above Y -0.55 (shell_kest.REACH, PLATING, LOW_Z).
const MORTAR_REACH := 1.70
const PLATING := 1.0
const MORTAR_LOW := -0.55
const PANEL_OUT := 0.92
const BAND_TOP := 0.04
# The satchel band stripe: shell_kest_plates.BAND_COLOR, amber mixed 0.3 toward oxide in sRGB.
const OCHRE := Color(206.8 / 255.0, 136.3 / 255.0, 65.0 / 255.0)
# Mortar pivots on the trunnion line under the pods (shell_kest.MORTAR_PIVOT, Blender (0, 0.33, -0.17)).
const MORTAR_PIVOT := Vector3(0.0, -0.17, -0.33)
# The Mortar's poses (shell_kest.POSES): rotation.x degrees and recoil along +Z (back): rest, the
# throw kick (clips/kest.json, 0.09 m from any stance), ready and riding (kest_kit.kest_cage_state:
# -pitch, its 0.08 m ride-beat recoil inside the kick's 0.09).
const POSES := {"rest": [0.0, 0.0], "kick": [0.0, 0.09], "ready": [-20.0, 0.0], "ready kick": [-20.0, 0.09],
	"riding": [-45.0, 0.09]}
# The Mortar's extra paint (shell_kest.OLIVE, STEEL, brass, STRIPE: sRGB mixes).
const OLIVE := Color("365754") * 0.6 + Color("d9b44a") * 0.4
const STRIPE := Color("e5a044") * 0.5 + Color("d9b44a") * 0.5
const MORTAR_PAINT := [OLIVE, STRIPE, Palette.STEEL, Palette.BRASS]
# The fuse caps sit on the housing tops (shell_kest POD_Z + HOUSING half height, 0.18 m); the
# throats lie within 0.2 m of a bell mouth.
const CAP_Y := 0.175
const THROAT := 0.2
# Godot axes: the head and the chase eyes (cage_contract_test.gd, ROSTER-LOOK section 3 rule 3).
const HEAD := Vector3(0.0, 0.20, -0.02)
const EYES := [Vector3(0.0, 1.06, 3.44), Vector3(0.0, 2.22, 7.17), Vector3(0.0, 3.55, 11.46)]
const SIGHT_HALF_ANGLE := 35.0
const CONE_SKIP := ["Gyro", "WeaponRing", "Dome"]
const NODES := ["Core", "Hub_00", "Hub_31", "Gap_00", "Gap_29", "Pod", "Gyro", "GyroInner", "WeaponRing",
	"Mortar", "MortarMouth_L", "MortarMouth_R", "VaneL", "VaneR", "VaneL_Blade", "VaneR_Blade", "Dome", "Pilot", "DecalPlate",
	"Control_Grip_L", "Control_Grip_R", "Control_Trigger", "Control_FusePlunger", "Control_ChargeKey",
	"Control_LapBar", "LapBar_L", "LapBar_R", "Control_Pedal_L", "Control_Pedal_R"]
const PARENTS := {"VaneL": "Pod", "VaneR": "Pod", "VaneL_Blade": "VaneL", "VaneR_Blade": "VaneR", "WeaponRing": "Pod", "Mortar": "WeaponRing", "Gyro": "Pod",
	"GyroInner": "Gyro", "Dome": "Pod", "Pilot": "Dome"}
const CLIPS := {"drop_land": 2.2, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const RIG_BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "crest", "ear.L", "ear.R",
	"goggles", "jaw", "snout", "shoulder.L", "upper_arm.L", "lower_arm.L", "hand.L", "curl.L",
	"shoulder.R", "upper_arm.R", "lower_arm.R", "hand.R", "curl.R", "tool.R", "tail.01", "tail.02",
]
const RIG_TRIS := Vector2i(10720, 10936)
const RIG_MESHES := {"Pilot": ["pilot"], "WingFan_L": ["pilot"], "WingFan_R": ["pilot"], "WingUpper_L": ["pilot"], "WingUpper_R": ["pilot"]}

var _t := T.new("world_one_shell_kest_test")


func _initialize() -> void:
	_run.call_deferred()


# --- helpers -----------------------------------------------------------------------------

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


static func under_any(node: Node, names: Array, stop: Node) -> bool:
	var n := node
	while n != null and n != stop:
		if String(n.name) in names:
			return true
		n = n.get_parent()
	return false


# Vertices of a mesh in root space, optionally one slot's surfaces only.
static func points(mi: MeshInstance3D, root: Node, slot := "") -> Array:
	var t := to_root(mi, root)
	var out := []
	for s in mi.mesh.get_surface_count():
		if slot != "" and HeroAssets.slot_of(mi.mesh, s) != slot:
			continue
		for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(t * v)
	return out


static func colors(mi: MeshInstance3D, slot: String) -> Array:
	var out := []
	for s in mi.mesh.get_surface_count():
		if HeroAssets.slot_of(mi.mesh, s) == slot:
			var cs = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			if cs != null:
				out.append_array(Array(cs))
	return out


static func counts(scene: Node) -> Dictionary:
	var out := {"v": 0, "t": 0, "s": 0, "t_no_pilot": 0}
	for mi in meshes(scene):
		for i in mi.mesh.get_surface_count():
			var arrays := (mi.mesh as Mesh).surface_get_arrays(i)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			var tris: int = (index.size() if index != null else vs.size()) / 3
			out.v += vs.size()
			out.t += tris
			out.s += 1
			if String(mi.name) != "Pilot":
				out.t_no_pilot += tris
	return out


static func near_any(c: Color, set: Array) -> bool:
	for p in set:
		var lin: Color = (p as Color).srgb_to_linear()
		if absf(c.r - lin.r) < 0.01 and absf(c.g - lin.g) < 0.01 and absf(c.b - lin.b) < 0.01:
			return true
	return false


static func in_cone(p: Vector3) -> bool:
	var d := p - HEAD
	if d.length() < 1e-6:
		return false
	var cos_half := cos(deg_to_rad(SIGHT_HALF_ANGLE))
	for e in EYES:
		if d.normalized().dot(((e as Vector3) - HEAD).normalized()) > cos_half:
			return true
	return false


# Solid Pod vertices in the sight cone, skipping the Gyro, WeaponRing and Dome subtrees.
static func cone_hits(scene: Node, pod: Node) -> int:
	var n := 0
	for mi in meshes(pod):
		if mi != pod and under_any(mi, CONE_SKIP, pod):
			continue
		for p in points(mi, scene):
			if in_cone(p):
				n += 1
	return n


static func low_reach(scene: Node, pod: Node) -> int:
	var n := 0
	for mi in meshes(pod):
		for p in points(mi, scene):
			if (p as Vector3).y < -0.6 and (p as Vector3).length() > 1.0:
				n += 1
	return n


static func far(pts: Array) -> float:
	var r := 0.0
	for p in pts:
		r = maxf(r, (p as Vector3).length())
	return r


func _load(path: String) -> Node:
	var packed := load(path) as PackedScene
	_t.check("loads " + path.get_file(), packed != null, path)
	return packed.instantiate() if packed != null else null


# --- checks ------------------------------------------------------------------------------

func _run() -> void:
	var shell := _load(SHELL)
	var rig := _load(RIG)
	if shell == null or rig == null:
		_finish()
		return
	_budget(shell, rig)
	_tree(shell)
	_materials(shell)
	_lattice(shell)
	var pod := shell.find_child("Pod", true, false)
	_t.check("pod sight cone", cone_hits(shell, pod) == 0, "%d solid Pod vertices in the 35 degree cone" % cone_hits(shell, pod))
	_t.check("pod low reach", low_reach(shell, pod) == 0, "%d Pod vertices past 1.0 m below Y -0.6" % low_reach(shell, pod))
	var reach := 0.0
	for mi in meshes(pod):
		if not under_any(mi, ["Dome", "Mortar"], pod):
			reach = maxf(reach, far(points(mi, shell)))
	_t.check("pod reach", reach <= REACH, "machinery but the Mortar reaches %.3f m, limit %.2f" % [reach, REACH])
	_vents(shell, pod)
	_ring(shell)
	for n in [2, 3, 4, 5]:
		_layer(n)
	_variant(shell)
	_closed("shell", shell)
	_check_rig(rig)
	shell.free()
	rig.free()
	_finish()


func _finish() -> void:
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _budget(shell: Node, rig: Node) -> void:
	var a := counts(shell)
	var b := counts(rig)
	_t.eq("shell surfaces", a.s, SURFACES)
	_t.check("shell tris", a.t_no_pilot >= SHELL_TRIS.x and a.t_no_pilot <= SHELL_TRIS.y,
		"%d tris without the pilot, band %d..%d" % [a.t_no_pilot, SHELL_TRIS.x, SHELL_TRIS.y])
	_t.check("shell verts", a.v <= SHELL_VERTS, "%d vertices, shell class %d" % [a.v, SHELL_VERTS])
	_t.check("pod ceiling", a.t + b.t <= MAX_T and a.v + b.v <= MAX_V and a.s + b.s <= MAX_DRAWS,
		"%d T, %d V, %d draws with the rig; ceiling %d T, %d V, %d draws" % [a.t + b.t, a.v + b.v, a.s + b.s, MAX_T, MAX_V, MAX_DRAWS])


func _tree(shell: Node) -> void:
	var missing := NODES.filter(func(n): return shell.find_child(n, true, false) == null)
	_t.check("nodes", missing.is_empty(), "missing %s" % [missing])
	var wrong := []
	for child in PARENTS:
		var node := shell.find_child(child, true, false)
		if node == null or String(node.get_parent().name) != PARENTS[child]:
			wrong.append(child)
	_t.check("parents", wrong.is_empty(), "nodes under the wrong parent %s" % [wrong])
	var pedals := shell.find_children("Control_Pedal*", "", true, false).size()
	_t.check("controls", shell.find_child("Control_FlightStick", true, false) == null and pedals == 2,
		"no FlightStick (the lap bar takes the ride), %d pedals, want 2" % pedals)


func _materials(shell: Node) -> void:
	var bad := []
	var accents := []
	var off := 0
	for mi in meshes(shell):
		for s in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, s)
			if not HeroAssets.SLOTS.has(slot) or slot in ["glass", "requisition_tag", "fleet_paint"]:
				bad.append("%s:%s" % [mi.name, slot])
			if slot == "class_accent":
				accents.append(String(mi.name))
		var allowed := [Palette.VERDIGRIS, Palette.RUST, Palette.SAND, Palette.CHARCOAL, OCHRE]
		if mi.name == &"Mortar":
			allowed.append_array(MORTAR_PAINT)
		for c in colors(mi, "paint"):
			if not near_any(c, allowed):
				off += 1
	_t.check("slots", bad.is_empty(), "section 9 slots, no glass or requisition_tag %s" % [bad])
	_t.check("paint colours", off == 0, "petrol, oxide, bone, charcoal, the ochre band or the Mortar's olive, steel, brass and stripe (%d off)" % off)
	_t.check("one glow", accents == ["Mortar"], "class_accent surfaces on %s, want only Mortar" % [accents])
	var mortar := shell.find_child("Mortar", true, false) as MeshInstance3D
	var mouths := [shell.find_child("MortarMouth_L", true, false), shell.find_child("MortarMouth_R", true, false)]
	var stray := 0
	var lit := {"cap -1": 0, "cap 1": 0, "throat -1": 0, "throat 1": 0}
	if mortar != null and mouths[0] != null and mouths[1] != null:
		for p in points(mortar, shell, "class_accent"):
			var side := int(signf(p.x))
			var mouth: Vector3 = to_root(mouths[0 if side < 0 else 1], shell).origin
			if p.y >= CAP_Y:
				lit["cap %d" % side] += 1
			elif p.distance_to(mouth) <= THROAT:
				lit["throat %d" % side] += 1
			else:
				stray += 1
	_t.check("glow on the fuse caps and in the throats", mortar != null and stray == 0 and lit.values().all(func(n): return n > 0),
		"%d class_accent vertices off a cap or a throat; lit vertices by part and side %s" % [stray, lit])
	var pod := shell.find_child("Pod", true, false) as MeshInstance3D
	var seat := AABB(Vector3(-0.25, -0.45, -0.3), Vector3(0.5, 0.4, 0.6))
	var seat_n := 0
	var seat_off := 0
	var t := to_root(pod, shell)
	for s in pod.mesh.get_surface_count():
		if HeroAssets.slot_of(pod.mesh, s) != "paint":
			continue
		var arrays := pod.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cs: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in vs.size():
			if seat.has_point(t * vs[i]):
				seat_n += 1
				if not near_any(cs[i], [Palette.VERDIGRIS]):
					seat_off += 1
	_t.check("petrol seat", seat_n > 0 and seat_off == 0, "%d seat paint vertices, %d not petrol" % [seat_n, seat_off])


func _lattice(shell: Node) -> void:
	var core := shell.find_child("Core", true, false) as MeshInstance3D
	var r := far(points(core, shell))
	var hubs := 0
	var gaps := 0
	for c in core.get_children():
		hubs += 1 if String(c.name).begins_with("Hub_") else 0
		gaps += 1 if String(c.name).begins_with("Gap_") else 0
	_t.check("lattice", r >= 0.95 and r <= CORE_LIMIT + 0.0001 and hubs == 32 and gaps == 30,
		"Core radius %.4f (0.95 to %.3f), %d hubs, %d gaps" % [r, CORE_LIMIT, hubs, gaps])


func _vents(shell: Node, pod: Node) -> void:
	for side in [-1.0, 1.0]:
		var name := "VaneL" if side < 0 else "VaneR"
		var vane := shell.find_child(name, true, false) as Node3D
		var blade := vane.get_node_or_null(name + "_Blade") as MeshInstance3D if vane != null else null
		if blade == null:
			for i in 6:
				_t.check(name, false, "missing")
			continue
		var hinge := to_root(vane, shell).origin
		_t.check(name + " hinge", absf(hinge.length() - 0.90) < 0.01 and signf(hinge.x) == side,
			"hinge at %s, radius %.3f, side %d" % [hinge, hinge.length(), side])
		var folded := points(blade, shell)
		var tip: Vector3 = folded[0]
		for p in folded:
			if (p as Vector3).length() > tip.length():
				tip = p
		var clock := rad_to_deg(atan2(absf(tip.x), tip.y))
		_t.check(name + " folded", absf(tip.length() - LATTICE_OUTER - 0.10) <= 0.03 and clock >= 45.0 and clock <= 75.0,
			"tip %.3f m past the lattice (0.10 +/-0.03) at %.0f degrees from the top (2 or 10 o'clock: 45 to 75)" % [tip.length() - LATTICE_OUTER, clock])
		vane.rotation.z = -side * PI * 0.5
		var opened := points(blade, shell)
		var o_far := far(opened)
		_t.check(name + " open", absf(o_far - LATTICE_OUTER - 0.25) <= 0.03 and o_far <= REACH,
			"open %.3f m past the lattice (0.25 +/-0.03), radius %.3f, limit %.2f" % [o_far - LATTICE_OUTER, o_far, REACH])
		var low := INF
		var cone := 0
		for p in opened:
			if (p as Vector3).length() > 0.98:
				low = minf(low, (p as Vector3).y)
			if in_cone(p):
				cone += 1
		_t.check(name + " open over the band", low > BAND_TOP + 0.05, "lowest open point past 0.98 m at Y %.3f, band top %.2f" % [low, BAND_TOP])
		_t.check(name + " open sight cone", cone == 0, "%d open vent vertices in the sight cone" % cone)
		var out_x := 0.0
		for p in opened:
			out_x = maxf(out_x, (p as Vector3).x * side)
		var spread: bool = tip.x * side > 0.0 and out_x > 1.0
		_t.check(name + " opens outward", spread, "open vent reaches past 1.0 m on its own side")
		vane.rotation.z = 0.0


func _ring(shell: Node) -> void:
	var mouths := []
	for tag in ["L", "R"]:
		var m := shell.find_child("MortarMouth_" + tag, true, false) as Node3D
		mouths.append(to_root(m, shell).origin if m != null else Vector3.ZERO)
	var ok := true
	for i in 2:
		var p: Vector3 = mouths[i]
		ok = ok and p.z < -0.7 and absf(p.x) >= 1.15 and absf(p.x) <= 1.35 and absf(p.y) < 0.15 and signf(p.x) == (-1.0 if i == 0 else 1.0)
	_t.check("pods flank the plating", ok, "mouths %s: forward (Godot -Z past 0.7), 1.15 to 1.35 m out on their own side, at the band" % [mouths])
	var ring := shell.find_child("WeaponRing", true, false) as MeshInstance3D
	var bins := {90: 0, 180: 0, 270: 0}
	var y_lo := INF
	var y_hi := -INF
	for p in points(ring, shell, "paint"):
		var flat := Vector2(p.x, p.z)
		if flat.length() < 1.12:
			continue
		var clock := fposmod(rad_to_deg(atan2(p.x, -p.z)), 360.0)
		for b in bins:
			if absf(clock - b) < 12.0:
				bins[b] += 1
				y_lo = minf(y_lo, p.y)
				y_hi = maxf(y_hi, p.y)
	_t.check("satchels at 3, 6 and 9", bins.values().all(func(n): return n > 0),
		"satchel paint vertices by clock %s" % [bins])
	_t.check("satchels flat on the ring", y_lo >= -0.13 and y_hi <= BAND_TOP + 0.02,
		"satchels span Y %.3f to %.3f; they hang flat under the band top" % [y_lo, y_hi])
	_bands(shell, ring)
	_mortar(shell)


# The satchel bands: UV2.x is the band index on the ochre band faces, UV2.y the heft class a face
# shows from. Ungated bands are exactly {1, 2, 3}; the class IV satchel carries band 4, gated to 4,
# at 7:30 on the ring row.
func _bands(shell: Node, ring: MeshInstance3D) -> void:
	var open := {}
	var gated := {}
	var gate_off := 0
	var band_n := 0
	var band_off := 0
	for s in ring.mesh.get_surface_count():
		var arrays := ring.mesh.surface_get_arrays(s)
		var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
		if uv2 == null:
			continue
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cs = arrays[Mesh.ARRAY_COLOR]
		var t := to_root(ring, shell)
		for i in vs.size():
			var band := int(roundf((uv2 as PackedVector2Array)[i].x))
			var gate := int(roundf((uv2 as PackedVector2Array)[i].y))
			if gate != 0:
				var p: Vector3 = t * vs[i]
				var clock := fposmod(rad_to_deg(atan2(p.x, -p.z)), 360.0)
				if gate != 4 or absf(clock - 225.0) > 12.0:
					gate_off += 1
			if band == 0:
				continue
			band_n += 1
			if cs == null or not near_any((cs as PackedColorArray)[i], [OCHRE]):
				band_off += 1
			if gate == 0:
				open[band] = true
			else:
				gated[band] = true
	var open_keys := open.keys()
	open_keys.sort()
	_t.check("satchel bands", open_keys == [1, 2, 3] and gated.keys() == [4] and gate_off == 0,
		"ungated band indices %s (want [1, 2, 3]), gated %s (want [4]), %d gated vertices off the class IV satchel at 7:30" % [open_keys, gated.keys(), gate_off])
	_t.check("band colour", band_n > 0 and band_off == 0, "%d band vertices, %d not ochre" % [band_n, band_off])


# Mortar pitches about its cradle line: turning it moves the tubes.
func _mortar(shell: Node) -> void:
	var mortar := shell.find_child("Mortar", true, false) as MeshInstance3D
	if mortar == null:
		_t.check("mortar pitches", false, "Mortar is not a mesh")
		return
	var origin := to_root(mortar, shell).origin
	var before := points(mortar, shell)
	mortar.rotation.x = deg_to_rad(20.0)
	var after := points(mortar, shell)
	mortar.rotation.x = 0.0
	var moved := 0.0
	for i in before.size():
		moved = maxf(moved, ((after[i] as Vector3) - (before[i] as Vector3)).length())
	_t.check("mortar pitches", origin.distance_to(MORTAR_PIVOT) < 0.01 and moved > 0.02,
		"Mortar origin %s (trunnion line %s), pods move %.3f m at 20 degrees" % [origin, MORTAR_PIVOT, moved])
	_poses(shell, mortar)


# Every Mortar pose stays inside ruling en's reach, above the slope line and outside the plating,
# and no Mortar vertex enters an open vent's (radius, height) hull, so no ring yaw meets a vent.
func _poses(shell: Node, mortar: MeshInstance3D) -> void:
	var rest := mortar.position
	var hulls := []
	for name in ["VaneL", "VaneR"]:
		var vane := shell.find_child(name, true, false) as Node3D
		var blade := vane.get_node_or_null(name + "_Blade") as MeshInstance3D if vane != null else null
		if blade == null:
			continue
		var side := -1.0 if name == "VaneL" else 1.0
		vane.rotation.z = -side * PI * 0.5
		var flat := PackedVector2Array()
		for p in points(blade, shell):
			flat.append(Vector2(Vector2((p as Vector3).x, (p as Vector3).z).length(), (p as Vector3).y))
		hulls.append(Geometry2D.convex_hull(flat))
		vane.rotation.z = 0.0
	var report := {}
	var ok := hulls.size() == 2
	for pose in POSES:
		mortar.rotation.x = deg_to_rad(POSES[pose][0])
		mortar.position = rest + Vector3(0.0, 0.0, POSES[pose][1])
		var pts := points(mortar, shell)
		var reach := far(pts)
		var low := INF
		var near := INF
		var in_vent := 0
		for p in pts:
			low = minf(low, (p as Vector3).y)
			near = minf(near, (p as Vector3).length())
			var q := Vector2(Vector2((p as Vector3).x, (p as Vector3).z).length(), (p as Vector3).y)
			for h in hulls:
				if Geometry2D.is_point_in_polygon(q, h):
					in_vent += 1
		report[pose] = "reach %.3f, low %.3f, near %.3f, %d in a vent" % [reach, low, near, in_vent]
		ok = ok and reach <= MORTAR_REACH and low >= MORTAR_LOW and near >= PLATING and in_vent == 0
	mortar.rotation.x = 0.0
	mortar.position = rest
	_t.check("mortar poses", ok, "reach %.2f, low %.2f, plating %.2f, open vents: %s" % [MORTAR_REACH, MORTAR_LOW, PLATING, report])


func _closed(label: String, scene: Node) -> void:
	var open := {}
	for mi: MeshInstance3D in meshes(scene):
		var edges: Vector2i = Revolvers.open_edges(mi.mesh)
		if edges != Vector2i.ZERO:
			open[String(mi.name)] = edges
	_t.check(label + " closed: no open or non-manifold edge", open.is_empty(), "open, non-manifold per mesh %s" % [open])


func _layer(n: int) -> void:
	var scene := _load(LAYER % n)
	if scene == null:
		for i in 3:
			_t.check("c%d" % n, false, "missing")
		return
	var core := scene.find_child("Core", true, false)
	var pod := scene.find_child("Pod", true, false) as MeshInstance3D
	var c := counts(scene)
	_t.check("c%d nodes and draws" % n, core != null and pod != null and c.s == (2 if n == 3 else 1),
		"Core and Pod present, %d surfaces (want %d)" % [c.s, 2 if n == 3 else 1])
	var panel_far := 0.0
	var off := 0
	var outside := 0
	if pod != null:
		for p in points(pod, scene, "paint"):
			if (p as Vector3).length() < 1.0:
				panel_far = maxf(panel_far, (p as Vector3).length())
			else:
				outside += 1
		for col in colors(pod, "paint"):
			if not near_any(col, [Palette.SAND, Palette.CHARCOAL, Palette.RUST, Palette.VERDIGRIS]):
				off += 1
	var rule := panel_far <= PANEL_OUT + 0.0025 and off == 0 and outside == 0
	rule = rule and pod != null and cone_hits(scene, pod) == 0 and low_reach(scene, pod) == 0
	_t.check("c%d panels" % n, rule,
		"panels reach %.4f m (outer face %.2f), %d off-colour, %d vertices past 1.0 m (none: the class IV satchel rides the ring), sight cone and low reach clear"
		% [panel_far, PANEL_OUT, off, outside])
	if n == 3:
		var rims := core as MeshInstance3D
		var r := far(points(rims, scene)) if rims != null else 99.0
		var slot := HeroAssets.slot_of(rims.mesh, 0) if rims != null else ""
		_t.check("c3 tread rims", rims != null and slot == "rubber" and r <= CORE_LIMIT + 0.0001,
			"thicker tread caps on Core: %s slot, radius %.4f, limit %.3f" % [slot, r, CORE_LIMIT])
	else:
		_t.check("c%d core" % n, core != null and not (core is MeshInstance3D), "panels hang from the Pod; Core is an empty")
	scene.free()


func _variant(shell: Node) -> void:
	var roost := _load(ROOST)
	if roost == null:
		for i in 2:
			_t.check("roost", false, "missing")
		return
	var missing := NODES.filter(func(n): return roost.find_child(n, true, false) == null)
	var c := counts(roost)
	_t.check("roost tree", missing.is_empty() and c.s == SURFACES, "missing %s, %d surfaces" % [missing, c.s])
	var a := shell.find_child("Core", true, false) as MeshInstance3D
	var b := roost.find_child("Core", true, false) as MeshInstance3D
	var ta: int = counts(a).t
	var tb: int = counts(b).t
	var rb := far(points(b, roost))
	_t.check("roost lattice", tb < ta and rb <= CORE_LIMIT + 0.0001, "Roost Frame Core %d tris against the default %d, radius %.4f" % [tb, ta, rb])
	_closed("roost", roost)
	roost.free()


func _check_rig(rig: Node) -> void:
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	var names := []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
	_t.check("kest rig bones", skeletons.size() == 1 and names == RIG_BONES,
		"%d skeleton, %d bones; expected 1 skeleton and 25 ordered names" % [skeletons.size(), names.size()])
	var actual := {}
	for mi in meshes(rig):
		var materials := []
		for i in mi.mesh.get_surface_count():
			var material: Material = mi.mesh.surface_get_material(i)
			materials.append(material.resource_name if material != null else "<missing>")
		actual[String(mi.name)] = materials
	_t.check("kest rig meshes", actual == RIG_MESHES, "mesh material names %s, expected %s" % [actual, RIG_MESHES])
	var triangles: int = counts(rig).t
	_t.check("kest rig triangles", triangles >= RIG_TRIS.x and triangles <= RIG_TRIS.y,
		"%d triangles, range %d..%d" % [triangles, RIG_TRIS.x, RIG_TRIS.y])
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := []
	if player != null:
		clips = Array(player.get_animation_list())
	var lost := CLIPS.keys().filter(func(c): return not (c in clips))
	_t.check("kest rig clips", player != null and lost.is_empty(), "seven pilot clips present (missing %s)" % [lost])
	for clip in CLIPS:
		var length := player.get_animation(clip).length if clip in clips else -1.0
		_t.check("kest rig length " + clip, absf(length - CLIPS[clip]) <= 0.001,
			"%.6f seconds, expected %.6f +/-0.001" % [length, CLIPS[clip]])
