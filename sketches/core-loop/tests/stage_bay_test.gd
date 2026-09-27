extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BayLap := preload("res://src/world/bay_lap.gd")
const Bay := preload("res://src/world/bay.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# Moss's bay through the real flow (DESIGN-V2 sections 12 and 15). The Warden's break
# opens the gates and the workshop barge docks behind them. Rolling into the cradle
# banks the ball's speed and throws it aboard; aboard, the difficulty clock and the
# events hold still, abilities cost nothing inside the practice yard's lines and only
# there, and the toys answer. The pad throws the ball back down in front of a gate with
# its banked speed along the gates' facing, the gates never moved while it was away,
# and it rolls through one into the launch.
#
# Evidence limit: calm and headless; the lounge, Moss's voice and the shop UI are other
# units'. The shop seam is exercised only through its absence on this branch (build has
# no shop yet), so enter() and leave() are covered by code review, not by this test.

const APPROACH := 14.0
const SPEED := 22.0
const TOLERANCE := 0.15
const SIM_SCALE := 2.0

var _game
var _failures := 0
var _phase := "boot"
var _clock := 0.0
var _events := []
var _offers_seen := 0
var _entered_speed := -1.0
var _clock_at_entry := -1.0
var _event_clock_at_entry := -1.0
var _before := 0.0
var _left_velocity := Vector3.ZERO
var _chosen := ""


func _initialize() -> void:
	_check_lap()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# The lap: round the stadium's centreline at 18 m/s touches all four marks and comes
# home under par; a run that turns back before the far mark never finishes.
func _check_lap() -> void:
	var lap := BayLap.new([Vector2(0.0, -13.0), Vector2(23.0, 0.0), Vector2(0.0, 13.0), Vector2(-23.0, 0.0)])
	var path := _stadium(Bay.TRACK_L, Bay.TRACK_R - 1.0)
	var step := 1.0 / 90.0
	var speed := 18.0
	var facts := []
	var s := 0.0
	var total := _length(path)
	var t := 0.0
	while t < 12.0:
		t += step
		s = fposmod(s + speed * step, total)
		facts.append_array(lap.step(step, _at(path, s), speed))
	var done := facts.filter(func(f): return f["kind"] == "lap_finished")
	var first: Dictionary = done[0] if not done.is_empty() else {}
	_report("lap round the rim", not done.is_empty() and absf(first["seconds"] - total / speed) < 0.4 and first["under_par"],
		"a %.0f m lap at 18 m/s: finished %s in %.2f s (the path takes %.2f s), par %.1f s, under par %s"
			% [total, not done.is_empty(), first.get("seconds", -1.0), total / speed, BayLap.PAR, first.get("under_par", false)])
	var short := BayLap.new([Vector2(0.0, -13.0), Vector2(23.0, 0.0), Vector2(0.0, 13.0), Vector2(-23.0, 0.0)])
	var cut := []
	for k in 200:
		var p := Vector2(lerpf(-5.0, 20.0, float(k) / 200.0), -13.0)
		cut.append_array(short.step(step, p, 18.0))
	for k in 200:
		var p := Vector2(lerpf(20.0, -5.0, float(k) / 200.0), -13.0)
		cut.append_array(short.step(step, p, 18.0))
	_report("a cut lap does not count", not cut.any(func(f): return f["kind"] == "lap_finished"),
		"out along the near straight and straight back: %s" % [cut.map(func(f): return f["kind"])])


static func _stadium(half: float, r: float) -> Array:
	var pts := []
	for k in 40:
		pts.append(Vector2(lerpf(-half, half, k / 40.0), -r))
	for k in 40:
		var a := -PI * 0.5 + PI * k / 40.0
		pts.append(Vector2(half, 0.0) + Vector2(cos(a), sin(a)) * r)
	for k in 40:
		pts.append(Vector2(lerpf(half, -half, k / 40.0), r))
	for k in 40:
		var a := PI * 0.5 + PI * k / 40.0
		pts.append(Vector2(-half, 0.0) + Vector2(cos(a), sin(a)) * r)
	return pts


static func _length(pts: Array) -> float:
	var total := 0.0
	for k in pts.size():
		total += (pts[k] as Vector2).distance_to(pts[(k + 1) % pts.size()])
	return total


static func _at(pts: Array, s: float) -> Vector2:
	var left := s
	for k in pts.size():
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % pts.size()]
		var d := a.distance_to(b)
		if left <= d:
			return a.lerp(b, left / d)
		left -= d
	return pts[0]


