extends SceneTree
# 2026-10-22 (MOTION-SPEC row 208): the carrier bank. The six shells, one per pilot, are posed on a
# vertical wall, a wall 30 degrees off vertical and a 30 degree slope, with the weapon ring aimed four
# ways, and the furthest reach of the WeaponRing and the bracket modules along the face normal is measured
# from every vertex of the posed meshes (not the hull the solver uses). Controls: a flat floor banks 0 and
# leaves the carrier level, the same wall with the bank switched off reaches past 0.99 (so the check can
# fail), the bank follows the smoothed normal without a pop, it returns to 0 in the air, the aim still
# applies, the pod stays level, and the fairlead's RopeExit leaves from the banked carrier.
# SCRAPKEEP_BANK_OUT=<abs path> also writes the per-shell angles as JSON.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CarrierBank := preload("res://src/presentation/carrier_bank.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const T := preload("res://tests/support/t.gd")

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const DT := 1.0 / 60.0
const FRAMES := 120
# The hull is exact for the solver; the measured meshes get this much slack for float noise only.
const SLACK := 0.002
const AIMS := [0.0, PI * 0.5, PI, -PI * 0.5]

var _t := T.new("carrier_bank_test")
var _angles := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hook := HeroAssets.new()
	var walls := {
		"vertical wall": Vector3(1.0, 0.0, 0.0),
		"wall 30 degrees off vertical": Vector3(sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)), 0.0),
		"30 degree slope": Vector3(sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)), 0.0),
	}
	for pilot in PILOTS:
		var path: String = HeroAssets.SHELLS[pilot]
		var packed := load(path) as PackedScene
		if not _t.check("%s shell loads" % pilot, packed != null, path):
			continue
		var parts := HeroAssets._split(packed.instantiate())
		var pod: Node3D = parts["pod"]
		var core: Node3D = parts["core"]
		var stage := Node3D.new()
		root.add_child(stage)
		stage.add_child(pod)
		stage.add_child(core)
		pod.rotation.y = 0.7
		var holder := pod.get_node_or_null("CarrierBank") as Node3D
		_t.check("%s bracket holder" % pilot, holder != null and holder.get_parent() == pod, "Pod > CarrierBank")
		_floor(hook, pod, pilot)
		for label in walls:
			_wall(hook, pod, pilot, label, walls[label])
		_airborne(hook, pod, pilot)
		_smooth(hook, pod, pilot)
		_fairlead(hook, pod, pilot)
		stage.queue_free()
	var out := OS.get_environment("SCRAPKEEP_BANK_OUT")
	if out != "":
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(_angles, "\t"))
	hook.free()
	quit(_t.verdict())


# Holds `normal` for FRAMES steps with the aim at `aim_yaw` (-Z faces yaw 0); `banked` false skips the bank.
func _hold(hook, pod: Node3D, normal: Vector3, aim_yaw: float, banked := true, frames := FRAMES) -> void:
	var aim := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	for i in frames:
		hook.steer_weapon_ring(pod, aim, DT)
		if banked:
			HeroAssets.update_carrier_bank(pod, normal, DT)


static func _angle(pod: Node3D) -> float:
	return HeroAssets.carrier_bank(pod).get_rotation_quaternion().get_angle()


# The furthest reach, from the pod's centre along -normal, of every vertex of the ring and the bracket
# modules as drawn now, and of the bracket mounts' origins.
static func _reach(pod: Node3D, normal: Vector3) -> float:
	var best := -INF
	var centre := pod.global_position
	var carriers: Array[Node3D] = []
	for carrier_name in ["WeaponRing", "CarrierBank"]:
		var carrier := pod.get_node_or_null(carrier_name) as Node3D
		if carrier != null:
			carriers.append(carrier)
	for carrier in carriers:
		var nodes := [carrier] + carrier.find_children("*", "Node3D", true, false)
		for node: Node3D in nodes:
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				var mesh: Mesh = (node as MeshInstance3D).mesh
				for s in mesh.get_surface_count():
					for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
						best = maxf(best, (node.global_transform * v - centre).dot(-normal))
			elif carrier.name == "CarrierBank" and node != carrier:
				best = maxf(best, (node.global_position - centre).dot(-normal))
	return best


func _floor(hook, pod: Node3D, pilot: String) -> void:
	pod.set_meta("bank_normal", Vector3.UP)
	_hold(hook, pod, Vector3.UP, 0.3)
	var ring := pod.get_node("WeaponRing") as Node3D
	var holder := pod.get_node("CarrierBank") as Node3D
	var level := minf(ring.global_basis.y.normalized().dot(Vector3.UP), holder.global_basis.y.normalized().dot(Vector3.UP))
	_t.check("%s flat floor: bank is 0" % pilot, _angle(pod) < 0.0001 and level > 0.99999,
		"bank %.5f deg, carrier up dot %.6f" % [rad_to_deg(_angle(pod)), level])
	_t.check("%s flat floor: carrier reach inside 0.99" % pilot, _reach(pod, Vector3.UP) <= CarrierBank.LIMIT + SLACK,
		"reach %.4f along -up with no bank" % _reach(pod, Vector3.UP))


