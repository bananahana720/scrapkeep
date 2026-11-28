extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Companion := preload("res://src/core/companion.gd")

# BUGFIX-COMBAT-A (wave 12-F, 2026-10-09): the hosted bug hunter's combat.gd and
# warden.gd findings, each held by a check that went red on eb87cb8.
# F001 Daisy Chain sets off each charge once, never twice through a nested chain.
# F002 a new attempt starts with no echo, marks, cloud, sentry or pulse clock from the old one.
# F004 a Warden's posture judge meets plating_for(kind, part): the choir brace and the open lens.
# F005 would_crush agrees with strike(): plate exposure and the primer coil count.
# F009 discovery_log is this run's log; a new run starts it empty.
# F010 pins counts this attempt's pins; a new attempt starts it at 0.

var _game
var _combat
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	await physics_frame
	_daisy_chain()
	_attempt_reset()
	await _warden_plating()
	_would_crush()
	_discovery_log()
	var ok := _failures == 0
	print("combat_bughunt_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)


# F001: three charges 1 m apart with a 2.5 m chain reach, the first set off by hand.
func _daisy_chain() -> void:
	var base: Vector3 = _game.player.ball_position() + Vector3(200.0, 0.0, 200.0)
	var seen := []
	var count := func(at: Vector3, _crit: bool): seen.append(at.x - base.x)
	_game.events.sticky_detonated.connect(count)
	_game.player.tree._knobs["sticky_chain"] = 2.5
	var first: Dictionary = {}
	for i in 3:
		var c: Dictionary = _combat.sticky.drop(base + Vector3(float(i), 0.0, 0.0), 1.0, 1.0, 99.0, 0.0)
		if i == 0:
			first = c
	_combat.detonate(_combat.sticky.take(first))
	_game.player.tree._knobs.erase("sticky_chain")
	_game.events.sticky_detonated.disconnect(count)
	_report("F001 chain", seen.size() == 3 and _combat.sticky.charges.is_empty(),
		"3 charges in reach: %d detonations at offsets %s" % [seen.size(), seen])


# F002 and F010: an attempt's specials and counters do not carry into the next attempt.
func _attempt_reset() -> void:
	var fired := [0]
	_combat._echo = {"row": {"fire": func(_f: float, _g): fired[0] += 1, "geometry": func(_f: float): return {}},
		"fraction": 0.6, "left": 0.1}
	_combat._marks = {12345: _combat._clock + 99.0}
	_combat._cloud = {"at": _game.player.ball_position(), "left": 99.0}
	_combat._sentry = {"at": _game.player.ball_position(), "left": 99.0, "next": 0.0}
	_combat._pulse_left = 5.0
	_combat.pins = 3
	_game.events.stage_content_cleared.emit("test")
	_combat._tick_echo(0.2)
	_report("F002 echo", fired[0] == 0 and _combat._echo.is_empty(),
		"a special echo pending at the retry fired %d time(s) into the new attempt" % fired[0])
	_report("F002 marks, cloud, sentry, pulse", _combat._marks.is_empty() and _combat._cloud.is_empty()
		and _combat._sentry.is_empty() and _combat._pulse_left == 0.0,
		"after the clear: marks %s, cloud %s, sentry %s, pulse %.1f" % [_combat._marks, _combat._cloud, _combat._sentry, _combat._pulse_left])
	_report("F010 pins", _combat.pins == 0, "pins after a new attempt: %d" % _combat.pins)


# F004: a choir Warden in a stagger, braced against ram. combat.resolve must hand the
# posture judge the plating plating_for answers for that kind and part.
func _warden_plating() -> void:
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(-200.0, 0.0, 0.0)
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		{"family": Roster.MIND, "stage": 1, "fleet": _combat.fleet, "plating": 30.0, "hp": 800.0})
	await physics_frame
	warden._posture.staggered = true
	warden.braced_kinds = ["ram"]
	var braced: Dictionary = _combat.resolve(warden, "ram", 10.0)
	var open: Dictionary = _combat.resolve(warden, "runner", 10.0, warden.family_point())
	var plain: Dictionary = _combat.resolve(warden, "stomp", 10.0)
	_report("F004 braced ram", is_equal_approx(float(braced.get("plating", -1.0)), 30.0 * Warden.CHOIR_BRACE_MULT),
		"a braced ram in the stagger meets plating %.1f (plating_for says %.1f)" % [float(braced.get("plating", -1.0)), warden.plating_for("ram", "")])
	_report("F004 open lens", float(open.get("plating", -1.0)) == 0.0,
		"a hit on the open %s meets plating %.1f" % [warden.family_point(), float(open.get("plating", -1.0))])
	_report("F004 unbraced control", is_equal_approx(float(plain.get("plating", -1.0)), 30.0),
		"an unbraced stomp meets plating %.1f" % float(plain.get("plating", -1.0)))
	warden.queue_free()


# F005: an unplated enemy whose hp sits between resolve()'s dealt and dealt x the strike
# multiplier. would_crush must say what strike() will do.
func _would_crush() -> void:
	var enemy = load("res://src/combat/enemy.gd").new()
	enemy.plating = 0.0
	enemy.max_hp = 2400.0
	var dealt: float = _combat.resolve(enemy, "ram", 10.0)["dealt"]
	enemy.hp = dealt * (1.0 + MindAttacks.BRACE_MULT) * 0.5
	var id: int = enemy.get_instance_id()
	_report("F005 control", not _combat.would_crush(enemy, "ram", 10.0),
		"hp %.1f above dealt %.1f, nothing exposed: no crush" % [enemy.hp, dealt])
	_combat._exposed[id] = {"until": _combat._clock + 99.0, "verb": "test"}
	_report("F005 exposed", _combat.would_crush(enemy, "ram", 10.0),
		"plate-exposed: strike deals %.1f against hp %.1f, would_crush %s" % [dealt * MindAttacks.BRACE_MULT, enemy.hp, _combat.would_crush(enemy, "ram", 10.0)])
	_combat._exposed.erase(id)
	var c := Companion.new()
	c.acquire("primer_coil")
	c.acquire("ram_prow")
	c.assemble(["primer_coil", "ram_prow"])
	_game.ctx.run.companion = c.to_dict()
	enemy.hp = dealt * (1.0 + Companion.PRIMER_COIL_MULT) * 0.5
	_combat._primed[id] = _combat._clock + 99.0
	_report("F005 primed", _combat.would_crush(enemy, "ram", 10.0) and _combat.primed(enemy),
		"primed under a primer coil: strike deals %.1f against hp %.1f, would_crush %s, prime kept %s"
		% [dealt * Companion.PRIMER_COIL_MULT, enemy.hp, _combat.would_crush(enemy, "ram", 10.0), _combat.primed(enemy)])
	_combat._primed.erase(id)
	_game.ctx.run.companion = {}
	enemy.free()


# F009: a trick found in run 1 and again in run 2 is in run 2's log once.
func _discovery_log() -> void:
	var at: Vector3 = _game.player.ball_position()
	_combat.discover("chain", at)
	_game.events.run_started.emit("rivet")
	_combat.discover("chain", at)
	_report("F009 log", _combat.discovery_log == ["chain"], "run 2's discovery_log: %s" % [_combat.discovery_log])
