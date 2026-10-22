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
	_heft(hook)
	var out := OS.get_environment("SCRAPKEEP_BANK_OUT")
	if out != "":
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(_angles, "\t"))
	hook.free()
	quit(_t.verdict())


# Holds `normal` for FRAMES steps with the aim at `aim_yaw` (-Z faces yaw 0).
func _hold(hook, pod: Node3D, normal: Vector3, aim_yaw: float, frames := FRAMES) -> void:
	var aim := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	for i in frames:
		hook.steer_weapon_ring(pod, aim, DT)
		HeroAssets.update_carrier_bank(pod, normal, DT)


static func _angle(pod: Node3D) -> float:
	return HeroAssets.carrier_bank(pod).get_rotation_quaternion().get_angle()


# The furthest reach, from the pod's centre along -normal, of every vertex of the ring and the bracket
# modules as drawn now, and of the bracket mounts' origins.
static func _reach(pod: Node3D, normal: Vector3, layers := false) -> float:
	var best := -INF
	var centre := pod.global_position
	var carriers: Array[Node3D] = []
	for carrier_name in ["WeaponRing", "CarrierBank"]:
		var carrier := pod.get_node_or_null(carrier_name) as Node3D
		if carrier != null:
			carriers.append(carrier)
	if layers:
		carriers.append_array(HeroAssets._holders(pod))
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
		_hold(hook, pod, Vector3.UP, aim_yaw, 2)
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
		_hold(hook, pod, Vector3.UP, 0.0, 2)
		var level := _reach(pod, normal)
		_t.check("%s %s: control, bank off reaches past 0.99" % [pilot, label], level > CarrierBank.LIMIT + 0.02,
			"level carrier reaches %.4f m into the wall" % level)
	if label == "30 degree slope":
		_t.check("%s %s: gentle slope banks 0" % [pilot, label], angle < 0.0001, "bank %.4f deg" % rad_to_deg(angle))


func _airborne(hook, pod: Node3D, pilot: String) -> void:
	_hold(hook, pod, Vector3.RIGHT, 0.0)
	var held := _angle(pod)
	_hold(hook, pod, Vector3.UP, 0.0, 240)
	_t.check("%s returns to 0 in the air" % pilot, held > 0.3 and _angle(pod) < 0.0005,
		"%.1f deg on the wall, %.4f deg after 4 s of world up" % [rad_to_deg(held), rad_to_deg(_angle(pod))])


func _smooth(hook, pod: Node3D, pilot: String) -> void:
	pod.set_meta("bank_normal", Vector3.UP)
	_hold(hook, pod, Vector3.UP, 0.0, 2)
	var last := 0.0
	var biggest_step := 0.0
	for i in FRAMES:
		HeroAssets.update_carrier_bank(pod, Vector3.RIGHT, DT)
		var now := _angle(pod)
		biggest_step = maxf(biggest_step, now - last)
		last = now
	_t.check("%s bank never pops" % pilot, biggest_step < last * 0.5, "largest one-frame step %.1f deg of %.1f deg" % [rad_to_deg(biggest_step), rad_to_deg(last)])
	_hold(hook, pod, Vector3.UP, 0.0, 240)


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
	_hold(hook, pod, Vector3.UP, 0.0, 240)


# --- heft layers ---------------------------------------------------------------------------------
# The shipped layer glbs bake their modules into the layer Pod mesh and carry none of BRACKET_PARTS, so
# these use a fixture layer that does: an Exhaust_L box 1.25 m out toward the wall, in classes 2 and 3.

func _layer_scene() -> PackedScene:
	var layer := Node3D.new()
	var core := Node3D.new()
	core.name = "Core"
	layer.add_child(core)
	var pod := Node3D.new()
	pod.name = "Pod"
	layer.add_child(pod)
	var part := MeshInstance3D.new()
	part.name = "Exhaust_L"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.1
	var paint := StandardMaterial3D.new()
	paint.resource_name = "paint"
	box.material = paint
	part.mesh = box
	part.position = Vector3(-1.25, 0.0, 0.0)
	pod.add_child(part)
	for n in [core, pod, part]:
		n.owner = layer
	var packed := PackedScene.new()
	packed.pack(layer)
	layer.free()
	return packed