func _wall(hook, pod: Node3D, pilot: String, label: String, normal: Vector3) -> void:
	var worst := 0.0
	var angle := 0.0
	var off := 0.0
	for aim_yaw in AIMS:
		pod.set_meta("bank_normal", Vector3.UP)
		_hold(hook, pod, Vector3.UP, aim_yaw, true, 2)
		_hold(hook, pod, normal, aim_yaw)
		worst = maxf(worst, _reach(pod, normal))
		angle = maxf(angle, _angle(pod))
		# The aim still applies: the bank taken out, the ring faces the aim.
		var forward := HeroAssets.carrier_bank(pod).inverse() * (-(pod.get_node("WeaponRing") as Node3D).global_basis.z)
		off = maxf(off, absf(angle_difference(atan2(-forward.x, -forward.z), aim_yaw)))
	_angles["%s | %s" % [pilot, label]] = snappedf(rad_to_deg(angle), 0.1)
	_t.check("%s %s: support at most 0.99" % [pilot, label], worst <= CarrierBank.LIMIT + SLACK,
		"worst reach %.4f m over 4 aims, bank up to %.1f deg" % [worst, rad_to_deg(angle)])
	_t.check("%s %s: the ring still turns to the aim" % [pilot, label], off < 0.02, "worst aim error %.4f rad" % off)
	if label == "vertical wall":
		var bank := HeroAssets.carrier_bank(pod)
		var axis := bank.get_rotation_quaternion().get_axis()
		var lean := (bank * Vector3.UP).dot(normal)
		_t.check("%s %s: bank follows the face normal" % [pilot, label],
			rad_to_deg(angle) > 20.0 and rad_to_deg(angle) < 60.0 and absf(axis.y) < 0.001 and absf(lean - sin(_angle(pod))) < 0.001 and lean > 0.3,
			"up to %.1f deg about a horizontal axis (y %.4f); the carrier up leans %.3f toward the face (sin of the last bank %.3f)" % [rad_to_deg(angle), axis.y, lean, sin(_angle(pod))])
		_t.check("%s %s: pod stays level" % [pilot, label], absf(pod.global_basis.y.normalized().dot(Vector3.UP) - 1.0) < 0.00001,
			"pod up dot %.6f" % pod.global_basis.y.normalized().dot(Vector3.UP))
		# Negative control: the same pose with the bank off must reach past 0.99.
		pod.set_meta("bank_normal", Vector3.UP)
		_hold(hook, pod, Vector3.UP, 0.0, true, 2)
		var level := _reach(pod, normal)
		_t.check("%s %s: control, bank off reaches past 0.99" % [pilot, label], level > CarrierBank.LIMIT + 0.02,
			"level carrier reaches %.4f m into the wall" % level)
	if label == "30 degree slope":
		_t.check("%s %s: gentle slope banks 0" % [pilot, label], angle < 0.0001, "bank %.4f deg" % rad_to_deg(angle))


func _airborne(hook, pod: Node3D, pilot: String) -> void:
	_hold(hook, pod, Vector3.RIGHT, 0.0)
	var held := _angle(pod)
	_hold(hook, pod, Vector3.UP, 0.0, true, 240)
	_t.check("%s returns to 0 in the air" % pilot, held > 0.3 and _angle(pod) < 0.0005,
		"%.1f deg on the wall, %.4f deg after 4 s of world up" % [rad_to_deg(held), rad_to_deg(_angle(pod))])


func _smooth(hook, pod: Node3D, pilot: String) -> void:
	pod.set_meta("bank_normal", Vector3.UP)
	_hold(hook, pod, Vector3.UP, 0.0, true, 2)
	var last := 0.0
	var biggest_step := 0.0
	for i in FRAMES:
		HeroAssets.update_carrier_bank(pod, Vector3.RIGHT, DT)
		var now := _angle(pod)
		biggest_step = maxf(biggest_step, now - last)
		last = now
	_t.check("%s bank never pops" % pilot, biggest_step < last * 0.5, "largest one-frame step %.1f deg of %.1f deg" % [rad_to_deg(biggest_step), rad_to_deg(last)])
	_hold(hook, pod, Vector3.UP, 0.0, true, 240)


func _fairlead(hook, pod: Node3D, pilot: String) -> void:
	var exit := pod.find_child("RopeExit", true, false) as Node3D
	if exit == null:
		return
	var anchor := pod.global_position + Vector3(6.0, 3.0, -2.0)
	for i in FRAMES:
		hook.steer_fairlead(pod, anchor, DT)
		HeroAssets.update_carrier_bank(pod, Vector3.RIGHT, DT)
	var carriage := pod.get_node("Fairlead") as Node3D
	var level := pod.global_basis * HeroAssets._level(pod, carriage)
	var yaw := atan2(level.z.x, level.z.z)
	var want := LineView.fairlead_point(pod.global_position, yaw, HeroAssets.carrier_bank(pod))
	_t.check("%s rope leaves the banked fairlead" % pilot, exit.global_position.distance_to(want) < 0.001 and _angle(pod) > 0.3,
		"RopeExit %.5f m from LineView.fairlead_point with the bank, bank %.1f deg" % [exit.global_position.distance_to(want), rad_to_deg(_angle(pod))])
	_hold(hook, pod, Vector3.UP, 0.0, true, 240)
