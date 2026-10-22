extends SceneTree

const T := preload("res://tests/support/t.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# MOTION-SPEC cableway row (wave 20): the grapple-line ride hangs the ball under the cable and the
# line view draws a hanger from the collar fairlead up to a trolley clamp on the cable. It builds the
# Cable Reach's real cable through contraptions.gd, boards it at three banked speeds from two starts,
# and walks the held path at the world's 90 Hz while the view steps with it. Checks, per speed:
# the ball centre stays under the cable with the ball clear of it; the hanger's two ends meet the
# fairlead and the cable within GAP; the landing end keeps the centre 1 m over the ground. The control
# rides the old target (the cable end itself) and must fail the clearance check.

const TICK := 1.0 / 90.0
const GAP := 0.05
const SPEEDS := [8.0, 24.0, 60.0]
const CABLE_RADIUS := 0.18

var _t


class FakePlayer extends Node3D:
	var kit := AugmentKit.new()
	var events := GameEvents.new()
	var tuning := Tuning.new()

	func shown_position() -> Vector3:
		return global_position

	func ball_position() -> Vector3:
		return global_position

	func grapple_range() -> float:
		return 60.0


func _initialize() -> void:
	_run.call_deferred()


func _ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, Gorge.flank(z) + lift, z)


func _run() -> void:
	_t = T.new("cableway_hanger_test")
	var map = Gorge.new()
	var specs: Array = map.contraptions.filter(func(s): return s["kind"] == "cable")
	map.contraptions = specs
	var world := Node3D.new()
	root.add_child(world)
	var c = Contraptions.new()
	world.add_child(c)
	c.setup(map, Callable(self, "_ground"), 14.0, 26.0)
	_t.eq("one cable built", c.cables.size(), 1)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(70.0, 60.0, -60.0)
	camera.look_at(Vector3(70.0, 35.0, -70.0))
	camera.current = true
	var player := FakePlayer.new()
	root.add_child(player)
	var view := LineView.new()
	root.add_child(view)
	view.setup(player, camera, player.events)
	var hero := HeroAssets.new()
	var pod := Node3D.new()
	var exit := Node3D.new()
	exit.name = "RopeExit"
	pod.add_child(exit)
	root.add_child(pod)
	HeroAssets.add_fairlead(pod)
	var cable: Dictionary = c.cables[0]
	var from: Vector3 = cable["from"]
	var to: Vector3 = cable["to"]
	var floor_h: float = Gorge.flank(to.z)
	var hang: float = Contraptions.CABLE_HANG
	_t.near("landing end rides 1.3 m under the cable", hang, 1.3)
	for planar in SPEEDS:
		for start in [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -2.5)]:
			var tag := "%.0f m/s, start %s" % [planar, str(start)]
			var ball := Vector3(from.x, Gorge.flank(from.z + start.z) + 1.0, from.z + start.z)
			var facts: Array = c.step(TICK, ball, Vector3(planar, 0.0, 0.0), null, false)
			var rides := facts.filter(func(f): return f["kind"] == "ride")
			_t.eq("boards (%s)" % tag, rides.size(), 1)
			if rides.is_empty():
				continue
			var ride = rides[0]["ride"]
			_t.check("the ride carries its cable ends (%s)" % tag, ride.cable_from == from and ride.cable_to == to)
			_t.check("the held path ends hanging under the cable end (%s)" % tag, ride.target.is_equal_approx(to - Vector3.UP * hang))
			var got := _ride(ride, view, player, ball, from, to, hero, pod)
			_t.check("RopeExit within %.2f m of the hanger start, worst %.3f (%s)" % [GAP, got["gap_rope"], tag], got["gap_rope"] <= GAP)
			_t.check("the hanger is up on the boarding tick (%s)" % tag, got["boarding_visible"])
			_t.check("ball clear of the cable all the way, min %.2f m (%s)" % [got["min_clear"], tag], got["min_clear"] >= Tuning.RADIUS + CABLE_RADIUS)
			_t.check("ball centre under the cable all the way, max over %.2f m (%s)" % [got["max_over"], tag], got["max_over"] < 0.0)
			_t.check("hanger ends within %.2f m: fairlead %.3f, cable %.3f (%s)" % [GAP, got["gap_fairlead"], got["gap_cable"], tag], got["gap_fairlead"] <= GAP and got["gap_cable"] <= GAP)
			_t.check("fairlead faces the clamp, worst dot %.2f (%s)" % [got["worst_dot"], tag], got["worst_dot"] > 0.9)
			_t.check("hanger drawn on %d of %d ticks (%s)" % [got["drawn"], got["ticks"], tag], got["drawn"] == got["ticks"])
			_t.check("centre %.2f m over the ground at the landing end (%s)" % [got["end_y"] - floor_h, tag], got["end_y"] - floor_h >= Tuning.RADIUS)
			view.set_ride(null)
			view.step(TICK)
			_t.check("the hanger hides on release (%s)" % tag, not view.hanger.visible)
			c.cables[0]["rest"] = 0.0
	# Control: the old target, the cable end itself, puts the cable through the ball.
	var old = RideRail.line("grapple_line", Vector3(from.x, Gorge.flank(from.z) + 1.0, from.z), to, 24.0, 18.0)
	old.cable_from = from
	old.cable_to = to
	var bad := _ride(old, view, player, Vector3(from.x, Gorge.flank(from.z) + 1.0, from.z), from, to)
	_t.check("control: the old target fails clear-of-cable, min %.2f m" % bad["min_clear"], bad["min_clear"] < Tuning.RADIUS + CABLE_RADIUS)
	_t.check("control: the old target ends with the cable inside the ball, max over %.2f m" % bad["max_over"], bad["max_over"] > -Tuning.RADIUS)
	_guard(map, specs[0], from, to)
	_world_order()
	_census()
	pod.free()
	hero.free()
	view.free()
	player.events.free()
	player.free()
	camera.free()
	world.free()
	quit(_t.verdict())


