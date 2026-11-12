extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const T := preload("res://tests/support/t.gd")

# The per-kind hook (warden.gd header, "The per-kind hook"; KF1, widened for KF2 to KF4 on
# 28fe659). A recording driver rides a park-style Warden (spec "harpoon_anchor": true and a
# "mount_driver") in a stepped headless fight on the alpha table's stage 1, through real
# physics: step runs every physics tick; charge_allowed false lets the pulse clock run and
# starts no charge until it answers true; on_charge and on_pulse fire once per cycle, the
# pulse reporting lifted while the ball sits in the reach ring; on_stagger fires open, then
# closed; on_chunk_lost fires with the chunks left when the drop finisher (a haul onto the
# staggered Warden) shatters one. A driver with mount_offset alone still fights, and a
# Warden that is no harpoon anchor loads no kind driver file.

# Where the test's Wardens stand from the stage's own Warden, so their rings never overlap.
const AWAY := Vector3(70.0, 0.0, 70.0)
const BALL_OUT := Vector3(10.0, 1.2, 0.0)
const PIER_UP := Vector3(0.0, 12.0, 0.0)
const PIER_OUT := 20.0


class Recorder:
	var allow := true
	var steps := 0
	var charges: Array = []
	var pulses: Array = []
	var staggers: Array = []
	var chunks: Array = []

	func mount_offset(_warden, _clock: float) -> Vector3:
		return Vector3.ZERO

	func step(_warden, _delta: float) -> void:
		steps += 1

	func charge_allowed(_warden) -> bool:
		return allow

	func on_charge(_warden, seconds: float) -> void:
		charges.append([Engine.get_physics_frames(), seconds])

	func on_pulse(_warden, lifted: bool) -> void:
		pulses.append([Engine.get_physics_frames(), lifted])

	func on_stagger(_warden, open: bool) -> void:
		staggers.append(open)

	func on_chunk_lost(_warden, left: int) -> void:
		chunks.append(left)


# The least a driver may answer.
class Bare:
	func mount_offset(_warden, _clock: float) -> Vector3:
		return Vector3.ZERO


var _t := T.new("warden_hook_test")
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _smashed := 0


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _run() -> void:
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
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(_seconds(0.4))
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _game.flow.warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	await _frames(2)
	await _recorded()
	await _bare()
	await _no_anchor()
	_t.check("the hook test ran its checks", _t.checks >= 11, "%d checks" % _t.checks)
	_game.free()
	quit(_t.verdict())


func _spawn(extra: Dictionary, offset: Vector3) -> Node3D:
	var base: Vector3 = _game.flow.warden.global_position if is_instance_valid(_game.flow.warden) else Vector3.ZERO
	var warden = WardenScript.new()
	_game.ctx.root.add_child(warden)
	warden.global_position = base + offset
	var spec := {"family": "reactor", "stage": 1, "plating": 90.0, "hp": 650.0, "reach": 30.0}
	spec = _combat.fleet.dress("warden", spec)
	spec.merge(extra, true)
	warden.setup(_player, _game.ctx.terrain, _game.ctx.root, Callable(_game.flow, "in_play"), 1.0, spec)
	warden.hit_player.connect(_combat._on_player_hit.bind("warden"))
	return warden


func _ball_spot(warden: Node3D) -> Vector3:
	var at: Vector3 = warden.global_position + BALL_OUT
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.2)


func _sit_ball(warden: Node3D) -> void:
	_player.reset_to(_ball_spot(warden))


# The stage's ground slopes, so a resting ball can roll out of reach: put it back once it strays.
func _hold_ball(warden: Node3D) -> void:
	var ball: Vector3 = _player.ball_position()
	var spot := _ball_spot(warden)
	if Vector2(ball.x - spot.x, ball.z - spot.z).length() > 3.0:
		_sit_ball(warden)


func _matched_force(warden: Node3D) -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < float(warden.plating):
		force += 0.05
	return force


func _stagger(warden: Node3D) -> bool:
	var guard := 0
	while is_instance_valid(warden) and not warden.staggered() and guard < 30:
		_combat.strike(warden, "ram", _matched_force(warden))
		await physics_frame
		guard += 1
	return is_instance_valid(warden) and warden.staggered()


