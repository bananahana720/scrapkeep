extends SceneTree
# smoke: timeout=900s

# World 1's lifts and a ball at cruise, at fixed places in each lift's cycle (wave 36 snag sweep, flume-merged.json: one
# row on Contraptions/hollow_lift at (-209.0, 19.85, -55.7), 13.8 m/s down to 3.7, left undecided because the sweep met
# the moving plate at one unknown point of its cycle). A lift is an AnimatableBody3D (contraptions.gd _build_lift) on a
# periodic SteamCycle: it fires up `rise` m, holds, sinks back to rest with its top 0.05 m over the ground, then charges.
# The flume's hollow_lift is read at every place; the dam's service_lift at the PHASES even places.
#
# Phase method: time is stepped, nothing is set. The test reads the lift's cycle (its public phase and clock, read
# only) every physics tick and releases the ball, parked still RUN_M short of the rim, on the tick that makes its
# front reach the rim at the wanted point of the cycle. The point actually met is measured and printed beside it.
#
# Each run rolls a line through the plate's centre: the sweep's undecided lane (heading -z) and one square to it. While
# the ball touches the lift it records where, in order, read from the lift's own collider:
#   wall   the drum under the plate (a shape named Drum) while the lift is off its rest. Allowed: a pillar deflects a ball.
#          At rest (charging) a drum contact is the plate's rim and reads side, so a step at rest is judged.
#   top    the plate, from above (the contact points down onto the plate within 45 degrees of vertical).
#   under  the plate, from below (the plate bears down on the ball within 45 degrees of vertical).
#   side   the plate, anything between (its rim or bevel).
# The direction is the ball centre less the nearest point of the plate's profile (the collider's lathe outline in radius
# and height, taken from its CylinderShape3D or ConvexPolygonShape3D), so the reading follows whatever plate is built. A
# ball centre inside the outline (a fast plate overran it in one tick) reads by the plate's motion: top while it fires,
# under while it sinks, the nearest face otherwise.
# A run reads:
#   lift   the plate met the ball while it fired and the ball then rose LIFTED_M over its height at the rim (riding it
#          up or being thrown is the lift's job), measured from its lowest point while the firing plate touched it.
#   catch  any under contact (the plate came down on the ball), or the plate kept it under CATCH of its speed.
#   loss   the plate kept it under CLEAN.
#   wall   it met the drum (and the plate cost it nothing before that).
#   clean  it never touched the lift, or the plate kept at least CLEAN.
# kept: the lowest planar speed while touching the plate, before any drum contact, over the speed BEFORE_M short of the rim.
# Places: PHASES even points of the cycle, FINE points across the end of the sink (hollow_lift), and "fire": the ball's
# front on the rim radius / cruise before the plate fires, so its centre is over the plate when it fires (both lifts).
# The last two columns are the ball centre's and the plate top's height over the rim ground at the lowest point.
# Controls: synthetic ball places read top, side and under against the flume plate's own profile (the under reader can
# fire); on flat open ground near the flume lift the same roll with nothing in its way keeps at least OPEN_KEEP, and a
# planted vertical 0.5 m step reads as a loss or a catch, so a clean table is the lift's and not a blind measure.
#
# Red on wave 36 by finding: at 2.5 to 3.4 s after firing the sinking plate lands on a ball that rolled under it while
# raised, on both lanes. The fix is the shape (wave 37 lift-drum): a solid drum fills the space under the plate.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const SteamCycle := preload("res://src/world/steam_cycle.gd")
const T := preload("res://tests/support/t.gd")

# id, stage index on the park table, map title, whether the FINE places are read too.
const LIFTS := [["hollow_lift", 2, "park_flume", true], ["service_lift", 1, "park_dam", false]]
const PHASES := 8
# Extra places across the end of the sink, where the plate's underside passes ball height (printed, judged alike).
const FINE := [2.6, 2.8, 3.0, 3.2, 3.4]
const CATCH := 0.5
const CLEAN := 0.85
const OPEN_KEEP := 0.95
const STEP_M := 0.5
const RUN_M := 10.0
const BEFORE_M := 3.0
const PAST_M := 4.0
const TOUCH_SLACK := 0.08
const FLAT_M := 0.1
# Within 45 degrees of vertical, a contact is from above or below.
const VERTICAL := 0.7071
const LIFTED_M := 2.0

