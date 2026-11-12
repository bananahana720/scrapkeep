extends SceneTree

const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const Cues := preload("res://src/presentation/flourish_cues.gd")
const Flow := preload("res://src/core/flow.gd")
const T := preload("res://tests/support/t.gd")

# Brindle's beats (world 1 plan, unit 3) through the real flow: the arrival plays inside the
# no-attack intro and never on an arena retry, each later phase gets its panel inside the
# 2.0 s transition beat, the rout plays over the world while the victory card waits, Tarn
# signs on over the card the first time, the victory window grows by at most HOLD_CAP and
# only on a first full play, and a skip gives the hold back.

const DT := 1.0 / 90.0
# fight_phases.gd's transition beat (#391): a phase panel must end inside it.
const TRANSITION_SECONDS := 2.0

class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _t
var _started := false


func _initialize() -> void:
	_t = T.new("brindle_beats_test")
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_run_all()
	return false


func _run_all() -> void:
	await process_frame
	_static_checks()
	_first_run()
	_repeat_run()
	_skip_run()
	var code: int = _t.verdict()
	_game.free()
	quit(code)


func _player():
	return _game.presentation.flourish


func _boss():
	return _game.boss


func _static_checks() -> void:
	var arrival := Rows.length("brindle_arrival", false)
	_t.check("01 the arrival fits the no-attack intro", arrival > 0.0 and arrival <= Rules.INTRO_SECONDS, "%.2f s of %.1f s" % [arrival, Rules.INTRO_SECONDS])
	for id in ["brindle_phase_2", "brindle_phase_3"]:
		var full := Rows.length(id, false)
		_t.check("02 %s fits the transition beat" % id, full > 0.0 and full < TRANSITION_SECONDS, "%.2f s" % full)
		# w37 film PF-26: a stamp or a drawn word over the turn covered Brindle and his target tags; the caption stays.
		for form in ["full", "short"]:
			var kinds := (Rows.ROWS[id][form] as Array).map(func(p: Dictionary) -> String: return String(p["kind"]))
			_t.check("02b %s %s draws no word over the fight, only its caption" % [id, form], not kinds.has("stamp") and not kinds.has("sfx_word") and kinds.has("caption"), str(kinds))
	var first := Rows.length("brindle_rout", false) + Rows.length("tarn_sign_on", false)
	_t.check("03 a first rout and sign-on need no more than the cap past the window", first - Flow.VICTORY_SECONDS <= Cues.HOLD_CAP,
		"%.2f s against %.1f + %.1f" % [first, Flow.VICTORY_SECONDS, Cues.HOLD_CAP])
	_t.check("04 a repeat rout fits the window", Rows.length("brindle_rout", true) <= Flow.VICTORY_SECONDS, "%.2f s" % Rows.length("brindle_rout", true))
	var triggers := {"arrival": Cues.matching("arrival", "brindle"), "rout": Cues.matching("rout", "brindle"),
		"sign_on": Cues.matching("sign_on", "brindle"), "phase": Cues.matching("phase", "brindle")}
	_t.check("05 one row per moment, three phase panels (two phases and the chase)", triggers.arrival.size() == 1 and triggers.rout.size() == 1 and triggers.sign_on.size() == 1 and triggers.phase.size() == 3, str(triggers))
	# FX-03: the chase turn has its own beat, a glance that waits for the scooter to leave the hull.
	for short in [false, true]:
		var chase: Array = Cues.world_beats("brindle_chase", short).filter(func(b): return b.get("kind") == "glance")
		_t.check("06 the chase turn glances along the scooter's arc (%s)" % ("short" if short else "full"),
			chase.size() == 1 and chase[0]["anchor"] == "scooter" and float(chase[0]["at"]) > 0.0
				and float(chase[0]["at"]) + float(chase[0]["seconds"]) <= Rules.EJECT_FLIGHT, str(chase))


func _to_arena() -> void:
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()


