# smoke: solo (Brindle's arena through the spine)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# Fight phases (fight_phases.gd, Andrew 23 Oct): the counts (bosses three, mini-bosses two),
# the mini-boss health turn, the phase signal the music swaps on, the transition beat, and the
# ratchet cue's timing. Then on the real Brindle: the phase signal, the transition beat (no
# posture, no new attack), and one cued follow-up per later phase with its cue ahead of it.
#
# Evidence limit: the boss is driven tick by tick with the ball parked off the hazards; no bot
# band was run, so how much harder the ratchet makes Brindle is not measured here.

const DT := 1.0 / 90.0

var _t := T.new("fight_phases_test")
var _phases_seen: Array = []
var _cues: Array = []


func _initialize() -> void:
	ChallengeDials.reset()
	_framework()
	_run()


func _framework() -> void:
	var bus := GameEvents.new()
	bus.fight_phase_changed.connect(func(id: String, p: int, n: int): _phases_seen.append([id, p, n]))
	bus.attack_cued.connect(func(id: String, a: String, s: float): _cues.append([id, a, s]))
	_t.eq("a boss has at most three phases", FightPhases.boss("x", null, 7).phases, FightPhases.BOSS_MAX)
	_t.eq("BOSS_MAX is three", FightPhases.BOSS_MAX, 3)
	var mini := FightPhases.mini("rogue_crane", "rogue", bus)
	_t.eq("a mini-boss has two phases", mini.phases, 2)
	_t.check("above half health it stays in phase one", not mini.by_health(0.6, 0.0) and mini.phase == 1)
	_t.check("at half health it turns to phase two", mini.by_health(0.5, 1.0) and mini.phase == 2)
	_t.check("and it never turns again", not mini.by_health(0.1, 2.0) and mini.phase == 2)
	mini.enter(5, 3.0)
	_t.eq("enter clamps to the fight's count", mini.phase, 2)
	_t.eq("the phase signal names the fight, phase and count", _phases_seen.slice(0, 2), [["rogue_crane", 1, 2], ["rogue_crane", 2, 2]])
	mini.tick(3.0 + FightPhases.TRANSITION_SECONDS * 0.5)
	_t.check("inside the transition beat", mini.in_transition())
	mini.tick(3.0 + FightPhases.TRANSITION_SECONDS + 0.01)
	_t.check("the beat ends after TRANSITION_SECONDS", not mini.in_transition())
	_t.eq("an undialled fight owes no follow-ups and keeps tempo 1", [mini.follow_ups(), mini.tempo(), mini.speed()], [0, 1.0, 1.0])
	mini.cue("sweep")
	_t.eq("the cue names the fight and the attack", _cues.back().slice(0, 2), ["rogue_crane", "sweep"])
	_t.check("cue to hit is at least 1.0 s and the drawn tell at least TELL_FLOOR",
			float(_cues.back()[2]) >= 1.0 and FightPhases.CUED_WARN >= ChallengeDials.TELL_FLOOR, str(_cues.back()))
	bus.free()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await physics_frame
	var boss = game.boss
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	_phases_seen.clear()
	_cues.clear()
	game.events.fight_phase_changed.connect(func(id: String, p: int, n: int): _phases_seen.append([id, p, n]))
	game.events.attack_cued.connect(func(id: String, a: String, s: float): _cues.append([id, a, s, boss.clock]))
	Harness.start_run(game)
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	game.run.max_hp = 100000.0
	game.run.hp = 100000.0
	_t.eq("Brindle publishes phase one of three", _phases_seen.back() if not _phases_seen.is_empty() else [], ["brindle", 1, 3])
	for p in [2, 3]:
		boss.jump_to_phase(p)
		var began: float = boss.clock
		_t.eq("Brindle publishes phase %d of three" % p, _phases_seen.back(), ["brindle", p, 3])
		var hull = boss.ship.hull_target() if boss.ship.has_method("hull_target") else boss.ship.hull
		var judged: Dictionary = boss.judge_hit(hull, "ram", 1.0e6, true, 3)
		_t.check("phase %d transition: a hit moves no posture" % p, float(judged.get("gain", -1.0)) == 0.0, str(judged.get("gain")))
		var committed_early := 0
		var cue_at := -1.0
		var cued_drawn := -1.0
		var cued_warn := -1.0
		while boss.clock - began < 40.0 and cued_drawn < 0.0:
			_park(game, boss)
			boss.advance(DT)
			game.run.heal(1000.0)
			for h in boss.active_hazards():
				if h.age <= DT * 1.5 and boss.clock - began < FightPhases.TRANSITION_SECONDS - DT:
					committed_early += 1
				if h.cued and cued_drawn < 0.0:
					cued_drawn = boss.clock
					cued_warn = h.warn_seconds
			if cue_at < 0.0 and not _cues.is_empty() and float(_cues.back()[3]) >= began:
				cue_at = float(_cues.back()[3])
		_t.eq("phase %d: no attack commits inside the transition beat" % p, committed_early, 0)
		_t.check("phase %d: a cued follow-up came" % p, cued_drawn > 0.0, "drawn at %.2f" % cued_drawn)
		_t.check("phase %d: its cue sounded CUE_LEAD before the draw" % p, cue_at > 0.0
				and absf(cued_drawn - cue_at - FightPhases.CUE_LEAD) <= DT * 2.0, "cue %.2f draw %.2f" % [cue_at, cued_drawn])
		_t.check("phase %d: its drawn tell is the short CUED_WARN" % p, absf(cued_warn - FightPhases.CUED_WARN) < 1e-4, str(cued_warn))
	ChallengeDials.set_overrides({"brindle.follow_ups_by_phase": [0.0, 0.0, 0.0, 0.0]})
	boss.jump_to_phase(2)
	var quiet := 0
	var began2: float = boss.clock
	while boss.clock - began2 < 25.0:
		_park(game, boss)
		boss.advance(DT)
		game.run.heal(1000.0)
		for h in boss.active_hazards():
			quiet += 1 if h.cued else 0
	_t.eq("the dial at 0 turns the ratchet off", quiet, 0)
	ChallengeDials.reset()
	game.free()
	quit(_t.verdict())


# Keeps the ball out by the rim, off the ship, so the fight runs on without hits.
func _park(game, boss) -> void:
	var spot: Vector3 = boss.arena.point_at(0.0, 30.0)
	Harness.put_ball(game, Vector3(spot.x, boss.arena.ground(spot) + 1.0, spot.z))