var t := T.new("park_hollow_lift_roll_test")
var game
var source := Intent.Scripted.new()
var lift: AnimatableBody3D
var cycle
var radius := 0.0
var hull := PackedVector2Array()
var exclude: Array[RID] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for row: Array in LIFTS:
		await _lift_table(row[0], row[1], row[2], row[3])
	quit(t.verdict())


func _lift_table(lift_id: String, stage: int, title: String, fine: bool) -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(stage) and terrain.is_ready(stage) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for i in 30:
		await physics_frame
	t.eq("real Game plays %s on the park table" % title, terrain.map().title, title)
	var found: Array = game.find_children(lift_id, "AnimatableBody3D", true, false)
	t.check("%s places %s" % [title, lift_id], found.size() == 1, "%d found" % found.size())
	if found.size() != 1:
		await _drop_game()
		return
	lift = found[0]
	cycle = null
	for l: Dictionary in lift.get_parent().lifts:
		if l["body"] == lift:
			cycle = l["cycle"]
			radius = float(l["spec"]["radius"])
	t.check("%s runs a periodic cycle" % lift_id, cycle != null and cycle.mode == SteamCycle.PERIODIC, "")
	if cycle == null:
		await _drop_game()
		return
	hull = _plate_hull()
	t.check("%s has a plate collider to read" % lift_id, hull.size() >= 3, "%d hull points" % hull.size())
	exclude = [game.player.body().get_rid(), lift.get_rid()]
	var period: float = cycle.rise + cycle.hold + cycle.sink + cycle.charge
	var cruise: float = game.player.tuning.f("cruise")
	var centre := lift.global_position
	print("  %s at (%.1f, %.1f), plate radius %.1f, drum %s, cycle %.2f s (rise %.2f hold %.2f sink %.2f charge %.2f), cruise %.1f" %
		[lift_id, centre.x, centre.z, radius, "yes" if _drum() != null else "no", period, cycle.rise, cycle.hold, cycle.sink, cycle.charge, cruise])
	if fine:
		_reader_controls(lift_id)
	# The square lane runs over whichever side, -x or +x, has the flatter run-up.
	var flat := Vector3(centre.x, 0.0, centre.z)
	var square := Vector3.RIGHT
	if _span(flat + Vector3.RIGHT * radius, Vector3.LEFT) < _span(flat + Vector3.LEFT * radius, Vector3.RIGHT):
		square = Vector3.LEFT
	var lanes := {"sweep lane -z": Vector3.FORWARD, ("square lane %s" % ("+x" if square == Vector3.RIGHT else "-x")): square}
	var places: Array[float] = []
	for k in PHASES:
		places.append(period * float(k) / float(PHASES))
	if fine:
		for f: float in FINE:
			places.append(f)
	var fire_at := places.size()
	places.append(fposmod(period - radius / cruise, period))
	print("  | lift | lane | cycle s (wanted) | met | plate top over rim ground m | touched, in order | lifted | kept | lowest at m past rim | read | ball, plate top over rim ground at lowest m |")
	var worst := {"catch": 0, "loss": 0, "under": 0, "lift": 0, "fire_lift": 0, "fire_met": 0}
	for lane: String in lanes:
		var dir: Vector3 = lanes[lane]
		var rim := flat + dir * -radius
		for i in places.size():
			var roll := await _roll(rim, dir, radius * 2.0, cruise, places[i], period, true)
			var read := _read(roll)
			if worst.has(read):
				worst[read] += 1
			if roll["touched"].has("under"):
				worst["under"] += 1
			if i == fire_at and roll["fire_touch"]:
				worst["fire_met"] += 1
				if read == "lift":
					worst["fire_lift"] += 1
			print("  | %s | %s | %s%.2f | %.2f | %.2f | %s | %s | %.2f | %.1f | %s | %.2f, %.2f |" % [lift_id, lane,
				"" if i < PHASES else ("fire " if i == fire_at else "fine "), places[i],
				roll["met"], roll["plate_over"], ",".join(roll["touched"]) if not roll["touched"].is_empty() else "-",
				"yes" if roll["lifted"] else "no", roll["kept"], roll["low_at"], read, roll["ball_low"], roll["plate_low"]])
	# The guard: no place in the cycle has the plate come down on a ball, or stop one at cruise.
	t.check("%s: no place in the cycle has the plate bear down on a ball (an under contact)" % lift_id,
		worst["under"] == 0, "%d runs with an under contact" % worst["under"])
	t.check("%s: no place in the cycle stops a ball at cruise against the plate (kept under %.0f%%, not lifted)" % [lift_id, CATCH * 100.0],
		worst["catch"] == 0, "%d catches" % worst["catch"])
	t.check("%s: no place in the cycle costs more than %.0f%% without a lift" % [lift_id, (1.0 - CLEAN) * 100.0],
		worst["loss"] == 0, "%d losses" % worst["loss"])
	t.check("%s: a ball on the plate as it fires is lifted (a fire row reads lift)" % lift_id, worst["fire_lift"] > 0,
		"%d of %d fire rows the firing plate met" % [worst["fire_lift"], worst["fire_met"]])
	if fine:
		await _ground_controls(centre, cruise, period)
	await _drop_game()


