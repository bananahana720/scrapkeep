extends SceneTree
# 2026-10-22 (issue #241, option a): CarrierBank.solve reports {angle, reach, clears}, so a hull no bank
# clears is visible instead of silently returning MAX_ANGLE. Planted hulls: five points at radius 1.2,
# 60 degrees apart in the bank plane (some point always sits inside the 34 degree window that reaches past
# 0.99, whichever way the bank turns), which no bank clears; a hull at 0.8 that clears level; one point at
# 1.2 that clears only after a bank. Regression: the shipped shells' hulls give the angle the old
# bisection gave. Through update_carrier_bank, a fitted shell on a wall leaves bank_residual 0.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CarrierBank := preload("res://src/presentation/carrier_bank.gd")
const T := preload("res://tests/support/t.gd")

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const WALL := Vector3.RIGHT
const TOL := 0.0001

var _t := T.new("carrier_bank_solver_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_unclearable()
	_clearable()
	_regression()
	_through_update()
	quit(_t.verdict())


# A point at `radius` in the bank plane, `deg` off the -normal direction (toward the wall side).
static func _pt(radius: float, deg: float) -> Vector3:
	return Vector3(-cos(deg_to_rad(deg)), sin(deg_to_rad(deg)), 0.0) * radius


# The pre-fix algorithm, kept as the reference.
static func _old_angle(ring: PackedVector3Array, yaw: float, brackets: PackedVector3Array, normal: Vector3) -> float:
	if CarrierBank.UP.cross(normal).length() < CarrierBank.FLAT:
		return 0.0
	var toward := -normal
	if CarrierBank.support(ring, yaw, brackets, Basis.IDENTITY, toward) <= CarrierBank.LIMIT:
		return 0.0
	var lo := 0.0
	var hi := CarrierBank.MAX_ANGLE
	for i in CarrierBank.STEPS:
		var mid := (lo + hi) * 0.5
		if CarrierBank.support(ring, yaw, brackets, CarrierBank.basis_for(normal, mid), toward) <= CarrierBank.LIMIT:
			hi = mid
		else:
			lo = mid
	return hi


func _unclearable() -> void:
	var ring := PackedVector3Array()
	for deg in [-120.0, -60.0, 0.0, 60.0, 120.0]:
		ring.append(_pt(1.2, deg))
	var none := PackedVector3Array()
	var s := CarrierBank.solve(ring, 0.0, none, WALL)
	_t.check("unclearable hull: clears is false", s["clears"] == false, "clears %s, reach %.4f" % [s["clears"], s["reach"]])
	var residual := maxf(0.0, s["reach"] - CarrierBank.LIMIT)
	# The nearest point is at most 30 degrees off the wall direction, so its reach is at least 1.2 cos 30.
	var floor_reach := 1.2 * cos(deg_to_rad(30.0))
	_t.check("unclearable hull: residual is what the best bank leaves", residual >= floor_reach - CarrierBank.LIMIT - TOL,
		"residual %.4f m, at least %.4f m" % [residual, floor_reach - CarrierBank.LIMIT - TOL])
	_t.check("unclearable hull: angle inside [0, MAX_ANGLE]", s["angle"] >= 0.0 and s["angle"] <= CarrierBank.MAX_ANGLE,
		"angle %.2f deg" % rad_to_deg(s["angle"]))
	# The evaluated set: 0, the six bisection midpoints (lo always moves up when nothing clears), MAX_ANGLE.
	var candidates := [0.0, CarrierBank.MAX_ANGLE]
	var lo := 0.0
	for i in CarrierBank.STEPS:
		lo = (lo + CarrierBank.MAX_ANGLE) * 0.5
		candidates.append(lo)
	var least := INF
	for a in candidates:
		least = minf(least, CarrierBank.support(ring, 0.0, none, CarrierBank.basis_for(WALL, a), -WALL))
	var reach_at := CarrierBank.support(ring, 0.0, none, CarrierBank.basis_for(WALL, s["angle"]), -WALL)
	_t.check("unclearable hull: angle is one evaluated", candidates.any(func(a): return is_equal_approx(a, s["angle"])), "angle %.4f rad" % s["angle"])
	_t.check("unclearable hull: angle is the least-reach one", absf(least - s["reach"]) < 1e-6 and absf(reach_at - s["reach"]) < 1e-6,
		"returned reach %.5f, support at that angle %.5f, least over %d evaluated %.5f" % [s["reach"], reach_at, candidates.size(), least])
	_t.check("unclearable hull: angle_for wrapper agrees", CarrierBank.angle_for(ring, 0.0, none, WALL) == s["angle"], "")


func _clearable() -> void:
	var ring := PackedVector3Array()
	for deg in [-120.0, -60.0, 0.0, 60.0, 120.0]:
		ring.append(_pt(0.8, deg))
	var none := PackedVector3Array()
	var s := CarrierBank.solve(ring, 0.0, none, WALL)
	_t.check("clearable hull at 0.8: clears, angle 0, residual 0", s["clears"] == true and s["angle"] == 0.0 and maxf(0.0, s["reach"] - CarrierBank.LIMIT) == 0.0,
		"clears %s, angle %.4f, reach %.4f" % [s["clears"], s["angle"], s["reach"]])
	var one := PackedVector3Array([_pt(1.2, 0.0), _pt(0.5, 90.0), _pt(0.5, -90.0), _pt(0.5, 180.0)])
	var b := CarrierBank.solve(one, 0.0, none, WALL)
	_t.check("single far point clears after a bank", b["clears"] == true and b["angle"] > 0.0 and b["reach"] <= CarrierBank.LIMIT,
		"clears %s, angle %.1f deg, reach %.4f" % [b["clears"], rad_to_deg(b["angle"]), b["reach"]])
	_t.check("single far point: angle matches the old bisection", b["angle"] == _old_angle(one, 0.0, none, WALL), "%.6f" % b["angle"])


func _regression() -> void:
	var normals := [WALL, Vector3(sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)), 0.0), Vector3(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)), 0.0), Vector3.UP]
	var same := 0
	var total := 0
	var worst := ""
	for pilot in PILOTS:
		var packed := load(HeroAssets.SHELLS[pilot]) as PackedScene
		if not _t.check("%s shell loads" % pilot, packed != null, HeroAssets.SHELLS[pilot]):
			continue
		var parts := HeroAssets._split(packed.instantiate())
		var stage := Node3D.new()
		root.add_child(stage)
		stage.add_child(parts["pod"])
		stage.add_child(parts["core"])
		var hull := HeroAssets._bank_hull(parts["pod"])
		for normal in normals:
			for yaw in [0.0, 0.7, PI * 0.5, PI, -PI * 0.5]:
				total += 1
				var got := CarrierBank.solve(hull["ring"], yaw, hull["brackets"], normal)
				var want := _old_angle(hull["ring"], yaw, hull["brackets"], normal)
				if got["angle"] == want and CarrierBank.angle_for(hull["ring"], yaw, hull["brackets"], normal) == want:
					same += 1
				else:
					worst = "%s yaw %.2f: %.6f vs %.6f" % [pilot, yaw, got["angle"], want]
		stage.queue_free()
	_t.check("regression: solve angle equals the old angle_for on every shipped shell pose", same == total, "%d of %d bit-identical %s" % [same, total, worst])


func _through_update() -> void:
	var hook := HeroAssets.new()
	var pod_scene := load(HeroAssets.SHELLS["pylon_engineer"]) as PackedScene
	if not _t.check("pylon shell loads", pod_scene != null, HeroAssets.SHELLS["pylon_engineer"]):
		return
	var parts := HeroAssets._split(pod_scene.instantiate())
	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(parts["pod"])
	stage.add_child(parts["core"])
	var pod: Node3D = parts["pod"]
	pod.set_meta("bank_normal", Vector3.UP)
	for i in 120:
		HeroAssets.update_carrier_bank(pod, WALL, 1.0 / 60.0)
	var bank := HeroAssets.carrier_bank(pod).get_rotation_quaternion().get_angle()
	_t.check("update_carrier_bank on a wall: bank_residual meta is 0", pod.has_meta("bank_residual") and pod.get_meta("bank_residual") == 0.0 and bank > 0.3,
		"residual %s, bank %.1f deg" % [pod.get_meta("bank_residual", "missing"), rad_to_deg(bank)])
	hook.free()
