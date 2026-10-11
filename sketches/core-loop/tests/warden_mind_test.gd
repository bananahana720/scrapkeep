extends SceneTree

const Game := preload("res://src/game.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const Habits := preload("res://src/combat/habits.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# KF4, the Mind's mechanisms (design-v3/wardens/mind.md sections 3, 4 and 8). A park Warden of
# the mind kind ("harpoon_anchor": true, no "mount_driver") loads src/combat/warden_mind.gd
# through warden.gd's per-kind hook, and the driver gives each mounting its one mechanism:
# - under_island (stage 5): each pulse tilts the island 10 degrees toward the ball, so the hand
#   swings 20 to 21 m away within 1.2 s and is home within 4 s of the pulse; a ball latched to a
#   knuckle at the pulse is dragged and leaves the line when the swing stops (warden.gd's 1.2 s
#   shrug delay) at 20 m/s or more across the ground; a stagger drops the lens 10 m (the
#   knuckles ride the island, which sinks 2 m) and raises it when the stagger ends.
# - spires (stage 6, choir): the hand leaves its perch every 8 s, at most 2 s late when a charge
#   is in flight, and flies 3 s to the next perch; no charge starts in flight; the open seat is
#   the current perch; a stagger in flight puts it on the bowl floor within 1 s and on a perch
#   2 s after the stagger ends; the choir brace and choir_switch still fire.
# Everything is counted in physics ticks. The Warden is stepped by hand (its _physics_process
# called with the tick's delta) except for the latched throw, which needs the ball's real
# physics and the real harpoon press.

const DRIVER_PATH := "res://src/combat/warden_mind.gd"
const TILT_DEGREES := 10.0
const SWING_BAND := Vector2(20.0, 21.0)
const SWING_OUT_S := 1.2
const SWING_HOME_S := 4.0
const THROW_SPEED := 20.0
const LENS_DROP := 10.0
const ISLAND_SINK := 2.0
const PERCH_CYCLE := 8.0
const LATE_MAX := 2.0
const FLIGHT_S := 3.0
const KNOCK_S := 1.0
const CLIMB_S := 2.0
# The knuckles on the back of the palm, 6 m off the axis and 8 m above the anchor (section 3.1:
# palm at 82 m, knuckles at 88 m, anchor at 80 m).
const KNUCKLES := [Vector3(6.0, 8.0, 0.0), Vector3(-6.0, 8.0, 0.0), Vector3(0.0, 8.0, -6.0)]

var t := T.new("warden_mind_test")
var _game
var _combat
var _fleet
var _player
var _source := Intent.Scripted.new()
var _dt := 1.0 / 90.0
var _tick := 0
var _ends: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _run() -> void:
	_dt = 1.0 / float(Engine.physics_ticks_per_second)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_fleet = _combat.fleet
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(10)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_game.events.line_state_changed.connect(func(id: String, _t: Node3D, _at: Vector3, cause: String):
		if id == "idle" or cause != "":
			_ends.append(cause))
	_clear_enemies()
	_hook()
	_tilt()
	_falter()
	await _throw()
	_flight()
	_perch_stagger()
	_knock_down()
	await _frames(2)
	_game.free()
	quit(t.verdict())


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if enemy.get("kind") != "vault":
			enemy.queue_free()


# A park-style mind Warden, as the park loader builds one: an anchor with no named driver.
func _spawn(stage: int, variant: String, offset: Vector3, extra := {}) -> Node3D:
	var at: Vector3 = _site() + offset
	var warden = WardenScript.new()
	_game.ctx.root.add_child(warden)
	warden.global_position = at
	var spec := {"kind": "warden", "family": "mind", "stage": stage, "variant": variant, "harpoon_anchor": true,
		"fleet": _fleet, "plating": 170.0 if stage == 5 else 190.0, "hp": 1250.0 if stage == 5 else 1400.0}
	spec.merge(extra, true)
	warden.setup(_player, _game.ctx.terrain, _game.ctx.root, func(): return true, 1.0, spec)
	warden.set_physics_process(false)
	return warden


func _site() -> Vector3:
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	return Vector3(spawn.x + 60.0, 0.0, spawn.z + 60.0)


# One physics tick of the Warden, by hand.
func _step(warden: Node3D, count := 1, ball_at = null) -> void:
	for i in count:
		if ball_at is Callable:
			_player.reset_to(ball_at.call())
		_tick += 1
		warden._physics_process(_dt)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _matched_force(warden: Node3D) -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < float(warden.plating):
		force += 0.05
	return force


# Rams until the Warden staggers; false when it never does.
func _stagger(warden: Node3D) -> bool:
	var force := _matched_force(warden)
	for i in 20:
		if warden.staggered():
			return true
		_combat.strike(warden, "ram", force)
	return warden.staggered()


func _driver_ok(warden: Node3D, label: String) -> bool:
	var driver = warden.mount_driver
	var ok: bool = driver != null and driver.get_script() != null and driver.get_script().resource_path == DRIVER_PATH
	if not ok:
		t.check(label, false, "no mind driver on the Warden (mount_driver %s)" % [driver])
	return ok


# The hook: a park mind Warden of either mounting gets the kind's driver; one that is not an
# anchor (the authored arenas' kind) gets none.
func _hook() -> void:
	var island := _spawn(5, "", Vector3.ZERO)
	var spires := _spawn(6, "choir", Vector3(200.0, 0.0, 0.0))
	var arena = WardenScript.new()
	_game.ctx.root.add_child(arena)
	arena.global_position = _site() + Vector3(-200.0, 0.0, 0.0)
	arena.setup(_player, _game.ctx.terrain, _game.ctx.root, func(): return true, 1.0, {"family": "mind", "stage": 5})
	var path := DRIVER_PATH
	var loaded := func(w): return w.mount_driver != null and w.mount_driver.get_script() != null \
			and w.mount_driver.get_script().resource_path == path
	t.check("a park mind Warden loads warden_mind.gd on both mountings", loaded.call(island) and loaded.call(spires)
			and island.mounting == "under_island" and spires.mounting == "spires",
		"under_island %s (%s), spires %s (%s)" % [loaded.call(island), island.mounting, loaded.call(spires), spires.mounting])
	t.check("a mind Warden that is not an anchor gets no driver", arena.mount_driver == null,
		"arena driver %s" % [arena.mount_driver])
	island.queue_free()
	spires.queue_free()
	arena.queue_free()


# The pendulum tilt: one pulse, then the swing out and back.
func _tilt() -> void:
	var warden := _spawn(5, "", Vector3.ZERO)
	if not _driver_ok(warden, "under_island: the tilt"):
		warden.queue_free()
		return
	var driver = warden.mount_driver
	var ball: Vector3 = warden.home + Vector3(15.0, 0.0, 4.0)
	var toward := _flat(ball - warden.home).normalized()
	var keep := func(): return ball
	var tilts := []
	driver.island_tilted.connect(func(degrees: float, away: Vector3): tilts.append([degrees, away, _tick]))
	var pulses: int = warden.pulses
	var guard := 0
	while warden.pulses == pulses and guard < _ticks(8.0):
		_step(warden, 1, keep)
		guard += 1
	var pulse_tick := _tick
	t.check("under_island: a pulse came", warden.pulses == pulses + 1, "pulses %d after %d ticks" % [warden.pulses - pulses, guard])
	var peak := Vector3.ZERO
	var reached := -1
	var home_at := -1
	var worst_home := 0.0
	for i in _ticks(SWING_HOME_S + 0.5):
		_step(warden, 1, keep)
		var offset: Vector3 = warden.global_position - warden.home
		if _flat(offset).length() > _flat(peak).length():
			peak = offset
		if reached < 0 and _flat(offset).length() >= SWING_BAND.x:
			reached = _tick - pulse_tick
		if _tick - pulse_tick >= _ticks(SWING_HOME_S) + 1:
			worst_home = maxf(worst_home, offset.length())
			if home_at < 0 and offset.length() < 0.05:
				home_at = _tick - pulse_tick
	var tilt_ok: bool = tilts.size() == 1 and is_equal_approx(float(tilts[0][0]), TILT_DEGREES) \
			and (tilts[0][1] as Vector3).dot(-toward) > 0.999 and int(tilts[0][2]) == pulse_tick
	t.check("under_island: the pulse tilts the island 10 degrees toward the ball", tilt_ok,
		"tilts %s, pulse at tick %d, toward the ball %s" % [tilts, pulse_tick, toward])
	var away := _flat(peak).normalized().dot(-toward)
	t.check("under_island: the anchor swings 20 to 21 m away within 1.2 s", _flat(peak).length() >= SWING_BAND.x
			and _flat(peak).length() <= SWING_BAND.y and reached >= 0 and reached <= _ticks(SWING_OUT_S) + 1 and away > 0.99,
		"peak %.2f m across (rise %.2f m), 20 m reached %d ticks after the pulse (limit %d), away %.3f" % [
			_flat(peak).length(), peak.y, reached, _ticks(SWING_OUT_S) + 1, away])
	t.check("under_island: the anchor is home within 4 s of the pulse", worst_home < 0.05,
		"worst offset from %d ticks on: %.3f m" % [_ticks(SWING_HOME_S) + 1, worst_home])
	warden.queue_free()


# The grip falters on a stagger: the lens drops 10 m, the knuckles ride the island down 2 m,
# and both return when the stagger ends.
func _falter() -> void:
	var warden := _spawn(5, "", Vector3(0.0, 0.0, 120.0))
	if not _driver_ok(warden, "under_island: the grip falter"):
		warden.queue_free()
		return
	var driver = warden.mount_driver
	var far := func(): return warden.home + Vector3(80.0, 0.0, 0.0)
	_step(warden, 5, far)
	var lens0: Vector3 = warden.family_point_at()
	var knuckle0: Vector3 = warden.hardpoint_at(0)
	var staggered := _stagger(warden)
	_step(warden, _ticks(0.6), far)
	var drop: float = lens0.y - warden.family_point_at().y
	var knuckle_drop: float = knuckle0.y - warden.hardpoint_at(0).y
	t.check("under_island: a stagger drops the lens 10 m", staggered and warden.staggered() and absf(drop - LENS_DROP) <= 0.2,
		"staggered %s, lens dropped %.2f m 0.6 s in" % [staggered, drop])
	t.check("under_island: the knuckles ride the island down 2 m", absf(knuckle_drop - ISLAND_SINK) <= 0.2
			and absf(float(driver.island_sink) - ISLAND_SINK) <= 0.01,
		"knuckle dropped %.2f m, island_sink %.2f m" % [knuckle_drop, float(driver.island_sink)])
	var guard := 0
	while warden.staggered() and guard < _ticks(8.0):
		_step(warden, 1, far)
		guard += 1
	_step(warden, _ticks(0.6), far)
	var back: float = absf(warden.family_point_at().y - lens0.y)
	t.check("under_island: the lens rises again when the stagger ends", not warden.staggered() and back <= 0.05
			and warden.hardpoint_at(0).distance_to(knuckle0) <= 0.05,
		"stagger closed after %d ticks, lens %.3f m off, knuckle %.3f m off" % [guard, back,
			warden.hardpoint_at(0).distance_to(knuckle0)])
	warden.queue_free()


func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


func _held(warden: Node3D) -> bool:
	var kit = _player.kit
	return kit.hooked and kit.on_body and kit.anchor_body == warden


# A ball latched to a knuckle at the pulse rides the swing and is thrown when it stops. Real
# physics, the real harpoon press (the lock bites the knuckle facing the ball), the key held.
func _throw() -> void:
	var warden := _spawn(5, "", Vector3(0.0, 0.0, -120.0))
	if not _driver_ok(warden, "under_island: the throw"):
		warden.queue_free()
		return
	warden.home += Vector3.UP * 20.0
	warden.hardpoints = KNUCKLES.duplicate()
	warden.set_physics_process(true)
	await _frames(2)
	var from: Vector3 = warden.home + Vector3(16.0, 8.0, 0.0)
	_game.camera.snap(warden.global_position - from)
	for i in _ticks(0.4):
		_player.reset_to(from)
		_aim_at(warden.global_position)
		warden._pulse_clock = 0.0
		await physics_frame
	_player.reset_to(from)
	_aim_at(warden.global_position)
	_source.hold = {"harpoon_held": true}
	_source.press = {"harpoon_pressed": true}
	await _frames(2)
	var latched := _held(warden)
	var lined: int = warden.lined_hardpoint()
	t.check("under_island: the ball latches a knuckle", latched and lined == 0,
		"latched %s, lined hardpoint %d" % [latched, lined])
	if not latched:
		_source.hold = {}
		warden.queue_free()
		return
	_ends.clear()
	var pulses: int = warden.pulses
	warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
	var clock := 0
	var at_pulse := -1
	var dropped := -1
	var v_drop := Vector3.ZERO
	var anchor_peak := 0.0
	for i in _ticks(5.0):
		await physics_frame
		clock += 1
		if at_pulse < 0 and warden.pulses > pulses:
			at_pulse = clock
		if at_pulse >= 0:
			anchor_peak = maxf(anchor_peak, _flat(warden.anchor_velocity()).length())
		if not _held(warden):
			dropped = clock
			await physics_frame
			v_drop = _player.body().linear_velocity
			break
	_source.hold = {}
	var after := float(dropped - at_pulse) / Engine.physics_ticks_per_second if at_pulse >= 0 and dropped >= 0 else -1.0
	t.check("under_island: the line drops when the swing stops", at_pulse >= 0 and absf(after - SWING_OUT_S) <= 0.1
			and _ends.has("shrugged"),
		"pulse at tick %d, line dropped %.2f s after it, ends %s" % [at_pulse, after, _ends])
	t.check("under_island: the throw leaves at 20 m/s or more across the ground", dropped >= 0
			and _flat(v_drop).length() >= THROW_SPEED,
		"planar %.1f m/s at the drop (vertical %+.1f), anchor peak %.1f m/s" % [_flat(v_drop).length(), v_drop.y, anchor_peak])
	warden.queue_free()
	await _frames(2)


func _perch_of(driver, offset: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in driver.perch_offsets.size():
		var d: float = offset.distance_to(driver.perch_offsets[i])
		if d < best_d:
			best_d = d
			best = i
	return best if best_d < 0.05 else -1


# The choir flight over 34 s: takeoffs, flights, charges, and one charge forced to straddle the
# perch clock so the takeoff waits for its pulse.
func _flight() -> void:
	var warden := _spawn(6, "choir", Vector3(0.0, 0.0, 300.0))
	if not _driver_ok(warden, "spires: the flight"):
		warden.queue_free()
		return
	var driver = warden.mount_driver
	var under := func(): return warden.global_position + Vector3(10.0, 0.0, 0.0)
	var takeoffs := []
	var landings := []
	driver.took_off.connect(func(from: int, to: int): takeoffs.append([_tick, from, to]))
	driver.landed.connect(func(perch: int): landings.append([_tick, perch]))
	var start := _tick
	var charges := 0
	var charges_in_flight := 0
	var pulses_off_perch := 0
	var pulse_ticks := []
	var was_charging := false
	var pulses: int = warden.pulses
	var forced := false
	for i in _ticks(34.0):
		if not forced and takeoffs.size() >= 2 and driver.phase == "perched" and float(driver.perch_clock) >= PERCH_CYCLE - 1.0 \
				and not warden._charging:
			warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
			forced = true
		var flying_before: bool = driver.flying()
		_step(warden, 1, under)
		if warden._charging and not was_charging:
			charges += 1
			if flying_before or driver.flying():
				charges_in_flight += 1
		was_charging = warden._charging
		if warden.pulses > pulses:
			pulses = warden.pulses
			pulse_ticks.append(_tick)
			if _perch_of(driver, warden.global_position - warden.home) < 0:
				pulses_off_perch += 1
	var intervals := []
	for i in range(1, takeoffs.size()):
		intervals.append(float(takeoffs[i][0] - takeoffs[i - 1][0]) / Engine.physics_ticks_per_second)
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	var in_band := not intervals.is_empty()
	var late := 0
	for gap in intervals:
		in_band = in_band and gap >= PERCH_CYCLE - tick_s and gap <= PERCH_CYCLE + LATE_MAX + tick_s
		if gap > PERCH_CYCLE + tick_s:
			late += 1
	t.check("spires: the hand leaves its perch every 8 s, at most 2 s late", takeoffs.size() >= 3 and in_band and late >= 1,
		"%d takeoffs from tick %d, intervals %s s, %d late" % [takeoffs.size(), start, intervals, late])
	var after_pulse := false
	for takeoff in takeoffs:
		for p in pulse_ticks:
			if int(takeoff[0]) - int(p) >= 0 and int(takeoff[0]) - int(p) <= 1 and float(takeoff[0] - start) > PERCH_CYCLE + 0.5:
				after_pulse = true
	t.check("spires: a takeoff the charge held back comes right after its pulse", forced and after_pulse,
		"forced %s, pulse ticks %s, takeoff ticks %s" % [forced, pulse_ticks, takeoffs.map(func(x): return x[0])])
	var flights_ok := landings.size() >= 3
	var lengths := []
	for i in mini(takeoffs.size(), landings.size()):
		var length := int(landings[i][0]) - int(takeoffs[i][0])
		lengths.append(length)
		flights_ok = flights_ok and absi(length - _ticks(FLIGHT_S)) <= 1 and int(landings[i][1]) == int(takeoffs[i][2])
	t.check("spires: each flight lasts 3 s and lands on the next perch", flights_ok,
		"flight ticks %s (3 s is %d), takeoffs %s, landings %s" % [lengths, _ticks(FLIGHT_S), takeoffs, landings])
	var order := takeoffs.size() >= 3
	for i in takeoffs.size():
		order = order and int(takeoffs[i][2]) == (int(takeoffs[i][1]) + 1) % 3
	t.check("spires: it flies the three perches in order", order, "takeoffs %s" % [takeoffs])
	t.check("spires: no charge starts in flight and every pulse comes from a perch", charges >= 3 and charges_in_flight == 0
			and pulses_off_perch == 0 and not pulse_ticks.is_empty(),
		"%d charges, %d in flight, %d pulses, %d off a perch" % [charges, charges_in_flight, pulse_ticks.size(), pulses_off_perch])
	warden.queue_free()


# A stagger on a perch: the hand stays, the open seat is that perch, the brace reads the habit,
# and a strike of another kind is the choir_switch.
func _perch_stagger() -> void:
	var warden := _spawn(6, "choir", Vector3(300.0, 0.0, 300.0))
	if not _driver_ok(warden, "spires: the perch stagger"):
		warden.queue_free()
		return
	var driver = warden.mount_driver
	var under := func(): return warden.global_position + Vector3(60.0, 0.0, 0.0)
	# Fly once, so the seat is checked on a perch other than the first.
	var guard := 0
	while (int(driver.perch) == 0 or driver.phase != "perched") and guard < _ticks(14.0):
		_step(warden, 1, under)
		guard += 1
	_step(warden, _ticks(0.5), under)
	var perch: int = driver.perch
	for i in 8:
		_game.events.enemy_struck.emit(null, "ram", 20.0)
	var adapted: int = _fleet.mind_memory.size()
	var staggered := _stagger(warden)
	var seat: Vector3 = warden.family_point_at()
	var seat_perch := -1
	var seat_d := INF
	for i in driver.perch_offsets.size():
		var d: float = _flat(seat - (warden.home + driver.perch_offsets[i])).length()
		if d < seat_d:
			seat_d = d
			seat_perch = i
	t.check("spires: the open seat is the current perch", staggered and perch != 0 and seat_perch == perch
			and seat_d <= WardenScript.CHOIR_RADIUS + 0.01,
		"staggered %s on perch %d, seat nearest perch %d at %.2f m" % [staggered, perch, seat_perch, seat_d])
	t.check("spires: the choir brace still fires", warden.braced_kinds == Habits.BRACES["ram"]["kinds"]
			and _fleet.mind_memory.size() == adapted + 1,
		"braced %s, adaptations %d to %d" % [warden.braced_kinds, adapted, _fleet.mind_memory.size()])
	var stayed := true
	for i in _ticks(1.0):
		_step(warden, 1, under)
		stayed = stayed and _perch_of(driver, warden.global_position - warden.home) == perch
	t.check("spires: a stagger on a perch leaves the hand on it", stayed and warden.staggered(), "stayed %s" % stayed)
	_combat.discovered.erase("choir_switch")
	_combat.strike(warden, "runner", 1.0)
	t.check("spires: choir_switch still fires", _combat.discovered.has("choir_switch"),
		"discovered %s" % [_combat.discovered.keys()])
	warden.queue_free()


# A stagger in flight knocks the hand onto the bowl floor within 1 s; it climbs back onto a
# perch 2 s after the stagger ends.
func _knock_down() -> void:
	var warden := _spawn(6, "choir", Vector3(-300.0, 0.0, 300.0))
	if not _driver_ok(warden, "spires: the knock-down"):
		warden.queue_free()
		return
	var driver = warden.mount_driver
	var far := func(): return warden.home + Vector3(0.0, 0.0, 200.0)
	var guard := 0
	while driver.phase != "flight" and guard < _ticks(10.0):
		_step(warden, 1, far)
		guard += 1
	_step(warden, _ticks(1.5), far)
	var in_flight: bool = driver.flying()
	var staggered := _stagger(warden)
	var stagger_tick := _tick
	var floor_y: float = warden.home.y + float(driver.floor_offset)
	var floored := -1
	var left_floor := false
	while warden.staggered() and _tick - stagger_tick < _ticks(8.0):
		_step(warden, 1, far)
		var on_floor := absf(warden.global_position.y - floor_y) < 0.05
		if floored < 0 and on_floor:
			floored = _tick - stagger_tick
		elif floored >= 0 and not on_floor:
			left_floor = true
	var end_tick := _tick
	t.check("spires: a stagger in flight puts the hand on the bowl floor within 1 s", in_flight and staggered
			and floored >= 0 and floored <= _ticks(KNOCK_S) + 1 and not left_floor,
		"in flight %s, staggered %s, on the floor %d ticks later (limit %d), left it early %s" % [in_flight, staggered,
			floored, _ticks(KNOCK_S) + 1, left_floor])
	var perched := -1
	for i in _ticks(CLIMB_S + 1.0):
		_step(warden, 1, far)
		if perched < 0 and _perch_of(driver, warden.global_position - warden.home) >= 0:
			perched = _tick - end_tick
	t.check("spires: back on a perch 2 s after the stagger ends", absi(perched - _ticks(CLIMB_S)) <= 1
			and driver.phase == "perched",
		"perched %d ticks after the stagger closed (2 s is %d), phase %s" % [perched, _ticks(CLIMB_S), driver.phase])
	warden.queue_free()