func _drop_game() -> void:
	game.free()
	for i in 3:
		await process_frame


# Controls for the reader itself: a ball over the plate's middle reads top, one beside its rim reads side, one under its
# middle reads under. Each place is a ball's radius plus a little off the plate, in the lift's own frame.
func _reader_controls(lift_id: String) -> void:
	var top := _bounds_y(true)
	var bottom := _bounds_y(false)
	var places := {"top": Vector2(0.5, top + 1.0), "under": Vector2(0.5, bottom - 1.0), "side": Vector2(radius + 1.0, (top + bottom) * 0.5)}
	for want: String in places:
		var got := _plate_reading(places[want])
		t.eq("control: the reader sees a ball %s %s's plate" % [{"top": "on", "under": "under", "side": "beside"}[want], lift_id], got, want)


func _bounds_y(high: bool) -> float:
	var y := -INF if high else INF
	for p: Vector2 in hull:
		y = maxf(y, p.y) if high else minf(y, p.y)
	return y


# The plate's outline in (radius, height) in the lift body's frame, from every collider on the lift but the drum.
func _plate_hull() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for node in lift.get_children():
		var cs := node as CollisionShape3D
		if cs == null or cs.name == "Drum" or cs.shape == null:
			continue
		var off := cs.position
		if cs.shape is CylinderShape3D:
			var c := cs.shape as CylinderShape3D
			for y: float in [-c.height * 0.5, c.height * 0.5]:
				pts.append(Vector2(0.0, off.y + y))
				pts.append(Vector2(c.radius, off.y + y))
		elif cs.shape is ConvexPolygonShape3D:
			for p: Vector3 in (cs.shape as ConvexPolygonShape3D).points:
				var q := p + off
				pts.append(Vector2(Vector2(q.x, q.z).length(), q.y))
				pts.append(Vector2(0.0, q.y))
	if pts.size() < 3:
		return PackedVector2Array()
	return Geometry2D.convex_hull(pts)


func _drum() -> CollisionShape3D:
	return lift.get_node_or_null("Drum") as CollisionShape3D


# top, under or side, from the ball centre (radius, height in the lift's frame) less the nearest point of the plate outline.
func _plate_reading(local: Vector2, phase := -1) -> String:
	var best := Vector2.INF
	var best_d := INF
	for i in hull.size():
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(local,hull[i], hull[(i + 1) % hull.size()])
		var d := local.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	var n := (local - best).normalized()
	if Geometry2D.is_point_in_polygon(local, hull):
		if phase == SteamCycle.FIRING:
			return "top"
		if phase == SteamCycle.RETURNING:
			return "under"
		n = -n
	if n.y >= VERTICAL:
		return "top"
	if n.y <= -VERTICAL:
		return "under"
	return "side"


func _read(roll: Dictionary) -> String:
	if roll["lifted"]:
		return "lift"
	if roll["touched"].has("under"):
		return "catch"
	if roll["plate_first"] and roll["kept"] < CATCH:
		return "catch"
	if roll["plate_first"] and roll["kept"] < CLEAN:
		return "loss"
	if roll["touched"].has("wall"):
		return "wall"
	return "clean"


