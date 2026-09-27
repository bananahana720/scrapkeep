extends Node3D

const Palette := preload("res://src/core/palette.gd")
const SteamCycle := preload("res://src/world/steam_cycle.gd")
const RideRail := preload("res://src/world/ride_rail.gd")

# The gorge's contraptions, built from the map's specs and run from world's physics
# tick (DESIGN-V2 section 9, VISUAL-LANGUAGE section 11). Every one is a momentum tool
# you ride, never a stop: a launcher that is not ready lets you roll through, a lift
# you are not on never holds you, and a door only stands where a valve opens it.
# Each shows its cycle on a bone gauge whose needle sweeps linearly, puffs steam at the
# fire moment, and reports a world fact with its own sound.
#
# step() returns facts for world to publish or apply:
#   {"kind": "ride", "ride": RideRail}           hold the ball to this rail
#   {"kind": "fact", "fact": String, "at": Vector3}   a WORLD_ROWS kind
#   {"kind": "codex", "id": String, "at": Vector3}
#   {"kind": "accel", "accel": Vector3}           a push to add this tick (a thermal)

const GAUGE_REACH := 60.0
const RAM_REACH := 2.8
const SLAM_REACH := 4.5
const THERMAL_LIFT := 34.0
const THERMAL_GAP := 1.5
const WALL_REACH := 3.6
const WALL_SPEED := 8.0
const DOOR_SINK := 6.5
const DOOR_SECONDS := 0.6
const CABLE_REST := 1.0
const PUFF_SECONDS := 0.7

var map
var ground: Callable
var cruise := 14.0
var gravity := 26.0

var barges: Array[Dictionary] = []
var lifts: Array[Dictionary] = []
var launchers: Array[Dictionary] = []
var cables: Array[Dictionary] = []
var valves: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var thermals: Array[Dictionary] = []

var _puffs: Array[Dictionary] = []
var _slams: Array[Vector3] = []
var _thermal_quiet := 0.0
var _gauge_mat: Material
var _needle_mat: Material
var _steam_mat: Material


func setup(map_ref, ground_ref: Callable, cruise_speed: float, g: float) -> void:
	map = map_ref
	ground = ground_ref
	cruise = cruise_speed
	gravity = g
	name = "Contraptions"
	_gauge_mat = Palette.solid(Palette.SAND)
	_needle_mat = Palette.solid(Palette.CHARCOAL)
	_steam_mat = Palette.unshaded(Color(Palette.SAND, 0.55))
	for spec in map.contraptions:
		match spec["kind"]:
			"barge":
				barges.append(_build_barge(spec))
			"lift":
				lifts.append(_build_lift(spec))
			"launcher":
				launchers.append(_build_launcher(spec))
			"cable":
				cables.append(_build_cable(spec))
			"valve":
				valves.append(_build_valve(spec))
			"cracked_wall":
				walls.append(_build_wall(spec))
			"thermal":
				thermals.append(_build_thermal(spec))
	reset()


# Back to the stage start: cycles on their seeded offsets, doors shut, walls whole.
func reset() -> void:
	for b in barges:
		b["time"] = b["spec"]["offset"]
		_place_barge(b, Vector3.INF)
	for l in lifts:
		l["cycle"] = SteamCycle.new(SteamCycle.PERIODIC, l["spec"]["charge"], l["spec"]["offset"])
		_place_lift(l)
	for l in launchers:
		l["cycle"] = SteamCycle.new(SteamCycle.ON_DEMAND, l["spec"]["charge"], 0.0)
	for c in cables:
		c["rest"] = 0.0
	for v in valves:
		v["open"] = false
		v["sink"] = 0.0
		v["door"].position = v["door_home"]
		if v["plume"] != null:
			v["plume"].visible = false
	for w in walls:
		w["broken"] = false
		w["body"].position = w["home"]
		w["body"].visible = true
	_slams.clear()
	_thermal_quiet = 0.0


func note_slam(at: Vector3) -> void:
	_slams.append(at)


