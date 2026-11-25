extends SceneTree
# 2026-10-10 (PD-RIVET): re-pinned for the Hoberman mecha. The C08 glass pod checks (16,000 T pod
# ceiling with the rig, one glass surface, base-shell vertices and extents kept) are gone: the
# approved pictures (concepts/codex/rivet/hero.png, chase.png, sheet.png) replace the visor,
# optical rail, raked side fins and saddle with the lattice, the drill nose, folded fins, twin
# stacks and laser pods on the weapon ring. The rig checks are unchanged.
# 2026-10-10 (PD-RIVET fix round): class V drops the Pod-mounted heavy drill, whose lens turned with
# the heading while DrillTip yaws with the aim; c5 is one draw and keeps the aimed drill showing.
# New checks: the lens stays on DrillTip with the ring yawed 30 degrees, the base draws per mesh
# (pinned here, not read from the registry exception), and panels clear the drill's yaw sweep.
# 2026-10-10 (PD-RIVET fix round 2): rebuilt on PD-0b's base (struts 0.06 m, caps 0.10 m). The
# 16-draw Hoberman pilot mecha cap replaces the pending ratification (docs/decisions.tsv w13-PD).
# Class V is the five-step heavy drill on the layer's WeaponRing (PD-0b's heft-layer route) and
# its upper panels moved to class IV, since each layer but III is one draw. New checks: c5's
# drill steps and 0.20 m lens face, the drill inside the sweep band the panels keep out of, and
# the lens on DrillTip with the fitted shell's ring yawed 30 degrees (hero_assets fit_shell_into).
# The sweep band grows to the heavy drill.
# 2026-11-23 (E1-09, wave 46, ruling ek): rebuilt on E1-03's closed-bar base. The laser pods leave
# the ring for rivet_revolvers.glb (rivet_revolvers_test), which hero_assets mounts under WeaponRing;
# LaserMuzzle_L/R stay here, on its barrel tips. New checks: no pods left on the ring, and every
# mesh but the hidden placeholder pilot is closed (no open or non-manifold edge), base and variant.
# 2026-11-23 (E1-09b, wave 46, ruling en): the revolvers become side-sponson rotary cannons at 3 and
# 9 o'clock; LaserMuzzle_L/R sit 1 cm past their hub crowns, 1.26 m outboard and 0.91 m forward.

# What it checks (P-UNITS PD-RIVET acceptance; ROSTER-LOOK sections 0 to 8):
#   budget     shell class tris and verts; draws equal the registry row's exception.
#   contract   no glass or requisition_tag slot, light or material_override (cage_contract_test).
#   tree       32 hubs and 30 gaps on Core; Pod > Gyro > GyroInner, WeaponRing, Dome > Pilot;
#              Drill, DrillTip and the laser muzzles under WeaponRing; Exhaust_L/R under Pod;
#              no laser pods on the ring (its copper is the collar studs and the drill hanger);
#              the cockpit controls (Lever, WinchLever, the lap bar and two pedals).
#   drill      DrillTip faces forward on the centre line the parallel laser muzzles fire along;
#              the lens sits on DrillTip with the ring yawed 30 degrees; 0.12 m across; three steps.
#   draws      surfaces per mesh, pinned, within the 16-draw Hoberman pilot mecha cap.
#   stacks     at 11:30 and 12:30 from behind, rear, 0.18 m past the lattice outline.
#   accent     class_accent only on the lens (Drill) and the exhaust mouths (Pod).
#   outline    nothing breaks the outline at 4 or 8 o'clock from behind; fins lie flat on the
#              lattice in the front lower gaps on both sides, inside the 0.985 core limit.
#   colour     charcoal lattice enamel, bone seat.
#   pod        sight cone empty; nothing past radius 1.0 below Y -0.6.
#   closed     every mesh but the placeholder Pilot: no open or non-manifold edge (POLISH.md).
#   variant    shell_rivet_calibrated: budget, contract, closed, machinery at the same points.
#   layers     shell_rivet_c2 to _c4: Core and Pod parts, detail budget and draws, panels inside
#              the lattice, out of the sight cone and clear of the drill's yaw sweep; II all
#              below Y -0.35. c5: Pod > WeaponRing heavy drill, one draw, five steps, a lens face
#              0.20 m across, inside the sweep band, on DrillTip at a 30 degree ring yaw (fitted).
#   rig        pilot_rivet_anim.glb: 25 ordered bones, meshes, triangles, seven clips.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Palette := preload("res://src/core/palette.gd")
const Cage := preload("res://tests/cage_contract_test.gd")
const Revolvers := preload("res://tests/rivet_revolvers_test.gd")
const T := preload("res://tests/support/t.gd")

