extends SceneTree

# Rule (port note P6 of LANDMARK-CARDS.md card 1, "Open on each pulse", wardens/reactor.md:100): park_dam's spillway
# gates, the landmark GLB's gate_l and gate_r leaves, swing open about their own trunnions while the stage-1 reactor's
# dam_face sheet runs and settle shut after it ends, whether the sheet runs out or the next charge cuts it. Each leaf's
# node has its origin on its hinge empty (landmarks.py: gate_l_hinge (-6, 44, -8), gate_r_hinge (6, 44, -8)) and turns
# about its local X, so the hinge never moves while the lip lifts to the trunnion's height. With no reactor, a reactor
# on another mounting, or a dead one, they rest shut. The swing is a view only: the leaves carry no collider, and
# posing them never changes the driver's sheet, cycle or ride state.

const T := preload("res://tests/support/t.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")
const DamRig := preload("res://src/world/park/dam_rig.gd")
const Augments := preload("res://src/movement/augments.gd")

const MAP := "park_dam"
const HINGES := {"gate_l": Vector3(-6.0, 44.0, -8.0), "gate_r": Vector3(6.0, 44.0, -8.0)}
# The lip's rise at OPEN_RAD: the leaf's sill (44 - 11.5 sin 0.62 = 37.3) up to about the trunnion's height.
const LIFT_BAND := Vector2(5.5, 7.5)


class Reactor:
	extends Node3D
	var mounting := "dam_face"
	var mount_driver = WardenReactor.new()
	var spec := {}
	var target = null
	var dead := false
	# The driver closes a sheet whose charge a stagger cancelled (W1-67), so it reads this.
	var _charging := true

	func is_dead() -> bool:
		return dead