func _first_run() -> void:
	var player = _player()
	var boss = _boss()
	Harness.start_run(_game)
	player.stop_all()
	_to_arena()
	_t.check("10 the arena opens on the arrival, in full", player.playing and player.id == "brindle_arrival" and not player.short, "%s short %s" % [player.id, player.short])
	var attacks := 0
	_game.events.boss_attack_telegraphed.connect(func(_id: String, _s: float): attacks += 1)
	var length: float = player.length()
	var t := 0.0
	while t < length:
		boss.advance(DT)
		player.advance(DT)
		t += DT
	_t.check("11 no attack is committed while it plays", attacks == 0, "%d telegraphs in %.2f s" % [attacks, length])
	_t.check("12 it ends on its own", not player.playing and player.played.back().id == "brindle_arrival" and not player.played.back().skipped, str(player.played.back()))

	_game.run.damage(99999.0, "test")
	_game.flow.retry_stage()
	_t.check("13 an arena retry replays no arrival", _game.flow.state_name() == "boss" and not (player.playing and player.id == "brindle_arrival"), "%s %s" % [player.playing, player.id])

	boss.jump_to_phase(2)
	_t.check("14 phase two gets its panel", player.playing and player.id == "brindle_phase_2", player.id)
	player.advance(TRANSITION_SECONDS)
	boss.jump_to_phase(3)
	_t.check("15 phase three gets its panel", player.playing and player.id == "brindle_phase_3", player.id)

	# The catch lands while phase three's panel still shows: the rout takes over at once.
	Harness.defeat(_game)
	var flow = _game.flow
	var screens = _game.get("screens")
	var hold: float = flow._victory_hold
	var expect: float = Rows.length("brindle_rout", false) + Rows.length("tarn_sign_on", false) - Flow.VICTORY_SECONDS
	_t.check("20 Tarn's grant was earned in this fight", _game.ctx.profile.earned("brindle_routed"), "")
	_t.check("21 the rout plays in full", flow.state_name() == "victory" and player.playing and player.id == "brindle_rout" and not player.short, "%s %s" % [flow.state_name(), player.id])
	_t.check("22 the window grows by the rout and sign-on, capped", is_equal_approx(hold, clampf(expect, 0.0, Cues.HOLD_CAP)) and is_equal_approx(flow._victory_left, Flow.VICTORY_SECONDS + hold),
		"hold %.2f, left %.2f" % [hold, flow._victory_left])
	_t.check("23 the victory card waits over the world", screens != null and not screens.visible and flow.victory_veil == Rows.length("brindle_rout", false), "veil %.2f" % flow.victory_veil)
	var prop = boss.arena.find_child("RoutScooter", true, false) if boss.arena != null else null
	_t.check("24 the scooter sails out of the catch", prop != null, "")
	screens._step_veil_wait(flow.victory_veil + 0.01)
	player.advance(Rows.length("brindle_rout", false) + 0.01)
	_t.check("25 the card shows when the rout ends", screens.visible, "")
	_t.check("26 Tarn signs on over it", player.playing and player.id == "tarn_sign_on", player.id)
	player.advance(Rows.length("tarn_sign_on", false) + 0.01)
	var log: Array = _game.run.get_meta("flourishes", [])
	var paid := 0.0
	for entry in log:
		if entry.id in ["brindle_rout", "tarn_sign_on"]:
			paid += float(entry.held)
	_t.check("27 the run log carries the hold the beats paid", absf(paid - hold) < 0.02, "paid %.2f of %.2f in %s" % [paid, hold, str(log.map(func(e): return [e.id, e.held]))])
	flow.physics_step(flow._victory_left + 0.01)
	_t.check("28 the window closes on time", flow.state_name() != "victory", flow.state_name())


func _repeat_run() -> void:
	var player = _player()
	Harness.start_run(_game)
	player.stop_all()
	_to_arena()
	_t.check("30 a second run's arrival is the short form", player.playing and player.id == "brindle_arrival" and player.short, "%s short %s" % [player.id, player.short])
	player.advance(Rules.INTRO_SECONDS)
	_game.camera.reduced_motion = true
	Harness.defeat(_game)
	_game.camera.reduced_motion = false
	var flow = _game.flow
	var prop = _game.boss.arena.find_child("RoutScooter", true, false) if _game.boss.arena != null else null
	_t.check("33 reduced motion keeps the overlay and drops the world beat", player.id == "brindle_rout" and prop == null, "")
	_t.check("31 the repeat rout is short and holds nothing", player.id == "brindle_rout" and player.short and flow._victory_hold == 0.0 and is_equal_approx(flow._victory_left, Flow.VICTORY_SECONDS),
		"%s short %s hold %.2f" % [player.id, player.short, flow._victory_hold])
	player.advance(Rows.length("brindle_rout", true) + 0.01)
	_t.check("32 Tarn signs on only once", not player.playing, player.id)
	flow.physics_step(flow._victory_left + 0.01)


func _skip_run() -> void:
	var player = _player()
	var profile = _game.ctx.profile
	Harness.start_run(_game)
	player.stop_all()
	_to_arena()
	player.advance(Rules.INTRO_SECONDS)
	# A profile that has seen the rout but not yet earned Tarn's grant: the chain and its hold.
	profile._doc["seen"].erase(Rows.SEEN_PREFIX + "brindle_rout")
	_game.presentation.flourish_cues._earned_in_fight["brindle_routed"] = true
	Harness.defeat(_game)
	var flow = _game.flow
	var before: float = flow._victory_left
	player.advance(0.9)
	player.skip()
	_t.check("40 a skipped rout gives back its hold and the sign-on's", before > Flow.VICTORY_SECONDS and flow._victory_left <= Flow.VICTORY_SECONDS + 0.001 and flow.victory_veil == 0.0,
		"left %.2f -> %.2f, veil %.2f" % [before, flow._victory_left, flow.victory_veil])
	_t.check("41 and the sign-on is dropped", not player.playing, player.id)
