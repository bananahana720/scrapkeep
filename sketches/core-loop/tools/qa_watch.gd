extends RefCounted

# bot_run --qa-log=1 (gameplay QA, 30 Oct): watches the ball each tick and writes qa-<seed>.ndjson,
# one row per place it went wrong, with the stage, the stage second, where, the flow state and the
# bot's goal. Reads only, so the seed replays exactly with or without it.
#   stuck   within STUCK_M of one point for STUCK_S of play (not a boss, not frozen, not on a line)
#   hung    at rest off the ground for HUNG_S (an ungrounded rest, ruling aa)
#   wedged  at rest on the ground pressed into a wall-steep contact for HUNG_S
#   fell    the fall rescue: the ball moved over TELEPORT_M in one tick from under the floor or off
#           the map (a blink or a boss's carry is not a fall)
#   objective  the HUD's objective plate changed (its id and words, with the gate's lock state)
# Each kind re-arms once the ball has left REARM_M of where it fired.

const STUCK_M := 3.0
const STUCK_S := 8.0
const HUNG_S := 1.0
const REST_SPEED := 0.5
const TELEPORT_M := 8.0
const REARM_M := 10.0
const DETAIL_M := 15.0

var _game
var _driver
var _file: FileAccess
var _stage := -1
var _last := Vector3.INF
var _anchor := Vector3.INF
var _anchor_s := 0.0
var _hung := 0.0
var _wedged := 0.0
var _fired := {}
var _objective := ""
var _blinked := -1
var counts := {}


func setup(game, driver, path: String) -> void:
	_game = game
	_driver = driver
	_file = FileAccess.open(path, FileAccess.WRITE)
	game.events.blink_used.connect(func(_from, _to): _blinked = driver.ticks)


# What a stuck or hung row needs for reading: the ball's motion and contact, and in a boss fight
# the pickups still on the ground within DETAIL_M.
func _detail(ball: Vector3) -> Dictionary:
	var player = _game.player
	var out := {"v": _v(player.state.velocity), "grounded": player.state.grounded, "n": _v(player.state.contact_normal)}
	var boss = _driver._boss() if _game.flow.state_name() == "boss" and _driver.has_method("_boss") else null
	if boss != null and boss.has_method("pickups_left"):
		var near := []
		for p in boss.pickups_left():
			if ball.distance_to(p["at"]) < DETAIL_M:
				near.append({"at": _v(p["at"]), "source": p["source"], "d": snappedf(ball.distance_to(p["at"]), 0.1)})
		out["pickups"] = near
	return out


func step(delta: float) -> void:
	if _game == null or _game.player == null or _game.flow == null or _game.run == null:
		return
	var player = _game.player
	var ball: Vector3 = player.ball_position()
	var stage: int = _game.run.stage
	if stage != _stage:
		_stage = stage
		_last = ball
		_anchor = ball
		_anchor_s = 0.0
		_fired.clear()
		_objective = ""
		return
	var state: String = _game.flow.state_name()
	if ball.distance_to(_last) > TELEPORT_M:
		var terrain = _game.ctx.terrain
		# A blink and a boss's scripted carry move the ball on purpose; only the fall rescue's
		# move (from under the floor or off the map) counts.
		if _blinked != _driver.ticks and (not terrain.contains(_last) or _last.y < terrain.floor_height(_last.x, _last.z) - 2.0):
			_emit("fell", _last, state, {"to": _v(ball)})
	_last = ball
	var playing: bool = _game.flow.in_play() and not player.frozen() and not player.kit.hooked
	if not playing:
		_anchor = ball
		_anchor_s = 0.0
		_hung = 0.0
		_wedged = 0.0
		return
	if ball.distance_to(_anchor) > STUCK_M:
		_anchor = ball
		_anchor_s = 0.0
	else:
		_anchor_s += delta
		if _anchor_s >= STUCK_S:
			_emit("stuck", ball, state, _detail(ball))
	var resting: bool = player.state.velocity.length() < REST_SPEED
	_hung = _hung + delta if resting and not player.state.grounded else 0.0
	if _hung >= HUNG_S:
		_emit("hung", ball, state, _detail(ball))
	_wedged = _wedged + delta if resting and player.state.grounded and player.state.contact_normal.y < 0.45 else 0.0
	if _wedged >= HUNG_S:
		_emit("wedged", ball, state, {"n": _v(player.state.contact_normal)})


# The HUD's objective plate, read once a second by the runner: a row each time its id changes,
# with the gate's lock state beside it, so a wrong plate during a lock reads off the log.
func read_text() -> void:
	if _game == null or _game.hud == null or _game.flow == null or not _game.flow.in_play():
		return
	var reading: Dictionary = _game.hud.objective_reading()
	var id := String(reading.get("id", ""))
	if id == _objective:
		return
	_objective = id
	var gate = _game.flow.gate
	_row("objective", _game.player.ball_position(), _game.flow.state_name(), {"id": id, "words": String(reading.get("words", "")),
		"yard_locked": gate != null and gate.lock_active(), "clamp_shut": gate != null and gate.locked(), "sealed": _game.flow.sealed})


func _emit(kind: String, at: Vector3, state: String, extra: Dictionary) -> void:
	var was = _fired.get(kind)
	if was is Vector3 and at.distance_to(was) < REARM_M:
		return
	_fired[kind] = at
	counts[kind] = int(counts.get(kind, 0)) + 1
	_row(kind, at, state, extra)


func _row(kind: String, at: Vector3, state: String, extra: Dictionary) -> void:
	var row := {"kind": kind, "stage": _stage, "s": snappedf(_game.run.stage_time, 0.1), "at": _v(at),
		"flow": state, "goal": String(_driver.get("_goal")) if _driver != null else ""}
	row.merge(extra)
	_file.store_line(JSON.stringify(row))
	_file.flush()


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]
