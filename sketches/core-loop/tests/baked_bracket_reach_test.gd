extends SceneTree
# 2026-10-22 (MOTION-SPEC row 208, wave 19 baked bracket parts): the carrier bank tilts the WeaponRing and the
# named BRACKET_PARTS, but geometry baked into a Pod mesh (a split port, a claw hook, a mast, a satchel plate)
# stays level with the pod and can stand past the 1.0 m ball on a wall. carrier_bank_test measures only the
# ring and the CarrierBank holders; this measures EVERY visible mesh vertex in the pod visual tree.
#
# For each of the six shells and each heft class 1 to 5 (the layers show cumulatively), the hero is fitted the
# way the game fits it (fit_shell_into), posed on a vertical wall and a wall 30 degrees off vertical, and the
# bank applied (the ring aimed four ways). The support distance along -normal of every vertex of every visible
# MeshInstance3D under the pod is taken from the pod's centre:
#   - banked nodes (under WeaponRing, CarrierBank or Fairlead) are measured as drawn, over the four aims and 16
#     pod yaws (the pod yaws freely against a wall; each pose settles its own bank), reporting the worst yaw and
#     the bank angle there;
#   - baked nodes do not bank, so the pod's yaw alone moves them; their worst case over EVERY pod yaw is exact
#     and closed form (|n horizontal| * horizontal radius - n.y * height), and is the number reported. A
#     posed measurement at POD_YAW cross-checks the formula.
# The max per node, and for nodes past LIMIT the vertices clustered by pod-frame angle (0 = forward, -Z; positive
# toward +X), are printed. KNOWN_BAKED lists today's over-limit nodes with their measured reach: a node past
# the limit that is not listed fails (something new pokes out), a listed node that grows fails, and the
# follow-up fix's acceptance is deleting rows until the table is empty. A listed node that no longer
# reaches past the limit prints as CLEARED and fails (delete its row), and a listed node more than TOL below its
# value fails as improved (lower its value), so the list tracks the truth.
# The cosmetic shell variants (VARIANTS: each swaps in its own base pod; classes 2 to 5 borrow the default
# layers) are measured at heft class 1 only, keyed by the variant's cosmetics id in the pilot field.
# Meshes hidden by a heft Replace (VisualInstance3D layers 0) are skipped. Only the base pod's Fairlead counts
# as banked (update_carrier_bank poses that one alone). Vertex arrays are cached per fit across classes.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CarrierBank := preload("res://src/presentation/carrier_bank.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const T := preload("res://tests/support/t.gd")

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const CLASSES := [1, 2, 3, 4, 5]
const DT := 1.0 / 60.0
const FRAMES := 40
const SLACK := 0.002
# Banked nodes are swept over this many evenly spaced pod yaws; each pose settles its own bank.
const YAWS := 16
const VARIANTS := ["shell_sable_felt", "shell_rivet_calibrated", "shell_kest_roost", "shell_tarn_redjaw_teeth",
	"shell_tally_abacus", "shell_cannon_choir"]
# A listed node may read this much above its measured value before it counts as worse.
const TOL := 0.003
const POD_YAW := 0.7
const AIMS := [0.0, PI * 0.5, PI, -PI * 0.5]
# Nodes below this reach are summarised, not listed, in the printed table.
const LIST_FROM := 0.9
# Vertices more than this many degrees apart (in the pod frame) belong to different clusters.
const GAP := 20.0
const WALLS := {
	"vertical wall": Vector3(1.0, 0.0, 0.0),
	"wall 30 degrees off vertical": Vector3(0.8660254, 0.5, 0.0),
}

# "pilot|heft class|node path under the pod" -> reach in metres measured 2026-10-22 on the base 26ac844b.
const KNOWN_BAKED := {
	"tarn|3|HeftC3/Pod": 1.1418,
	"tarn|4|HeftC3/Pod": 1.1418,
	"tarn|4|HeftC4/Pod": 1.1716,
	"tarn|5|HeftC3/Pod": 1.1418,
	"tarn|5|HeftC4/Pod": 1.1716,
	"tarn|5|HeftC5/Pod": 1.2113,
}

var _t := T.new("baked_bracket_reach_test")
var _over := 0
var _cleared := 0
var _seen := {}
var _cache := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for pilot in PILOTS:
		_shell(pilot, pilot, "", CLASSES)
	for variant in VARIANTS:
		var row: Dictionary = Cosmetics.row(variant)
		_shell(variant, String(row.get("pilot", "")), variant, [1])
	for key in KNOWN_BAKED:
		if not _seen.has(key):
			_cleared += 1
			_t.check("%s: cleared" % key, false, "CLEARED (listed %.4f m), now inside the limit: delete its KNOWN_BAKED row" % KNOWN_BAKED[key])
	print("baked_bracket_reach_test: %d node/class rows past %.3f m, %d allowlist rows cleared" % [_over, CarrierBank.LIMIT + SLACK, _cleared])
	quit(_t.verdict())