func _recorded() -> void:
	var rec := Recorder.new()
	var warden := _spawn({"harpoon_anchor": true, "mount_driver": rec}, AWAY)
	_t.check("a park Warden keeps the spec's driver", warden.mount_driver == rec, "driver %s" % warden.mount_driver)
	_sit_ball(warden)
	await _frames(2)
	# step, every physics tick.
	var before := rec.steps
	await _frames(90)
	_t.eq("step runs every physics tick (90 frames)", rec.steps - before, 90)
	# charge_allowed false: the pulse clock runs, no charge starts.
	rec.allow = false
	warden._pulse_clock = 0.0
	rec.charges.clear()
	for i in _seconds(warden.pulse_cycle(warden.stage) - warden.PULSE_TELEGRAPH + 1.0):
		_hold_ball(warden)
		await physics_frame
	_t.check("charge_allowed false starts no charge while the clock runs", rec.charges.is_empty() and not warden._charging
			and warden._pulse_clock >= warden.pulse_cycle(warden.stage) - warden.PULSE_TELEGRAPH,
		"charges %d, charging %s, pulse clock %.2f s" % [rec.charges.size(), warden._charging, warden._pulse_clock])
	var gated_at: int = Engine.get_physics_frames()
	rec.allow = true
	await _frames(2)
	_t.check("the charge starts on the first tick charge_allowed answers true", rec.charges.size() == 1
			and int(rec.charges[0][0]) - gated_at <= 1 and is_equal_approx(float(rec.charges[0][1]), warden.PULSE_TELEGRAPH),
		"charges %s, released at frame %d" % [rec.charges, gated_at])
	# Two full cycles: one charge and one pulse each, lifted while the ball is in the reach ring.
	rec.charges.clear()
	rec.pulses.clear()
	# From the charge's start: a pulse 2 s in and one a stage cycle later (world 1 runs its Wardens 0.85 fast).
	for i in _seconds(2.0 * warden.pulse_cycle(warden.stage) + 0.5):
		_hold_ball(warden)
		await physics_frame
	var lifted := rec.pulses.all(func(p): return p[1] == true)
	_t.check("on_pulse fires once per pulse, lifted in the reach ring", rec.pulses.size() == 2 and lifted,
		"pulses %s, ball %s from the Warden" % [rec.pulses, _player.ball_position() - warden.global_position])
	_t.check("on_charge fires once per cycle", rec.charges.size() == 2, "charges %s" % [rec.charges])
	# The stagger opens, then closes.
	rec.staggers.clear()
	var opened := await _stagger(warden)
	await _frames(1)
	var open_seen := rec.staggers.duplicate()
	await _frames(_seconds(warden.stagger_left() + 0.3))
	_t.check("on_stagger fires open then closed", opened and open_seen == [true] and rec.staggers == [true, false],
		"staggered %s, at the open %s, after %s" % [opened, open_seen, rec.staggers])
	# The drop finisher: a haul onto the staggered Warden shatters a chunk.
	rec.chunks.clear()
	var chunks_before: int = warden.chunks_left()
	var dropped := await _drop(warden)
	_t.check("on_chunk_lost fires with the chunks left on the drop finisher", dropped and rec.chunks == [chunks_before - 1]
			and warden.chunks_left() == chunks_before - 1,
		"smashes %d, chunks %d to %d, hook %s" % [_smashed, chunks_before, warden.chunks_left(), rec.chunks])
	_source.hold = {}
	warden.queue_free()
	await _frames(2)


func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


# warden_anchor_test's finisher: latch above the open core from a pier-hung hardpoint, hold,
# then Ctrl hauls; the smash removes a chunk.
func _drop(warden: Node3D) -> bool:
	if not await _stagger(warden):
		return false
	var out := Vector3.LEFT
	var side := Vector3.FORWARD
	warden.hardpoints = [out * PIER_OUT + PIER_UP, side * PIER_OUT + PIER_UP, -side * PIER_OUT + PIER_UP]
	var top: Vector3 = warden.global_position + Vector3.UP * warden.HALF_HEIGHT
	var from := top + out * 6.0 + Vector3.UP * 8.0
	_source.hold = {}
	_game.camera.snap(warden.global_position - from)
	for i in _seconds(0.4):
		_player.reset_to(from)
		_aim_at(warden.global_position)
		await physics_frame
	_player.reset_to(from)
	_aim_at(warden.global_position)
	_source.hold = {"harpoon_held": true}
	_source.press = {"harpoon_pressed": true}
	await _frames(_seconds(0.5))
	_smashed = 0
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for i in _seconds(1.5):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	await _frames(2)
	return _smashed == 1


# A driver that answers mount_offset alone: the Warden charges, pulses, staggers and closes.
func _bare() -> void:
	var warden := _spawn({"harpoon_anchor": true, "mount_driver": Bare.new()}, AWAY)
	_sit_ball(warden)
	warden._pulse_clock = warden.pulse_cycle(warden.stage) - warden.PULSE_TELEGRAPH
	await _frames(_seconds(warden.PULSE_TELEGRAPH + 0.2))
	var pulsed: int = warden.pulses
	var opened := await _stagger(warden)
	await _frames(_seconds(warden.stagger_left() + 0.3))
	_t.check("a driver without the optional methods still fights", warden.mount_driver is Bare and pulsed == 1 and opened
			and not warden.staggered(),
		"driver %s, pulses %d, staggered then %s, now %s" % [warden.mount_driver, pulsed, opened, warden.staggered()])
	warden.queue_free()
	await _frames(2)


# No harpoon_anchor flag, no kind file: the authored arenas' Wardens keep no driver. With the
# flag and no mount_driver, the reactor Warden loads warden_reactor.gd when it exists.
func _no_anchor() -> void:
	var plain := _spawn({}, AWAY)
	var anchored := _spawn({"harpoon_anchor": true}, AWAY + Vector3(40.0, 0.0, 0.0))
	await _frames(2)
	_t.check("a Warden without harpoon_anchor loads no driver file", plain.mount_driver == null,
		"driver %s" % plain.mount_driver)
	var kind_file := ResourceLoader.exists("res://src/combat/warden_reactor.gd")
	var path := ""
	if anchored.mount_driver != null and anchored.mount_driver.get_script() != null:
		path = anchored.mount_driver.get_script().resource_path
	_t.check("a park reactor Warden loads its kind file exactly when it exists",
		(path == "res://src/combat/warden_reactor.gd") == kind_file and (kind_file or anchored.mount_driver == null),
		"file exists %s, driver script '%s'" % [kind_file, path])
	plain.queue_free()
	anchored.queue_free()
	await _frames(2)
