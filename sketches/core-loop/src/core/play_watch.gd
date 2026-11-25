extends RefCounted


const STUCK_M := 3.0
const STUCK_S := 8.0
const HUNG_S := 1.0
const REST_SPEED := 0.5
const TELEPORT_M := 8.0
const REARM_M := 10.0
const BLANK_S := 3.0
const BAR_S := 3.0
const BAR_OFF := 0.05

var counts := {}
var plates := 0
var blank_max := 0.0
var bar_off_max := 0.0

var _game
var _sink: Callable
var _ticks := 0
var _stage := -1
var _last := Vector3.INF
var _anchor := Vector3.INF
var _anchor_s := 0.0
var _hung := 0.0
var _wedged := 0.0
var _fired := {}
var _objective := ""
var _blank := 0.0
var _blank_told := false
var _bar_off := 0.0
var _bar_seen := false
var _bar_told := false
var _blinked := -10
var _was_in_play := false


func watch(game, sink: Callable) -> void:
	_game = game
	_sink = sink
	game.events.blink_used.connect(_on_blink)


func _on_blink(_from: Vector3, _to: Vector3) -> void:
	_blinked = _ticks


func _detail(_ball: Vector3) -> Dictionary:
	var player = _game.player
	return {"v": _v(player.state.velocity), "grounded": player.state.grounded, "n": _v(player.state.contact_normal)}


func _who() -> Dictionary:
	return {}


func step(delta: float) -> void:
	if _game == null or _game.player == null or _game.flow == null or _game.run == null:
		return
	_ticks += 1
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
	var in_play: bool = _game.flow.in_play()
	if in_play and _was_in_play and ball.distance_to(_last) > TELEPORT_M:
		var terrain = _game.ctx.terrain
		if _ticks - _blinked > 2 and (not terrain.contains(_last) or _last.y < terrain.floor_height(_last.x, _last.z) - 2.0):
			_emit("fell", _last, state, {"to": _v(ball)})
	_last = ball
	_was_in_play = in_play
	var playing: bool = in_play and not player.frozen() and not player.kit.hooked and not player.kit.mounted
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


func read_text(since := 1.0) -> void:
	if _game == null or _game.hud == null or _game.flow == null or not _game.flow.in_play():
		_blank = 0.0
		_blank_told = false
		_bar_off = 0.0
		_bar_seen = false
		_bar_told = false
		return
	var reading: Dictionary = _game.hud.objective_reading()
	var state: String = _game.flow.state_name()
	var hull: float = clampf(_game.run.hp / maxf(1.0, _game.run.max_hp), 0.0, 1.0)
	var shown: float = _game.hud.hull_shown()
	if absf(shown - hull) > BAR_OFF:
		_bar_off = _bar_off + since if _bar_seen else 0.0
		_bar_seen = true
		bar_off_max = maxf(bar_off_max, _bar_off)
		if _bar_off >= BAR_S and not _bar_told:
			_bar_told = true
			counts["bar"] = int(counts.get("bar", 0)) + 1
			_row("bar", _game.player.ball_position(), state, {"shown": snappedf(shown, 0.01), "hull": snappedf(hull, 0.01)})
	else:
		_bar_off = 0.0
		_bar_seen = false
		_bar_told = false
	if String(reading.get("words", "")).strip_edges() == "" and state != "lap":
		_blank += since
		blank_max = maxf(blank_max, _blank)
		if _blank >= BLANK_S and not _blank_told:
			_blank_told = true
			counts["blank"] = int(counts.get("blank", 0)) + 1
			_row("blank", _game.player.ball_position(), state, {"id": String(reading.get("id", ""))})
	else:
		_blank = 0.0
		_blank_told = false
	var id := String(reading.get("id", ""))
	if id == _objective:
		return
	_objective = id
	plates += 1
	var gate = _game.flow.gate
	_row("objective", _game.player.ball_position(), state, {"id": id, "words": String(reading.get("words", "")),
		"yard_locked": gate != null and gate.lock_active(), "clamp_shut": gate != null and gate.locked(), "sealed": _game.flow.sealed})


func _emit(kind: String, at: Vector3, state: String, extra: Dictionary) -> void:
	var was = _fired.get(kind)
	if was is Vector3 and at.distance_to(was) < REARM_M:
		return
	_fired[kind] = at
	counts[kind] = int(counts.get(kind, 0)) + 1
	_row(kind, at, state, extra)


func _row(kind: String, at: Vector3, state: String, extra: Dictionary) -> void:
	var row := {"kind": kind, "stage": _stage, "s": snappedf(_game.run.stage_time, 0.1), "at": _v(at), "flow": state}
	row.merge(_who())
	row.merge(extra)
	_sink.call(row)


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]