# One physics tick. riding is true while world already holds the ball to a rail.
func step(delta: float, ball: Vector3, velocity: Vector3, kit, riding: bool) -> Array:
	var facts := []
	for b in barges:
		b["time"] += delta
		_place_barge(b, ball)
	for l in lifts:
		var what: String = l["cycle"].step(delta)
		_place_lift(l)
		if what == "fired":
			var top: Vector3 = l["home"]
			facts.append({"kind": "fact", "fact": "lift_fired", "at": top})
			_puff(top + Vector3.UP * 0.5, 4.0)
		_needle(l["needle"], l["cycle"].gauge())
	var planar := Vector2(velocity.x, velocity.z).length()
	for l in launchers:
		var what: String = l["cycle"].step(delta)
		if what == "charging":
			facts.append({"kind": "fact", "fact": "launcher_charging", "at": l["mouth"]})
		_needle(l["needle"], l["cycle"].gauge())
		_launcher_pose(l)
		if riding or not _at_mouth(ball, l["mouth"], l["spec"]["radius"]):
			continue
		if l["cycle"].trigger():
			var spec: Dictionary = l["spec"]
			var ride = RideRail.arc(spec["style"], ball, spec["target"], planar, spec["floor"], spec["min_flight"], gravity)
			facts.append({"kind": "ride", "ride": ride})
			facts.append({"kind": "fact", "fact": String(spec["style"]) + "_fired", "at": l["mouth"]})
			_puff(l["mouth"] + Vector3.UP * 1.5, 6.0)
			riding = true
	for c in cables:
		c["rest"] = maxf(0.0, c["rest"] - delta)
		if riding or c["rest"] > 0.0 or ball.distance_to(c["from"]) > c["spec"]["radius"]:
			continue
		c["rest"] = CABLE_REST
		facts.append({"kind": "ride", "ride": RideRail.line("grapple_line", ball, c["to"], planar, c["spec"]["floor"])})
		facts.append({"kind": "fact", "fact": "ride_grapple_line", "at": c["from"]})
		riding = true
	for v in valves:
		_step_valve(v, delta, ball, planar, facts)
	for w in walls:
		_step_wall(w, ball, velocity, kit, facts)
	_thermal_quiet = maxf(0.0, _thermal_quiet - delta)
	for t in thermals:
		if kit == null or not kit.gliding:
			continue
		var base: Vector3 = t["base"]
		if Vector2(ball.x - base.x, ball.z - base.z).length() > t["spec"]["radius"] or ball.y < base.y or ball.y > base.y + t["spec"]["height"]:
			continue
		facts.append({"kind": "accel", "accel": Vector3.UP * THERMAL_LIFT})
		if _thermal_quiet <= 0.0:
			_thermal_quiet = THERMAL_GAP
			facts.append({"kind": "fact", "fact": "thermal_ride", "at": ball})
			facts.append({"kind": "codex", "id": "steam_thermal", "at": ball})
	_slams.clear()
	return facts


func _process(delta: float) -> void:
	for p in _puffs.duplicate():
		p["left"] -= delta
		var f: float = 1.0 - p["left"] / PUFF_SECONDS
		var node: MeshInstance3D = p["node"]
		node.scale = Vector3.ONE * lerpf(0.4, 1.0, f) * p["size"]
		node.position.y += delta * 3.0
		if p["left"] <= 0.0:
			node.queue_free()
			_puffs.erase(p)
	for v in valves:
		if v["plume"] != null and v["plume"].visible:
			v["plume"].rotate_y(delta * 0.8)


static func _at_mouth(ball: Vector3, mouth: Vector3, radius: float) -> bool:
	return Vector2(ball.x - mouth.x, ball.z - mouth.z).length() <= radius and absf(ball.y - mouth.y) < 3.0


# ---- Barges ----

func _build_barge(spec: Dictionary) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.name = spec["id"]
	body.sync_to_physics = true
	var size: Vector3 = spec["size"]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = size
	deck.mesh = dm
	deck.material_override = Palette.striped(Palette.SANDSTONE, Palette.CHARCOAL)
	body.add_child(deck)
	var hull := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = size.x * 0.45
	hm.bottom_radius = size.x * 0.2
	hm.height = 3.0
	hull.mesh = hm
	hull.material_override = Palette.solid(Palette.RUST)
	hull.position = Vector3.DOWN * 2.1
	body.add_child(hull)
	for corner in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		var jet := MeshInstance3D.new()
		var jm := CylinderMesh.new()
		jm.top_radius = 0.8
		jm.bottom_radius = 1.2
		jm.height = 1.6
		jet.mesh = jm
		jet.material_override = Palette.solid(Palette.COPPER)
		jet.position = Vector3(corner.x * size.x * 0.42, -1.2, corner.z * size.z * 0.42)
		body.add_child(jet)
	# Amber hazard-free edge bands: a barge's rim reads as a ledge you can roll off.
	for side in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x, 0.12, 0.5)
		band.mesh = bm
		band.material_override = Palette.solid(Palette.AMBER, 0.6)
		band.position = Vector3(0.0, size.y * 0.5 + 0.02, side * (size.z * 0.5 - 0.25))
		body.add_child(band)
	add_child(body)
	return {"spec": spec, "body": body, "time": 0.0, "tilt": Vector2.ZERO}


