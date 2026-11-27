extends SceneTree
# 2026-10-09 (w12 BEACON-CLAMP): every Warden family's weak point clears every surface of the lantern beacon.
# Measured cause: the RECIPE-CART tripod ran its legs and collar through the weak points (0.58 to 1.16 m from the
# centres against the 1.3 m sphere, units/swap-fix/REPORT.md), so the game kept the copper mast.
# The frame, its lens at socket_lens and both detail shells are read as imported GLBs; the Warden sits on the frame's
# socket_clamp, and each point is the Warden's own family_point_at (the mind's choir lens at all three seats).

const Warden := preload("res://src/combat/warden.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const Roster := preload("res://src/combat/roster.gd")
const Game := preload("res://src/game.gd")
const Beacon := preload("res://src/core/beacon.gd")
const T := preload("res://tests/support/t.gd")
const FRAME := "res://assets/models/lantern_beacon_frame.glb"
const LENS := "res://assets/models/lantern_beacon_lens.glb"
const SHELLS := ["res://assets/models/lantern_beacon_detail1.glb", "res://assets/models/lantern_beacon_detail2.glb"]

var _t := T.new("lantern_beacon_clearance_test")
var _done := false
var _game
var _mast_done := false
var _ticks := 0


# Runs on the first frame: in _initialize nothing is inside the tree yet, so every global transform reads as identity.
func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_run()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	return false


# 2026-10-10 (w13 LANTERN-SHELLS): the mast branch of the hero hook's _dress_mast, reachable now that a beacon built with
# authored = false keeps its copper mast. The mast beacon replaces the game's lantern, a Warden sits on its mast, and the
# hook splits the mast into two segments and six rails that keep every family's weak point clear.
func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _mast_done:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.flow.force_warden = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	if _ticks < 6:
		return false
	_mast_done = true
	_run_mast()
	_game.free()
	quit(_t.verdict())
	return false


func _run_mast() -> void:
	var hook = _game.presentation.hero_assets
	var warden = _game.flow.warden
	_t.check("a Warden spawned for the mast check", warden != null and hook.warden_of(warden).size() > 0)
	if warden == null:
		return
	var lantern_beacon = _game.flow.beacon
	_t.check("the game's beacon is the lantern", lantern_beacon.clamp_seat() != null)
	var mast_beacon := Beacon.new()
	mast_beacon.authored = false
	_game.add_child(mast_beacon)
	mast_beacon.setup()
	_t.check("an unauthored beacon builds the mast and no lantern", mast_beacon.clamp_seat() == null and mast_beacon.get_node_or_null("LanternFrame") == null)
	mast_beacon.global_position = Vector3(500, 0, 500)
	_game.flow.beacon = mast_beacon
	hook._restore_mast()
	warden.global_position = mast_beacon.global_position + Vector3.UP * Beacon.MAST_HEIGHT * 0.5
	hook._dress_mast(warden)
	_t.check("the mast branch ran for this Warden", not hook._mast.is_empty() and hook._mast.owner == warden.get_instance_id() and hook._mast.root != null)
	if hook._mast.is_empty() or hook._mast.root == null:
		return
	var support: Node3D = hook._mast.root
	var segments := 0
	var rails := 0
	var minimum := INF
	for visual in support.get_children():
		var centre: Vector3 = visual.to_local(warden.family_point_at())
		var box: AABB = visual.mesh.get_aabb()
		if box.size.x < 0.3:
			rails += 1
		else:
			segments += 1
		minimum = minf(minimum, centre.distance_to(centre.clamp(box.position, box.end)))
	_t.eq("mast split into two segments", segments, 2)
	_t.eq("mast braced by six rails", rails, 6)
	_t.check("the split mast keeps the weak point clear", minimum >= Warden.FAMILY_POINT_RADIUS, "%.3f m, sphere %.1f m" % [minimum, Warden.FAMILY_POINT_RADIUS])
	_t.check("the original mast is hidden", mast_beacon.get_children().any(func(c): return c is MeshInstance3D and c.mesh is CylinderMesh and c.layers == 0))
	hook._restore_mast()
	_t.check("the mast restores", hook._mast.is_empty() and (not is_instance_valid(support) or support.is_queued_for_deletion()))


func _run() -> void:
	var frame := (load(FRAME) as PackedScene).instantiate() as Node3D
	root.add_child(frame)
	var lens_socket := frame.find_child("socket_lens", true, false) as Node3D
	var seat := frame.find_child("socket_clamp", true, false) as Node3D
	_t.check("frame carries socket_lens", lens_socket != null)
	_t.check("frame carries socket_clamp", seat != null)
	var parts: Array[Node3D] = [frame]
	if lens_socket != null:
		var lens := (load(LENS) as PackedScene).instantiate() as Node3D
		root.add_child(lens)
		lens.global_position = lens_socket.global_position
		parts.append(lens)
	for path: String in SHELLS:
		var shell := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(shell)
		parts.append(shell)
	var tris := PackedVector3Array()
	for part in parts:
		tris.append_array(triangles(part))
	_t.check("lantern triangles read", tris.size() > 3 * 2000, "%d triangles" % (tris.size() / 3))
	# The Warden's seat: the frame's socket, or the game's spawn seat (HALF_HEIGHT over the beacon) when it is missing,
	# so a frame without the socket still reports what its surfaces do to the weak points.
	var at: Vector3 = seat.global_position if seat != null else Vector3.UP * Warden.HALF_HEIGHT
	_t.near("socket_clamp is the Warden's spawn seat", at.distance_to(Vector3.UP * Warden.HALF_HEIGHT), 0.0, 0.001)
	for row in points(at):
		var clearance := surface_clearance(row.at, tris)
		print("LANTERN_CLEARANCE %s %.3f sphere %.1f" % [row.id, clearance, Warden.FAMILY_POINT_RADIUS])
		_t.check(row.id + " weak point clears the lantern", clearance >= Warden.FAMILY_POINT_RADIUS,
			"%.3f m from %s, sphere %.1f m" % [clearance, row.at, Warden.FAMILY_POINT_RADIUS])
	for part in parts:
		part.free()


# Every family's weak point for a Warden standing at `at`, read through Warden.family_point_at.
func points(at: Vector3) -> Array:
	var out := []
	for family: String in Roster.WARDEN_FAMILIES:
		var variants := ["", "choir"] if family == Roster.MIND else [""]
		for variant: String in variants:
			for seat in (3 if variant == "choir" else 1):
				var warden := Warden.new()
				var kit := WardenKit.new()
				kit.family = family
				warden.family = family
				warden.variant = variant
				warden.open_lens = seat
				warden._kit = kit
				root.add_child(warden)
				warden.global_position = at
				out.append({"id": family + ("_choir%d" % seat if variant == "choir" else ""), "at": warden.family_point_at()})
				warden.free()
				kit.free()
	return out


# Every triangle under node in world space.
static func triangles(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null:
			continue
		var xf := view.global_transform
		for v in view.mesh.get_faces():
			out.append(xf * v)
	return out


# Exact distance from p to the nearest of the triangles (surfaces, not vertices).
static func surface_clearance(p: Vector3, tris: PackedVector3Array) -> float:
	var best := INF
	for i in range(0, tris.size(), 3):
		best = minf(best, p.distance_to(closest_on_triangle(p, tris[i], tris[i + 1], tris[i + 2])))
	return best


# Ericson, Real-Time Collision Detection 5.1.5.
static func closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)