func _fit(layers: bool, heft: int) -> Array:
	var hook := HeroAssets.new()
	hook.shell_assets = {"fx": HeroAssets.SHELLS["pylon_engineer"]}
	if layers:
		for n in [2, 3]:
			hook.shell_assets["fx_c%d" % n] = "fixture://layer%d" % n
			hook._scenes["fixture://layer%d" % n] = _layer_scene()
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, "pylon_engineer", "fx", heft, {})
	return [hook, ball, rec]


func _heft(_unused) -> void:
	var wall := Vector3.RIGHT
	var plain := _fit(false, 1)
	var with_layers := _fit(true, 3)
	var low := _fit(true, 1)
	var holders := HeroAssets._holders(with_layers[2].pod, false)
	_t.check("heft fixture: layer holders found", holders.size() >= 3, "%d CarrierBank holders under the pod (base, the two fixture layers, and the shipped c4 and c5 layers, empty)" % holders.size())
	# 1. Heft 3: every holder is posed, and the layer brackets reach 0.99 or less.
	var pod: Node3D = with_layers[2].pod
	_hold(with_layers[0], pod, wall, 0.0)
	var reach := _reach(pod, wall, true)
	_t.check("heft 3 on a vertical wall: layer brackets reach 0.99 or less", reach <= CarrierBank.LIMIT + SLACK and _angle(pod) > deg_to_rad(30.0),
		"worst reach %.4f m with the layer brackets, bank %.1f deg" % [reach, rad_to_deg(_angle(pod))])
	for h in HeroAssets._holders(pod, false):
		h.basis = Basis.IDENTITY
	var unposed := _reach(pod, wall, true)
	_t.check("heft 3 control: layer holders left level reach past 0.99", unposed > CarrierBank.LIMIT + 0.05, "reach %.4f m" % unposed)
	# 2. Heft 1: the hidden layers' parts do not tilt the carrier; heft 3 tilts it more; back to 1 settles back.
	var want_pod: Node3D = plain[2].pod
	_hold(plain[0], want_pod, wall, 0.0)
	var visible_need := _angle(want_pod)
	var first: Node3D = low[2].pod
	_hold(low[0], first, wall, 0.0)
	_t.check("heft 1 bank is what its visible parts need", absf(_angle(first) - visible_need) < 0.0005,
		"%.2f deg with hidden layers, %.2f deg without them" % [rad_to_deg(_angle(first)), rad_to_deg(visible_need)])
	var hulls := HeroAssets._bank_hull(first, false)
	var stale := CarrierBank.angle_for(hulls["ring"], 0.0, hulls["brackets"], wall)
	_t.check("heft 1 control: a hull of every layer banks further", rad_to_deg(stale) > rad_to_deg(visible_need) + 3.0,
		"all-layer hull %.2f deg, visible %.2f deg" % [rad_to_deg(stale), rad_to_deg(visible_need)])
	low[0].set_heft_class(low[2], 3, false)
	_hold(low[0], first, wall, 0.0)
	var raised := _angle(first)
	low[0].set_heft_class(low[2], 1, false)
	_hold(low[0], first, wall, 0.0)
	_t.check("the hull follows the heft class", raised > visible_need + deg_to_rad(3.0) and absf(_angle(first) - visible_need) < 0.0005,
		"heft 1 %.2f deg, heft 3 %.2f deg, back to heft 1 %.2f deg" % [rad_to_deg(visible_need), rad_to_deg(raised), rad_to_deg(_angle(first))])
	for fitted in [plain, with_layers, low]:
		fitted[1].free()
		fitted[0].free()
