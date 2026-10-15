extends SceneTree
# 2026-10-10 (PD-0): new. The Hoberman mecha contract every pilot shell inherits (ROSTER-LOOK
# sections 0 to 8, P-UNITS PD-0 acceptance 1 to 8), checked on the neutral fixture shell.
# 2026-10-10 (PD-0 fix round): the inner gimbal ring is its own mesh (Gyro > GyroInner) and both
# rings follow the tumble; the sight cone walks every mesh under Pod and refuses a seeded one;
# hero_assets.sync_lattice turns the lattice snap on for Hoberman shells only; KNOWN_OVER rows
# name their owning clip units. EXPECTED_CHECKS 39 -> 45.

# What it checks, in order:
#   budget     the neutral shell sits inside the shell class: tris, verts and draws (surfaces).
#   contract   contract_problems() refuses a glass or requisition_tag slot, a Light3D and a
#              material_override, on fixtures built from the neutral shell, and passes the shell.
#   lattice    32 hubs, 12 five-way and 20 three-way; 30 gaps; empties face outward; strut pairs
#              0.035 m; Core radius 0.95 to 0.985; no glass on Core.
#   ring       WeaponRing under Pod, band radius 1.02 to 1.10 and 0.08 m tall; it reaches a new
#              aim within 0.2 s at rate 14 and stays level while Core tumbles; both gimbal rings
#              turn while Core tumbles and the inner ring's axis follows the lattice.
#   pod        no Pod vertex past radius 1.0 below Y -0.6; the sight cone is empty of every Pod
#              mesh but Gyro, WeaponRing and Dome, and refuses a seeded mesh child inside it.
#   gimbal     Gyro > GyroInner; both rings clear every pilot outside KNOWN_OVER by 0.03 m, stay
#              inside the lattice inner face and clear the 0.92 landing fold.
#   chunks     36 chunks on a lattice shell seat within 0.05 m of a hub or strut; the shell
#              does not scale per class there and still does elsewhere; sync_lattice turns the
#              snap on for the Hoberman Core and off for a glass shell.
#   copper     the copper slot is Palette.COPPER, metallic 0.6, roughness 0.4, never tinted.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.
# SCRAPKEEP_ENVELOPE_OUT=<abs path> also writes the per-pilot kept-clip envelope as JSON.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Accretion := preload("res://src/build/accretion.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

const NEUTRAL := "res://assets/models/world_one/shell_neutral.glb"
# 2026-10-10 (PD-0b) re-pin: the glass fixture was SHELLS[DEFAULT_CLASS], which turns into a
# lattice once Sable's row points at her Hoberman shell. It is now the legacy VD-01 root glass
# shell below, which no pilot's SHELLS row names, so the check no longer moves with the roster.
const GLASS := "res://assets/models/shell_sable.glb"
const BUDGETS := "res://assets/asset_budgets.json"
const EXPECTED_CHECKS := 45
const CORE_LIMIT := 0.985
const STRUT_PAIR := 0.035
const LATTICE_INNER := 0.94
const HUB_ANGLE := 37.377
const RING_RATE := 14.0
const CLEARANCE := 0.03
const FOLD := 0.92
const CANNON_FOLD := 0.85
const CHUNK_SEAT := 0.05
# The pilot's head and the chase eyes at the close, mid and far look cameras, Godot axes
# (ROSTER-LOOK section 3 rule 3, section 9 step 6); the head from the pilots' head bones.
const HEAD := Vector3(0.0, 0.20, -0.02)
const EYES := [Vector3(0.0, 1.06, 3.44), Vector3(0.0, 2.22, 7.17), Vector3(0.0, 3.55, 11.46)]
const SIGHT_HALF_ANGLE := 35.0
const KEPT_CLIPS := ["drop_land", "big_cheer", "wince", "slump", "phew", "brace", "heave"]
const BAD_SLOTS := ["glass", "requisition_tag"]
# Half the depth of the gimbal rings' plane (Godot Z) plus the clearance: the slab a ring that
# does not spin would sweep.
const SLAB := 0.05
# 2026-10-10 (PD-0): three pilots' kept clips reach past the lattice inner face (0.94 m), so no
# gimbal ring inside the lattice can clear them; PILOT-CLIPS section 10 assumed every kept clip
# stays under 0.98 m. Measured here with full skinning at 30 Hz: Rivet's slump swings an arm out
# to 0.920 m, Sable's big_cheer raises one to 0.925 m, Kest's slump hangs a wing to 1.034 m. The
# check holds each to its measured reach (no worse) and fails once one fits, so the row is
# removed when the clip units re-key them. Every other pilot must clear by CLEARANCE.
# Owners (the clip units that re-key the clip to a reach of 0.80 m or less, inner ring 0.830
# minus CLEARANCE): runner_gunner (Rivet) PE-RIVET, pylon_engineer (Sable) PE-SABLE,
# demolitions_caster (Kest) PE-KEST.
const KNOWN_OVER := {"runner_gunner": 0.9204, "pylon_engineer": 0.9246, "demolitions_caster": 1.0344}