func _bay():
	return _game.world.bay


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	var player = _game.player
	match _phase:
		"boot":
			_game.ctx.calm = true
			player.source = Intent.Scripted.new()
			var bus = _game.events
			bus.bay_entered.connect(func(banked: float): _entered_speed = banked; _events.append("bay_entered"))
			bus.bay_left.connect(func(v: Vector3): _left_velocity = v; _events.append("bay_left"))
			bus.world_fact.connect(func(kind: String, _at: Vector3): _events.append(kind))
			bus.reward_offered.connect(func(_o: Array): _offers_seen += 1)
			bus.reward_chosen.connect(func(id: String): _chosen = id)
			_game.flow.beacon_seconds_override = 0.3
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "enter"
		"enter":
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_phase = "beacon"
			_clock = 0.0
		"beacon":
			if _clock < 0.1:
				var at: Vector3 = _game.flow.beacon.global_position + Vector3.UP * 1.5
				player.reset_to(at, Vector3(0.0, 0.0, 4.0))
				player.body().global_position = at
			if _game.flow.state_name() == "gates" and _bay().docked:
				_report("the bay docks on the gates", true, "docked at %s over gates at %s; cradle at %s"
					% [_bay()._barge.global_position, _game.ctx.build.gates.offers[0]["at"], _bay().cradle_at])
				_run_at_cradle()
				_phase = "to_cradle"
				_clock = 0.0
				Engine.time_scale = SIM_SCALE
			elif _clock > 20.0:
				_report("the bay docks on the gates", false, "flow %s, docked %s" % [_game.flow.state_name(), _bay().docked])
				return _finish()
		"to_cradle":
			if _entered_speed >= 0.0:
				_report("the cradle banks the ball's speed", absf(_entered_speed - _before) <= _before * TOLERANCE,
					"rolled in at %.2f m/s, banked %.2f m/s" % [_before, _entered_speed])
				_offers_seen = 0
				_phase = "aboard"
				_clock = 0.0
			elif _clock > 4.0:
				_report("the cradle banks the ball's speed", false, "never caught; ball at %s" % [player.ball_position()])
				return _finish()
		"aboard":
			if _game.world.ride == null and _bay().on_deck(player.ball_position()) and player.state.grounded:
				if _clock_at_entry < 0.0:
					_clock_at_entry = _game.world.director.stage_time
					_event_clock_at_entry = _game.world.events.stage_time
					_clock = 0.0
				elif _clock > 2.0:
					var held: bool = _game.world.director.stage_time == _clock_at_entry and _game.world.events.stage_time == _event_clock_at_entry
					_report("the clock pauses aboard", held and _bay().inside,
						"after %.1f s aboard the difficulty clock reads %.2f s (was %.2f) and the event clock %.2f s (was %.2f)"
							% [_clock, _game.world.director.stage_time, _clock_at_entry, _game.world.events.stage_time, _event_clock_at_entry])
					_phase = "yard"
					_clock = 0.0
			elif _clock > 8.0:
				_report("the cradle throws the ball aboard", false, "ball at %s, deck at %.1f" % [player.ball_position(), _bay().deck_y()])
				return _finish()
		"yard":
			_check_yard()
			_phase = "toys"
			_clock = 0.0
		"toys":
			if _clock < 0.05:
				_place_on_deck(Bay.BELL, Vector3.ZERO)
			elif _clock > 0.5:
				_report("the bell rings", _events.has("bay_bell"), "rolled under the bell: facts %s" % [_events.filter(func(k): return String(k).begins_with("bay_"))])
				var v: Vector3 = _bay().facing * 6.0
				_place_on_deck(Bay.PAD - Vector2(4.0, 0.0), v)
				_phase = "pad"
				_clock = 0.0
		"pad":
			if _events.has("bay_left") and _game.world.ride == null and player.state.grounded:
				var planar: float = player.planar_velocity().length()
				var heading: float = player.planar_velocity().normalized().dot(_bay().facing)
				_report("the pad returns the banked speed", planar >= _entered_speed * (1.0 - TOLERANCE) and heading > 0.9,
					"banked %.2f m/s; back on the ground at %.2f m/s heading %.2f along the gates' facing" % [_entered_speed, planar, heading])
				_report("the clock runs again after", _game.world.director.stage_time > _clock_at_entry,
					"difficulty clock %.2f s, was %.2f s at entry" % [_game.world.director.stage_time, _clock_at_entry])
				_report("the gates held still", _offers_seen == 0, "reward_offered while aboard: %d" % _offers_seen)
				_phase = "gate"
				_clock = 0.0
			elif _clock > 8.0:
				_report("the pad returns the banked speed", false, "left %s, ride %s, ball %s" % [_events.has("bay_left"), _game.world.ride, player.ball_position()])
				return _finish()
		"gate":
			if _chosen != "" or _clock > 3.0:
				_report("rolls through a gate into the launch", _chosen != "",
					"reward_chosen %s; flow %s" % [_chosen, _game.flow.state_name()])
				return _finish()
	return false


func _run_at_cradle() -> void:
	var cradle: Vector3 = _bay().cradle_at
	var dir: Vector3 = -_bay().facing
	var start := cradle - dir * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_before = SPEED
	_game.player.reset_to(at, dir * SPEED)
	_game.player.body().global_position = at


func _place_on_deck(uv: Vector2, velocity: Vector3) -> void:
	var at: Vector3 = _bay().deck_point(uv, 1.05)
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at


# Inside the yard a spent charge comes straight back; one step outside it does not.
func _check_yard() -> void:
	var abilities = _game.player.abilities
	_place_on_deck(Vector2(5.0, 3.0), Vector3.ZERO)
	var ball: Vector3 = _game.player.ball_position()
	var yard_in: bool = _bay().in_yard(ball)
	abilities.spend(AbilityState.SPECIAL)
	var spent: int = abilities.slot(AbilityState.SPECIAL).charges
	_game.world._physics_process(1.0 / 90.0)
	var back: int = abilities.slot(AbilityState.SPECIAL).charges
	_place_on_deck(Vector2(-6.0, 0.0), Vector3.ZERO)
	var outside: Vector3 = _bay().deck_point(Vector2(-6.0, 0.0), 1.05)
	abilities.spend(AbilityState.SPECIAL)
	_game.world._physics_process(1.0 / 90.0)
	var stays: int = abilities.slot(AbilityState.SPECIAL).charges
	_report("the yard waives cooldowns, only inside", yard_in and spent == 0 and back == 1 and not _bay().in_yard(outside) and stays == 0,
		"in the yard %s: spent to %d, back to %d next tick; outside the lines (in yard %s): spent to %d and still cooling"
			% [yard_in, spent, back, _bay().in_yard(outside), stays])


func _finish() -> bool:
	Engine.time_scale = 1.0
	print("stage_bay_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
