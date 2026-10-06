extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The Warden charge's progress watch in bot_driver.gd _ram_laps: a ball that keeps moving but
# gains no ground on the Warden for CHARGE_WINDOW enters a bounded recovery (retreat, side-step,
# then charge again), at most RECOVER_LIMIT times per target; a ball closing on it never does.
# The player, the harpoon hand, the climb and the stick are stubbed so only the watch is under test.

const WARDEN := Vector3(20.0, 1.6, 90.0)
const POCKET := Vector3(-99.0, 13.0, -93.0)
const STEP := 1.0 / 90.0


class FakePlayer:
	var at := Vector3.ZERO

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

	func _climbing(_ball: Vector3, _at: Vector3) -> bool:
		return false

	func _charge_escape(ball: Vector3, at: Vector3) -> Array[Vector3]:
		var toward := Vector3(at.x - ball.x, 0.0, at.z - ball.z).normalized()
		var back := ball - toward * RECOVER_BACK
		var out: Array[Vector3] = [back, back + toward.rotated(Vector3.UP, PI * 0.5) * RECOVER_SIDE]
		return out

	func _count(key: String, by: float = 1.0) -> void:
		counts[key] = counts.get(key, 0) + by

	func _act(steer: Vector3, _aim, _delta: float, _fight: Node3D = null, _evade := true) -> void:
		steered = steer


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_charge_recover_test")
	var warden := Node3D.new()
	root.add_child(warden)
	warden.global_position = WARDEN

	# Oscillating in the pocket at 6 m/s (above STUCK_SPEED): no ground gained on the Warden.
	var game := FakeGame.new()
	game.flow.warden = warden
	var stuck := Probe.new(game)
	stuck._fight_target = warden
	var entered := -1.0
	var time := 0.0
	while time < BotDriver.CHARGE_WINDOW + 1.0:
		game.player.at = POCKET + Vector3(cos(time * 4.0), 0.0, sin(time * 4.0)) * 1.5
		stuck._ram_laps(warden, null, STEP)
		time += STEP
		if stuck._fight_phase == "recover":
			entered = time
			break
	t.check("stuck: recovery starts once the window passes", entered >= BotDriver.CHARGE_WINDOW and entered <= BotDriver.CHARGE_WINDOW + 0.1, str(entered))
	t.eq("stuck: one recovery counted", stuck.counts.get("charge_recoveries", 0), 1)
	t.check("stuck: recovery steers away from the Warden", stuck.steered != WARDEN and _flat(stuck.steered, WARDEN) > _flat(POCKET, WARDEN), str(stuck.steered))
	t.eq("stuck: recovery presses jump", stuck.source.press.get("jump_pressed", false), true)

	# The legs time out while the ball stays put, and the charge resumes.
	var legs := 0.0
	while stuck._fight_phase == "recover" and legs < 2.0 * BotDriver.RECOVER_LEG_SECONDS + 1.0:
		stuck._ram_laps(warden, null, STEP)
		legs += STEP
	t.eq("stuck: the charge resumes after the legs", stuck._fight_phase, "charge")
	t.check("stuck: the legs are bounded", legs <= 2.0 * BotDriver.RECOVER_LEG_SECONDS + 0.1, str(legs))

	# Still stuck: recoveries stop at the cap so the stage watchdog ends a hopeless run.
	var spent := 0.0
	while spent < 120.0:
		stuck._ram_laps(warden, null, STEP)
		spent += STEP
	t.eq("stuck: recoveries capped per target", stuck.counts.get("charge_recoveries", 0), BotDriver.RECOVER_LIMIT)

	# The per-target reset (_fight on a new target, _on_stage_entered) clears the watch.
	stuck._reset_charge_watch()
	t.eq("reset: recoveries cleared", stuck._recoveries, 0)
	t.eq("reset: no legs held", stuck._recover_legs.size(), 0)

	# Control: closing on the Warden at 8 m/s never recovers.
	var cgame := FakeGame.new()
	cgame.flow.warden = warden
	var closing := Probe.new(cgame)
	closing._fight_target = warden
	var start := Vector3(-60.0, 1.6, -60.0)
	var dir := (WARDEN - start).normalized()
	var ctime := 0.0
	var seen_recover := false
	while ctime < 20.0:
		cgame.player.at = start + dir * 8.0 * ctime
		closing._ram_laps(warden, null, STEP)
		if closing._fight_phase == "recover":
			seen_recover = true
		ctime += STEP
	t.check("control: a closing charge never recovers", not seen_recover, closing._fight_phase)
	t.eq("control: no recovery counted", closing.counts.get("charge_recoveries", 0), 0)

	# Control: a non-Warden target (a boss hull) is never watched.
	var hull := Node3D.new()
	root.add_child(hull)
	hull.global_position = WARDEN
	var hgame := FakeGame.new()
	hgame.flow.warden = warden
	var boss := Probe.new(hgame)
	boss._fight_target = hull
	var htime := 0.0
	while htime < 20.0:
		hgame.player.at = POCKET + Vector3(cos(htime * 4.0), 0.0, sin(htime * 4.0)) * 1.5
		boss._ram_laps(hull, null, STEP)
		htime += STEP
	t.eq("control: a non-Warden target never recovers", boss.counts.get("charge_recoveries", 0), 0)

	warden.free()
	hull.free()
	quit(t.verdict())
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