var t := T.new("dam_gates_test")
var _dt := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % MAP))
	var bake := ParkGraphTool.load_bake("res://assets/park/" + MAP)
	var ground := Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
	var parent := Node3D.new()
	root.add_child(parent)
	var node: Node3D = ParkRecipes.place_landmark(park, parent, ground)
	var rig = node.get_node_or_null("DamRig") if node != null else null
	if not t.check("the dam carries its rig", rig != null, "proxy %s" % (node.get_meta("landmark_proxy", false) if node != null else "no node")):
		quit(t.verdict())
		return
	t.eq("the rig drives both leaves", rig.leaves.map(func(v): return String(v.name)), DamRig.LEAVES)

	# The leaves hang on their hinge empties with the trunnion along X.
	var origin: Vector3 = ParkRecipes.ride_frame(ParkRecipes.landmark_row(park))["origin"]
	for k in rig.leaves.size():
		var leaf: MeshInstance3D = rig.leaves[k]
		var rest: Transform3D = rig.rests[k]
		var hinge: Vector3 = origin + HINGES[String(leaf.name)]
		t.check("%s sits on its hinge" % leaf.name, rest.origin.distance_to(hinge) < 0.01, "%s, hinge %s" % [rest.origin, hinge])
		t.check("%s turns about X" % leaf.name, rest.basis.x.distance_to(Vector3.RIGHT) < 0.001 and rest.basis.is_orthonormal(),
			"%s" % rest.basis)
		t.check("%s has no collider" % leaf.name, leaf.find_children("*", "CollisionObject3D", true, false).is_empty()
			and leaf.find_children("*", "CollisionShape3D", true, false).is_empty())
	var sills: Array[float] = []
	for leaf in rig.leaves:
		sills.append(_lip(leaf))

	# No reactor: shut.
	for i in 30:
		rig.pose(null, _dt)
	_shut("no reactor: the leaves rest shut", rig)

	# The rig finds the dam's reactor and passes over a reactor on another mounting.
	var anchor := _v3(park["landmark"]["warden"]["anchor"])
	var decoy := Reactor.new()
	decoy.mounting = "flume"
	parent.add_child(decoy)
	decoy.global_position = anchor
	decoy.add_to_group(Augments.ANCHOR_GROUP)
	t.check("a flume reactor is not the dam's", DamRig.find_reactor(self, node.global_position) == null)
	var reactor := Reactor.new()
	parent.add_child(reactor)
	reactor.global_position = anchor + Vector3(0.0, 0.0, 5.0)
	reactor.add_to_group(Augments.ANCHOR_GROUP)
	t.check("the rig finds the dam_face reactor", DamRig.find_reactor(self, node.global_position) == reactor)
	for i in int(DamRig.SEEK_EVERY / _dt) + 4:
		await physics_frame
	t.check("the running rig takes up the reactor", rig.warden == reactor)
	t.check("between pulses the leaves stay shut", rig.angle() == 0.0)
	parent.set_physics_process(false)
	rig.set_physics_process(false)

	# A pulse: the sheet runs, the leaves open in OPEN_SECONDS and hold.
	var driver = reactor.mount_driver
	driver.gates_opened += 1
	driver.sheet_left = WardenReactor.SHEET_SECONDS
	var before := _state(driver)
	# A control driver stepped the same way with no rig: the posed driver must match it tick for tick.
	var control := Reactor.new()
	control.mount_driver.gates_opened = driver.gates_opened
	control.mount_driver.sheet_left = driver.sheet_left
	var matched := true
	var quarter := -1.0
	var opened_at := -1.0
	var clock := 0.0
	while driver.sheet_live():
		driver.step(reactor, _dt)
		control.mount_driver.step(control, _dt)
		rig.pose(driver, _dt)
		matched = matched and _state(driver) == _state(control.mount_driver)
		clock += _dt
		if quarter < 0.0 and clock >= DamRig.OPEN_SECONDS * 0.25:
			quarter = rig.angle()
		if opened_at < 0.0 and is_equal_approx(rig.angle(), DamRig.OPEN_RAD):
			opened_at = clock
		if clock >= WardenReactor.SHEET_SECONDS - 4.0 * _dt and clock < WardenReactor.SHEET_SECONDS - 3.0 * _dt:
			t.near("open through the sheet", rig.angle(), DamRig.OPEN_RAD, 1e-6)
			for k in rig.leaves.size():
				var leaf: MeshInstance3D = rig.leaves[k]
				var lift := _lip(leaf) - sills[k]
				t.check("%s's lip lifts to the trunnion" % leaf.name, lift >= LIFT_BAND.x and lift <= LIFT_BAND.y, "%.2f m" % lift)
				t.check("%s's hinge holds" % leaf.name, leaf.transform.origin.distance_to(rig.rests[k].origin) < 0.001)
	t.check("the leaves open within OPEN_SECONDS", opened_at > 0.0 and opened_at <= DamRig.OPEN_SECONDS + 2.0 * _dt, "%.3f s" % opened_at)
	t.check("the leaves take OPEN_SECONDS, not snap", opened_at >= DamRig.OPEN_SECONDS - 2.0 * _dt, "%.3f s" % opened_at)
	t.check("the leaves ease in: a quarter of the way through they lag a linear swing", quarter > 0.0
		and quarter < 0.2 * DamRig.OPEN_RAD, "%.4f rad against linear %.4f" % [quarter, 0.25 * DamRig.OPEN_RAD])
	t.check("through the live sheet the posed driver matches a control driver with no rig", matched)
	control.free()

	# The sheet runs out: shut within CLOSE_SECONDS.
	var shut_after := _close_time(rig, driver, reactor)
	t.check("the leaves settle shut within CLOSE_SECONDS", shut_after > 0.0 and shut_after <= DamRig.CLOSE_SECONDS + 2.0 * _dt, "%.3f s" % shut_after)
	_shut("after the sheet the leaves rest shut", rig)

	# The posing never reaches the fight: the driver's state moved only by its own step.
	var after_rig := _state(driver)
	rig.pose(driver, _dt)
	t.eq("posing changes no driver state", _state(driver), after_rig)
	t.eq("the sheet's cycle is the pulse's", driver.gates_opened, before["gates_opened"])

	# The next charge cuts the sheet short: the leaves start home at once.
	driver.gates_opened += 1
	driver.sheet_left = WardenReactor.SHEET_SECONDS
	for i in int(DamRig.OPEN_SECONDS / _dt) + 2:
		driver.step(reactor, _dt)
		rig.pose(driver, _dt)
	driver.on_charge(reactor, 1.0)
	t.check("a charge ends the sheet", not driver.sheet_live())
	var was: float = rig.angle()
	rig.pose(driver, _dt)
	t.check("a cut sheet starts the leaves home", rig.angle() < was, "%.4f from %.4f" % [rig.angle(), was])
	shut_after = _close_time(rig, driver, reactor)
	t.check("a cut sheet shuts within CLOSE_SECONDS", shut_after <= DamRig.CLOSE_SECONDS + 2.0 * _dt, "%.3f s" % shut_after)

	# A dead reactor leaves them shut, sheet or no sheet.
	driver.sheet_left = WardenReactor.SHEET_SECONDS
	reactor.dead = true
	for i in 30:
		rig.pose(rig._driver(), _dt)
	_shut("a dead reactor: the leaves rest shut", rig)

	parent.free()
	quit(t.verdict())


# How long the leaves take to close from their pose now, stepping the driver too; -1 if they never do in 3 s.
func _close_time(rig, driver, reactor) -> float:
	var clock := 0.0
	while clock < 3.0:
		driver.step(reactor, _dt)
		rig.pose(driver, _dt)
		clock += _dt
		if rig.angle() == 0.0:
			return clock
	return -1.0


func _shut(label: String, rig) -> void:
	var ok: bool = rig.angle() == 0.0
	for k in rig.leaves.size():
		ok = ok and rig.leaves[k].transform.is_equal_approx(rig.rests[k])
	t.check(label, ok, "angle %.4f" % rig.angle())


# The leaf's lowest point in the landmark's space: its lip.
func _lip(leaf: MeshInstance3D) -> float:
	var low := INF
	var faces := leaf.mesh.get_faces()
	for v in faces:
		low = minf(low, (leaf.transform * v).y)
	return low


func _state(driver) -> Dictionary:
	return {"gates_opened": driver.gates_opened, "sheet_left": driver.sheet_left, "riding": driver.riding,
		"rides": driver.rides, "entered": driver.entered_sheet_cycle, "paid_cycle": driver.paid_cycle}


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