# Seconds since the plate last fired, read from the cycle's public phase and clock.
func _cycle_at() -> float:
	match cycle.phase:
		SteamCycle.FIRING:
			return cycle.t
		SteamCycle.HOLDING:
			return cycle.rise + cycle.t
		SteamCycle.RETURNING:
			return cycle.rise + cycle.hold + cycle.t
	return cycle.rise + cycle.hold + cycle.sink + cycle.t


func _ground(at: Vector3) -> float:
	var space := game.player.body().get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 60.0, at.z), Vector3(at.x, -200.0, at.z))
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	return at.y if hit.is_empty() else float(hit.position.y)


# Height span of the ground over the RUN_M run-up short of `rim` along `dir`.
func _span(rim: Vector3, dir: Vector3) -> float:
	var lo := INF
	var hi := -INF
	for k in int(RUN_M) + 1:
		var y := _ground(rim - dir * float(k))
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo


# A lane start 8 m clear of the plate whose run-up, crossing and run-out are flat ground.
func _open_lane(centre: Vector3) -> Vector3:
	for off: Vector3 in [Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(0, 0, 40), Vector3(0, 0, -40), Vector3(-40, 0, 0), Vector3(40, 0, 0)]:
		var c0: Vector3 = centre + off - Vector3.RIGHT * radius
		var lo := INF
		var hi := -INF
		for k in int(2.0 * radius + 2.0 * RUN_M) + 1:
			var y := _ground(c0 + Vector3.RIGHT * (float(k) - RUN_M))
			lo = minf(lo, y)
			hi = maxf(hi, y)
		if hi - lo < FLAT_M:
			print("  open control lane at (%.1f, %.1f), height span %.2f m" % [c0.x, c0.z, hi - lo])
			return Vector3(c0.x, 0.0, c0.z)
	return Vector3.INF


func _ground_controls(centre: Vector3, cruise: float, period: float) -> void:
	var c0 := _open_lane(centre)
	t.check("control: flat open ground near the lift", c0 != Vector3.INF, "")
	if c0 == Vector3.INF:
		return
	var open := await _roll(c0, Vector3.RIGHT, 2.0 * radius, cruise, 0.0, period, false)
	print("  open ground (control): kept %.2f, lifted %s" % [open["kept"], open["lifted"]])
	t.check("control: open ground keeps at least %.0f%%" % [OPEN_KEEP * 100.0], open["kept"] >= OPEN_KEEP, "kept %.2f" % open["kept"])
	var step := StaticBody3D.new()
	step.name = "PlantedStep"
	step.collision_layer = 0
	step.collision_mask = 0
	step.set_collision_layer_value(ParkRecipes.WORLD_LAYER, true)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0 * radius, STEP_M, 2.0 * radius)
	shape.shape = bs
	step.add_child(shape)
	lift.get_parent().add_child(step)
	var mid := c0 + Vector3.RIGHT * radius
	step.global_position = Vector3(mid.x, _ground(mid) + STEP_M * 0.5, mid.z)
	for i in 2:
		await physics_frame
	var planted := await _roll(c0, Vector3.RIGHT, 2.0 * radius, cruise, 0.0, period, false, step)
	var planted_read := _read(planted)
	print("  planted %.1f m step (control): kept %.2f, lifted %s, reads %s" % [STEP_M, planted["kept"], planted["lifted"], planted_read])
	t.check("control: a planted %.1f m vertical step reads as a loss or a catch (the measure sees a rim)" % STEP_M,
		planted_read == "catch" or planted_read == "loss", "reads %s, kept %.2f" % [planted_read, planted["kept"]])
	step.free()