func _shell(label: String, pilot: String, variant: String, classes: Array) -> void:
	_cache.clear()
	var hook := HeroAssets.new()
	var map: Dictionary = Cosmetics.asset_paths() if variant != "" else {}
	for p in PILOTS:
		map[p] = HeroAssets.SHELLS[p]
	hook.shell_assets = map
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, pilot, variant, 1, {})
	if not _t.check("%s fits" % label, not rec.is_empty() and (variant == "" or (ResourceLoader.exists(String(map.get(variant, ""))) and rec.variant == variant)), "pilot %s variant '%s'" % [pilot, variant]):
		ball.free()
		hook.free()
		return
	var pod: Node3D = rec.pod
	pod.rotation.y = POD_YAW
	# The closed form for baked nodes needs the pod at the ball centre with an orthonormal, unit-scale basis.
	var b := pod.global_basis
	var rigid := absf(b.x.length() - 1.0) < 1e-4 and absf(b.y.length() - 1.0) < 1e-4 and absf(b.z.length() - 1.0) < 1e-4 \
		and absf(b.x.dot(b.y)) < 1e-4 and absf(b.y.dot(b.z)) < 1e-4 and absf(b.x.dot(b.z)) < 1e-4 and b.determinant() > 0.0
	_t.check("%s pod is rigid at the ball centre" % label, pod.global_position.distance_to(ball.global_position) < 1e-4 and rigid,
		"origin %.6f m off, basis %s" % [pod.global_position.distance_to(ball.global_position), "orthonormal" if rigid else "NOT rigid"])
	for cls in classes:
		hook.set_heft_class(rec, cls, false)
		_measure(hook, pod, label, cls)
	ball.free()
	hook.free()


# Under a node the bank moves: the ring, the bracket holder, the fairlead carriage.
static func _banked(pod: Node3D, node: Node) -> bool:
	var at := node
	while at != null and at != pod:
		if at.name == "WeaponRing" or at.name == "CarrierBank" or (at.name == "Fairlead" and at.get_parent() == pod):
			return true
		at = at.get_parent()
	return false


func _hold(hook, pod: Node3D, normal: Vector3, aim_yaw: float) -> void:
	var aim := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	pod.set_meta("bank_normal", normal)
	for i in FRAMES:
		hook.steer_weapon_ring(pod, aim, DT)
		HeroAssets.update_carrier_bank(pod, normal, DT)


func _measure(hook, pod: Node3D, pilot: String, cls: int) -> void:
	var recs: Array = []
	# The pod is itself a mesh in the shipped shells (the base Pod geometry), so it is measured too.
	var nodes: Array = [pod]
	nodes.append_array(pod.find_children("*", "MeshInstance3D", true, false))
	for node in nodes:
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.layers == 0:
			continue
		var verts := PackedVector3Array()
		if _cache.has(mi.mesh):
			verts = _cache[mi.mesh]
		else:
			for s in mi.mesh.get_surface_count():
				verts.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
			_cache[mi.mesh] = verts
		var n := verts.size()
		var r := {"node": mi, "path": "(pod)" if mi == pod else String(pod.get_path_to(mi)), "mesh": mi.mesh.resource_name, "verts": verts,
			"banked": _banked(pod, mi), "max": -INF, "yaw": 0.0, "bank": 0.0, "wall": "", "sane": true,
			"best": [], "ang": [], "y": [], "rad": []}
		for arr in ["best", "ang", "y", "rad"]:
			(r[arr] as Array).resize(n)
		(r["best"] as Array).fill(-INF)
		recs.append(r)
	for label in WALLS:
		var normal: Vector3 = WALLS[label]
		for yi in range(YAWS):
			pod.rotation.y = TAU * yi / YAWS
			for aim_yaw in AIMS:
				# Baked nodes need one pose per wall (their worst yaw is closed form); banked ones every pose.
				var baked_only: bool = yi > 0 or aim_yaw != AIMS[0]
				_hold(hook, pod, normal, aim_yaw)
				var bank := HeroAssets.carrier_bank(pod).get_rotation_quaternion().get_angle()
				var to_pod := pod.global_transform.affine_inverse()
				var centre := pod.global_position
				for r in recs:
					var banked: bool = r["banked"]
					if not banked and baked_only:
						continue
					var xf: Transform3D = (r["node"] as Node3D).global_transform
					var verts: PackedVector3Array = r["verts"]
					var top := -INF
					for i in verts.size():
						var w := xf * verts[i]
						var reach := (w - centre).dot(-normal)
						var p := to_pod * w
						if not banked:
							reach = _worst_yaw(p, normal)
							if (w - centre).dot(-normal) > reach + 0.0005:
								r["sane"] = false
						top = maxf(top, reach)
						if reach > (r["best"] as Array)[i]:
							(r["best"] as Array)[i] = reach
							(r["ang"] as Array)[i] = rad_to_deg(atan2(p.x, -p.z))
							(r["y"] as Array)[i] = p.y
							(r["rad"] as Array)[i] = Vector2(p.x, p.z).length()
					if top > r["max"]:
						r["max"] = top
						r["yaw"] = rad_to_deg(pod.rotation.y)
						r["bank"] = rad_to_deg(bank)
						r["wall"] = label
	print("--- %s, heft class %d: %d visible meshes (banked nodes posed on each wall at 16 pod yaws, baked nodes worst over any pod yaw)" % [pilot, cls, recs.size()])
	var quiet := 0
	var worst_quiet := 0.0
	for r in recs:
		var peak: float = r["max"]
		if not r["sane"]:
			_t.check("%s class %d %s: posed reach inside the closed form" % [pilot, cls, r["path"]], false, "a posed vertex reaches past the worst-yaw bound")
		if peak < LIST_FROM and peak <= CarrierBank.LIMIT + SLACK:
			quiet += 1
			worst_quiet = maxf(worst_quiet, peak)
			continue
		print("  %-64s %-24s %s max %.4f m%s%s" % [r["path"], r["mesh"], "banked" if r["banked"] else "baked ", peak,
			("  at pod yaw %.1f deg, bank %.1f deg, %s" % [r["yaw"], r["bank"], r["wall"]]) if r["banked"] else "",
			"  OVER" if peak > CarrierBank.LIMIT + SLACK else ""])
		if peak > CarrierBank.LIMIT + SLACK:
			_over += 1
			for c in _clusters(r):
				print("      cluster at %+6.1f deg yaw: %d verts, max %.4f m, height %.3f to %.3f, radius up to %.3f" % [c["at"], c["n"], c["max"], c["lo"], c["hi"], c["rad"]])
			_verdict(pilot, cls, r["path"], peak)
	print("  %d quieter meshes, worst %.4f m" % [quiet, worst_quiet])
	# The banked parts must stay inside the limit (carrier_bank_test's contract, over everything banked).
	for r in recs:
		if r["banked"]:
			_t.check("%s class %d %s: banked part inside the limit" % [pilot, cls, r["path"]], r["max"] <= CarrierBank.LIMIT + SLACK,
				"reach %.4f m" % r["max"])