const SHELL := "res://assets/models/world_one/shell_rivet.glb"
const VARIANT := "res://assets/models/world_one/shell_rivet_calibrated.glb"
const LAYER := "res://assets/models/world_one/shell_rivet_c%d.glb"
const RIG := "res://assets/models/pilot_rivet_anim.glb"
const BUDGETS := "res://assets/asset_budgets.json"
const REGISTRY := "res://assets/registry.json"
const EXPECTED_CHECKS := 61
const CORE_LIMIT := 0.985
const LATTICE_OUTER := 0.975
const LATTICE_INNER := 0.94
const LENS := 0.12
const DRILL_STEPS := 3
const STACK_RISE := 0.18
const LAYER_DRAWS := {2: 1, 3: 2, 4: 1, 5: 1}
const DRAW_CAP := 16
const HEAVY_STEPS := 5
const HEAVY_LENS := 0.20
const DRILL_Y := -0.22
# Surfaces per mesh in shell_rivet.glb: PD-0's base (Core 3, Pod 3, Gyro 1, GyroInner 1, WeaponRing 2)
# plus the exhaust mouths on Pod, copper on WeaponRing, the Drill and the placeholder Pilot.
const BASE_DRAWS := {"Core": 3, "Pod": 4, "Gyro": 1, "GyroInner": 1, "WeaponRing": 3, "Drill": 2, "Pilot": 1}
# The band the drill sweeps as the ring yaws (Godot axes): horizontal radius past 0.85 m, height
# from -0.45 to 0.01 m, sized to the class V heavy drill (shell_rivet_plates.py SWEEP_R, SWEEP_Z).
const SWEEP_R := 0.85
const SWEEP_Y := Vector2(-0.45, 0.01)
const CONTROLS := ["Control_Grip_L", "Control_Grip_R", "Control_Trigger", "Control_Lever", "Control_WinchLever",
	"Control_LapBar", "LapBar_L", "LapBar_R", "Control_Pedal_L", "Control_Pedal_R", "DecalPlate"]
const MACHINERY := ["Drill", "DrillTip", "LaserMuzzle_L", "LaserMuzzle_R", "Exhaust_L", "Exhaust_R"]
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const RIG_BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "crest", "ear.L", "ear.R",
	"goggles", "jaw", "snout", "shoulder.L", "upper_arm.L", "lower_arm.L", "hand.L", "curl.L",
	"shoulder.R", "upper_arm.R", "lower_arm.R", "hand.R", "curl.R", "tool.R", "tail.01", "tail.02",
]
# The triangle range allows one percent of export variation.
const RIG_TRIS := Vector2i(10351, 10561)
const RIG_MESHES := {"Claws_L": ["pilot"], "Claws_R": ["pilot"], "Pilot": ["pilot"]}

