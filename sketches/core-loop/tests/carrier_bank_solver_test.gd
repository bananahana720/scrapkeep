extends SceneTree
# 2026-10-22 (issue #241, option a): CarrierBank.solve reports {angle, reach, clears} at the angle the old
# bisection returned (MAX_ANGLE when no midpoint clears), so a hull no bank clears is visible. Planted
# hulls: five points at radius 1.2, 60 degrees apart in the bank plane (some point always sits inside the
# 34 degree window that reaches past 0.99), which no bank clears; two points whose midpoints all fail but
# MAX_ANGLE clears; a hull at 0.8 that clears level. Regression: the shipped shells' hulls give the old
# angle bit for bit. Through update_carrier_bank: a shell on a wall leaves bank_residual 0, a planted
# bracket hull sets it and bank_warned.

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
	var none := PackedVector3Array()
	# F1: every midpoint fails (88.6 degrees reaches about 0.9995) but MAX_ANGLE clears.
	var edge := PackedVector3Array([_pt(1.2, 0.0), _pt(1.2, -55.0), _pt(0.5, 90.0), _pt(0.5, 180.0)])
	var e := CarrierBank.solve(edge, 0.0, none, WALL)
	_t.check("midpoints fail, MAX_ANGLE clears: angle MAX_ANGLE, clears true", e["angle"] == CarrierBank.MAX_ANGLE and e["clears"] == true and e["reach"] <= CarrierBank.LIMIT,
		"angle %.4f deg, reach %.4f, clears %s" % [rad_to_deg(e["angle"]), e["reach"], e["clears"]])
	var ring := PackedVector3Array()
	for deg in [-120.0, -60.0, 0.0, 60.0, 120.0]:
		ring.append(_pt(1.2, deg))
	var s := CarrierBank.solve(ring, 0.0, none, WALL)
	var at_max := CarrierBank.support(ring, 0.0, none, CarrierBank.basis_for(WALL, CarrierBank.MAX_ANGLE), -WALL)
	var residual := maxf(0.0, s["reach"] - CarrierBank.LIMIT)
	_t.check("unclearable hull: angle is the old MAX_ANGLE, clears false", s["angle"] == CarrierBank.MAX_ANGLE and s["clears"] == false,
		"angle %.2f deg, clears %s" % [rad_to_deg(s["angle"]), s["clears"]])
	_t.check("unclearable hull: residual is support(MAX) - LIMIT, above 0.04", absf(residual - (at_max - CarrierBank.LIMIT)) < 1e-6 and residual > 0.04,
		"residual %.5f m, support at MAX %.5f" % [residual, at_max])
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
		"clears %s, angle %.1f deg (bisected), reach %.4f" % [b["clears"], rad_to_deg(b["angle"]), b["reach"]])
	_t.check("single far point: angle matches the old bisection", b["angle"] == _old_angle(one, 0.0, none, WALL), "%.6f" % b["angle"])


func _regression() -> void:
	var normals := [WALL, Vector3(sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)), 0.0), Vector3(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)), 0.0), Vector3.UP]
	var same := 0
	var total := 0
	var worst := ""
	var banked := {}
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
		_t.check("%s hull is non-empty" % pilot, hull["ring"].size() + hull["brackets"].size() > 0, "%d ring, %d bracket points" % [hull["ring"].size(), hull["brackets"].size()])
		for normal in normals:
			for yaw in [0.0, 0.7, PI * 0.5, PI, -PI * 0.5]:
				total += 1
				var got := CarrierBank.solve(hull["ring"], yaw, hull["brackets"], normal)
				var want := _old_angle(hull["ring"], yaw, hull["brackets"], normal)
				if want > 0.0 and normal == WALL:
					banked[pilot] = int(banked.get(pilot, 0)) + 1
				if got["angle"] == want and CarrierBank.angle_for(hull["ring"], yaw, hull["brackets"], normal) == want:
					same += 1
				else:
					worst = "%s yaw %.2f: %.6f vs %.6f" % [pilot, yaw, got["angle"], want]
		stage.queue_free()
	for pilot in PILOTS:
		_t.check("%s banks on the wall in the regression poses" % pilot, int(banked.get(pilot, 0)) >= 1, "%d of 5 yaws" % int(banked.get(pilot, 0)))
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
	_planted_update()
	hook.free()


# A bracket holder with five far boxes (radius 1.2, 60 degrees apart in the bank plane) that no bank clears.
func _planted_update() -> void:
	var pod := Node3D.new()
	var holder := Node3D.new()
	holder.name = "CarrierBank"
	pod.add_child(holder)
	var boxes: Array[MeshInstance3D] = []
	for deg in [-120.0, -60.0, 0.0, 60.0, 120.0]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.01
		box.mesh = mesh
		box.position = _pt(1.2, deg)
		holder.add_child(box)
		boxes.append(box)
	root.add_child(pod)
	pod.set_meta("bank_normal", Vector3.UP)
	for i in 120:
		HeroAssets.update_carrier_bank(pod, WALL, 1.0 / 60.0)
	var residual := float(pod.get_meta("bank_residual", -1.0))
	_t.check("planted unclearable brackets: bank_residual above 0.04, bank_warned set", residual > 0.04 and pod.has_meta("bank_warned"),
		"residual %.4f m, warned for hull key '%s'" % [residual, pod.get_meta("bank_warned", "unset")])
	var warned = pod.get_meta("bank_warned", null)
	for i in 10:
		HeroAssets.update_carrier_bank(pod, WALL, 1.0 / 60.0)
	_t.check("same hull key: bank_warned unchanged (one warning)", pod.get_meta("bank_warned", null) == warned, "key '%s'" % pod.get_meta("bank_warned", "unset"))
	# Pull the boxes in to 0.8 and refresh the hull: it clears, residual 0, the warning re-arms.
	for box in boxes:
		box.position *= 0.8 / 1.2
	pod.remove_meta("bank_hull")
	HeroAssets.update_carrier_bank(pod, WALL, 1.0 / 60.0)
	_t.check("hull pulled in: bank_residual 0 and bank_warned cleared", float(pod.get_meta("bank_residual", -1.0)) == 0.0 and not pod.has_meta("bank_warned"),
		"residual %s, warned %s" % [pod.get_meta("bank_residual", "missing"), pod.has_meta("bank_warned")])
	pod.free()
