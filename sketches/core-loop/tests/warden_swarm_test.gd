extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# KF3 (wardens/swarm.md sections 3 and 4): the swarm's two mountings through its driver,
# src/combat/warden_swarm.gd, in a stepped headless fight on the alpha table, counted in
# physics frames. The driver is loaded by path so this file compiles before it exists.
#
# headframe (stage 3): the hive dwells 4 s low and 4 s high and moves 30 m in 2 s each way;
# the pulse fires at the end of each dwell and a charge starts only in a dwell; a stagger
# drops the hive to the collar within 1.0 s and the cycle resumes from the low dwell when the
# stagger ends; a ball latched through the rise leaves the stop with at least 12 m/s upward
# and the hoist_ride fact fires; the snip (the swarm's shrug on the pulse) changes a latched
# ball's velocity by the pulse lift and nothing else.
# sinkhole (stage 4, brood): each chunk lost raises the pool floor 5 m behind a pool_swell
# telegraph; no step rises while the ball is grounded on the pool, except the 6 s lift
# fallback, which leaves planar speed within 1 percent; the lamp guard's last kill by a
# cruise ram pays 25 posture as a rack scatter does; brood_dark still fires.
# A park-style spawn (spec "harpoon_anchor": true, family swarm) loads the driver itself.

const DRIVER_PATH := "res://src/combat/warden_swarm.gd"
const DWELL := 4.0
const MOVE := 2.0
const RISE := 30.0
const BRAKE_LIMIT := 1.0
# Frames a dwell may run long: it waits on its pulse, which the warden's float clocks can
# land up to three ticks after the window (warden_swarm.gd charge_allowed).
const DWELL_SLACK := 3
const THROW_MIN := 12.0
const POOL_STEP := 5.0
const SWELL := 2.0
const POOL_RISE := 3.0
const HOLD_FALLBACK := 6.0
const RACK_POSTURE := 25.0
const LIFT := 10.0
# The smash's hit-stop slows game time for a few frames, so a swell counted in frames right
# after a real smash runs a little long; telegraph_timing_swarm_test holds it to one tick.
const SLOW_TOLERANCE := 0.1

var _game
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _smashed := 0
var _facts: Array = []
var _out := Vector3.LEFT
var _side := Vector3.FORWARD


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _tick() -> float:
	return 1.0 / Engine.physics_ticks_per_second


func _driver_script():
	if not ResourceLoader.exists(DRIVER_PATH):
		return null
	return load(DRIVER_PATH)


func _start(stage: int) -> bool:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_facts.clear()
	_smashed = 0
	_game.events.world_fact.connect(func(kind: String, at: Vector3): _facts.append({"kind": kind, "at": at, "frame": Engine.get_physics_frames()}))
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	await _frames(_ticks(0.4))
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	_clear_enemies()
	await _frames(2)
	return true


# The hoist checks run with no posture build-up and no guard on the floor, so a drone's hit
# never moves the ball or the bar (the guard's own rule is warden_guard_posture_test's).
func _quiet() -> void:
	_warden._posture.posture = 0.0
	_warden._guard_wait = 999.0
	if _warden.guard != null:
		for enemy in _warden.guard.alive():
			enemy.queue_free()


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()


func _end() -> void:
	_source.hold = {}
	_game.free()
	_game = null
	await _frames(2)


# The park's way in: the Warden is an anchor and its kind's driver moves it.
func _attach() -> Object:
	var script = _driver_script()
	if script == null:
		return null
	_warden.set_harpoon_anchor(true)
	_warden.set_mount_driver(script.new())
	_warden._pulse_clock = 0.0
	return _warden.mount_driver


func _pick_side() -> void:
	var terrain = _game.ctx.terrain
	var home: Vector3 = _warden.home
	var best := -INF
	for i in 8:
		var out := Vector3.LEFT.rotated(Vector3.UP, TAU * float(i) / 8.0)
		var worst := INF
		for d in [8.0, 14.0, 20.0]:
			worst = minf(worst, home.y - terrain.height(home.x + out.x * d, home.z + out.z * d))
		if worst > best:
			best = worst
			_out = out
	_side = _out.cross(Vector3.UP).normalized()