var _t := T.new("world_one_shell_rivet_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shell := _load(SHELL)
	_t.check("shell loads", shell != null, SHELL)
	if shell == null:
		_finish()
		return
	root.add_child(shell)
	_budget("shell", shell, "shell", _exception(SHELL))
	_draws(shell)
	var problems := Cage.contract_problems(shell)
	_t.check("shell contract", problems.is_empty(), str(problems))
	_tree(shell)
	_drill(shell)
	_stacks(shell)
	_accent(shell)
	_outline(shell)
	_colours(shell)
	_pod(shell)
	_closed("shell", shell)
	_variant(shell)
	_layers()
	_check_rig()
	shell.queue_free()
	_finish()


func _finish() -> void:
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


# --- helpers -------------------------------------------------------------------------------------

static func _load(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null


static func meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else [])


static func slot_of(mesh: Mesh, surface: int) -> String:
	var mat := mesh.surface_get_material(surface)
	return mat.resource_name if mat != null else ""


# Vertices of one mesh in the scene root's space (the shell's own frame), optionally one slot.
static func points(mi: MeshInstance3D, top: Node3D, slot := "") -> PackedVector3Array:
	var xf := top.global_transform.affine_inverse() * mi.global_transform
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		if slot != "" and slot_of(mi.mesh, s) != slot:
			continue
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


static func at(top: Node3D, name: String) -> Node3D:
	return top.find_child(name, true, false) as Node3D


static func pos(top: Node3D, node: Node3D) -> Vector3:
	return (top.global_transform.affine_inverse() * node.global_transform).origin


static func counts(scene: Node) -> Dictionary:
	var out := {"tris": 0, "verts": 0, "draws": 0}
	for mi: MeshInstance3D in meshes(scene):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			out.draws += 1
			out.verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			out.tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return out


func _exception(path: String) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	for e in doc["assets"]:
		if e.get("path", "") == path:
			return e.get("exception", {})
	return {}


func _budget(label: String, scene: Node, klass: String, exception: Dictionary) -> void:
	var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"][klass]
	var c := counts(scene)
	var draws_cap := int(exception.get("draws", cap.draws))
	print("%s budget: %d tris, %d verts, %d draws" % [label, c.tris, c.verts, c.draws])
	_t.check(label + " tris and verts", c.tris > 0 and c.tris <= int(exception.get("tris", cap.tris))
		and c.verts <= int(exception.get("verts", cap.verts)), "%d tris within %d, %d verts within %d" % [c.tris, cap.tris, c.verts, cap.verts])
	_t.check(label + " draws", c.draws <= draws_cap, "%d draws within %d (%s)" % [c.draws, draws_cap, "registry exception" if exception.has("draws") else klass])


func _draws(shell: Node3D) -> void:
	var got := {}
	var total := 0
	for mi: MeshInstance3D in meshes(shell):
		got[String(mi.name)] = mi.mesh.get_surface_count()
		total += mi.mesh.get_surface_count()
	_t.check("shell draws per mesh", got == BASE_DRAWS and total <= DRAW_CAP, "%s (%d), want %s within %d" % [got, total, BASE_DRAWS, DRAW_CAP])


# --- the base mecha --------------------------------------------------------------------------------

func _tree(shell: Node3D) -> void:
	var core := at(shell, "Core")
	var pod := at(shell, "Pod")
	var marks := 0
	for i in 32:
		marks += 1 if core != null and core.get_node_or_null("Hub_%02d" % i) != null else 0
	for i in 30:
		marks += 1 if core != null and core.get_node_or_null("Gap_%02d" % i) != null else 0
	_t.eq("32 hubs and 30 gaps on Core", marks, 62)
	var gyro := pod.get_node_or_null("Gyro") if pod != null else null
	var dome := pod.get_node_or_null("Dome") if pod != null else null
	_t.check("Pod > Gyro > GyroInner, WeaponRing, Dome > Pilot", gyro != null and gyro.get_node_or_null("GyroInner") != null
		and pod.get_node_or_null("WeaponRing") != null and dome != null and dome.get_node_or_null("Pilot") is MeshInstance3D)
	var ring := pod.get_node_or_null("WeaponRing") if pod != null else null
	var on_ring := ["Drill", "DrillTip", "LaserMuzzle_L", "LaserMuzzle_R"].filter(func(n): return ring == null or ring.get_node_or_null(n) == null)
	_t.check("drill and laser muzzles ride WeaponRing", on_ring.is_empty() and ring.get_node("Drill") is MeshInstance3D, "missing %s" % [on_ring])
	# The laser pods sat on the band at 11 and 1 o'clock; the ring's copper is now the collar studs
	# (under the band) and the drill hanger (on the centre line).
	var pods := 0
	if ring is MeshInstance3D:
		for v in points(ring as MeshInstance3D, shell, "copper"):
			pods += 1 if v.y > -0.03 and absf(v.x) > 0.1 else 0
	_t.eq("no laser pods left on the ring", pods, 0)
	var on_pod := ["Exhaust_L", "Exhaust_R"].filter(func(n): return pod.get_node_or_null(n) == null)
	_t.check("exhausts ride Pod", on_pod.is_empty(), "missing %s" % [on_pod])
	var missing := CONTROLS.filter(func(n): return at(pod, n) == null)
	_t.check("cockpit controls", missing.is_empty(), "missing %s" % [missing])


func _drill(shell: Node3D) -> void:
	var tip := at(shell, "DrillTip")
	var left := at(shell, "LaserMuzzle_L")
	var right := at(shell, "LaserMuzzle_R")
	var drill := at(shell, "Drill") as MeshInstance3D
	var fwd := Vector3(0, 0, -1)
	var tip_fwd := -(tip.global_transform.basis.z).normalized()
	var lasers_fwd := [-(left.global_transform.basis.z).normalized(), -(right.global_transform.basis.z).normalized()]
	_t.check("DrillTip faces forward (+Y in Blender)", tip_fwd.dot(fwd) > 0.9999 and absf(pos(shell, tip).x) < 0.001,
		"forward %s at %s" % [tip_fwd, pos(shell, tip)])
	var lp := pos(shell, left)
	var rp := pos(shell, right)
	var tp := pos(shell, tip)
	_t.check("DrillTip lines up with the laser fire", lasers_fwd.all(func(f): return f.dot(tip_fwd) > 0.9999)
		and absf(lp.x + rp.x) < 0.001 and lp.x < -1.2 and rp.x > 1.2 and tp.z < -1.1 and lp.z < -0.85,
		"muzzles %s %s, tip %s, all firing %s" % [lp, rp, tp, tip_fwd])
	var lens := 0.0
	for v in points(drill, shell, "class_accent"):
		lens = maxf(lens, Vector2(v.x - tp.x, v.y - tp.y).length())
	_t.near("lens is 0.12 m across", lens * 2.0, LENS, 0.004)
	# The lens rides the aimed carrier: yaw the ring 30 degrees off the heading and it stays on DrillTip.
	var ring := at(shell, "WeaponRing")
	ring.rotation.y = deg_to_rad(30.0)
	var lens_pts := points(drill, shell, "class_accent")
	var centre := Vector3.ZERO
	for v in lens_pts:
		centre += v
	centre /= maxf(1.0, float(lens_pts.size()))
	var tip_yawed := pos(shell, tip)
	ring.rotation.y = 0.0
	_t.check("lens on DrillTip with the ring yawed 30 degrees", lens_pts.size() > 0 and centre.distance_to(tip_yawed) < 0.01
		and absf(tip_yawed.x) > 0.5, "lens centre %s, DrillTip %s" % [centre, tip_yawed])
	var levels := {}
	for v in points(drill, shell, "copper"):
		levels[snappedf(v.z, 0.005)] = true
	_t.eq("three drill steps (four shoulder planes)", levels.size(), DRILL_STEPS + 1)


func _stacks(shell: Node3D) -> void:
	for tag in ["L", "R"]:
		var p := pos(shell, at(shell, "Exhaust_" + tag))
		var clock := rad_to_deg(atan2(p.x, p.y))
		var outline := sqrt(LATTICE_OUTER * LATTICE_OUTER - p.x * p.x - p.z * p.z)
		var side_ok := p.x < 0.0 if tag == "L" else p.x > 0.0
		_t.check("stack %s at %s:30, rear, 0.18 m up" % [tag, "11" if tag == "L" else "12"],
			side_ok and absf(absf(clock) - 15.0) < 4.0 and p.z > 0.1 and absf(p.y - outline - STACK_RISE) < 0.01,
			"mouth %s, clock %.1f degrees from top, %.3f m past the outline" % [p, clock, p.y - outline])


func _accent(shell: Node3D) -> void:
	var owners := {}
	var stray := 0
	var mouths := [pos(shell, at(shell, "Exhaust_L")), pos(shell, at(shell, "Exhaust_R"))]
	for mi: MeshInstance3D in meshes(shell):
		for s in mi.mesh.get_surface_count():
			if slot_of(mi.mesh, s) == "class_accent":
				owners[String(mi.name)] = true
		if String(mi.name) == "Pod":
			for v in points(mi, shell, "class_accent"):
				stray += 1 if mouths.all(func(m): return v.distance_to(m) > 0.06) else 0
	_t.check("class_accent only on the lens and the exhaust mouths", owners.keys().size() == 2 and owners.has("Drill")
		and owners.has("Pod") and stray == 0, "accent on %s, %d Pod accent vertices away from the mouths" % [owners.keys(), stray])


func _outline(shell: Node3D) -> void:
	var breaks := 0
	for mi: MeshInstance3D in meshes(shell):
		for v in points(mi, shell):
			if Vector2(v.x, v.y).length() <= 0.99:
				continue
			var clock := fposmod(rad_to_deg(atan2(v.x, v.y)), 360.0)
			breaks += 1 if absf(clock - 120.0) < 15.0 or absf(clock - 240.0) < 15.0 else 0
	_t.eq("nothing breaks the outline at 4 or 8 o'clock", breaks, 0)
	var core := at(shell, "Core") as MeshInstance3D
	var far := 0.0
	var fins := {"left": 0, "right": 0}
	for v in points(core, shell):
		far = maxf(far, v.length())
	for v in points(core, shell, "copper"):
		# Above the pins (0.977) and hub drums (0.975): only a fin's top face (0.983).
		if v.length() > 0.981 and v.y < -0.35 and v.z < -0.5:
			fins["left" if v.x < 0.0 else "right"] += 1
	_t.check("fins lie flat in the front lower gaps", fins.left >= 6 and fins.right >= 6 and far <= CORE_LIMIT + 0.0001,
		"%s copper vertices on the lattice face, Core reaches %.4f (limit %.3f, under 0.05 m proud)" % [fins, far, CORE_LIMIT])


static func _near(c: Color, want: Color) -> bool:
	var lin := want.srgb_to_linear()
	return absf(c.r - lin.r) < 0.01 and absf(c.g - lin.g) < 0.01 and absf(c.b - lin.b) < 0.01


static func _paint(mi: MeshInstance3D) -> Array:
	var out := []
	for s in mi.mesh.get_surface_count():
		if slot_of(mi.mesh, s) == "paint":
			out.append_array(Array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]))
	return out