var _t := T.new("cage_contract_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(NEUTRAL) as PackedScene
	_t.check("neutral shell loads", packed != null, NEUTRAL)
	if packed == null:
		_finish()
		return
	var scene: Node3D = packed.instantiate()
	root.add_child(scene)
	_budget(scene)
	_contract(packed, scene)
	var core := scene.find_child("Core", true, false) as MeshInstance3D
	var pod := scene.find_child("Pod", true, false) as MeshInstance3D
	_t.check("Core and Pod", core != null and pod != null, "Core and Pod meshes under the root")
	if core == null or pod == null:
		_finish()
		return
	_lattice(core)
	_ring(scene, core, pod)
	_pod(pod)
	_gimbal(pod)
	_chunks(core)
	_copper(scene)
	scene.queue_free()
	_finish()


func _finish() -> void:
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


# --- helpers -----------------------------------------------------------------------------

static func meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else [])


static func slot_of(mesh: Mesh, surface: int) -> String:
	var mat := mesh.surface_get_material(surface)
	return mat.resource_name if mat != null else ""


# Vertices of one mesh in the given ancestor's space, optionally only one slot's surfaces.
static func points(mi: MeshInstance3D, space: Node3D, slot := "") -> PackedVector3Array:
	var xf := space.global_transform.affine_inverse() * mi.global_transform
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		if slot != "" and slot_of(mi.mesh, s) != slot:
			continue
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


static func node_name(blender_name: String) -> String:
	return blender_name.validate_node_name()


# The mecha contract (ROSTER-LOOK sections 6 and 8): no glass or requisition_tag slot, no light
# node, no per-instance material_override anywhere in the shell. Returns the problems found.
static func contract_problems(scene: Node) -> Array:
	var out := []
	for n in scene.find_children("*", "", true, false) + [scene]:
		if n is Light3D:
			out.append("%s is a %s" % [n.name, n.get_class()])
		if n is GeometryInstance3D and (n as GeometryInstance3D).material_override != null:
			out.append("%s has a material_override" % n.name)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				if slot_of(mi.mesh, s) in BAD_SLOTS:
					out.append("%s carries the %s slot" % [mi.name, slot_of(mi.mesh, s)])
	return out


# --- budget and contract --------------------------------------------------------------------

func _budget(scene: Node) -> void:
	var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"]["shell"]
	var tris := 0
	var verts := 0
	var draws := 0
	for mi: MeshInstance3D in meshes(scene):
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("NEUTRAL_BUDGET %d tris, %d verts, %d draws; caps %d / %d / %d" % [tris, verts, draws, cap.tris, cap.verts, cap.draws])
	_t.check("budget tris", tris > 0 and tris <= int(cap.tris), "%d tris within %d" % [tris, cap.tris])
	_t.check("budget verts", verts <= int(cap.verts), "%d verts within %d" % [verts, cap.verts])
	_t.check("budget draws", draws <= int(cap.draws), "%d draws within %d" % [draws, cap.draws])


func _contract(packed: PackedScene, scene: Node) -> void:
	var clean := contract_problems(scene)
	_t.check("contract passes the neutral shell", clean.is_empty(), str(clean))
	for bad in ["glass", "requisition_tag", "light", "material_override"]:
		var fixture: Node3D = packed.instantiate()
		var pod := fixture.find_child("Pod", true, false) as MeshInstance3D
		match bad:
			"light":
				pod.add_child(OmniLight3D.new())
			"material_override":
				pod.material_override = StandardMaterial3D.new()
			_:
				var mesh := pod.mesh.duplicate() as ArrayMesh
				var mat := StandardMaterial3D.new()
				mat.resource_name = bad
				mesh.surface_set_material(0, mat)
				pod.mesh = mesh
		var found := contract_problems(fixture)
		_t.check("contract refuses " + bad, not found.is_empty(), str(found))
		fixture.free()