func _ground(at: Vector3) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.5)


func _offset() -> float:
	return _warden.global_position.y - _warden.home.y


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < float(_warden.plating):
		force += 0.05
	return force


func _fill() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 30:
		_combat.strike(_warden, "ram", _matched_force())
		await physics_frame
		guard += 1


func _run() -> void:
	_report("the swarm driver exists", _driver_script() != null, DRIVER_PATH)
	await _park_spawn()
	await _headframe()
	await _sinkhole()
	print("warden_swarm_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# A park Warden of the swarm kind loads the driver; one that does not opt in, or another kind, does not.
func _park_spawn() -> void:
	if not await _start(3):
		_report("stage 3 fields a Warden", false, "no Warden")
		return
	var made := []
	for spec in [{"stage": 3, "family": "swarm", "harpoon_anchor": true}, {"stage": 3, "family": "swarm"},
			{"stage": 1, "family": "reactor", "harpoon_anchor": true}]:
		var w = WardenScript.new()
		_game.ctx.root.add_child(w)
		w.global_position = _warden.global_position + Vector3(80.0 + 20.0 * made.size(), 0.0, 80.0)
		w.setup(_player, _game.ctx.terrain, _game.ctx.root, Callable(_game.flow, "in_play"), 1.0, spec)
		var driver = w.mount_driver
		made.append(driver.get_script().resource_path if driver != null and driver.get_script() != null else "")
		w.queue_free()
	_report("a park swarm Warden loads its driver, no other does", made[0] == DRIVER_PATH and made[1] != DRIVER_PATH
			and made[2] != DRIVER_PATH, "anchor swarm %s, plain swarm '%s', anchor reactor '%s'" % made)
	await _end()


func _headframe() -> void:
	if not await _start(3):
		_report("stage 3 fields a Warden", false, "no Warden")
		return
	_report("stage 3 is the headframe hive", _warden.family == "swarm" and _warden.mounting == "headframe",
		"family %s, mounting %s" % [_warden.family, _warden.mounting])
	var driver = _attach()
	if driver == null:
		_report("headframe: driver attached", false, "no driver")
		await _end()
		return
	_pick_side()
	await _hoist_cycle(driver)
	await _brake_drop(driver)
	await _ride(driver)
	await _snip(driver)
	await _end()


# Two full cycles: dwell and move lengths by run of frames, the travel, and where each charge and pulse falls.
func _hoist_cycle(driver) -> void:
	var stand := _ground(_warden.home + _out * 14.0)
	var classes: Array = []
	var top := 0.0
	var pulses: int = _warden.pulses
	var charging: bool = _warden._charging
	var pulse_phases: Array = []
	var charge_phases: Array = []
	for i in _ticks(2.0 * (2.0 * (DWELL + MOVE)) + 0.5):
		_player.reset_to(stand)
		_quiet()
		await physics_frame
		var y := _offset()
		top = maxf(top, y)
		classes.append(0 if y < 0.01 else (2 if y > RISE - 0.01 else 1))
		if _warden.pulses > pulses:
			pulses = _warden.pulses
			pulse_phases.append(float(driver.clock))
		if _warden._charging and not charging:
			charge_phases.append(float(driver.clock))
		charging = _warden._charging
	var runs := _runs(classes)
	var lows := []
	var highs := []
	var moves := []
	for i in range(1, runs.size() - 1):
		var run: Array = runs[i]
		(lows if run[0] == 0 else (highs if run[0] == 2 else moves)).append(run[1])
	if not runs.is_empty() and runs[0][0] == 0:
		lows.push_front(runs[0][1])
	var ok_low := lows.size() >= 2 and lows.all(func(n): return absi(n - _ticks(DWELL)) <= DWELL_SLACK)
	var ok_high := highs.size() >= 2 and highs.all(func(n): return absi(n - _ticks(DWELL)) <= DWELL_SLACK)
	var ok_move := moves.size() >= 3 and moves.all(func(n): return absi(n - _ticks(MOVE)) <= 2)
	_report("headframe: dwells 4 s low and 4 s high, moves 30 m in 2 s each way", ok_low and ok_high and ok_move
			and absf(top - RISE) < 0.01,
		"low runs %s, high runs %s, move runs %s frames (dwell %d, move %d), top %.2f m" % [lows, highs, moves,
			_ticks(DWELL), _ticks(MOVE), top])
	var at_end := pulse_phases.size() >= 3 and pulse_phases.all(func(p): return _near_any(p, [DWELL, 2.0 * DWELL + MOVE], 1.5))
	_report("headframe: the pulse fires at the end of each dwell", at_end,
		"pulses at hoist clock %s (dwells end at %.1f and %.1f)" % [pulse_phases, DWELL, 2.0 * DWELL + MOVE])
	var in_dwell := charge_phases.size() >= 3 and charge_phases.all(func(p): return _near_any(p, [DWELL - 2.0, 2.0 * DWELL + MOVE - 2.0], 1.5))
	_report("headframe: a charge starts only in a dwell, 2 s before its end", in_dwell, "charges at hoist clock %s" % [charge_phases])


func _near_any(value: float, marks: Array, ticks: float) -> bool:
	for mark in marks:
		if absf(value - float(mark)) <= ticks * _tick():
			return true
	return false


# [class, frames] runs.
func _runs(classes: Array) -> Array:
	var runs := []
	for c in classes:
		if runs.is_empty() or runs[-1][0] != c:
			runs.append([c, 0])
		runs[-1][1] += 1
	return runs


# Stagger at the high dwell: the hive lands within 1.0 s, stays at the collar for the stagger,
# and the low dwell after it lasts DWELL before the next rise.
func _brake_drop(driver) -> void:
	var stand := _ground(_warden.home + _out * 14.0)
	var guard := 0
	while _offset() < RISE - 0.01 and guard < _ticks(14.0):
		_player.reset_to(stand)
		_quiet()
		await physics_frame
		guard += 1
	await _frames(_ticks(0.5))
	var opened := -1
	var landed := -1
	await _fill()
	opened = Engine.get_physics_frames()
	var stayed := true
	var stagger_ticks := 0
	while is_instance_valid(_warden) and _warden.staggered() and stagger_ticks < _ticks(10.0):
		_player.reset_to(stand)
		await physics_frame
		stagger_ticks += 1
		if landed < 0 and _offset() <= 0.01:
			landed = Engine.get_physics_frames()
		elif landed >= 0:
			stayed = stayed and _offset() <= 0.01
	var drop_s := float(landed - opened) * _tick() if landed >= 0 else INF
	_report("headframe: a stagger drops the hive to the collar within 1.0 s", drop_s <= BRAKE_LIMIT and stayed,
		"landed %.3f s after the stagger opened, stayed at the collar %s, stagger %.2f s" % [drop_s, stayed, stagger_ticks * _tick()])
	var low := 0
	while _offset() <= 0.01 and low < _ticks(10.0):
		_player.reset_to(stand)
		_quiet()
		await physics_frame
		low += 1
	_report("headframe: the cycle resumes from the low dwell when the stagger ends", absi(low - _ticks(DWELL)) <= 2,
		"rose %d frames after the stagger ended (dwell %d)" % [low, _ticks(DWELL)])


# Latch in the low dwell on a grip cell off the body, hold the key through the rise: the stop
# throws the ball upward and the hoist_ride fact fires.
func _ride(_driver) -> void:
	var script = _driver_script()
	_warden.set_mount_driver(script.new())
	var driver = _warden.mount_driver
	_warden.hardpoints = [_out * 6.0 + Vector3.UP * 3.0]
	var stand := _ground(_warden.home + _out * 6.0)
	for i in _ticks(1.0):
		_player.reset_to(stand)
		_quiet()
		await physics_frame
	_warden._pulse_clock = 0.0
	_facts.clear()
	_player.grapple_to(_warden.hardpoint_at(0), Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	var held_rise := 0
	var dropped_vy := -INF
	var drop_clock := -1.0
	var was_held := false
	for i in _ticks(DWELL + MOVE + 0.5):
		_quiet()
		await physics_frame
		var held := _held()
		if held and float(driver.clock) > DWELL and float(driver.clock) < DWELL + MOVE:
			held_rise += 1
		if was_held and not held:
			drop_clock = float(driver.clock)
			await physics_frame
			dropped_vy = _player.body().linear_velocity.y
			break
		was_held = held
	_source.hold = {}
	var rides := _facts.filter(func(f): return f["kind"] == "hoist_ride").size()
	_report("headframe: a ball latched through the rise leaves the stop with at least 12 m/s upward",
		held_rise >= _ticks(MOVE) - 3 and absf(drop_clock - (DWELL + MOVE)) <= 2.0 * _tick() and dropped_vy >= THROW_MIN,
		"held %d frames of the rise, line dropped at hoist clock %.3f (%s), upward %.2f m/s" % [held_rise, drop_clock,
			_player.kit.line_end, dropped_vy])
	_report("headframe: the hoist_ride fact fires on the ride", rides == 1, "%d hoist_ride facts" % rides)
	await _frames(_ticks(1.5))


func _held() -> bool:
	var kit = _player.kit
	return kit.hooked and kit.on_body and kit.anchor_body == _warden


# At the high dwell a swinging ball latched on the grip cell is snipped on the pulse; its
# velocity changes by the pulse lift (if the reach ring held it) and nothing else.
func _snip(driver) -> void:
	var guard := 0
	while not (_offset() > RISE - 0.01 and float(driver.clock) < 2.0 * DWELL + MOVE - 2.5) and guard < _ticks(14.0):
		_quiet()
		await physics_frame
		guard += 1
	_warden._pulse_clock = _warden.PULSE_CYCLE
	var hang: Vector3 = _warden.hardpoint_at(0) + Vector3.DOWN * 6.0
	_player.reset_to(hang, _side * 6.0)
	_player.grapple_to(_warden.hardpoint_at(0), Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	var shrugs: int = _warden.shrugs
	var v_prev := Vector3.ZERO
	var v_drop := Vector3.ZERO
	var dropped := false
	var lifted := false
	for i in _ticks(4.0):
		_quiet()
		var v: Vector3 = _player.body().linear_velocity
		await physics_frame
		if not _held():
			lifted = _warden.last_pulse_lifted
			v_prev = v
			v_drop = _player.body().linear_velocity
			dropped = true
			break
	_source.hold = {}
	var lift := LIFT if lifted else 0.0
	var rise := v_drop.y - v_prev.y
	var planar := Vector2(v_drop.x - v_prev.x, v_drop.z - v_prev.z).length()
	# One tick of gravity is the only other change.
	var gravity_tick: float = absf(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * _tick() * 4.0
	_report("headframe: the snip changes a latched ball's velocity by the pulse lift only",
		dropped and _warden.shrugs == shrugs + 1 and planar < 0.2 and absf(rise - lift) <= gravity_tick + 0.5,
		"dropped %s, shrugs %d to %d, planar change %.3f m/s, vertical %+.2f m/s (lift %.1f)" % [dropped, shrugs,
			_warden.shrugs, planar, rise, lift])


func _sinkhole() -> void:
	if not await _start(4):
		_report("stage 4 fields a Warden", false, "no Warden")
		return
	_report("stage 4 is the brood's sinkhole nest", _warden.family == "swarm" and _warden.variant == "brood"
			and _warden.mounting == "sinkhole", "family %s, variant %s, mounting %s" % [_warden.family, _warden.variant, _warden.mounting])
	var driver = _attach()
	if driver == null:
		_report("sinkhole: driver attached", false, "no driver")
		await _end()
		return
	_pick_side()
	await _lamp_guard()
	# The test pool lies beside the nest at ground level so the ball can stand on its floor.
	var centre := _ground(_warden.home + _out * 50.0)
	var floor_y: float = _game.ctx.terrain.height(centre.x, centre.z)
	driver.set_pool(Vector3(centre.x, floor_y, centre.z), floor_y, 30.0)
	await _frames(2)
	await _pool_step(driver, floor_y, centre)
	await _pool_hold(driver, floor_y, centre)
	await _end()


# The lamp guard: the cruise ram that kills the last lamp pays 25 posture once; brood_dark fires.
func _lamp_guard() -> void:
	_warden._posture.posture = 0.0
	_warden._step_guard(_warden.GUARD_RESPAWN)
	var kind: String = _warden.guard_kind()
	var alive: Array = _warden.guard.alive() if _warden.guard != null else []
	if kind != "lamp_swarm" or alive.is_empty():
		_report("sinkhole: the brood's guard is a lamp swarm", false, "guard kind %s, %d alive" % [kind, alive.size()])
		return
	var lamp: Node3D = alive[0]
	lamp.set_physics_process(false)
	await _frames(2)
	var cruise: float = _player.tuning.f("cruise")
	var force := cruise * 1.6
	var strikes := 0
	while is_instance_valid(lamp) and not lamp.is_dead() and strikes < 40:
		_combat.strike(lamp, "ram", force)
		strikes += 1
	var killed: bool = not is_instance_valid(lamp) or lamp.is_dead()
	await _frames(3)
	var paid: float = _warden.posture()
	await _frames(3)
	_report("sinkhole: the lamp guard's last kill pays 25 posture as a rack scatter does", killed
			and SpeedTier.of(force, cruise) >= SpeedTier.CRUISE and absf(paid - RACK_POSTURE) < 0.5 and absf(_warden.posture() - paid) < 0.5,
		"killed in %d cruise rams, posture %.1f then %.1f" % [strikes, paid, _warden.posture()])
	var dark := false
	for i in _ticks(1.0):
		await physics_frame
		dark = dark or _combat.discovered.has("brood_dark")
	_report("sinkhole: brood_dark still fires", dark, "discovered %s" % [_combat.discovered.keys()])
	_warden._posture.posture = 0.0
	_clear_enemies()


# Lose one chunk with the ball off the pool: the swell telegraphs for 2 s, then the floor rises 5 m over 3 s.
func _lose_chunk() -> bool:
	var chunks: int = _warden.chunks_left()
	var top: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	await _fill()
	_smashed = 0
	_player.reset_to(top + _side * 6.0 + Vector3.UP * 6.0)
	_player.grapple_to(top, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _frames(2)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for i in _ticks(1.5):
		await physics_frame
		if _smashed > 0 or _warden.chunks_left() < chunks:
			break
	_source.hold = {}
	return _warden.chunks_left() == chunks - 1


func _pool_step(driver, floor_y: float, _centre: Vector3) -> void:
	_facts.clear()
	var lost := await _lose_chunk()
	var lost_frame := Engine.get_physics_frames()
	var target: float = driver.pool_target
	var rose_at := -1
	var done_at := -1
	var start: float = driver.pool_floor
	for i in _ticks(SWELL + POOL_RISE + 2.0):
		await physics_frame
		if rose_at < 0 and float(driver.pool_floor) > start + 0.001:
			rose_at = Engine.get_physics_frames()
		if done_at < 0 and absf(float(driver.pool_floor) - (floor_y + POOL_STEP)) < 0.001:
			done_at = Engine.get_physics_frames()
	var swells := _facts.filter(func(f): return f["kind"] == "pool_swell").size()
	_report("sinkhole: a chunk lost raises the pool floor 5 m behind a 2 s swell", lost and absf(target - (floor_y + POOL_STEP)) < 0.001
			and swells == 1 and rose_at > 0 and absf(float(rose_at - lost_frame) * _tick() - SWELL) <= SLOW_TOLERANCE
			and done_at > 0 and absf(float(done_at - rose_at) * _tick() - POOL_RISE) <= SLOW_TOLERANCE,
		"lost %s, floor %.2f to target %.2f (want %.2f), %d swells, rose %.3f s after the loss, took %.3f s" % [lost, start,
			target, floor_y + POOL_STEP, swells, float(rose_at - lost_frame) * _tick(), float(done_at - rose_at) * _tick()])
	await _frames(_ticks(4.5))


# Lose a chunk and stand the ball on the pool: the floor holds under it; after 6 s the fallback
# lifts the ball straight up with planar speed kept, and the floor rises under the airborne ball.
func _pool_hold(driver, floor_y: float, centre: Vector3) -> void:
	var lost := await _lose_chunk()
	var stand := Vector3(centre.x, float(driver.pool_floor) + 1.0, centre.z)
	_player.reset_to(stand)
	var target: float = driver.pool_target
	var under := 0
	var lifts: int = driver.lifts
	var kicked := false
	var planar_before := -1.0
	var planar_after := -1.0
	var lift_frame := -1
	var last_floor: float = driver.pool_floor
	var last_planar := 0.0
	var held_peak := 0.0
	for i in _ticks(SWELL + HOLD_FALLBACK + POOL_RISE + 8.0):
		if not kicked and float(driver.held) >= HOLD_FALLBACK - 0.25:
			_player.reset_to(_player.ball_position(), _side * 6.0)
			kicked = true
		var grounded_before: bool = _player.state.grounded and _on_pool(driver)
		await physics_frame
		held_peak = maxf(held_peak, float(driver.held))
		var planar := Vector2(_player.body().linear_velocity.x, _player.body().linear_velocity.z).length()
		if float(driver.pool_floor) > last_floor + 0.0001 and grounded_before:
			under += 1
		last_floor = driver.pool_floor
		if lift_frame < 0 and int(driver.lifts) > lifts:
			lift_frame = i
			planar_before = last_planar
		elif lift_frame >= 0 and planar_after < 0.0 and i >= lift_frame + 1:
			planar_after = planar
		last_planar = planar
		if absf(float(driver.pool_floor) - target) < 0.001 and lift_frame >= 0 and planar_after >= 0.0:
			break
	var share := absf(planar_after - planar_before) / maxf(planar_before, 0.001)
	_report("sinkhole: no step rises while the ball is grounded on the pool", lost and under == 0
			and absf(float(driver.pool_floor) - target) < 0.001 and absf(target - (floor_y + 2.0 * POOL_STEP)) < 0.001,
		"lost %s, %d ticks rose under a grounded ball, floor %.2f of target %.2f (want %.2f)" % [lost, under, driver.pool_floor,
			target, floor_y + 2.0 * POOL_STEP])
	_report("sinkhole: the 6 s fallback lifts the ball with planar speed within 1 percent", lift_frame >= 0
			and held_peak >= HOLD_FALLBACK - 2.0 * _tick() and planar_before > 2.0 and share <= 0.01,
		"held %.2f s, lifted %s, planar %.3f to %.3f m/s (%.2f%%)" % [held_peak, lift_frame >= 0, planar_before, planar_after, share * 100.0])


func _on_pool(driver) -> bool:
	var ball: Vector3 = _player.ball_position()
	var centre: Vector3 = driver.pool_centre
	return Vector2(ball.x - centre.x, ball.z - centre.z).length() <= float(driver.pool_radius) \
			and ball.y - float(driver.pool_floor) <= 3.0
