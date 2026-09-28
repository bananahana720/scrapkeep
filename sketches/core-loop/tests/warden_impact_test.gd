extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenDrop := preload("res://src/combat/warden_drop.gd")
const DropJuice := preload("res://src/presentation/drop_juice.gd")

# The drop mode's one physical hit predicate (warden_drop.gd, review findings 1 and 5),
# through real ball contacts on the stage 1 Warden. Each case puts the ball somewhere,
# lets the physics make the contact and reads the verdict the rule gave it:
#   drop        off a line, descending onto the open core's top at speed: one segment's
#               worth times speed over DROP_REF_SPEED, and the rebound keeps at least
#               REBOUND_MIN of the arrival speed a moment later
#   duplicate   a second descending contact inside REARM of the drop: nothing
#   floor ram   off a line but flat along the bowl floor at 35 m/s into the open core:
#               a miss, nothing dealt, thrown at the return lift
#   shut        off a line onto the core's top with the window shut: a miss, nothing
#   lift slam   a ball that never left the bowl (the pulse lift, a bowl shortcut)
#               slamming the open core from above: floor, nothing and no throw
#   gun hold    weapon hits on the open core hold it HOLD_PER_HIT each up to HOLD_CAP,
#               deal nothing alone, and their banked share lands with the drop
#   gun full    under `full` the gun deals 0 in a pulse window and its full punch once
#               a drop has staggered the Warden
#   hit-stop    the landing's stop is at most 70 ms and a chain of stops is refused past
#               the cumulative budget
#   v2          a v2 Warden has no drop rules and the plating rule answers as before
#
# Evidence limit: contacts are real physics from placed starts, not a player's run;
# the lapper bot measures whole laps.

const OUT := 58.0
const WAIT := 1.6
const SETTLE := 0.25
const REBOUND_MIN := 0.6

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _warden
var _drop
var _cases: Array = []
var _case := {}
var _phase := "boot"
var _clock := 0.0
var _contacts := 0
var _hp := 0.0
var _landed: Array = []
var _stop_calls := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_cases = [
		{"name": "drop", "line": true, "open": true, "run": _drop_case, "judge": _judge_drop},
		{"name": "duplicate", "line": true, "open": true, "run": _drop_case, "judge": _judge_duplicate, "no_rearm_wait": true,
			"out_s": WardenDrop.REBOUND_CLEAR + 0.05},
		{"name": "floor ram", "line": true, "open": true, "run": _ram_case, "judge": _judge_ram},
		{"name": "shut", "line": true, "open": false, "run": _drop_case, "judge": _judge_shut},
		{"name": "lift slam", "line": false, "open": true, "run": _drop_case, "judge": _judge_slam},
		{"name": "gun hold", "line": true, "open": true, "run": _gun_hold_case, "judge": _judge_gun_hold},
		{"name": "gun full", "line": true, "open": true, "run": _gun_full_case, "judge": _judge_gun_full},
	]


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.flow.force_warden = true
			_game.player.source = _source
			_game.tuning.set_option("loop_mode", "drop")
			_game.tuning.set_option("gun_role", "hold")
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.events.warden_drop_landed.connect(func(_at: Vector3, speed: float, _left: int, _n: int): _landed.append(speed))
			_to("settle")
		"settle":
			if _clock > 0.3:
				_game.run.set_max_hp(99999.0)
				_game.ctx.spawner.heft_override = 1.0
				_warden = _game.flow.warden
				_drop = _warden.get("drop") if is_instance_valid(_warden) else null
				_report("drop rules", _drop != null and _drop.gun_role == "hold",
					"stage 1 Warden in drop mode carries warden_drop.gd (%s)" % ("hold" if _drop != null else "none"))
				if _drop == null:
					return _finish()
				_next()
		"out":
			_hold_cycle()
			if _clock > float(_case.get("out_s", 0.05)):
				_to("place")
		"bowl":
			_hold_cycle()
			_game.player.reset_to(_ground(20.0))
			if _clock > WardenDrop.DROP_MEMORY + 0.2:
				_to("place")
		"place":
			_hold_cycle()
			_set_window(_case["open"])
			_contacts = _drop.contacts
			_hp = _warden.hp
			_case["run"].call()
			_to("fly")
		"fly":
			_hold_cycle()
			if not _case["open"]:
				_warden._open_left = 0.0
			if _drop.contacts > _contacts or _clock > WAIT:
				_case["contact"] = _drop.last_contact.duplicate() if _drop.contacts > _contacts else {}
				_case["same_tick"] = _drop.contacts - _contacts
				_to("after")
		"after":
			_hold_cycle()
			if _clock >= SETTLE:
				_case["judge"].call()
				_next()
		"stop":
			_step_hit_stop()
		"v2":
			if _clock > 0.3:
				var w = _game.flow.warden
				var rule: Dictionary = w.loop_rule("stomp", "core", 30.0, 60.0, 1.0) if is_instance_valid(w) else {"x": 1}
				_report("v2", is_instance_valid(w) and w.get("drop") == null and rule.is_empty() and not _game.ctx.terrain.map().loop_live,
					"after a flip to v2: no drop rules, loop_rule answers {} (plating rule), lips parked")
				return _finish()
	return false


