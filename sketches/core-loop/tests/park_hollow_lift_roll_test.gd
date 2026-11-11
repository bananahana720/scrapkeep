extends SceneTree
# smoke: timeout=600s

# The flume's hollow lift and a ball at cruise, at fixed places in the lift's cycle (wave 36 snag sweep,
# flume-merged.json: one row on Contraptions/hollow_lift at (-209.0, 19.85, -55.7), 13.8 m/s down to 3.7, left
# undecided because the sweep met the moving plate at one unknown point of its cycle). The plate is an
# AnimatableBody3D cylinder (contraptions.gd _build_lift) on a periodic SteamCycle: it fires up `rise` m, holds,
# sinks back to rest with its top 0.05 m over the ground, then charges.
#
# Phase method: time is stepped, nothing is set. The test reads the lift's cycle (its public phase and clock, read
# only) every physics tick and releases the ball, parked still RUN_M short of the rim, on the tick that makes its
# front reach the rim at the wanted point of the cycle. The point actually met is measured and printed beside it.
#
# Each run rolls a line through the plate's centre: the sweep's undecided lane (heading -z) and one square to it
# (heading +x). It records, while the ball touches the plate, the lowest planar speed as a share of the speed
# BEFORE_M short of the rim, where on the plate it touched (top, side, underside, in order), and whether the ball was
# lifted (on the plate's top while the plate fires up: riding it up or being thrown is the lift's job). A run is a catch when it keeps under CATCH with no lift,
# clean when it keeps at least CLEAN or never touches the plate.
# Controls on flat open ground near the lift: the same roll with nothing in its way keeps at least OPEN_KEEP, and a
# planted vertical 0.5 m step reads as a loss, so a clean table is the plate's and not a blind measure.
#
# Red on wave 36 by finding, not by defect: at 2.5 to 3.4 s after firing the sinking plate lands on a ball that rolled
# under it while raised and stops it dead, on both lanes. No plate shape that keeps its top radius and timing avoids
# that contact, so the fix (timing, or keeping the ball out from under the raised plate) is the owner's call.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const SteamCycle := preload("res://src/world/steam_cycle.gd")
const T := preload("res://tests/support/t.gd")

const LIFT_ID := "hollow_lift"
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