# Parks the ball still RUN_M short of `rim` (world, on the rim the line enters over), waits for the tick that puts its
# front on the rim at `place` seconds after the plate fired, then rolls it along `dir` across `length` and PAST_M on.
func _roll(rim: Vector3, dir: Vector3, length: float, cruise: float, place: float, period: float, timed: bool, other: Node3D = null) -> Dictionary:
	var player = game.player
	var start: Vector3 = rim - dir * RUN_M
	var start_at := Vector3(start.x, _ground(start) + Tuning.RADIUS + 0.05, start.z)
	var rim_ground := _ground(rim - dir * 0.5)
	source.hold = {}
	player.reset_to(start_at, Vector3.ZERO)
	await physics_frame
	if timed:
		# Front of the ball to the rim at cruise; the tick of release is one tick before the roll moves it.
		var lead := (RUN_M - Tuning.RADIUS) / cruise + 1.0 / float(Engine.physics_ticks_per_second)
		var launch := fposmod(place - lead, period)
		var prev := fposmod(_cycle_at() - launch, period)
		for i in int(period * 2.0 * Engine.physics_ticks_per_second):
			player.reset_to(start_at, Vector3.ZERO)
			await physics_frame
			var d := fposmod(_cycle_at() - launch, period)
			if d < prev:
				break
			prev = d
	player.reset_to(start_at, dir * cruise)
	var touch_in := RUN_M - Tuning.RADIUS
	var before := -1.0
	var met := -1.0
	var plate_over := 0.0
	var kept_min := INF
	var any_min := INF
	var touched: Array[String] = []
	var lifted := false
	var walled := false
	var plate_first := false
	var fire_touch := false
	var fire_low := INF
	var y_met := 0.0
	var low_at := 0.0
	var ball_low := 0.0
	var plate_low := 0.0
	var limit := int((length + RUN_M * 2.0) / cruise * 2.5 * Engine.physics_ticks_per_second) + 90
	for tick in limit:
		game.camera.yaw = atan2(-dir.x, -dir.z)
		source.hold = {"move": Vector2(0.0, 1.0)}
		player.grant_immunity(1.0)
		await physics_frame
		var ball: Vector3 = player.ball_position()
		var s: float = (ball - start).dot(dir)
		var speed: float = player.planar_velocity().length()
		if before < 0.0 and s >= touch_in - BEFORE_M:
			before = speed
		if met < 0.0 and s >= touch_in:
			met = _cycle_at()
			y_met = ball.y
			plate_over = lift.global_position.y + _bounds_y(true) - rim_ground
		if s >= touch_in and s <= RUN_M + length + PAST_M:
			var plate := false
			for found: String in _touch(ball, other):
				var where := found
				if not touched.has(where):
					touched.append(where)
				if where == "wall":
					walled = true
				else:
					plate = true
				if where != "wall" and other == null and cycle.phase == SteamCycle.FIRING:
					fire_touch = true
					fire_low = minf(fire_low, ball.y)
			if plate and not walled:
				plate_first = true
				if speed < kept_min:
					kept_min = speed
					low_at = s - touch_in
					ball_low = ball.y - rim_ground
					plate_low = lift.global_position.y + _bounds_y(true) - rim_ground
			elif not plate_first and speed < any_min:
				ball_low = ball.y - rim_ground
				plate_low = lift.global_position.y + _bounds_y(true) - rim_ground
			any_min = minf(any_min, speed)
		# Lifted: the plate met the ball as it fired and the ball rose LIFTED_M (its job: riding it up, or being thrown).
		if fire_touch and met >= 0.0 and ball.y - fire_low >= LIFTED_M:
			lifted = true
		if s > RUN_M + length + PAST_M or lifted:
			break
	source.hold = {}
	var low := kept_min if plate_first else any_min
	return {
		"before": before, "met": met, "plate_over": plate_over, "lifted": lifted, "plate_first": plate_first or other != null,
		"low_at": low_at, "touched": touched, "kept": low / before if before > 0.0 and low < INF else 0.0,
		"ball_low": ball_low, "plate_low": plate_low, "fire_touch": fire_touch,
	}


# What the ball touches this tick: "wall" for the lift's drum, and top, side or under for its plate (see the header).
# With `other` (a control body), "side" when the ball touches it at all.
func _touch(ball: Vector3, other: Node3D) -> Array[String]:
	var out: Array[String] = []
	var space := game.player.body().get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + TOUCH_SLACK
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, ball)
	q.exclude = [game.player.body().get_rid()]
	var want: RID = other.get_rid() if other != null else lift.get_rid()
	for r: Dictionary in space.intersect_shape(q, 32):
		if r["rid"] != want:
			continue
		if other != null:
			out.append("side")
			continue
		var owner := lift.shape_owner_get_owner(lift.shape_find_owner(int(r["shape"])))
		var local := ball - lift.global_position
		var where := ""
		if owner is Node and (owner as Node).name == "Drum":
			where = "side" if cycle.phase == SteamCycle.CHARGING else "wall"
		else:
			where = _plate_reading(Vector2(Vector2(local.x, local.z).length(), local.y), cycle.phase)
		if not out.has(where):
			out.append(where)
	return out
