extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The Warden charge's progress watch in bot_driver.gd _ram_laps: a ball that keeps moving but
# gains no ground on the Warden for CHARGE_WINDOW enters a bounded recovery (retreat, side-step,
# then charge again, or back off and over a wall ahead), at most RECOVER_LIMIT times per stage;
# a ball closing on it never does. The player, the harpoon hand, the climb, the ground, the wall
# probes and the stick are stubbed so only the watch and the escape are under test.

const WARDEN := Vector3(20.0, 1.6, 90.0)
const POCKET := Vector3(-99.0, 13.0, -93.0)
const STEP := 1.0 / 90.0


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


# Walls are two planes across the bearing from POCKET to the Warden: one wall_ahead metres
# toward it, one wall_behind metres away from it. INF means open ground.
class Probe extends BotDriver:
	var counts := {}
	var steered := Vector3.INF
	var climb_seen := false
	var wall_ahead := INF
	var wall_behind := INF
	var bearing := Vector3.ZERO

	func _init(game_ref) -> void:
		super(game_ref, "completionist", 2)

	func _harpoon_hand(_target: Node3D, _delta: float) -> void:
		pass

	func _climbing(_ball: Vector3, _at: Vector3) -> bool:
		return false

	func _ground_point(x: float, z: float) -> Vector3:
		return Vector3(x, POCKET.y, z)

	func _way_clear(_from: Vector3, _to: Vector3) -> bool:
		return true

	func _face_ahead(from: Vector3, dir: Vector3, reach: float) -> float:
		var s := Vector3(from.x - POCKET.x, 0.0, from.z - POCKET.z).dot(bearing)
		var d := INF
		if dir.dot(bearing) > 0.9:
			d = wall_ahead - s
		elif dir.dot(bearing) < -0.9:
			d = wall_behind + s
		return d if d > 0.0 and d <= reach else INF

	func _count(key: String, by: float = 1.0) -> void:
		counts[key] = counts.get(key, 0) + by

	func _act(steer: Vector3, _aim, _delta: float, _fight: Node3D = null, _evade := true) -> void:
		steered = steer
		climb_seen = climb_seen or _recover_climb


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
	var bearing := Vector3(WARDEN.x - POCKET.x, 0.0, WARDEN.z - POCKET.z).normalized()
	var game := FakeGame.new()
	game.flow.warden = warden
	var stuck := Probe.new(game)
	stuck.bearing = bearing
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
	t.check("stuck: the charge resumes after the legs", entered > 0.0 and stuck._fight_phase == "charge", stuck._fight_phase)
	t.check("stuck: each leg is held to its cap", legs >= 2.0 * BotDriver.RECOVER_LEG_SECONDS - 0.1 and legs <= 2.0 * BotDriver.RECOVER_LEG_SECONDS + 0.1, str(legs))
	t.check("open ground: no wall climb", not stuck._recover_wall and not stuck.climb_seen, str(stuck._recover_wall))

	# Still stuck: recoveries stop at the cap so the stage watchdog ends a hopeless run.
	var spent := 0.0
	while spent < 120.0:
		stuck._ram_laps(warden, null, STEP)
		spent += STEP
	t.eq("stuck: recoveries capped per target", stuck.counts.get("charge_recoveries", 0), BotDriver.RECOVER_LIMIT)

	# A new target (_fight) resets the watch but not the stage's cap: no fourth recovery.
	stuck._reset_charge_watch()
	t.eq("reset: no legs held", stuck._recover_legs.size(), 0)
	t.eq("reset: the cap survives a target swap", stuck._recoveries, BotDriver.RECOVER_LIMIT)
	spent = 0.0
	while spent < 3.0 * BotDriver.CHARGE_WINDOW:
		stuck._ram_laps(warden, null, STEP)
		spent += STEP
	t.eq("reset: still no recovery past the cap", stuck.counts.get("charge_recoveries", 0), BotDriver.RECOVER_LIMIT)

	# A pit: a wall 4 m ahead toward the Warden, 9 m of floor behind. The recovery backs off to
	# RECOVER_JUMP_AT short of the far wall, then rolls over the near one with walls not dodged.
	var pgame := FakeGame.new()
	pgame.flow.warden = warden
	var pit := Probe.new(pgame)
	pit.bearing = bearing
	pit.wall_ahead = 4.0
	pit.wall_behind = 9.0
	pit._fight_target = warden
	pgame.player.at = POCKET
	var ptime := 0.0
	while pit._fight_phase != "recover" and ptime < BotDriver.CHARGE_WINDOW + 1.0:
		pgame.player.at = POCKET + bearing.rotated(Vector3.UP, PI * 0.5) * sin(ptime * 4.0) * 1.5
		pit._ram_laps(warden, null, STEP)
		ptime += STEP
	t.check("pit: a wall ahead picks the climb", pit._fight_phase == "recover" and pit._recover_wall, pit._fight_phase)
	var back_by := -Vector3(pit._recover_legs[0].x - pgame.player.at.x, 0.0, pit._recover_legs[0].z - pgame.player.at.z).dot(bearing) if pit._recover_legs.size() == 2 else 0.0
	t.check("pit: backs off to the room behind", absf(back_by - (9.0 - BotDriver.RECOVER_JUMP_AT)) < 0.6, str(back_by))
	var over_by := Vector3(pit._recover_legs[1].x - POCKET.x, 0.0, pit._recover_legs[1].z - POCKET.z).dot(bearing) if pit._recover_legs.size() == 2 else 0.0
	t.check("pit: the climb leg ends past the wall", over_by > 4.0 + BotDriver.RECOVER_OVER - 0.6, str(over_by))
	# Reach the back point, then roll at the wall.
	pgame.player.at = pit._recover_legs[0]
	pit.source.press.clear()
	pit._ram_laps(warden, null, STEP)
	t.check("pit: the climb leg does not dodge walls", pit.climb_seen, str(pit._recover_legs.size()))
	pgame.player.at = POCKET + bearing * 2.0
	pit.source.press.clear()
	pit._ram_laps(warden, null, STEP)
	t.eq("pit: jumps within RECOVER_JUMP_AT of the wall", pit.source.press.get("jump_pressed", false), true)
	pgame.player.state.grounded = false
	pgame.player.state.velocity = Vector3(0.0, 0.5, 0.0)
	pit.source.press.clear()
	pit._ram_laps(warden, null, STEP)
	t.eq("pit: the air jump at the top of the first", pit.source.press.get("jump_pressed", false), true)
	pgame.player.state.velocity = Vector3(0.0, 6.0, 0.0)
	pit.source.press.clear()
	pit._ram_laps(warden, null, STEP)
	t.eq("pit: no air jump while still rising", pit.source.press.get("jump_pressed", false), false)

	# Control: closing on the Warden at 8 m/s never recovers.
	var cgame := FakeGame.new()
	cgame.flow.warden = warden
	var closing := Probe.new(cgame)
	closing.bearing = bearing
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
	boss.bearing = bearing
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