func _colours(shell: Node3D) -> void:
	var core := _paint(at(shell, "Core") as MeshInstance3D)
	var charcoal := core.filter(func(c): return _near(c, Palette.CHARCOAL)).size()
	var other := core.filter(func(c): return not _near(c, Palette.CHARCOAL) and not _near(c, Palette.SAND)).size()
	_t.check("charcoal steel lattice", charcoal > 1000 and other == 0, "%d charcoal, %d off (bone is the chalk mark)" % [charcoal, other])
	var seat := _paint(at(shell, "Pod") as MeshInstance3D)
	_t.check("bone seat", not seat.is_empty() and seat.all(func(c): return _near(c, Palette.SAND)), "%d Pod paint colours" % seat.size())


func _pod(shell: Node3D) -> void:
	var pod := at(shell, "Pod") as MeshInstance3D
	_t.eq("sight cone empty", Cage.cone_hits(pod), 0)
	var low := 0
	for mi: MeshInstance3D in meshes(pod):
		for v in points(mi, shell):
			low += 1 if v.y < -0.6 and v.length() > 1.0 else 0
	_t.eq("pod low reach", low, 0)


func _closed(label: String, scene: Node3D) -> void:
	var open := {}
	for mi: MeshInstance3D in meshes(scene):
		if mi.name == &"Pilot":
			continue
		var edges: Vector2i = Revolvers.open_edges(mi.mesh)
		if edges != Vector2i.ZERO:
			open[String(mi.name)] = edges
	_t.check(label + " closed: no open or non-manifold edge", open.is_empty(), "open, non-manifold per mesh %s" % [open])