func _to(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _next() -> void:
	if _cases.is_empty():
		_stop_calls = 0
		_to("stop")
		return
	_case = _cases.pop_front()
	_drop.gun_role = "full" if _case["name"] == "gun full" else "hold"
	_warden.hp = _warden.max_hp
	_drop.staggered = false
	if not _case.get("no_rearm_wait", false):
		_drop._rearm = 0.0
	_drop._dropped = false
	_game.player.reset_to(_ground(OUT if _case["line"] else 20.0))
	_to("out" if _case["line"] else "bowl")


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_mast().x + out, _mast().z, 1.5)


func _mast() -> Vector3:
	return _warden.global_position


func _top() -> Vector3:
	return _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT


# The family cycle is parked so a natural pulse never lands in the middle of a case.
func _hold_cycle() -> void:
	_warden._pulse_clock = 0.0
	_warden._charging = false


func _set_window(open: bool) -> void:
	if open:
		if _warden._open_left <= 0.0:
			_warden._open(_warden.CORE_WINDOW)
	else:
		_warden._open_left = 0.0


# From 6 m out and 4.5 m over the core's top, at 26 m/s toward the mast and falling.
func _drop_case() -> void:
	var from := _top() + Vector3(-6.0, 4.5, 0.0)
	_game.player.reset_to(from, Vector3(20.0, -16.0, 0.0))


func _ram_case() -> void:
	var floor_y: float = _game.ctx.terrain.height(_mast().x - 14.0, _mast().z) + 1.05
	_game.player.reset_to(Vector3(_mast().x - 14.0, floor_y, _mast().z), Vector3(35.0, 0.0, 0.0))


func _gun_hold_case() -> void:
	var combat = _game.ctx.spawner
	var point: String = _warden.family_point()
	var before: float = _warden._open_left
	for i in 30:
		combat.strike(_warden, "runner", 12.0, point)
	_case["held"] = _warden._open_left - before
	_case["gun_hp"] = _hp - _warden.hp
	_case["banked"] = _drop.banked
	_case["body_before"] = _warden.hp
	combat.strike(_warden, "runner", 12.0, "")
	_case["body_dealt"] = _case["body_before"] - _warden.hp
	_drop_case()


func _gun_full_case() -> void:
	var combat = _game.ctx.spawner
	combat.strike(_warden, "runner", 12.0, _warden.family_point())
	_case["pulse_window_gun"] = _hp - _warden.hp
	_drop_case()


# The first contact the case made; any later touch inside REARM is the duplicate rule's.
func _contact() -> Dictionary:
	return _case.get("contact", {})


func _judge_drop() -> void:
	var c := _contact()
	var dealt: float = _hp - _warden.hp
	var speed_in: float = _landed[-1] if not _landed.is_empty() else 0.0
	var expected: float = _drop.segment_hp * speed_in / WardenDrop.DROP_REF_SPEED
	var ratio: float = _game.player.state.velocity.length() / maxf(0.1, speed_in)
	_report("drop", c.get("verdict") == "drop" and absf(dealt - expected) < 0.5 and _landed.size() == 1 and _drop.drops_landed == 1,
		"verdict %s at %.1f m/s, %.2f m over the top (%d contact(s) that tick): dealt %.1f (a segment %.0f x heft 1 x speed/%.0f = %.1f), badge %d / %d"
			% [c.get("verdict", "no contact"), speed_in, c.get("height", 0.0), _case.get("same_tick", 0), dealt, _drop.segment_hp,
				WardenDrop.DROP_REF_SPEED, expected, _drop.segments_left(), _drop.drops])
	_report("momentum", ratio >= REBOUND_MIN and not _warden.family_open(),
		"%.2f s after the drop the ball keeps %.2fx of its %.1f m/s (band >= %.1f); the hold window shut behind it"
			% [SETTLE, ratio, speed_in, REBOUND_MIN])


func _judge_duplicate() -> void:
	var c := _contact()
	_report("duplicate", c.get("verdict") == "floor" and _hp == _warden.hp and _drop.drops_landed == 1,
		"a second descending contact %.2f s after the drop: %s, dealt %.1f"
			% [WardenDrop.REARM - _drop._rearm, c.get("verdict", "no contact"), _hp - _warden.hp])


