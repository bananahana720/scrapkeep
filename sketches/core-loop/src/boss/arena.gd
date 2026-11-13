extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BowlDress := preload("res://src/presentation/arena_bowl_dress.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
# The crane mast, its boom and the vent nozzle (tools/blender/world_one/slag_bowl_kit.py), each about its centre.
const KIT := "res://assets/models/world_one/slag_bowl_kit.glb"
const KIT_PARTS := ["CraneMast", "CraneBoom", "VentNozzle"]

# The Slag Bowl: a foundry bowl about 124 m across, built ahead during stage 3's beacon, placed when
# the fight starts and freed when it ends. A flat inner floor with two slag channels,
# a banked outer ring that is the fight's momentum lane, a rim wall a pylon plants on,
# two deck ramps and two kickers for height, four crane masts to grapple, and four rim
# water vents that quench slag into crust. Everything is on the world layer (1), so the
# grapple, the pylon and the camera read it like terrain.

const FLOOR_R := 44.0
const BANK_R := 60.0
const BANK_H := 10.0
const WALL_THICK := 2.0
const WALL_H := 6.0
const SEGMENTS := 72
const BANK_STEPS := 10
const RING_A := Vector2(16.0, 21.0)
const RING_B := Vector2(30.0, 36.0)
const MAST_R := 27.0
const MAST_ANGLES := [45.0, 135.0, 225.0, 315.0]
const MAST_HEIGHT := 20.0
const RAMP_ANGLES := [0.0, 180.0]
const RAMP_FROM := 41.0
const RAMP_TO := 25.0
const RAMP_TOP := 6.5
const RAMP_HALF_WIDTH := 4.0
const KICKER_ANGLES := [90.0, 270.0]
const KICKER_R := 39.0
const KICKER_LENGTH := 7.0
const KICKER_TOP := 1.6
const KICKER_HALF_WIDTH := 3.0
const WEDGE_FRAME := "wedge_frame"
const VENT_ANGLES := [60.0, 120.0, 240.0, 300.0]
const VENT_R := 43.0
const VENT_SPAN := 0.4363323  # 25 degrees either side of the vent
# Ruling cv: the entry's tangent faces 115, 25 degrees off the flume gate's 90 (the rail turns the rest in flight).
# A bearing in 240 to 300 keeps it inside the hand-over's 30; 245 is the one there whose straight run onto the bank
# passes outside the 270 kicker and away from the 240 and 300 vent pads, as the old 210 did.
const ENTRY_ANGLE := 245.0
const ENTRY_R := 41.0
const ENTRY_LIFT := 3.0
# The bowl's entry point lies this far past the finished stage's exit gate, along its facing: about where the
# launch's 0.6 s flight carries a ball at 20 m/s.
const ENTRY_AHEAD := 12.0
# The rescue puts the ball on the bank here: past the slag channels and the floor.
const RESCUE_R := 50.0
# The bowl floats this far above the highest ground under it.
const CLEARANCE := 30.0

var _quenched_until := [0.0, 0.0, 0.0, 0.0]
var _vent_ready_at := [0.0, 0.0, 0.0, 0.0]
var _crusts := {}


# Above the finished stage's beacon, pulled inward until the whole bowl is inside the
# map, and high enough that no ground pokes through it.
static func place(terrain, stage: int) -> Vector3:
	var at := Vector3.ZERO
	if terrain != null and terrain.has_method("beacon_point"):
		at = terrain.beacon_point(stage)
	return _settle(terrain, Vector2(at.x, at.z))


# Brindle's bowl (ruling cv): ahead of the finished stage's exit gate, so the launch out of it lands where it aimed,
# on the entry's tangent. A map that states no exit row keeps the bowl over its beacon (place()).
static func place_ahead(terrain, stage: int) -> Vector3:
	var rows := {}
	if terrain != null and terrain.has_method("map_for"):
		var map = terrain.map_for(stage)
		if map != null and map.has_method("handover"):
			rows = map.handover()
	if not rows.has("exit"):
		return place(terrain, stage)
	return _settle(terrain, centre_ahead(rows["exit"]))


# The bowl's centre in the finished stage's frame (x, z) that puts its entry point ENTRY_AHEAD along the exit row's
# heading (ParkMap.handover()). Pure, so the hand-over test reads the same placement.
static func centre_ahead(exit: Dictionary) -> Vector2:
	var heading := deg_to_rad(float(exit["heading_deg"]))
	var entry: Vector2 = Vector2(exit["at"]) + Vector2(sin(heading), cos(heading)) * ENTRY_AHEAD
	var angle := deg_to_rad(ENTRY_ANGLE)
	return entry - Vector2(cos(angle), sin(angle)) * ENTRY_R


static func _settle(terrain, flat: Vector2) -> Vector3:
	var reach := BANK_R + WALL_THICK + 2.0
	for _i in 20:
		if _inside(terrain, flat, reach):
			break
		flat *= 0.8
	var top := -INF
	for ring in [0.0, FLOOR_R * 0.5, FLOOR_R, BANK_R]:
		for k in 12:
			var a := TAU * k / 12.0
			var x: float = flat.x + cos(a) * ring
			var z: float = flat.y + sin(a) * ring
			top = maxf(top, terrain.height(x, z) if terrain != null and terrain.has_method("height") else 0.0)
	return Vector3(flat.x, top + CLEARANCE, flat.y)


static func _inside(terrain, flat: Vector2, reach: float) -> bool:
	if terrain == null or not terrain.has_method("contains"):
		return true
	for k in 8:
		var a := TAU * k / 8.0
		if not terrain.contains(Vector3(flat.x + cos(a) * reach, 0.0, flat.y + sin(a) * reach)):
			return false
	return true


# The bowl's greybox checkers, drawn ahead by boss.gd's warm_arena; Palette keeps one of each.
const CHECKERS := [[Palette.CHARCOAL, Color("30302c")], [Palette.SANDSTONE, Palette.COPPER],
	[Palette.RUST, Palette.CHARCOAL], [Palette.AMBER, Palette.CHARCOAL]]


static var _looks_warm := false


# Flow calls this a physics tick at a time while Brindle's world's last stage runs: a step a call
# of the Requisition's models, the bowl's looks and kits, then the bowl itself, off the boss-entry frame.
# True once done.
static func warm_ahead() -> bool:
	if _ahead_bowl != null and _ahead_bowl.built():
		return true
	return Requisition.warm() and warm_looks() and BowlDress.warm() and warm_bowl()


static func drop_ahead() -> void:
	if _ahead_bowl != null:
		_ahead_bowl.free()
		_ahead_bowl = null
	Requisition.drop_ahead()
	BowlDress.drop_ahead()
	Palette.drop_checkers()
	_looks_warm = false


# The checkers, then the neutral plate looks the dressing (arena_bowl_dress.gd) and the floor paint, a few rows a call.
static func warm_looks() -> bool:
	if not _looks_warm:
		for pair in CHECKERS:
			Palette.checker_texture(pair[0], pair[1], 4, 64)
		_looks_warm = true
		return false
	for id in NEUTRAL_LOOKS:
		if not Palette.warm_look(id):
			return false
	return true


const NEUTRAL_LOOKS := ["rusted-salvaged-plate-worn", "riveted-gyro-metal"]


static func surface_height(r: float) -> float:
	if r <= FLOOR_R:
		return 0.0
	var t := clampf((r - FLOOR_R) / (BANK_R - FLOOR_R), 0.0, 1.0)
	return BANK_H * t * t


static func dir(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


# The ground under a world point: the floor, or the bank's height at that radius.
func ground(point: Vector3) -> float:
	return global_position.y + surface_height(radius_of(point))


func radius_of(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func angle_of(point: Vector3) -> float:
	return atan2(point.z - global_position.z, point.x - global_position.x)


func point_at(angle: float, r: float, lift := 0.0) -> Vector3:
	return global_position + dir(angle) * r + Vector3.UP * (surface_height(r) + lift)


# The counter-clockwise tangent at an angle, flat and unit length.
static func tangent(angle: float) -> Vector3:
	return Vector3(-sin(angle), 0.0, cos(angle))


# How the bowl is entered and left (wave 36, ruling cv), in the bowl's own frame (origin at its centre), as ParkMap.handover()
# states a park stage's. The bowl hangs ahead of the finished stage's exit gate (place_ahead()), so its atlas origin is
# centre_ahead() of that stage's exit row.
# The way out to world 2 is parked until after the sitting. The arrival speed is the share of cruise boss.gd
# _place_ball sets: the carried speed, never under cruise.
static func handover() -> Dictionary:
	var angle := deg_to_rad(ENTRY_ANGLE)
	var heading := tangent(angle)
	return {
		"stage": "slag_bowl",
		"atlas": {"over": "exit", "ahead_m": ENTRY_AHEAD, "heading_deg": 0.0},
		"exit": {"kind": "none", "why": "the way out to world 2 is parked"},
		"arrives": {"kind": "land", "at": Vector2(cos(angle), sin(angle)) * ENTRY_R,
			"heading_deg": rad_to_deg(atan2(heading.x, heading.z)), "speed_cruise": 1.0, "from": "flume gate"},
	}


func entry_point() -> Vector3:
	return point_at(deg_to_rad(ENTRY_ANGLE), ENTRY_R, ENTRY_LIFT + 1.0)


func entry_heading() -> Vector3:
	return arrival_heading()


# The heading a ball enters the bowl on, wherever it is placed: the launch into it turns to this in flight.
static func arrival_heading() -> Vector3:
	return tangent(deg_to_rad(ENTRY_ANGLE))


# Inside the bowl's footprint, out to just past the rim wall.
func contains(point: Vector3) -> bool:
	return radius_of(point) <= BANK_R + WALL_THICK + 4.0


# The terrain API's ground queries, answered by the bowl. Combat's drones read their
# ground from the terrain they were given; in the arena that has to be this, not the
# parked stage map 30 m below.
class Ground:
	extends RefCounted

	var bowl

	func _init(bowl_ref) -> void:
		bowl = bowl_ref

	func height(x: float, z: float) -> float:
		return bowl.ground(Vector3(x, 0.0, z))

	func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
		return Vector3(x, height(x, z) + clearance, z)

	func contains(point: Vector3) -> bool:
		return bowl.contains(point)


func ground_query() -> RefCounted:
	return Ground.new(self)


# --- Vents and quenching -------------------------------------------------------------

func vent_at(point: Vector3) -> int:
	if point.y - ground(point) > 2.5:
		return -1
	for i in VENT_ANGLES.size():
		var pad := point_at(deg_to_rad(VENT_ANGLES[i]), VENT_R)
		if Vector2(point.x - pad.x, point.z - pad.z).length() <= Rules.VENT_REACH:
			return i
	return -1


# Returns true when the vent fired (it was off cooldown).
func quench(vent: int, now: float) -> bool:
	if now < _vent_ready_at[vent]:
		return false
	_vent_ready_at[vent] = now + Rules.VENT_COOLDOWN
	_quenched_until[vent] = now + Rules.QUENCH_SECONDS
	_show_crust(vent, true)
	return true


func is_quenched(point: Vector3, now: float) -> bool:
	var a := angle_of(point)
	for i in VENT_ANGLES.size():
		if now < _quenched_until[i] and absf(angle_difference(a, deg_to_rad(VENT_ANGLES[i]))) <= VENT_SPAN:
			return true
	return false


func step(now: float) -> void:
	for i in VENT_ANGLES.size():
		if _crusts.has(i) and now >= _quenched_until[i]:
			_show_crust(i, false)


func _show_crust(vent: int, on: bool) -> void:
	if _crusts.has(vent):
		_crusts[vent].queue_free()
		_crusts.erase(vent)
	if not on:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid := deg_to_rad(VENT_ANGLES[vent])
	for band in [RING_A, RING_B]:
		_add_band(st, band, mid - VENT_SPAN, mid + VENT_SPAN, 10, 0.12)
	var mat := Palette.unshaded(Color(0.42, 0.4, 0.38, 0.95))
	mat.no_depth_test = true
	# Under every telegraph (40) and its keylines (39), which are opaque and would cover the safe span:
	# the live slag leaves the quenched span undrawn instead.
	mat.render_priority = 38
	_crusts[vent] = _mesh_node(st, mat, "Crust_%d" % vent)


# --- Build ---------------------------------------------------------------------------

func _ready() -> void:
	name = "SlagBowl"
	while not build_step():
		pass
	BowlDress.bind_yard(self)


# The bowl a piece a call: its geometry is local, so it builds off the tree too; only the yard's bus
# waits for the tree (_ready). Flow's warm builds one ahead a piece a physics tick (warm_ahead); the
# fight's entry takes it whole (take_ahead) instead of building it on its entry frame. True once built.
var _built := 0
var _body: StaticBody3D


func build_step() -> bool:
	match _built:
		0:
			_body = StaticBody3D.new()
			_body.name = "Bowl"
			_body.collision_layer = 1
			_body.collision_mask = 0
			add_child(_body)
			_bowl_floor(_body)
		1:
			_bowl_bank(_body)
		2:
			_bowl_wall(_body)
		3:
			_bowl_channels()
			for a in MAST_ANGLES:
				_mast(_body, deg_to_rad(a))
		4:
			for a in RAMP_ANGLES:
				var at := deg_to_rad(a)
				_wedge(_body, _local(at, RAMP_FROM), -dir(at), RAMP_FROM - RAMP_TO, RAMP_TOP, RAMP_HALF_WIDTH, "Ramp")
			for a in KICKER_ANGLES:
				var at := deg_to_rad(a)
				_wedge(_body, _local(at, KICKER_R) - tangent(at) * KICKER_LENGTH * 0.5, tangent(at),
					KICKER_LENGTH, KICKER_TOP, KICKER_HALF_WIDTH, "Kicker")
			for a in VENT_ANGLES:
				_vent(deg_to_rad(a))
		5:
			BowlDress.build(self)
		_:
			return true
	_built += 1
	return false


func built() -> bool:
	return _built > LAST_STEP


const LAST_STEP := 5


# The bowl warm_ahead built, or a new one built on its entry.
static var _ahead_bowl: Node3D


static func warm_bowl() -> bool:
	if _ahead_bowl == null:
		_ahead_bowl = new()
	return _ahead_bowl.build_step()


static func take_ahead() -> Node3D:
	var bowl := _ahead_bowl if _ahead_bowl != null else new()
	_ahead_bowl = null
	return bowl


func _bowl_floor(body: StaticBody3D) -> void:
	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_band(floor_st, Vector2(0.0, FLOOR_R), 0.0, TAU, SEGMENTS, 0.0)
	_solid_part(body, floor_st, 0, "Floor")


func _bowl_bank(body: StaticBody3D) -> void:
	var bank_st := SurfaceTool.new()
	bank_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in BANK_STEPS:
		var r0 := lerpf(FLOOR_R, BANK_R, float(k) / BANK_STEPS)
		var r1 := lerpf(FLOOR_R, BANK_R, float(k + 1) / BANK_STEPS)
		for i in SEGMENTS:
			var a0 := TAU * i / SEGMENTS
			var a1 := TAU * (i + 1) / SEGMENTS
			_quad(bank_st, _local(a0, r0), _local(a1, r0), _local(a1, r1), _local(a0, r1))
	_solid_part(body, bank_st, 1, "Bank")


func _bowl_wall(body: StaticBody3D) -> void:
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := BANK_R + WALL_THICK
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var lo := BANK_H
		var hi := BANK_H + WALL_H
		_quad(wall_st, _flat(a0, BANK_R, lo), _flat(a1, BANK_R, lo), _flat(a1, BANK_R, hi), _flat(a0, BANK_R, hi))
		_quad(wall_st, _flat(a0, BANK_R, hi), _flat(a1, BANK_R, hi), _flat(a1, outer, hi), _flat(a0, outer, hi))
		_quad(wall_st, _flat(a0, outer, hi), _flat(a1, outer, hi), _flat(a1, outer, lo - 2.0), _flat(a0, outer, lo - 2.0))
	_solid_part(body, wall_st, 2, "RimWall")


func _solid_part(body: StaticBody3D, st: SurfaceTool, checker: int, label: String) -> void:
	var node := _mesh_node(st, Palette.striped(CHECKERS[checker][0], CHECKERS[checker][1]), label)
	var shape := CollisionShape3D.new()
	var trimesh: ConcavePolygonShape3D = node.mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)


func _bowl_channels() -> void:
	for band in [RING_A, RING_B]:
		var groove := SurfaceTool.new()
		groove.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_band(groove, band, 0.0, TAU, SEGMENTS, 0.03)
		_mesh_node(groove, Palette.solid(Color("171a19")), "Channel")


func _mast(body: StaticBody3D, angle: float) -> void:
	var base := _local(angle, MAST_R)
	var pole := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.0
	cylinder.height = MAST_HEIGHT
	pole.shape = cylinder
	pole.position = base + Vector3.UP * MAST_HEIGHT * 0.5
	body.add_child(pole)
	var bar := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.8, 0.8)
	bar.shape = box
	bar.position = base + Vector3.UP * (MAST_HEIGHT - 0.4)
	bar.rotation.y = -angle + PI * 0.5
	body.add_child(bar)
	# The kit's mast and boom where the colliders stand (a cylinder and a box when the kit is missing).
	var pole_mesh := ModelKit.part(KIT, KIT_PARTS, "CraneMast", self)
	if pole_mesh == null:
		pole_mesh = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.2
		cm.height = MAST_HEIGHT
		pole_mesh.mesh = cm
		add_child(pole_mesh)
	pole_mesh.set_meta("bowl_surface", "Mast")
	pole_mesh.material_override = Palette.solid(Palette.COPPER)
	pole_mesh.position = pole.position
	var bar_mesh := ModelKit.part(KIT, KIT_PARTS, "CraneBoom", self)
	if bar_mesh == null:
		bar_mesh = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		bar_mesh.mesh = bm
		add_child(bar_mesh)
	bar_mesh.set_meta("bowl_surface", "Crossbar")
	bar_mesh.material_override = Palette.solid(Palette.COPPER, 0.3)
	bar_mesh.position = bar.position
	bar_mesh.rotation = bar.rotation


# A ramp or kicker: a wedge that rises from 0 at `foot` to `top` over `length` along
# `forward`. Its leading edge is flush with the floor, so rolling onto it costs nothing.
func _wedge(body: StaticBody3D, foot: Vector3, forward: Vector3, length: float, top: float, half: float, label: String) -> void:
	var f := Vector3(forward.x, 0.0, forward.z).normalized()
	var s := Vector3.UP.cross(f).normalized() * half
	var end := foot + f * length
	var points := PackedVector3Array([
		foot - s, foot + s, end - s, end + s, end - s + Vector3.UP * top, end + s + Vector3.UP * top,
	])
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	shape.shape = convex
	body.add_child(shape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, points[0], points[1], points[5], points[4])
	_quad(st, points[4], points[5], points[3], points[2])
	for p in [points[0], points[4], points[2], points[1], points[3], points[5]]:
		st.add_vertex(p)
	var node := _mesh_node(st, Palette.striped(CHECKERS[3][0], CHECKERS[3][1]), label)
	# The wedge's own frame (origin at the foot centre on the floor, +Z up the slope), the one point the dress places a recipe at.
	node.set_meta(WEDGE_FRAME, Transform3D(Basis(Vector3.UP.cross(f), Vector3.UP, f), foot))


func _vent(angle: float) -> void:
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Rules.VENT_REACH
	disc.bottom_radius = Rules.VENT_REACH
	disc.height = 0.1
	pad.mesh = disc
	pad.material_override = Palette.solid(Palette.ARC, 0.6)
	pad.position = _local(angle, VENT_R, 0.06)
	pad.name = "WaterVent"
	add_child(pad)
	var nozzle := ModelKit.part(KIT, KIT_PARTS, "VentNozzle", self)
	if nozzle == null:
		nozzle = MeshInstance3D.new()
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.7
		pipe.bottom_radius = 0.9
		pipe.height = 3.0
		nozzle.mesh = pipe
		nozzle.material_override = Palette.solid(Palette.VERDIGRIS)
		add_child(nozzle)
	nozzle.name = "VentNozzle_%d" % roundi(rad_to_deg(angle))
	nozzle.position = _local(angle, VENT_R + 3.5, 1.5)


func _local(angle: float, r: float, lift := 0.0) -> Vector3:
	return dir(angle) * r + Vector3.UP * (surface_height(r) + lift)


func _flat(angle: float, r: float, y: float) -> Vector3:
	return dir(angle) * r + Vector3.UP * y


func _add_band(st: SurfaceTool, band: Vector2, from_angle: float, to_angle: float, segments: int, lift: float) -> void:
	for i in segments:
		var a0 := lerpf(from_angle, to_angle, float(i) / segments)
		var a1 := lerpf(from_angle, to_angle, float(i + 1) / segments)
		_quad(st, _local(a0, band.x, lift), _local(a1, band.x, lift), _local(a1, band.y, lift), _local(a0, band.y, lift))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, c, b, a, d, c]:
		st.add_vertex(p)


func _mesh_node(st: SurfaceTool, mat: Material, label: String) -> MeshInstance3D:
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.set_meta("bowl_surface", label)
	node.mesh = st.commit()
	if mat is BaseMaterial3D:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	add_child(node)
	return node