# --- lattice -----------------------------------------------------------------------------------

func _lattice(core: MeshInstance3D) -> void:
	var hubs: Array[Vector3] = []
	for i in 32:
		var h := core.get_node_or_null(node_name("Hub.%02d" % i)) as Node3D
		if h != null:
			hubs.append(h.position)
	var gaps: Array[Node3D] = []
	for i in 30:
		var g := core.get_node_or_null(node_name("Gap.%02d" % i)) as Node3D
		if g != null:
			gaps.append(g)
	_t.check("32 hubs", hubs.size() == 32 and core.get_node_or_null(node_name("Hub.32")) == null, "%d Hub.NN empties" % hubs.size())
	var five := 0
	var three := 0
	for h in hubs:
		var near := hubs.filter(func(o): return o != h and rad_to_deg(h.angle_to(o)) < HUB_ANGLE + 1.0).size()
		five += 1 if near == 5 else 0
		three += 1 if near == 3 else 0
	_t.check("hub kinds", five == 12 and three == 20, "%d five-way, %d three-way hubs (want 12 and 20)" % [five, three])
	_t.check("30 gaps", gaps.size() == 30 and core.get_node_or_null(node_name("Gap.30")) == null, "%d Gap.NN empties" % gaps.size())
	var inward := 0
	for g in gaps:
		inward += 1 if g.basis.y.normalized().dot(g.position.normalized()) < 0.999 else 0
	for i in 32:
		var h := core.get_node_or_null(node_name("Hub.%02d" % i)) as Node3D
		if h != null:
			inward += 1 if h.basis.y.normalized().dot(h.position.normalized()) < 0.999 else 0
	_t.check("empties face outward", inward == 0 and not gaps.is_empty(), "%d Hub or Gap empties not facing out" % inward)
	# Strut pairs: the bars' outer faces and inner faces are planes; their offsets differ by
	# the pair thickness. The chalk mark (paint, on a cap past 0.98) is not a strut.
	var outer := 0.0
	var inner := 9.0
	var arrays := []
	for s in core.mesh.get_surface_count():
		if slot_of(core.mesh, s) == "paint":
			arrays = core.mesh.surface_get_arrays(s)
	if not arrays.is_empty():
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for k in range(0, idx.size(), 3):
			var a := vs[idx[k]]
			var n := (vs[idx[k + 1]] - a).cross(vs[idx[k + 2]] - a).normalized()
			var c := (a + vs[idx[k + 1]] + vs[idx[k + 2]]) / 3.0
			# Radial faces only, whatever the winding (Godot flips glTF's); the chalk mark is
			# the one paint face past 0.98.
			var plane := absf(n.dot(a))
			if absf(n.dot(c.normalized())) > 0.98 and plane < 0.98:
				outer = maxf(outer, plane)
				inner = minf(inner, plane)
	_t.near("strut pair thickness", outer - inner, STRUT_PAIR, 0.002)
	var far := 0.0
	for v in points(core, core):
		far = maxf(far, v.length())
	_t.check("core radius", far >= 0.95 and far <= CORE_LIMIT + 0.0001, "lattice reaches %.4f m (0.95 to %.3f)" % [far, CORE_LIMIT])
	var glass := []
	for s in core.mesh.get_surface_count():
		if slot_of(core.mesh, s) == "glass":
			glass.append(s)
	_t.check("no glass on Core", glass.is_empty(), "glass surfaces %s" % [glass])


# --- weapon ring ---------------------------------------------------------------------------------