# --- the Calibrated variant ----------------------------------------------------------------------

func _variant(shell: Node3D) -> void:
	var variant := _load(VARIANT)
	_t.check("variant loads", variant != null, VARIANT)
	if variant == null:
		for i in 5:
			_t.check("variant skipped", false)
		return
	root.add_child(variant)
	_budget("variant", variant, "shell", _exception(VARIANT))
	var problems := Cage.contract_problems(variant)
	_t.check("variant contract", problems.is_empty(), str(problems))
	_closed("variant", variant)
	var moved := []
	for n in MACHINERY + CONTROLS:
		var a := at(shell, n)
		var b := at(variant, n)
		if a == null or b == null or pos(shell, a).distance_to(pos(variant, b)) > 0.001:
			moved.append(n)
	_t.check("variant keeps the machinery where it was", moved.is_empty(), "moved or missing %s" % [moved])
	variant.queue_free()


# --- heft layers -----------------------------------------------------------------------------------

func _layers() -> void:
	for n in [2, 3, 4]:
		var path := LAYER % n
		var layer := _load(path)
		_t.check("c%d loads with Core and Pod" % n, layer != null and at(layer, "Core") != null and at(layer, "Pod") is MeshInstance3D, path)
		if layer == null or not (at(layer, "Pod") is MeshInstance3D):
			for i in 3:
				_t.check("c%d skipped" % n, false)
			continue
		root.add_child(layer)
		var c := counts(layer)
		_t.check("c%d detail budget" % n, c.tris <= 1500 and c.verts <= 3000 and c.draws == LAYER_DRAWS[n]
			and c.draws <= int(_exception(path).get("draws", 1)), "%d tris, %d verts, %d draws (want %d)" % [c.tris, c.verts, c.draws, LAYER_DRAWS[n]])
		var pod := at(layer, "Pod") as MeshInstance3D
		var far := 0.0
		var low_top := -INF
		var swept := 0
		for v in points(pod, layer, "paint"):
			far = maxf(far, v.length())
			low_top = maxf(low_top, v.y)
			swept += 1 if Vector2(v.x, v.z).length() > SWEEP_R and v.y > SWEEP_Y.x and v.y < SWEEP_Y.y else 0
		var problems := Cage.contract_problems(layer)
		_t.check("c%d panels inside the lattice, out of the sight cone and the drill sweep" % n, far > 0.85 and far <= LATTICE_INNER
			and Cage.cone_hits(pod) == 0 and swept == 0 and problems.is_empty(),
			"panels reach %.3f (inner face %.2f), cone %d, %d vertices in the drill sweep, %s" % [far, LATTICE_INNER, Cage.cone_hits(pod), swept, problems])
		match n:
			2:
				_t.check("c2 panels below Y -0.35", low_top < -0.35, "highest panel vertex %.3f" % low_top)
			3:
				var caps := at(layer, "Core") as MeshInstance3D
				var reach := 0.0
				for v in (points(caps, layer, "rubber") if caps != null else PackedVector3Array()):
					reach = maxf(reach, v.length())
				_t.check("c3 wider tread caps on Core", caps != null and reach > 0.98 and reach <= CORE_LIMIT + 0.0001, "caps reach %.4f" % reach)
			4:
				var collars := 0
				for v in points(pod, layer, "paint"):
					collars += 1 if v.z > 0.1 and v.y > 0.7 else 0
				_t.check("c4 collars round the stack bases", collars > 0, "%d collar vertices" % collars)
		layer.queue_free()
	_heavy_drill()


