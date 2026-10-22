extends SceneTree
# 2026-10-22 (MOTION-SPEC row 208, wave 19 fix round): a heft change in play animates (`set_heft_class(...,
# true)`), and _slam moves every mesh under the layer holder, now including the banked parts under
# HeftC<n>/Pod/CarrierBank, to rest + outward * HEFT_SLAM_FROM. The bank hull is cached on layer visibility
# alone, so a hull built mid-slam used to keep the displaced points after the slam settled. _points_under
# reads a node's `heft_rest` position, so the hull is the rest geometry.
#
# For a shell whose heft layer has a banked part (Tally class 5 HeavyDrums, Tarn class 3 ClawHooks): fit it,
# heft up with animate on, build the hull while the slam is in flight (the banked part sits off its rest),
# finish the tween (kill it and apply rest), then pose it on a vertical wall the way baked_bracket_reach_test does (pod yaws,
# four aims, the bank re-settled at each) and measure every banked vertex. The reach must be 0.992 or less
# and the settled bank angle must match a shell fitted at the same class without animation.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CarrierBank := preload("res://src/presentation/carrier_bank.gd")
const T := preload("res://tests/support/t.gd")

const CASES := [["tally", 5, "HeavyDrums"], ["tarn", 3, "ClawHooks"]]
const DT := 1.0 / 60.0
const FRAMES := 40
const YAWS := 8
const AIMS := [0.0, PI * 0.5, PI, -PI * 0.5]
const WALL := Vector3(1.0, 0.0, 0.0)
const MAX_REACH := 0.992
const ANGLE_TOL := 0.0005

var _t := T.new("heft_slam_bank_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for c in CASES:
		_case(String(c[0]), int(c[1]), String(c[2]))
	quit(_t.verdict())


func _fit(pilot: String) -> Array:
	var hook := HeroAssets.new()
	var map := {}
	for p in HeroAssets.SHELLS:
		map[p] = HeroAssets.SHELLS[p]
	hook.shell_assets = map
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, pilot, "", 1, {})
	return [hook, ball, rec]


# The banked meshes under the pod: the ring, the CarrierBank holder and the fairlead carriage.
static func _banked(pod: Node3D, node: Node) -> bool:
	var at := node
	while at != null and at != pod:
		if at.name == "WeaponRing" or at.name == "CarrierBank" or (at.name == "Fairlead" and at.get_parent() == pod):
			return true
		at = at.get_parent()
	return false


static func _reach(pod: Node3D) -> float:
	var best := -INF
	var centre := pod.global_position
	for mi: MeshInstance3D in pod.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree() or not _banked(pod, mi):
			continue
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				best = maxf(best, (mi.global_transform * v - centre).dot(-WALL))
	return best


func _hold(hook, pod: Node3D, aim_yaw: float, frames := FRAMES) -> void:
	var aim := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	pod.set_meta("bank_normal", WALL)
	for i in frames:
		hook.steer_weapon_ring(pod, aim, DT)
		HeroAssets.update_carrier_bank(pod, WALL, DT)


func _angle(pod: Node3D) -> float:
	return HeroAssets.carrier_bank(pod).get_rotation_quaternion().get_angle()


# The worst banked reach over the pod yaws and aims, the bank re-settled at each pose.
func _sweep(hook, pod: Node3D) -> float:
	var worst := -INF
	for yi in YAWS:
		pod.rotation.y = TAU * yi / YAWS
		for aim in AIMS:
			_hold(hook, pod, aim)
			worst = maxf(worst, _reach(pod))
	return worst


func _case(pilot: String, cls: int, part_name: String) -> void:
	var fitted := _fit(pilot)
	var hook = fitted[0]
	var rec: Dictionary = fitted[2]
	var pod: Node3D = rec.pod
	if not _t.check("%s fits" % pilot, not rec.is_empty()):
		return
	# Heft up with animate on: the slam starts at once, every layer mesh off its rest.
	hook.set_heft_class(rec, cls, true)
	var parts: Array = []
	for mi in pod.find_children(part_name, "MeshInstance3D", true, false):
		if _banked(pod, mi):
			parts.append(mi)
	_t.check("%s class %d: %s is a banked layer part" % [pilot, cls, part_name], not parts.is_empty(), "%d banked meshes named %s" % [parts.size(), part_name])
	var displaced := 0.0
	for mi: MeshInstance3D in parts:
		displaced = maxf(displaced, mi.position.distance_to(mi.get_meta("heft_rest", mi.position)))
	_t.check("%s class %d: the slam is in flight" % [pilot, cls], displaced > HeroAssets.HEFT_SLAM_FROM * 0.5, "%s sits %.3f m off its rest" % [part_name, displaced])
	# The hull builds now, from the layer as it stands mid-slam.
	pod.rotation.y = 0.0
	_hold(hook, pod, 0.0, 2)
	# Finish the slam: kill each layer tween and apply the rest positions, as the tween's last step does.
	for holder in pod.find_children("HeftC*", "Node3D", false, false):
		var tween = holder.get_meta("heft_tween") if holder.has_meta("heft_tween") else null
		if tween is Tween and tween.is_valid():
			tween.kill()
		HeroAssets._rest(holder)
	var settled := 0.0
	for mi: MeshInstance3D in parts:
		settled = maxf(settled, mi.position.distance_to(mi.get_meta("heft_rest", mi.position)))
	_t.check("%s class %d: the slam has settled" % [pilot, cls], settled < 0.001, "%s is %.5f m off its rest" % [part_name, settled])
	var reach := _sweep(hook, pod)
	_t.check("%s class %d: banked reach 0.992 or less after a mid-slam hull" % [pilot, cls], reach <= MAX_REACH,
		"max banked reach %.4f m over %d yaws x 4 aims on a vertical wall" % [reach, YAWS])
	# The control: the same class fitted with no slam banks the same.
	var control := _fit(pilot)
	var control_pod: Node3D = control[2].pod
	control[0].set_heft_class(control[2], cls, false)
	pod.rotation.y = 0.0
	control_pod.rotation.y = 0.0
	_hold(hook, pod, 0.0, 120)
	_hold(control[0], control_pod, 0.0, 120)
	_t.check("%s class %d: the bank matches an unanimated fit" % [pilot, cls], absf(_angle(pod) - _angle(control_pod)) < ANGLE_TOL,
		"%.3f deg after the slam, %.3f deg without one" % [rad_to_deg(_angle(pod)), rad_to_deg(_angle(control_pod))])
	var control_reach := _sweep(control[0], control_pod)
	_t.check("%s class %d: the unanimated fit reaches %.3f or less too" % [pilot, cls, MAX_REACH], control_reach <= MAX_REACH,
		"max banked reach %.4f m" % control_reach)
	for f in [fitted, control]:
		f[1].free()
		f[0].free()