func _ring(scene: Node3D, core: MeshInstance3D, pod: MeshInstance3D) -> void:
	var ring := pod.get_node_or_null("WeaponRing") as MeshInstance3D
	_t.check("WeaponRing under Pod", ring != null and ring.get_parent() == pod, "Pod > WeaponRing")
	if ring == null:
		for i in 5:
			_t.check("weapon ring check %d" % i, false, "no WeaponRing")
		return
	var lo := 9.0
	var hi := 0.0
	var bottom := 9.0
	var top := -9.0
	for v in points(ring, pod, "paint"):
		var r := Vector2(v.x, v.z).length()
		lo = minf(lo, r)
		hi = maxf(hi, r)
		bottom = minf(bottom, v.y)
		top = maxf(top, v.y)
	_t.check("ring radius", lo >= 1.02 and hi <= 1.10, "band from %.3f to %.3f m (1.02 to 1.10)" % [lo, hi])
	_t.near("ring height", top - bottom, 0.08, 0.002)
	# Steer: the pod faces one way, the aim another; Core tumbles every frame.
	var rolling := Node3D.new()
	var juice := Node3D.new()
	root.add_child(rolling)
	root.add_child(juice)
	core.reparent(rolling, false)
	pod.reparent(juice, false)
	pod.rotation = Vector3(0.0, 0.7, 0.0)
	var hook := HeroAssets.new()
	var aim := Vector3(-1.0, -0.3, 0.2).normalized()
	var want := atan2(-aim.x, -aim.z)
	var level := 1.0
	var elapsed := 0.0
	var reached := INF
	var gyro := pod.get_node_or_null("Gyro") as Node3D
	var inner: Node3D = gyro.get_node_or_null("GyroInner") if gyro != null else null
	var outer_turn := [INF, -INF]
	var inner_turn := [INF, -INF]
	var follows := 1.0
	while elapsed < 0.4:
		rolling.rotate(Vector3(1, 0.3, 0.2).normalized(), 0.51)
		hook.steer_weapon_ring(pod, aim, 1.0 / 60.0)
		if inner != null:
			HeroAssets.counter_tilt(pod, gyro, core)
			outer_turn = [minf(outer_turn[0], gyro.rotation.x), maxf(outer_turn[1], gyro.rotation.x)]
			inner_turn = [minf(inner_turn[0], inner.rotation.y), maxf(inner_turn[1], inner.rotation.y)]
			follows = minf(follows, inner.global_basis.z.normalized().dot(core.global_basis.z.normalized()))
		elapsed += 1.0 / 60.0
		level = minf(level, ring.global_basis.y.normalized().dot(Vector3.UP))
		var f := -ring.global_basis.z
		if reached == INF and absf(angle_difference(atan2(-f.x, -f.z), want)) < 0.1:
			reached = elapsed
	_t.check("ring reaches the aim", reached <= 0.2 + 0.0001, "within 0.1 rad of a %.2f rad turn after %.3f s (rate %.0f)" % [absf(angle_difference(0.7, want)), reached, HeroAssets.WEAPON_RING_RATE])
	_t.check("ring stays level", level > 0.9999, "min up-dot %.6f while Core tumbled %.0f rad" % [level, 0.51 * 24])
	_t.eq("ring rate", HeroAssets.WEAPON_RING_RATE, RING_RATE)
	_t.check("both gimbal rings move", inner != null and outer_turn[1] - outer_turn[0] > 0.5 and inner_turn[1] - inner_turn[0] > 0.2,
		"outer ring swept %.2f rad, inner %.2f rad while Core tumbled" % [outer_turn[1] - outer_turn[0], inner_turn[1] - inner_turn[0]])
	_t.check("inner ring follows the lattice", inner != null and follows > 0.9999, "min dot of the inner ring's axis with Core's %.6f" % follows)
	if gyro != null:
		gyro.rotation = Vector3.ZERO
	if inner != null:
		inner.rotation = Vector3.ZERO
	hook.free()
	pod.reparent(scene, false)
	core.reparent(scene, false)
	pod.rotation = Vector3.ZERO
	rolling.free()
	juice.free()


# --- pod reach and sight cone ----------------------------------------------------------------------