# Class V: the heavy drill rides the layer's Pod > WeaponRing, which hero_assets reparents under
# the base ring, so it yaws with the aim and its lens face stays on DrillTip.
func _heavy_drill() -> void:
	var path := LAYER % 5
	var layer := _load(path)
	var pod := at(layer, "Pod") if layer != null else null
	var module := pod.get_node_or_null("WeaponRing") as MeshInstance3D if pod != null else null
	_t.check("c5 loads with Core, Pod and Pod > WeaponRing", layer != null and at(layer, "Core") != null and module != null, path)
	if module == null:
		for i in 4:
			_t.check("c5 skipped", false)
		if layer != null:
			layer.free()
		return
	root.add_child(layer)
	var c := counts(layer)
	_t.check("c5 detail budget", c.tris <= 1500 and c.verts <= 3000 and c.draws == LAYER_DRAWS[5]
		and c.draws <= int(_exception(path).get("draws", 1)) and slot_of(module.mesh, 0) == "copper",
		"%d tris, %d verts, %d draws (want %d), slot %s" % [c.tris, c.verts, c.draws, LAYER_DRAWS[5], slot_of(module.mesh, 0)])
	var pts := points(module, layer)
	var levels := {}
	var front := INF
	for v in pts:
		levels[snappedf(v.z, 0.005)] = true
		front = minf(front, v.z)
	var across := 0.0
	var outside := 0
	for v in pts:
		if v.z < front + 0.0005:
			across = maxf(across, 2.0 * Vector2(v.x, v.y - DRILL_Y).length())
		outside += 0 if Vector2(v.x, v.z).length() > SWEEP_R and v.y > SWEEP_Y.x and v.y < SWEEP_Y.y else 1
	_t.check("c5 five-step heavy drill with a 0.20 m lens face", levels.size() == HEAVY_STEPS + 1 and absf(across - HEAVY_LENS) < 0.006,
		"%d shoulder planes (want %d), lens face %.3f m across" % [levels.size(), HEAVY_STEPS + 1, across])
	_t.check("c5 drill inside the sweep band the panels keep out of", outside == 0, "%d vertices outside the band" % outside)
	layer.queue_free()
	# Fitted as the game fits it: class V, the ring yawed 30 degrees to the aim.
	var hook := HeroAssets.new()
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, "runner_gunner", "", 5, {})
	var fpod: Node3D = rec.get("pod")
	var ring: Node3D = fpod.get_node_or_null("WeaponRing") if fpod != null else null
	var heavy := ring.get_node_or_null("HeftC5/WeaponRing") as MeshInstance3D if ring != null else null
	var tip := ring.get_node_or_null("DrillTip") as Node3D if ring != null else null
	var detail := "ring %s, heavy drill %s, DrillTip %s" % [ring != null, heavy != null, tip != null]
	var ok := false
	if heavy != null and tip != null:
		var want := deg_to_rad(30.0)
		hook.steer_weapon_ring(fpod, Vector3(-sin(want), 0.0, -cos(want)), 10.0)
		var fwd := -tip.global_basis.z.normalized()
		var world: Array[Vector3] = []
		var far := -INF
		for s in heavy.mesh.get_surface_count():
			for v in heavy.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var w: Vector3 = heavy.global_transform * v
				world.append(w)
				far = maxf(far, w.dot(fwd))
		var centre := Vector3.ZERO
		var n := 0
		for w in world:
			if w.dot(fwd) > far - 0.0005:
				centre += w
				n += 1
		centre /= maxf(1.0, float(n))
		var off := tip.global_position - ball.global_position
		var yaw := rad_to_deg(atan2(-fwd.x, -fwd.z))
		ok = heavy.is_visible_in_tree() and centre.distance_to(tip.global_position) < 0.01 and absf(off.x) > 0.5 and absf(absf(yaw) - 30.0) < 1.0
		detail = "lens face centre %s, DrillTip %s (%.4f m), ring yaw %.1f degrees, shown %s" % [centre, tip.global_position,
			centre.distance_to(tip.global_position), yaw, heavy.is_visible_in_tree()]
	_t.check("c5 lens on DrillTip with the fitted ring yawed 30 degrees", ok, detail)
	ball.free()
	hook.free()