var t := T.new("park_hollow_lift_roll_test")
var game
var source := Intent.Scripted.new()
var lift: AnimatableBody3D
var cycle
var radius := 0.0
var exclude: Array[RID] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	game.flow.enter_stage(2, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for i in 30:
		await physics_frame
	t.eq("real Game plays the flume on the park table", terrain.map().title, "park_flume")
	var found: Array = game.find_children(LIFT_ID, "AnimatableBody3D", true, false)
	t.check("the flume places the hollow lift", found.size() == 1, "%d found" % found.size())
	if found.size() != 1:
		game.free()
		quit(t.verdict())
		return
	lift = found[0]
	for l: Dictionary in lift.get_parent().lifts:
		if l["body"] == lift:
			cycle = l["cycle"]
			radius = float(l["spec"]["radius"])
	t.check("the lift runs a periodic cycle", cycle != null and cycle.mode == SteamCycle.PERIODIC, "")
	if cycle == null:
		game.free()
		quit(t.verdict())
		return
	exclude = [game.player.body().get_rid(), lift.get_rid()]
	var period: float = cycle.rise + cycle.hold + cycle.sink + cycle.charge
	var cruise: float = game.player.tuning.f("cruise")
	var centre := lift.global_position
	print("  lift at (%.1f, %.1f), plate radius %.1f, cycle %.2f s (rise %.2f hold %.2f sink %.2f charge %.2f), cruise %.1f" %
		[centre.x, centre.z, radius, period, cycle.rise, cycle.hold, cycle.sink, cycle.charge, cruise])
	# The square lane runs over whichever side, -x or +x, has the flatter run-up.
	var square := Vector3.RIGHT
	if _span(Vector3(centre.x, 0.0, centre.z) + Vector3.LEFT * radius, Vector3.LEFT) < _span(Vector3(centre.x, 0.0, centre.z) + Vector3.RIGHT * -radius, Vector3.RIGHT):
		square = Vector3.LEFT
	var lanes := {"sweep lane -z": Vector3.FORWARD, ("square lane %s" % ("+x" if square == Vector3.RIGHT else "-x")): square}
	var places: Array[float] = []
	for k in PHASES:
		places.append(period * float(k) / float(PHASES))
	for f: float in FINE:
		places.append(f)
	print("  | lane | cycle s (wanted) | met | plate top over rim ground m | touched, in order | lifted | kept | lowest at m past rim | read |")
	var worst := {"catch": 0, "loss": 0}
	for lane: String in lanes:
		var dir: Vector3 = lanes[lane]
		var rim := Vector3(centre.x, 0.0, centre.z) + dir * -radius
		for i in places.size():
			var roll := await _roll(rim, dir, radius * 2.0, cruise, places[i], period, true)
			var read := _read(roll)
			if read == "catch" or read == "loss":
				worst[read] += 1
			print("  | %s | %s%.2f | %.2f | %.2f | %s | %s | %.2f | %.1f | %s |" % [lane, "" if i < PHASES else "fine ", places[i],
				roll["met"], roll["plate_over"], ",".join(roll["touched"]) if not roll["touched"].is_empty() else "-",
				"yes" if roll["lifted"] else "no", roll["kept"], roll["low_at"], read])
	# The guard: no place in the cycle stops a ball at cruise against the plate.
	t.check("no place in the cycle stops a ball at cruise against the plate (kept under %.0f%%, not lifted)" % [CATCH * 100.0],
		worst["catch"] == 0, "%d catches" % worst["catch"])
	t.check("no place in the cycle costs more than %.0f%% without a lift" % [(1.0 - CLEAN) * 100.0],
		worst["loss"] == 0, "%d losses" % worst["loss"])
	# Controls on open flat ground near the lift.
	var c0 := _open_lane(centre)
	t.check("control: flat open ground near the lift", c0 != Vector3.INF, "")
	if c0 != Vector3.INF:
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
	game.free()
	quit(t.verdict())


func _read(roll: Dictionary) -> String:
	if roll["lifted"]:
		return "lift"
	if roll["touched"].is_empty() or roll["kept"] >= CLEAN:
		return "clean"
	if roll["kept"] < CATCH:
		return "catch"
	return "loss"


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


# Parks the ball still RUN_M short of `rim` (world, on the rim the line enters over), waits for the tick that puts its
# front on the rim at `place` seconds after the plate fired, then rolls it along `dir` across `length` and PAST_M on.
# kept: the lowest planar speed while touching the plate (or `other`, for a control; over the whole crossing when
# neither is given) over the speed BEFORE_M short of the rim.
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
	var low_at := 0.0
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
			plate_over = lift.global_position.y + 0.5 - rim_ground
		if s >= touch_in and s <= RUN_M + length + PAST_M:
			any_min = minf(any_min, speed)
			var where := _touch(ball, other)
			if where != "" and not touched.has(where):
				touched.append(where)
			# Lifted: on the plate's top while it fires up (its job: riding it up, or being thrown).
			if where == "top" and other == null and cycle.phase == SteamCycle.FIRING:
				lifted = true
			if where != "" and speed < kept_min:
				kept_min = speed
				low_at = s - touch_in
		if s > RUN_M + length + PAST_M or lifted:
			break
	source.hold = {}
	var low := kept_min if other != null or not touched.is_empty() else any_min
	if other != null and touched.is_empty():
		low = any_min
	return {
		"before": before, "met": met, "plate_over": plate_over, "lifted": lifted,
		"low_at": low_at, "touched": touched, "kept": low / before if before > 0.0 and low < INF else 0.0,
	}


# Where the ball touches the plate this tick, from the plate's own shape: "top", "side", "under" or "" (no touch).
# With `other` (a control body), "side" when the ball touches it at all.
func _touch(ball: Vector3, other: Node3D) -> String:
	var space := game.player.body().get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + TOUCH_SLACK
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, ball)
	q.exclude = [game.player.body().get_rid()]
	var want: RID = other.get_rid() if other != null else lift.get_rid()
	var hit := false
	for r: Dictionary in space.intersect_shape(q, 32):
		if r["rid"] == want:
			hit = true
	if not hit:
		return ""
	if other != null:
		return "side"
	var c := lift.global_position
	if ball.y >= c.y + 0.5:
		return "top"
	if ball.y <= c.y - 0.5:
		return "under"
	return "side"