func _pod(pod: MeshInstance3D) -> void:
	var low := 0
	for mi: MeshInstance3D in meshes(pod):
		for v in points(mi, pod):
			low += 1 if v.y < -0.6 and v.length() > 1.0 else 0
	_t.check("pod low reach", low == 0, "%d Pod vertices past radius 1.0 below Y -0.6" % low)
	var inside := cone_hits(pod)
	_t.check("sight cone empty", inside == 0, "%d solid Pod vertices inside the %.0f degree cone (Gyro, WeaponRing and Dome may cross)" % [inside, SIGHT_HALF_ANGLE])
	# Seeded: a heft-layer box hung under Pod, and a bracket under that, inside the cone.
	var planted := MeshInstance3D.new()
	planted.name = "HeftC2"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.06
	planted.mesh = box
	planted.position = HEAD + (EYES[1] - HEAD).normalized() * 0.5
	pod.add_child(planted)
	var bracket := planted.duplicate() as MeshInstance3D
	bracket.name = "Bracket"
	bracket.position = Vector3.ZERO
	planted.add_child(bracket)
	var seeded := cone_hits(pod)
	_t.check("sight cone refuses a seeded Pod mesh", seeded >= 2 * box.get_mesh_arrays()[Mesh.ARRAY_VERTEX].size(),
		"%d vertices inside with a box child and grandchild under Pod" % seeded)
	pod.remove_child(planted)
	planted.free()


# Solid Pod vertices inside the sight cone: every mesh under Pod except the subtrees rooted at
# Gyro, WeaponRing and Dome (shell_base.sight_cone_hits and CONE_SKIP do the same in Blender).
static func cone_hits(pod: MeshInstance3D) -> int:
	var cos_half := cos(deg_to_rad(SIGHT_HALF_ANGLE))
	var axes := EYES.map(func(e): return (e - HEAD).normalized())
	var inside := 0
	for mi in cone_meshes(pod, pod):
		for v in points(mi, pod):
			var d := (v - HEAD).normalized()
			for a in axes:
				if d.dot(a) > cos_half:
					inside += 1
					break
	return inside


static func cone_meshes(node: Node, top: Node) -> Array:
	if node != top and String(node.name).get_slice("_", 0) in ["Gyro", "WeaponRing", "Dome"]:
		return []
	var out := [node] if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else []
	for c in node.get_children():
		out += cone_meshes(c, top)
	return out


# --- gimbal against the kept-clip envelope ------------------------------------------------------

func _gimbal(pod: MeshInstance3D) -> void:
	var gyro := pod.get_node_or_null("Gyro") as MeshInstance3D
	_t.check("Gyro under Pod", gyro != null, "Pod > Gyro, the outer gimbal ring")
	var inner: MeshInstance3D = gyro.get_node_or_null("GyroInner") if gyro != null else null
	_t.check("GyroInner under Gyro", inner != null and inner.mesh != null, "Gyro > GyroInner, the inner ring as its own mesh")
	var lo := 9.0
	var hi := 0.0
	if gyro != null:
		for mi: MeshInstance3D in meshes(gyro):
			for v in points(mi, pod):
				lo = minf(lo, v.length())
				hi = maxf(hi, v.length())
	var envelope := kept_envelope()
	var worst := 0.0
	var known := []
	for p in envelope:
		if KNOWN_OVER.has(p):
			if envelope[p] > KNOWN_OVER[p] + 0.001 or envelope[p] < lo - CLEARANCE:
				known.append("%s %.4f (recorded %.4f)" % [p, envelope[p], KNOWN_OVER[p]])
		else:
			worst = maxf(worst, envelope[p])
	_t.check("envelope covers six pilots", envelope.size() == 6, str(envelope))
	_t.check("gimbal clears the pilots", lo - worst >= CLEARANCE - 0.0001 and worst > 0.0,
		"inner ring at %.4f m, widest kept clip outside KNOWN_OVER %.4f m, clearance %.4f (want %.2f)" % [lo, worst, lo - worst, CLEARANCE])
	_t.check("known over-reach unchanged", known.is_empty(),
		"KNOWN_OVER pilots no wider than recorded and still not clearing: %s" % [known])
	_t.check("gimbal inside the lattice", hi <= LATTICE_INNER, "outer ring to %.4f m, lattice inner face %.2f" % [hi, LATTICE_INNER])
	var lowest := hi / LATTICE_INNER
	print("FOLD lowest clearing scale %.4f; 0.92 landing fold %s; Cannon 0.85 fold %s" % [lowest,
		"clears" if LATTICE_INNER * FOLD >= hi else "hits", "clears" if LATTICE_INNER * CANNON_FOLD >= hi else "hits the rings"])
	_t.check("gimbal clears the landing fold", LATTICE_INNER * FOLD >= hi, "lattice inner face at the %.2f fold %.4f, rings to %.4f" % [FOLD, LATTICE_INNER * FOLD, hi])
	var out := OS.get_environment("SCRAPKEEP_ENVELOPE_OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"tool": "tests/cage_contract_test.gd", "clips": KEPT_CLIPS, "sample_hz": 30,
			"max_radius_m": envelope, "gimbal_inner_m": snappedf(lo, 0.0001), "gimbal_outer_m": snappedf(hi, 0.0001),
			"clearance_m": snappedf(lo - worst, 0.0001), "lowest_fold_scale": snappedf(lowest, 0.0001)}, "\t"))
		f.close()