# Where a barge is at time t along its lane: dwell at a, travel, dwell at b, travel back.
static func barge_offset(spec: Dictionary, t: float) -> float:
	var travel: float = spec["travel"]
	var dwell: float = spec["dwell"]
	var period := 2.0 * (travel + dwell)
	var s := fposmod(t, period)
	if s < dwell:
		return 0.0
	if s < dwell + travel:
		return smoothstep(0.0, 1.0, (s - dwell) / travel)
	if s < 2.0 * dwell + travel:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (s - 2.0 * dwell - travel) / travel)


# The scripted settle: a barge leans a few degrees toward the ball's weight, a pure
# function of where the ball sits on the deck, so a test can hold it to a number.
const BARGE_TILT := 3.0


static func barge_tilt(local: Vector3, size: Vector3) -> Vector2:
	var fx := clampf(local.x / (size.x * 0.5), -1.0, 1.0)
	var fz := clampf(local.z / (size.z * 0.5), -1.0, 1.0)
	return Vector2(fz, -fx) * deg_to_rad(BARGE_TILT)


func _place_barge(b: Dictionary, ball: Vector3) -> void:
	var spec: Dictionary = b["spec"]
	var at: Vector3 = (spec["a"] as Vector3).lerp(spec["b"], barge_offset(spec, b["time"]))
	var size: Vector3 = spec["size"]
	var target := Vector2.ZERO
	if ball != Vector3.INF:
		var local: Vector3 = ball - ((get_parent() as Node3D).global_position + at)
		if absf(local.x) < size.x * 0.5 and absf(local.z) < size.z * 0.5 and local.y > 0.0 and local.y < size.y + 2.5:
			target = barge_tilt(local, size)
	b["tilt"] = (b["tilt"] as Vector2).lerp(target, 0.05)
	var tilt: Vector2 = b["tilt"]
	var body: AnimatableBody3D = b["body"]
	body.transform = Transform3D(Basis.from_euler(Vector3(tilt.x, 0.0, tilt.y)), at)


func barge_position(index: int) -> Vector3:
	return barges[index]["body"].global_position


# ---- Lifts ----

