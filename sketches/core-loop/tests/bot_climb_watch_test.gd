extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The Warden charge's progress watch on a fight climb in bot_driver.gd _charge_watch: a ball
# below the Warden that rocks on a ledge, gaining neither height nor 3D distance for
# CHARGE_WINDOW, enters the bounded recovery and its climb route is dropped for a replan; a ball
# gaining height on the climb never does. The climb itself is stubbed so only the watch is
# under test.

const WARDEN := Vector3(5.0, 25.0, -55.0)
const LEDGE := Vector3(15.0, 12.0, -15.0)
const STEP := 1.0 / 90.0
# One swing on the ledge; the closest point of the first swing is the last progress the watch sees.
const ROCK_PERIOD := TAU / 1.5


class FakeState:
	var grounded := true
	var air_actions := 1
	var velocity := Vector3.ZERO


class FakePlayer:
	var at := Vector3.ZERO
	var state := FakeState.new()

	func ball_position() -> Vector3:
		return at


class FakeFlow:
	var warden: Node3D = null


class FakeGame:
	var bot_driven := false
	var player := FakePlayer.new()
	var flow := FakeFlow.new()


class Probe extends BotDriver:
	var counts := {}
	var steered := Vector3.INF

	func _init(game_ref) -> void:
		super(game_ref, "completionist", 2)

	func _harpoon_hand(_target: Node3D, _delta: float) -> void:
		pass

	func _climb_route(_from: Vector3, to: Vector3) -> Array[Vector3]:
		var route: Array[Vector3] = [Vector3(to.x, to.y, to.z + 30.0), to]
		return route

	func _ground_point(x: float, z: float) -> Vector3:
		return Vector3(x, LEDGE.y, z)

	func _way_clear(_from: Vector3, _to: Vector3) -> bool:
		return true

	func _face_ahead(_from: Vector3, _dir: Vector3, _reach: float) -> float:
		return INF

	func _count(key: String, by: float = 1.0) -> void:
		counts[key] = counts.get(key, 0) + by

	func _act(steer: Vector3, _aim, _delta: float, _fight: Node3D = null, _evade := true) -> void:
		steered = steer


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_climb_watch_test")
	var warden := Node3D.new()
	root.add_child(warden)
	warden.global_position = WARDEN

	# Rocking under the ledge: z swings 15 m, height 11 to 14, never topping it.
	var game := FakeGame.new()
	game.flow.warden = warden
	var stuck := Probe.new(game)
	stuck._fight_target = warden
	var entered := -1.0
	var time := 0.0
	var climbed := false
	while time < BotDriver.CHARGE_WINDOW + ROCK_PERIOD + 1.0:
		game.player.at = LEDGE + Vector3(0.0, 1.5 * sin(time * 1.5) - 0.5, 7.5 * sin(time * 1.5))
		stuck._ram_laps(warden, null, STEP)
		climbed = climbed or stuck._goal.ends_with(" climb")
		time += STEP
		if stuck._fight_phase == "recover":
			entered = time
			break
	t.check("rocking: the climb is steering", climbed, stuck._goal.left(40))
	t.check("rocking: recovery starts once the window passes", entered >= BotDriver.CHARGE_WINDOW and entered <= BotDriver.CHARGE_WINDOW + ROCK_PERIOD, str(entered))
	t.eq("rocking: one recovery counted", stuck.counts.get("charge_recoveries", 0), 1)
	t.check("rocking: the climb route is dropped for a replan", stuck._fight_climb.is_empty() and stuck._fight_climb_clock <= 0.0, str(stuck._fight_climb.size()))
	t.check("rocking: recovery steers to its leg, not the climb", stuck.steered == stuck._recover_legs[0] if not stuck._recover_legs.is_empty() else false, str(stuck.steered))

	# Still rocking: recoveries stop at the stage cap.
	var spent := 0.0
	while spent < 120.0:
		game.player.at = LEDGE + Vector3(0.0, 1.5 * sin(spent * 1.5) - 0.5, 7.5 * sin(spent * 1.5))
		stuck._ram_laps(warden, null, STEP)
		spent += STEP
	t.eq("rocking: recoveries capped per stage", stuck.counts.get("charge_recoveries", 0), BotDriver.RECOVER_LIMIT)

	# Control: a climb that rises 1 m a second (the Warden stays above LEVEL_BAND) never recovers,
	# though its 3D distance to the Warden grows on the switchback.
	var cgame := FakeGame.new()
	cgame.flow.warden = warden
	var rising := Probe.new(cgame)
	rising._fight_target = warden
	var ctime := 0.0
	var seen_recover := false
	var start := Vector3(15.0, 0.0, 20.0)
	while ctime < 15.0:
		cgame.player.at = start + Vector3(0.0, ctime, 2.0 * ctime)
		rising._ram_laps(warden, null, STEP)
		if rising._fight_phase == "recover":
			seen_recover = true
		ctime += STEP
	t.check("control: the rising climb is watched as a climb", rising._goal.ends_with(" climb"), rising._goal.left(40))
	t.check("control: a rising climb never recovers", not seen_recover, rising._fight_phase)
	t.eq("control: no recovery counted", rising.counts.get("charge_recoveries", 0), 0)

	# Rocking across LEVEL_BAND below the Warden: the climb flips on and off about once a
	# second, faster than CHARGE_WINDOW, and the ball gets nowhere. The flips keep the clock.
	var fgame := FakeGame.new()
	fgame.flow.warden = warden
	var flipper := Probe.new(fgame)
	flipper._fight_target = warden
	var ftime := 0.0
	var flips := 0
	var was_climbing := false
	var flip_entered := -1.0
	var band_y := WARDEN.y - BotDriver.LEVEL_BAND
	while ftime < BotDriver.CHARGE_WINDOW + ROCK_PERIOD + 1.0:
		fgame.player.at = Vector3(WARDEN.x, band_y + 1.5 * sin(ftime * 3.0), WARDEN.z + 40.0)
		flipper._ram_laps(warden, null, STEP)
		var now_climbing := flipper._climbing(fgame.player.at, WARDEN)
		if now_climbing != was_climbing:
			flips += 1
			was_climbing = now_climbing
		ftime += STEP
		if flipper._fight_phase == "recover":
			flip_entered = ftime
			break
	t.check("flip-flop: the climb flips faster than the window", flips >= 3, str(flips))
	t.check("flip-flop: recovery starts once the window passes", flip_entered >= BotDriver.CHARGE_WINDOW and flip_entered <= BotDriver.CHARGE_WINDOW + 0.5, str(flip_entered))
	t.eq("flip-flop: one recovery counted", flipper.counts.get("charge_recoveries", 0), 1)

	# Pinned inside RUNUP on the Warden's level (a box collider between): the charge jiggles in
	# place 15 m out and never closes. It is watched like a charge beyond RUNUP.
	var pgame := FakeGame.new()
	pgame.flow.warden = warden
	var pinned := Probe.new(pgame)
	pinned._fight_target = warden
	var ptime := 0.0
	var pin_entered := -1.0
	while ptime < BotDriver.CHARGE_WINDOW + 1.0:
		pgame.player.at = Vector3(WARDEN.x + 0.5 * sin(ptime * 3.0), WARDEN.y, WARDEN.z + 15.0 + 0.5 * cos(ptime * 3.0))
		pinned._ram_laps(warden, null, STEP)
		ptime += STEP
		if pinned._fight_phase == "recover":
			pin_entered = ptime
			break
	t.check("inside runup: the charge is not a climb", not pinned._goal.ends_with(" climb"), pinned._goal.left(40))
	t.check("inside runup: recovery starts once the window passes", pin_entered >= BotDriver.CHARGE_WINDOW and pin_entered <= BotDriver.CHARGE_WINDOW + 0.1, str(pin_entered))

	# Control: a runup's end starts the watch afresh, so a charge back in from the runup point
	# at 8 m/s closes and never recovers.
	var rgame := FakeGame.new()
	rgame.flow.warden = warden
	var lapper := Probe.new(rgame)
	lapper._fight_target = warden
	var rtime := 0.0
	var lap_recover := false
	var lap_phases := {}
	var out_at := Vector3(WARDEN.x, WARDEN.y, WARDEN.z + 3.0)
	while rtime < 30.0:
		var leg := fmod(rtime, 6.0)
		var off := 3.0 + (leg * 7.0 if leg < 3.0 else (6.0 - leg) * 7.0)
		rgame.player.at = Vector3(WARDEN.x, WARDEN.y, WARDEN.z + off)
		lapper._ram_laps(warden, null, STEP)
		lap_phases[lapper._fight_phase] = true
		if lapper._fight_phase == "recover":
			lap_recover = true
		rtime += STEP
	t.check("control: ram laps run both phases", lap_phases.has("runup") and lap_phases.has("charge"), str(lap_phases.keys()))
	t.check("control: ram laps never recover", not lap_recover, lapper._fight_phase)

	warden.free()
	quit(t.verdict())
	return false