# The widest any vertex of each pilot reaches from the pod origin over the seven kept clips,
# sampled at 30 Hz with each vertex rigid on its first bone (the pilot asset tests' method).
func kept_envelope() -> Dictionary:
	var out := {}
	for class_id in HeroAssets.PILOTS:
		var scene: Node3D = (load(HeroAssets.PILOTS[class_id]) as PackedScene).instantiate()
		root.add_child(scene)
		var found := scene.find_children("*", "Skeleton3D", true, false)
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if found.size() != 1 or player == null:
			scene.free()
			continue
		var sk: Skeleton3D = found[0]
		var to_root := scene.global_transform.affine_inverse() * sk.global_transform
		# Each vertex: up to four [bone, bind-space point, weight] terms, linear blend skinning.
		var verts := []
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if mi.skin == null:
				continue
			for s in mi.mesh.get_surface_count():
				var arrays: Array = mi.mesh.surface_get_arrays(s)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				for k in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					var terms := []
					for w in 4:
						var weight := weights[k * 4 + w]
						if weight <= 0.0:
							continue
						var bind: int = arrays[Mesh.ARRAY_BONES][k * 4 + w]
						var bone: int = mi.skin.get_bind_bone(bind)
						if bone < 0:
							bone = sk.find_bone(mi.skin.get_bind_name(bind))
						if bone >= 0:
							terms.append([bone, mi.skin.get_bind_pose(bind) * arrays[Mesh.ARRAY_VERTEX][k], weight])
					if not terms.is_empty():
						verts.append(terms)
		var r := 0.0
		var rest := 0.0
		var worst_clip := ""
		var worst_at := Vector3.ZERO
		var slab := 0.0
		for clip in [""] + KEPT_CLIPS:
			var anim: Animation = null
			if clip != "":
				if not player.has_animation(clip):
					continue
				anim = player.get_animation(clip)
				player.play(clip)
			var frames := 1 if anim == null else int(ceil(anim.length * 30.0)) + 1
			for f in frames:
				if anim != null:
					player.seek(minf(float(f) / 30.0, anim.length), true)
					player.advance(0)
				var xf := []
				for b in sk.get_bone_count():
					xf.append(to_root * (sk.get_bone_global_rest(b) if anim == null else sk.get_bone_global_pose(b)))
				for terms in verts:
					var p := Vector3.ZERO
					for term in terms:
						p += ((xf[term[0]] as Transform3D) * (term[1] as Vector3)) * float(term[2])
					if anim == null:
						rest = maxf(rest, p.length())
					elif p.length() > r:
						r = p.length()
						worst_clip = clip
						worst_at = p
					if anim != null and absf(p.z) < SLAB:
						slab = maxf(slab, p.length())
		out[class_id] = snappedf(r, 0.0001)
		print("ENVELOPE %s %.4f m (rest %.4f, widest in %s at %s; ring-plane slab %.4f) over %d vertices" % [class_id, r, rest, worst_clip, worst_at, slab, verts.size()])
		scene.free()
	return out


# --- accretion chunks on the lattice ----------------------------------------------------------------