# --- the rig (unchanged) ---------------------------------------------------------------------------

func _check_rig() -> void:
	var rig := _load(RIG)
	if rig == null:
		_t.check("rig loads", false, RIG)
		return
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	var names := []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
	_t.check("rig bones", skeletons.size() == 1 and names == RIG_BONES, "%d skeleton, %d bones" % [skeletons.size(), names.size()])
	var actual := {}
	for mi: MeshInstance3D in meshes(rig):
		var materials := []
		for i in mi.mesh.get_surface_count():
			materials.append(slot_of(mi.mesh, i) if mi.mesh.surface_get_material(i) != null else "<missing>")
		actual[String(mi.name)] = materials
	_t.check("rig meshes", actual == RIG_MESHES, "mesh material names %s, expected %s" % [actual, RIG_MESHES])
	var triangles: int = counts(rig).tris
	_t.check("rig triangles", triangles >= RIG_TRIS.x and triangles <= RIG_TRIS.y, "%d in %d..%d" % [triangles, RIG_TRIS.x, RIG_TRIS.y])
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := Array(player.get_animation_list()) if player != null else []
	var lost := CLIPS.keys().filter(func(c): return not (c in clips))
	_t.check("rig clips", player != null and lost.is_empty(), "seven pilot clips present (missing %s)" % [lost])
	for clip in CLIPS:
		var length := player.get_animation(clip).length if clip in clips else -1.0
		_t.near("rig length " + clip, length, CLIPS[clip], 0.001)
	rig.free()