func _verdict(pilot: String, cls: int, path: String, peak: float) -> void:
	var key := "%s|%d|%s" % [pilot, cls, path]
	_seen[key] = true
	print("      KNOWN_BAKED row: \"%s\": %.4f," % [key, peak])
	if not KNOWN_BAKED.has(key):
		_t.check("%s class %d %s: not past the limit" % [pilot, cls, path], false, "NEW: reaches %.4f m (limit %.2f), not in KNOWN_BAKED" % [peak, CarrierBank.LIMIT])
	else:
		var known := float(KNOWN_BAKED[key])
		_t.check("%s class %d %s: no worse than the known reach" % [pilot, cls, path], peak <= known + TOL,
			"reach %.4f m, known %.4f m" % [peak, known])
		_t.check("%s class %d %s: not improved" % [pilot, cls, path], peak >= known - TOL,
			"reach %.4f m, listed %.4f m; improved: lower its KNOWN_BAKED value to %.4f" % [peak, known, peak])


# The furthest this pod-frame point can reach along -normal over every pod yaw.
static func _worst_yaw(p: Vector3, normal: Vector3) -> float:
	return Vector2(normal.x, normal.z).length() * Vector2(p.x, p.z).length() - normal.y * p.y


# Over-limit vertices of a record, clustered by pod-frame angle (circular, gaps over GAP degrees).
static func _clusters(r: Dictionary) -> Array:
	var best: Array = r["best"]
	var ang: Array = r["ang"]
	var pts: Array = []
	for i in best.size():
		if best[i] > CarrierBank.LIMIT + SLACK:
			pts.append([ang[i], i])
	pts.sort_custom(func(a, b): return a[0] < b[0])
	var groups: Array = []
	for p in pts:
		if groups.is_empty() or p[0] - groups[-1][-1][0] > GAP:
			groups.append([p])
		else:
			groups[-1].append(p)
	if groups.size() > 1 and groups[0][0][0] + 360.0 - groups[-1][-1][0] <= GAP:
		var last: Array = groups.pop_back()
		last.append_array(groups[0])
		groups[0] = last
	var out: Array = []
	for g in groups:
		var sx := 0.0
		var sy := 0.0
		var top := -INF
		var lo := INF
		var hi := -INF
		var rad := 0.0
		for p in g:
			sx += cos(deg_to_rad(p[0]))
			sy += sin(deg_to_rad(p[0]))
			top = maxf(top, best[p[1]])
			lo = minf(lo, (r["y"] as Array)[p[1]])
			hi = maxf(hi, (r["y"] as Array)[p[1]])
			rad = maxf(rad, (r["rad"] as Array)[p[1]])
		out.append({"at": rad_to_deg(atan2(sy, sx)), "n": g.size(), "max": top, "lo": lo, "hi": hi, "rad": rad})
	return out