func _chunks(core: MeshInstance3D) -> void:
	var hubs: Array[Vector3] = []
	for i in 32:
		var h := core.get_node_or_null(node_name("Hub.%02d" % i)) as Node3D
		if h != null:
			hubs.append(h.position)
	var links := []
	for i in hubs.size():
		for j in range(i + 1, hubs.size()):
			if rad_to_deg(hubs[i].angle_to(hubs[j])) < HUB_ANGLE + 1.0:
				links.append([hubs[i], hubs[j]])
	_t.eq("60 links between the hubs", links.size(), 60)
	var acc := Accretion.new()
	root.add_child(acc)
	acc.setup()
	acc.set_lattice(true)
	acc.show_build(1.0e6, [], [], 5)
	var worst := 0.0
	var spots := {}
	for c in acc.get_children():
		if not (c is MeshInstance3D):
			continue
		var p: Vector3 = (c as Node3D).position
		spots[p.snapped(Vector3.ONE * 0.01)] = true
		var best := INF
		for h in hubs:
			best = minf(best, p.distance_to(h))
		for l in links:
			best = minf(best, _arc_distance(p, l[0], l[1]))
		worst = maxf(worst, best)
	_t.check("36 chunks seat on the lattice", acc.chunk_count() == 36 and worst <= CHUNK_SEAT,
		"%d chunks, farthest %.4f m from a hub or strut (want %.2f)" % [acc.chunk_count(), worst, CHUNK_SEAT])
	_t.check("chunks stay spread", spots.size() >= 30, "%d distinct seats for %d chunks" % [spots.size(), acc.chunk_count()])
	_t.check("lattice shells do not grow per class", acc.scale.is_equal_approx(Vector3.ONE), "accretion scale %s at class V" % acc.scale)
	acc.set_lattice(false)
	acc.show_build(1.0e6, [], [], 5)
	_t.check("other shells still grow", acc.scale.x > 1.2, "accretion scale %.2f at class V off the lattice" % acc.scale.x)
	# The game wires it: hero_assets.sync_lattice reads the worn Core.
	var roll := Node3D.new()
	root.add_child(roll)
	acc.reparent(roll, false)
	HeroAssets.sync_lattice(core, roll)
	acc.show_build(1.0e6, [], [], 5)
	_t.check("Hoberman shell turns the snap on", acc.lattice and acc.scale.is_equal_approx(Vector3.ONE), "lattice %s, scale %s at class V" % [acc.lattice, acc.scale])
	var glass_scene: Node3D = (load(GLASS) as PackedScene).instantiate()
	var glass_core := glass_scene.find_child("Core", true, false)
	HeroAssets.sync_lattice(glass_core, roll)
	_t.check("glass shell leaves the snap off", glass_core != null and not glass_core.has_node("Hub_00") and not acc.lattice and acc.scale.x > 1.2,
		"lattice %s, scale %.2f with %s" % [acc.lattice, acc.scale.x, GLASS])
	glass_scene.free()
	roll.free()


# Distance from p to the strut mid surface along the great-circle arc from a to b.
static func _arc_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var n := a.cross(b).normalized()
	var q := p - n * p.dot(n)
	var on_arc := a.cross(q).dot(n) >= 0.0 and q.cross(b).dot(n) >= 0.0
	if not on_arc or q.length() < 0.0001:
		return minf(p.distance_to(a), p.distance_to(b))
	return p.distance_to(q.normalized() * a.length())


# --- copper slot ----------------------------------------------------------------------------------

func _copper(scene: Node3D) -> void:
	var row: Dictionary = HeroAssets.SLOTS.get("copper", {})
	_t.check("copper row", row.get("color", Color.BLACK) == Palette.COPPER and is_equal_approx(row.get("metal", 0.0), 0.6)
		and is_equal_approx(row.get("rough", 0.0), 0.4) and not row.has("from") and not row.get("vertex", false),
		"SLOTS copper %s" % row)
	var hook := HeroAssets.new()
	hook.paint(scene, {"paint": Color(0.2, 0.3, 0.9), "class": Color.RED})
	var copper := 0
	var wrong := []
	for mi: MeshInstance3D in meshes(scene):
		for s in mi.mesh.get_surface_count():
			if slot_of(mi.mesh, s) != "copper":
				continue
			copper += 1
			var mat := mi.get_surface_override_material(s) as StandardMaterial3D
			if mat == null or mat.albedo_color != Palette.COPPER or not is_equal_approx(mat.metallic, 0.6) or not is_equal_approx(mat.roughness, 0.4):
				wrong.append(mi.name)
	_t.check("copper surfaces keep copper under paint", copper >= 2 and wrong.is_empty(), "%d copper surfaces, wrong on %s" % [copper, wrong])
	hook.free()