func _judge_ram() -> void:
	var c := _contact()
	var v: Vector3 = _game.player.state.velocity
	var lift: Vector3 = _drop.rebound_to
	var to_lift := Vector2(lift.x - _game.player.ball_position().x, lift.z - _game.player.ball_position().z).normalized()
	var heading := Vector2(v.x, v.z).normalized()
	_report("floor ram", c.get("verdict") == "miss" and not c.get("on_core", true) and _hp == _warden.hp and heading.dot(to_lift) > 0.8,
		"a %.1f m/s ram along the floor into the open core: %s (on the core %s, descending %s), dealt %.1f, thrown %.0f deg off the lift's line"
			% [c.get("speed", 0.0), c.get("verdict", "no contact"), c.get("on_core"), c.get("descending"), _hp - _warden.hp,
				rad_to_deg(acos(clampf(heading.dot(to_lift), -1.0, 1.0)))])


func _judge_shut() -> void:
	var c := _contact()
	_report("shut", c.get("verdict") == "miss" and not c.get("open", true) and _hp == _warden.hp,
		"a drop onto the shut core: %s, dealt %.1f" % [c.get("verdict", "no contact"), _hp - _warden.hp])


func _judge_slam() -> void:
	var c := _contact()
	_report("lift slam", c.get("verdict") == "floor" and not c.get("from_line", true) and _hp == _warden.hp,
		"a ball that stayed in the bowl %.0f s dropping onto the open core at %.1f m/s: %s, dealt %.1f (bowl shortcuts count for nothing)"
			% [WardenDrop.DROP_MEMORY, c.get("speed", 0.0), c.get("verdict", "no contact"), _hp - _warden.hp])


func _judge_gun_hold() -> void:
	var c := _contact()
	var gun_share: float = _drop.damage["gun"]
	_report("gun hold", absf(_case["held"] - WardenDrop.HOLD_CAP) < 0.001 and _case["gun_hp"] == 0.0 and _case["body_dealt"] == 0.0,
		"30 runner hits on the open core held it %.2f s (cap %.1f, 0.1 a hit), dealt %.1f alone, banked %.2f; a body hit dealt %.1f"
			% [_case["held"], WardenDrop.HOLD_CAP, _case["gun_hp"], _case["banked"], _case["body_dealt"]])
	_report("banked share lands", c.get("verdict") == "drop" and absf(gun_share - _case["banked"]) < 0.01 and _drop.banked == 0.0,
		"the drop landed %s; the gun's banked %.2f landed with it (gun damage %.2f)" % [c.get("verdict", "no contact"), _case["banked"], gun_share])


func _judge_gun_full() -> void:
	var c := _contact()
	var combat = _game.ctx.spawner
	var before: float = _warden.hp
	var punch: float = combat.punch_of("runner", 12.0)
	combat.strike(_warden, "runner", 12.0, "")
	var stagger_hit: float = before - _warden.hp
	_report("gun full", _case["pulse_window_gun"] == 0.0 and c.get("verdict") == "drop" and _drop.staggered
		and absf(stagger_hit - punch) < 0.01 and _warden._open_left > WardenDrop.STAGGER_SECONDS - 1.0,
		"under full a gun hit in a pulse window dealt %.1f; after the drop (%s) the stagger stands %.1f s and a body hit dealt %.1f (punch %.1f)"
			% [_case["pulse_window_gun"], c.get("verdict", "no contact"), _warden._open_left, stagger_hit, punch])


# Real stops through the spine: the landing's own length, then a chain inside one second.
func _step_hit_stop() -> void:
	if _game._hit_stopped:
		return
	if _stop_calls == 0:
		_game.hit_stop_spent = 0.0
		_game.hit_stops_skipped = 0
		_game._stop_log = []
	if _stop_calls < 4:
		_stop_calls += 1
		_game.hit_stop(DropJuice.DROP_HIT_STOP)
		return
	_report("hit-stop", DropJuice.DROP_HIT_STOP <= 0.07 and _game.hit_stop_spent <= _game.HIT_STOP_BUDGET + 0.0001 and _game.hit_stops_skipped >= 2,
		"the landing stops %.0f ms; four in a row spent %.0f ms (budget %.0f ms a second) and %d were refused"
			% [DropJuice.DROP_HIT_STOP * 1000.0, _game.hit_stop_spent * 1000.0, _game.HIT_STOP_BUDGET * 1000.0, _game.hit_stops_skipped])
	Engine.time_scale = 1.0
	_game.tuning.set_option("loop_mode", "v2")
	_game.flow.retry_stage()
	_to("v2")


func _finish() -> bool:
	print("warden_impact_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