# A cable end 1.5 m over the ground: the guard cuts the hang so the landing centre keeps 1.05 m.
func _guard(map, spec: Dictionary, from: Vector3, to: Vector3) -> void:
	var low: Dictionary = spec.duplicate()
	var end := Vector3(to.x, Gorge.flank(to.z) + 1.5, to.z)
	low["to"] = end
	map.contraptions = [low]
	var world := Node3D.new()
	root.add_child(world)
	var c = Contraptions.new()
	world.add_child(c)
	c.setup(map, Callable(self, "_ground"), 14.0, 26.0)
	var ball := Vector3(from.x, Gorge.flank(from.z) + 1.0, from.z)
	var rides: Array = c.step(TICK, ball, Vector3(24.0, 0.0, 0.0), null, false).filter(func(f): return f["kind"] == "ride")
	_t.eq("low end boards", rides.size(), 1)
	if not rides.is_empty():
		var landing: float = rides[0]["ride"].target.y - Gorge.flank(to.z)
		_t.check("low end (1.5 m up) lands %.2f m over ground, at least 1.05" % landing, landing >= Contraptions.CABLE_LAND_CLEAR - 0.001)
		_t.check("low end hang is reduced, %.2f m" % (end.y - rides[0]["ride"].target.y), end.y - rides[0]["ride"].target.y < Contraptions.CABLE_HANG - 0.1)
	var unguarded := 1.5 - Contraptions.CABLE_HANG
	_t.check("control: the unguarded hang lands %.2f m up and fails 1.05" % unguarded, unguarded < Contraptions.CABLE_LAND_CLEAR)
	_t.near("an end 2.4 m up keeps the full hang", Contraptions.cable_hang(2.4, 0.0), Contraptions.CABLE_HANG)
	_t.near("an end at the ground falls back to no hang", Contraptions.cable_hang(0.5, 0.0), 0.0)
	world.free()


# world.gd pushes the ride to the view after the contraption step, so a fresh ride's hanger is up that tick.
func _world_order() -> void:
	var src := FileAccess.get_file_as_string("res://src/world/world.gd")
	var step_at := src.find("contraptions[ctx.flow.stage()].step(")
	var show_at := src.find("\t_show_ride()\n\tif bay.in_yard")
	_t.check("world.gd shows the ride after the contraption step", step_at > 0 and show_at > step_at)