func _build_lift(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	var body := AnimatableBody3D.new()
	body.name = spec["id"]
	body.sync_to_physics = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = spec["radius"]
	cyl.height = 1.0
	shape.shape = cyl
	body.add_child(shape)
	var plate := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = spec["radius"]
	pm.bottom_radius = spec["radius"]
	pm.height = 1.0
	plate.mesh = pm
	plate.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
	body.add_child(plate)
	var piston := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 1.2
	sm.bottom_radius = 1.2
	sm.height = float(spec["rise"]) + 1.0
	piston.mesh = sm
	piston.material_override = Palette.solid(Palette.COPPER)
	piston.position = Vector3.DOWN * (float(spec["rise"]) * 0.5 + 0.5)
	body.add_child(piston)
	add_child(body)
	var home := foot + Vector3.DOWN * 0.45
	var needle := _dial(foot + Vector3(float(spec["radius"]) + 1.6, 0.0, 0.0))
	return {"spec": spec, "body": body, "home": home, "needle": needle, "cycle": null}


func _place_lift(l: Dictionary) -> void:
	var ext: float = l["cycle"].extension() if l["cycle"] != null else 0.0
	var body: AnimatableBody3D = l["body"]
	body.transform = Transform3D(Basis.IDENTITY, (l["home"] as Vector3) + Vector3.UP * float(l["spec"]["rise"]) * ext)


func lift_top(index: int) -> float:
	return lifts[index]["body"].global_position.y + 0.5


# ---- Launchers ----

func _build_launcher(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var mouth: Vector3 = ground.call(at.x, at.y, 1.0)
	var root := Node3D.new()
	root.name = spec["id"]
	add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = float(spec["radius"]) - 0.6
	tm.outer_radius = spec["radius"]
	ring.mesh = tm
	ring.material_override = Palette.solid(Palette.AMBER, 0.8)
	ring.position = mouth + Vector3.DOWN * 0.8
	root.add_child(ring)
	var target: Vector3 = spec["target"]
	var aim := Vector3(target.x - mouth.x, 0.0, target.z - mouth.z).normalized()
	var arm: MeshInstance3D = null
	match spec["style"]:
		"cannon":
			var barrel := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 2.0
			bm.bottom_radius = 2.8
			bm.height = 8.0
			barrel.mesh = bm
			barrel.material_override = Palette.solid(Palette.RUST)
			barrel.position = mouth - aim * 5.0 + Vector3.UP * 2.0
			barrel.basis = Basis.looking_at(aim + Vector3.UP * 0.9, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			root.add_child(barrel)
			var band := MeshInstance3D.new()
			var km := TorusMesh.new()
			km.inner_radius = 2.2
			km.outer_radius = 2.9
			band.mesh = km
			band.material_override = Palette.solid(Palette.COPPER)
			band.position = barrel.position
			band.basis = barrel.basis
			root.add_child(band)
		"trebuchet":
			for side in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(1.0, 12.0, 1.0)
				post.mesh = pm
				post.material_override = Palette.solid(Palette.RUST)
				post.position = mouth - aim * 6.0 + aim.cross(Vector3.UP) * side * 3.0 + Vector3.UP * 5.0
				root.add_child(post)
			arm = MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(1.0, 1.0, 20.0)
			arm.mesh = am
			arm.material_override = Palette.solid(Palette.COPPER)
			arm.position = mouth - aim * 6.0 + Vector3.UP * 10.5
			root.add_child(arm)
		"geyser":
			var column := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 2.4
			cm.bottom_radius = 1.6
			cm.height = 10.0
			column.mesh = cm
			column.material_override = _steam_mat
			column.position = mouth + Vector3.UP * 4.0
			root.add_child(column)
			arm = column
	var needle := _dial(mouth + aim.cross(Vector3.UP) * (float(spec["radius"]) + 2.0) + Vector3.DOWN * 1.0)
	return {"spec": spec, "root": root, "mouth": mouth, "aim": aim, "needle": needle, "arm": arm, "cycle": null}


# The trebuchet's arm cocks back as it charges; the geyser's column swells.
func _launcher_pose(l: Dictionary) -> void:
	var arm: MeshInstance3D = l["arm"]
	if arm == null:
		return
	var g: float = l["cycle"].gauge()
	match l["spec"]["style"]:
		"trebuchet":
			var aim: Vector3 = l["aim"]
			arm.basis = Basis.looking_at(aim.rotated(aim.cross(Vector3.UP).normalized(), lerpf(-0.9, 0.7, g)), Vector3.UP)
		"geyser":
			arm.scale = Vector3(1.0, lerpf(0.2, 1.3, g), 1.0)


# ---- The grapple line ----

func _build_cable(spec: Dictionary) -> Dictionary:
	var from: Vector3 = spec["from"]
	var to: Vector3 = spec["to"]
	var cable := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = from.distance_to(to)
	cable.mesh = cm
	cable.material_override = Palette.solid(Palette.CHARCOAL)
	cable.position = (from + to) * 0.5
	cable.basis = Basis.looking_at((to - from).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(cable)
	var hook := MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = float(spec["radius"]) - 0.5
	hm.outer_radius = spec["radius"]
	hook.mesh = hm
	hook.material_override = Palette.solid(Palette.AMBER, 1.2)
	hook.position = from
	hook.basis = Basis.looking_at(Vector3(to.x - from.x, 0.0, to.z - from.z).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(hook)
	return {"spec": spec, "from": from, "to": to, "rest": 0.0}


# ---- Valves ----

func _build_valve(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	var wheel := MeshInstance3D.new()
	var wm := TorusMesh.new()
	wm.inner_radius = 1.3
	wm.outer_radius = 1.9
	wheel.mesh = wm
	wheel.material_override = Palette.solid(Palette.RUST)
	wheel.position = foot + Vector3.UP * 1.6
	wheel.rotation.x = PI * 0.5
	add_child(wheel)
	var crack := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.25, 0.1, 3.6)
	crack.mesh = km
	crack.material_override = Palette.solid(Palette.CHARCOAL)
	crack.position = wheel.position + Vector3(0.0, 0.0, 0.0)
	crack.rotation = Vector3(PI * 0.5, 0.0, 0.6)
	add_child(crack)
	var stripe := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.5
	sm.bottom_radius = 0.5
	sm.height = 1.6
	stripe.mesh = sm
	stripe.material_override = Palette.striped(Palette.AMBER, Palette.CHARCOAL)
	stripe.position = foot + Vector3.UP * 0.8
	add_child(stripe)
	var d: Dictionary = spec["door"]
	var dat: Vector2 = d["at"]
	var door_foot: Vector3 = ground.call(dat.x, dat.y, 0.0)
	var size: Vector3 = d["size"]
	var door := StaticBody3D.new()
	door.name = String(spec["id"]) + "_door"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	door.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
	door.add_child(mesh)
	door.position = door_foot + Vector3.UP * (size.y * 0.5 - 0.5)
	door.rotation.y = d["turn"]
	add_child(door)
	var plume: MeshInstance3D = null
	var vent = spec.get("vent")
	if vent != null:
		var vat: Vector2 = vent["at"]
		var vfoot: Vector3 = ground.call(vat.x, vat.y, 0.0)
		plume = MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 3.0
		pm.bottom_radius = 1.4
		pm.height = 18.0
		plume.mesh = pm
		plume.material_override = Palette.unshaded(Color(Color("3d8bff"), 0.35))
		plume.position = vfoot + Vector3.UP * 9.0
		plume.visible = false
		add_child(plume)
		_dashed_ring(vfoot + Vector3.UP * 0.1, vent["radius"])
	return {"spec": spec, "wheel": wheel, "door": door, "door_home": door.position, "plume": plume, "open": false,
		"sink": 0.0, "at": wheel.position}


func _step_valve(v: Dictionary, delta: float, ball: Vector3, planar: float, facts: Array) -> void:
	if v["open"]:
		if v["sink"] < 1.0:
			v["sink"] = minf(1.0, v["sink"] + delta / DOOR_SECONDS)
			v["door"].position = (v["door_home"] as Vector3) + Vector3.DOWN * DOOR_SINK * v["sink"]
		return
	var at: Vector3 = v["at"]
	var smashed := planar >= cruise and Vector2(ball.x - at.x, ball.z - at.z).length() <= RAM_REACH and absf(ball.y - at.y) < 3.0
	for s in _slams:
		if s.distance_to(at) <= SLAM_REACH:
			smashed = true
	if not smashed:
		return
	v["open"] = true
	v["wheel"].rotation.z = 0.8
	facts.append({"kind": "fact", "fact": "valve_smashed", "at": at})
	facts.append({"kind": "fact", "fact": "route_opened", "at": v["door_home"]})
	_puff(at, 5.0)
	var vent = v["spec"].get("vent")
	if vent != null:
		v["plume"].visible = true
		var vat: Vector2 = vent["at"]
		facts.append({"kind": "fact", "fact": "reactor_vented", "at": v["plume"].position})
		if Vector2(ball.x, ball.z).distance_to(vat) > float(vent["radius"]):
			facts.append({"kind": "codex", "id": "do_not_open_until_clear", "at": at})


# ---- The cracked wall (Rivet) ----

func _build_wall(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var foot: Vector3 = ground.call(at.x, at.y, 0.0)
	var size: Vector3 = spec["size"]
	var body := StaticBody3D.new()
	body.name = spec["id"]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS)
	body.add_child(mesh)
	for k in 3:
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(size.x * 0.7, 0.18, size.z + 0.1)
		crack.mesh = cm
		crack.material_override = Palette.solid(Palette.CHARCOAL)
		crack.position = Vector3(0.0, -1.5 + k * 1.4, 0.0)
		crack.rotation.z = 0.5 - k * 0.45
		body.add_child(crack)
	body.position = foot + Vector3.UP * (size.y * 0.5 - 0.6)
	body.rotation.y = spec["turn"]
	add_child(body)
	return {"spec": spec, "body": body, "home": body.position, "broken": false}


# Only Rivet's overdrive sprint crumbles it, the tick before contact, so the ball never
# meets it as a wall. Anyone else meets a plain wall, which they can see.
func _step_wall(w: Dictionary, ball: Vector3, velocity: Vector3, kit, facts: Array) -> void:
	if w["broken"] or kit == null or not kit.sprinting:
		return
	var body: StaticBody3D = w["body"]
	var centre: Vector3 = body.global_position
	var along: Vector3 = body.global_basis.z
	var rel := ball - centre
	var flat := Vector2(velocity.x, velocity.z).length()
	var ahead := absf(rel.dot(along)) - float(w["spec"]["size"].z) * 0.5
	var side := absf(rel.dot(body.global_basis.x))
	if flat < WALL_SPEED or ahead > WALL_REACH + flat / 30.0 or side > float(w["spec"]["size"].x) * 0.5 + 1.0 or absf(rel.y) > 4.0:
		return
	w["broken"] = true
	body.position = (w["home"] as Vector3) + Vector3.DOWN * 400.0
	body.visible = false
	facts.append({"kind": "fact", "fact": "wall_crumbled", "at": centre})
	facts.append({"kind": "fact", "fact": "route_opened", "at": centre})
	facts.append({"kind": "codex", "id": "sprint_through", "at": centre})
	for k in 5:
		_puff(centre + Vector3(randf_range(-3.0, 3.0), randf_range(-1.5, 2.0), randf_range(-1.0, 1.0)), 2.5)


# ---- Thermals (Kest) ----

func _build_thermal(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec["at"]
	var base: Vector3 = ground.call(at.x, at.y, 0.0)
	var column := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = float(spec["radius"]) * 1.3
	cm.bottom_radius = float(spec["radius"]) * 0.5
	cm.height = spec["height"]
	column.mesh = cm
	column.material_override = Palette.unshaded(Color(Palette.SAND, 0.12))
	column.position = base + Vector3.UP * float(spec["height"]) * 0.5
	add_child(column)
	var grate := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = float(spec["radius"]) * 0.6
	gm.bottom_radius = float(spec["radius"]) * 0.6
	gm.height = 0.3
	grate.mesh = gm
	grate.material_override = Palette.striped(Palette.COPPER, Palette.CHARCOAL)
	grate.position = base + Vector3.UP * 0.1
	add_child(grate)
	return {"spec": spec, "base": base}


# ---- Shared visuals ----

# A bone gauge dial on a post; returns the needle to turn.
func _dial(at: Vector3) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.2
	pm.bottom_radius = 0.2
	pm.height = 3.0
	post.mesh = pm
	post.material_override = Palette.solid(Palette.COPPER)
	post.position = at + Vector3.UP * 1.5
	add_child(post)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.1
	fm.bottom_radius = 1.1
	fm.height = 0.15
	face.mesh = fm
	face.material_override = _gauge_mat
	face.position = at + Vector3.UP * 3.4
	face.rotation.x = PI * 0.5
	add_child(face)
	var redline := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.2, 0.5, 0.05)
	redline.mesh = rm
	redline.material_override = Palette.solid(Palette.RUST)
	redline.position = face.position + Vector3(0.75, 0.55, 0.1)
	redline.rotation.z = -0.8
	add_child(redline)
	var needle := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.12, 0.95, 0.05)
	needle.mesh = nm
	needle.material_override = _needle_mat
	needle.position = face.position + Vector3(0.0, 0.0, 0.12)
	add_child(needle)
	return needle


# The needle sweeps linearly from -120 to +120 degrees: it measures time.
static func _needle(needle: MeshInstance3D, g: float) -> void:
	needle.rotation.z = -lerpf(-2.1, 2.1, clampf(g, 0.0, 1.0))


func _puff(at: Vector3, size: float) -> void:
	var node := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	node.mesh = s
	node.material_override = _steam_mat
	node.position = to_local(at) if is_inside_tree() else at
	add_child(node)
	_puffs.append({"node": node, "left": PUFF_SECONDS, "size": size})


func _dashed_ring(at: Vector3, radius: float) -> void:
	for k in 16:
		var a := TAU * k / 16.0
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.3, 0.06, radius * TAU / 32.0)
		dash.mesh = dm
		dash.material_override = Palette.solid(Palette.SAND)
		dash.position = at + Vector3(cos(a), 0.0, sin(a)) * radius
		dash.rotation.y = -a
		add_child(dash)