# Every park map's cables, on the map's baked ground: the guarded landing keeps 1.05 m, and the hang is cut
# only where the ground is close. A map with no bake is skipped.
func _census() -> void:
	var rows := 0
	for id in ["park_crown", "park_dam", "park_flume", "park_islands", "park_pit", "park_sinkhole", "park_test"]:
		var ground: Callable = ParkGround.ground(id)
		if not ground.is_valid():
			continue
		var pm = ParkMap.new("res://src/world/park/%s.json" % id)
		for spec in pm.contraptions.filter(func(s): return s["kind"] == "cable"):
			var end: Vector3 = spec["to"]
			var gy: float = ground.call(end.x, end.z)
			var hang := Contraptions.cable_hang(end.y, gy)
			rows += 1
			var landing := end.y - hang - gy
			_t.check("%s %s lands %.2f m over its ground (end %.2f m up, hang %.2f)" % [id, spec["id"], landing, end.y - gy, hang],
				landing >= Contraptions.CABLE_LAND_CLEAR - 0.001 or hang == 0.0)
	_t.check("the census walked park cable rows (%d)" % rows, rows > 0)


func _ride(ride, view, player, start: Vector3, from: Vector3, to: Vector3, hero = null, pod = null) -> Dictionary:
	var out := {"gap_rope": 0.0, "boarding_visible": false, "min_clear": INF, "max_over": -INF, "gap_fairlead": 0.0, "gap_cable": 0.0, "worst_dot": 1.0, "drawn": 0, "ticks": 0, "end_y": 0.0}
	view.set_ride(ride)
	var ball := start
	player.global_position = start
	view.step(TICK)
	out["boarding_visible"] = view.hanger.visible
	if hero != null:
		pod.global_position = start
		hero.steer_fairlead(pod, view.hanger_to, INF if view.hanger_fresh else TICK)
	while true:
		var v = ride.step(TICK)
		if v == null:
			break
		ball = ride.point_at(ride.time)
		player.global_position = ball
		view.step(TICK)
		if hero != null:
			pod.global_position = ball
			hero.steer_fairlead(pod, view.hanger_to, INF if view.hanger_fresh else TICK)
			out["gap_rope"] = maxf(out["gap_rope"], (pod.find_child("RopeExit", true, false) as Node3D).global_position.distance_to(view.hanger_from))
		out["ticks"] += 1
		var on_cable := LineView.clamp_on_cable(from, to, ball)
		out["min_clear"] = minf(out["min_clear"], ball.distance_to(on_cable))
		# Height of the cable straight over the ball's ground position, against the ball centre.
		var ab := Vector2(to.x - from.x, to.z - from.z)
		var f := clampf(Vector2(ball.x - from.x, ball.z - from.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		out["max_over"] = maxf(out["max_over"], ball.y - lerpf(from.y, to.y, f))
		if view.hanger.visible:
			out["drawn"] += 1
			var mesh: ImmediateMesh = view.hanger.mesh
			var arrays := mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var first := (verts[0] + verts[1]) * 0.5
			var last_i := SEGMENTS_VERTS - 2
			var last := (verts[last_i] + verts[last_i + 1]) * 0.5
			var flat := Vector3(view.hanger_from.x - ball.x, 0.0, view.hanger_from.z - ball.z)
			out["gap_fairlead"] = maxf(out["gap_fairlead"], maxf(first.distance_to(view.hanger_from), absf(flat.length() - LineView.FAIRLEAD_RADIUS) + absf(view.hanger_from.y - ball.y)))
			out["gap_cable"] = maxf(out["gap_cable"], last.distance_to(LineView.clamp_on_cable(from, to, last)))
			out["gap_cable"] = maxf(out["gap_cable"], last.distance_to(view.hanger_to))
			var toward := Vector3(view.hanger_to.x - ball.x, 0.0, view.hanger_to.z - ball.z)
			if toward.length() > 1.5 and flat.length() > 0.01:
				out["worst_dot"] = minf(out["worst_dot"], flat.normalized().dot(toward.normalized()))
	out["end_y"] = ball.y
	return out


# The hanger ribbon's vertex count: two per point, SEGMENTS + 1 points.
const SEGMENTS_VERTS := (LineView.SEGMENTS + 1) * 2
