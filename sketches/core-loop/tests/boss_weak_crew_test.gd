# smoke: solo timeout=240s (twenty boots of the Waking arena; 153 s on a 4-core cloud box on 2026-10-23 with the record half running beside it)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const Waking := preload("res://src/boss/waking.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const CrewFitter := preload("res://src/combat/crew_fitter.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SkillBand := preload("res://tools/skill_band.gd")

# The Waking's crew fitters (challenge lane, weak points step 2b). Dial 0 has no crew; at dial 1 an opening calls
# min(3, 6 - alive) fitters, three waves a floor phase at most; two fitters fitting for 3.5 s seal the hatch, one
# or 3.4 s do not; a reel impact on a fitting fitter drops its plate and a plain contact does not; a closed hatch
# retires its crew with no kill; the expert hits a fitter before the hatch and the novice goes for neither.
#
# Evidence limit: strikes are enemy_struck events shaped like the ball's own with the line state set by hand, and
# fitters are placed on their slots; the flight to the slot is checked only by distance. No human play.

var _t := T.new("boss_weak_crew_test")
var _killed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await _dial_zero()
	await _waves()
	await _fit_clock()
	await _knock()
	await _real_damage()
	await _cue_and_plate()
	await _retire()
	await _death_on_the_sealing_tick()
	await _plain_shove()
	await _bot()
	await _learner()
	await _outcome_phase()
	await _freed_without_died()
	_finish()


# Two sections (_record_survives and _stats, together about 160 s of the one-file run on 2026-10-23) live in boss_weak_crew_record_test.gd, which
# extends this file, so neither file nears the fast lane's per-test limit.
func _finish() -> void:
	ChallengeDials.reset()
	quit(_t.verdict())


func _boot(overrides: Dictionary):
	ChallengeDials.reset()
	var dials := {"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]}
	dials.merge(overrides)
	ChallengeDials.set_overrides(dials)
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	Harness.boot(game)
	Harness.enter_world(game, 2)
	for i in 3:
		await physics_frame
	var mod = Harness.module(game, 2)
	_killed = 0
	mod.ctx.events.enemy_killed.connect(func(_k, _at, _scrap): _killed += 1)
	return [game, mod]


func _fitters(mod) -> Array:
	return mod.get_tree().get_nodes_in_group("enemy").filter(func(e): return e.get("kind") == "crew_fitter" and not e.is_dead())


func _drop_floors(mod, n: int) -> void:
	for k in range(1, n + 1):
		mod._free_part("hatch_%d" % k)
		mod._free_body(mod._floor_bodies.get(k))
		mod._floor_bodies.erase(k)


# Puts a fitter on its slot and lets the boss book it the way a flight would.
func _seat(f) -> void:
	f.global_position = f.slot
	f.velocity = Vector3.ZERO


func _step_until(mod, seconds: float) -> void:
	var until: float = mod.clock + seconds
	while mod.clock < until:
		for f in _fitters(mod):
			if f.fit_state == f.State.FITTING:
				_seat(f)
		await physics_frame


func _dial_zero() -> void:
	var booted = await _boot({"waking.weak_points": 0.0})
	var game = booted[0]
	var mod = booted[1]
	mod._open_hatch(1)
	mod._open_override()
	mod._open_point("hatch_1")
	mod._call_crew("hatch_1")
	var blocked: bool = mod.weak_open().is_empty()
	for i in 90:
		await physics_frame
	var seen := 0
	for e in mod.get_tree().get_nodes_in_group("enemy"):
		seen += 1 if e.get("kind") == "crew_fitter" else 0
	_t.check("dial 0: no opening path opens a point (so none calls a crew)", blocked, "")
	_t.check("dial 0: no crew_fitter ever stands and no crew is kept", seen == 0 and mod._crew.is_empty() and mod.crew().is_empty(), str(seen))
	var cue_nodes: Array = mod.get_tree().root.find_children("SeamPlate*", "", true, false) + mod.get_tree().root.find_children("WeldSpark", "", true, false)
	_t.check("dial 0: no plate or cue node exists and no seal cue fired", cue_nodes.is_empty() and mod._plates.is_empty() and mod._fallen.is_empty()
			and mod.seal_cue_log.is_empty(), str(cue_nodes))
	game.free()
	await physics_frame


func _waves() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var sizes := []
	for i in 4:
		mod.weak.step(mod.clock + 100.0)
		mod._step_crew()
		var before: int = _fitters(mod).size()
		mod._open_hatch(1)
		sizes.append(_fitters(mod).size() - before)
	_t.check("a hatch opening spawns 3 fitters, the 4th opening in one floor phase spawns none", sizes == [3, 3, 3, 0], str(sizes))
	_t.check("the wave counter stands at the per-phase limit", mod._crew_waves == Waking.CREW_WAVES_PER_PHASE, str(mod._crew_waves))
	mod.weak.step(mod.clock + 100.0)
	mod._step_crew()
	mod.phase = 2
	mod._open_point("hatch_2")
	_t.check("the counter resets when the floor phase advances: a wave comes", _fitters(mod).size() == 3 and mod._crew_waves == 1, str(_fitters(mod).size()))
	mod.weak.step(mod.clock + 100.0)
	mod._step_crew()
	mod.phase = 4
	mod._open_point("override")
	_t.check("the pit override is its own phase's hatch and calls a wave", _fitters(mod).size() == 3 and mod._crew_waves == 1, str(_fitters(mod).size()))
	var head: Vector3 = mod.weak_part("override").global_position
	var far := true
	for f in _fitters(mod):
		far = far and Vector2(f.global_position.x - head.x, f.global_position.z - head.z).length() > 30.0
	_t.check("fitters spawn far from the hatch, so the player has travel time", far, "")
	game.free()
	await physics_frame
	var capped = await _boot({"waking.weak_points": 1.0})
	var cmod = capped[1]
	cmod.phase = 1
	cmod._open_point("hatch_1")
	cmod._open_point("hatch_2")
	var six: int = _fitters(cmod).size()
	cmod._open_point("hatch_3")
	var still_six: int = _fitters(cmod).size()
	_t.check("never more than 6 alive: 3 then 3 then none", six == 6 and still_six == 6, "%d %d" % [six, still_six])
	_fitters(cmod)[0].remove_for_test()
	cmod.weak.step(cmod.clock + 100.0)
	cmod._open_point("override")
	_t.check("with one dead the next wave is 6 - alive = 1", _fitters(cmod).size() == 6 and cmod._crew_alive() == 6, str(_fitters(cmod).size()))
	capped[0].free()
	await physics_frame


# A ram-level reel strike on a fitter through the real damage path, as _real_damage: it knocks a fitting one off.
func _knock_one(mod, f) -> void:
	var kit = mod.ctx.player.kit
	kit.hooked = true
	kit.winching = true
	mod.ctx.spawner.strike(f, "ram", 60.0)
	kit.hooked = false
	kit.winching = false


func _open_two(mod) -> Array:
	mod._open_hatch(1)
	var all := _fitters(mod)
	for i in range(2, all.size()):
		all[i].remove_for_test()
	var two := all.slice(0, 2)
	for f in two:
		_seat(f)
	return two


func _fit_since(mod) -> float:
	return float(mod.weak._parts["hatch_1"]["fit_since"])


func _fit_clock() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, 0.1)
	var since := _fit_since(mod)
	_t.check("two fitters on their slots start the fit clock", since >= 0.0 and mod.weak.fitters("hatch_1") == 2 and two[0].state_name() == "fitting", str(since))
	await _step_until(mod, 1.0)
	_t.check("the fitter reads its seal progress and hatch", two[0].hatch_id() == "hatch_1" and two[0].seal_progress > 0.2 and two[0].seal_progress < 0.5, str(two[0].seal_progress))
	await _step_until(mod, since + 3.4 - mod.clock)
	_t.check("3.4 s of two fitters does not seal the hatch", mod.weak.state("hatch_1") == WeakPoints.OPEN, "%.3f" % (mod.clock - since))
	await _step_until(mod, 0.2)
	_t.check("3.5 s of two fitters seals it through the rule", mod.weak.state("hatch_1") == WeakPoints.SHUT and mod.weak.open_points().is_empty(), "%.3f" % (mod.clock - since))
	_t.check("the seal is recorded once with its hatch and floor phase", mod.weak_sealed.size() == 1 and mod.weak_sealed[0]["id"] == "hatch_1"
			and mod.weak_sealed[0]["phase"] == 1 and mod.weak.fit_seals("hatch_1") == 1, str(mod.weak_sealed))
	game.free()
	await physics_frame
	var lone = await _boot({"waking.weak_points": 1.0})
	var lmod = lone[1]
	var pair := _open_two(lmod)
	pair[1].remove_for_test()
	await _step_until(lmod, 5.0)
	_t.check("one fitter never seals it (held 5 s of the 6 s window)", lmod.weak.state("hatch_1") == WeakPoints.OPEN and lmod.weak.fitters("hatch_1") == 1
			and lmod.weak._parts["hatch_1"]["fit_since"] < 0.0, str(lmod.weak.fitters("hatch_1")))
	lone[0].free()
	await physics_frame


func _strike(mod, f, kind: String, reel: bool) -> void:
	var kit = mod.ctx.player.kit
	kit.hooked = reel
	kit.winching = reel
	mod.ctx.events.enemy_struck.emit(f, kind, 20.0)
	kit.hooked = false
	kit.winching = false


func _knock() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, 0.5)
	_strike(mod, two[0], "ram", false)
	_t.check("a plain contact does not knock a fitting fitter off", two[0].state_name() == "fitting" and mod.weak.fitters("hatch_1") == 2, two[0].state_name())
	_strike(mod, two[0], "bolt", true)
	_t.check("a reel line with a non-reel verb does not either", two[0].state_name() == "fitting" and mod.weak.fitters("hatch_1") == 2, two[0].state_name())
	_strike(mod, two[0], "ram", true)
	_t.check("a reel impact knocks it off: knock_fit called, one fitter left", two[0].state_name() == "knocked" and mod.weak.fitters("hatch_1") == 1, two[0].state_name())
	_t.check("and the fit clock is cleared below fit_min", _fit_since(mod) < 0.0, str(_fit_since(mod)))
	_strike(mod, two[0], "ram", true)
	_t.check("a second reel on the knocked fitter changes nothing", mod.weak.fitters("hatch_1") == 1, "")
	await _step_until(mod, CrewFitter.KNOCK_SECONDS + 0.1)
	_t.check("after KNOCK_SECONDS it is inbound or back on the hatch", two[0].state_name() in ["inbound", "fitting"], two[0].state_name())
	game.free()
	await physics_frame


# The real damage path (combat's strike and door pass), not a bare enemy_struck: a ram-level reel impact must knock a
# fitting fitter off and never hurt or kill it, so no kill, meter or on-kill effect books for a harmless drone.
func _real_damage() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, 0.5)
	var f = two[0]
	var kills: int = mod.ctx.run.kills
	var kit = mod.ctx.player.kit
	kit.hooked = true
	kit.winching = true
	mod.ctx.spawner.strike(f, "ram", 60.0)
	kit.hooked = false
	kit.winching = false
	_t.check("a real ram-level reel strike dislodges a fitting fitter", f.state_name() == "knocked", f.state_name())
	_t.check("and it is still alive and valid, at full health", is_instance_valid(f) and not f.is_dead() and f.hp == f.max_hp, str(f.hp))
	_t.check("and no kill is recorded", mod.ctx.run.kills == kills, "%d %d" % [mod.ctx.run.kills, kills])
	_t.check("a fitter is not crushable, and combat predicts no crush on it", f.crushable() == false and mod.ctx.spawner.would_crush(f, "ram", 60.0) == false,
			"%s %s" % [f.crushable(), mod.ctx.spawner.would_crush(f, "ram", 60.0)])
	_t.check("and plate_drop is discovered", "plate_drop" in game.ctx.codex.discovered_this_run(), "")
	await _step_until(mod, CrewFitter.KNOCK_SECONDS + 0.1)
	_t.check("after KNOCK_SECONDS it is inbound again", is_instance_valid(f) and f.state_name() in ["inbound", "fitting"], f.state_name() if is_instance_valid(f) else "freed")
	game.free()
	await physics_frame


func _retire() -> void:
	for how in ["sealed", "timeout", "broken", "floor gone"]:
		var booted = await _boot({"waking.weak_points": 1.0})
		var game = booted[0]
		var mod = booted[1]
		mod._open_hatch(1)
		var wave := _fitters(mod)
		_seat(wave[0])
		_seat(wave[1])
		await _step_until(mod, 0.1)
		var kills: int = mod.ctx.run.kills
		_killed = 0
		match how:
			"sealed":
				await _step_until(mod, WeakPoints.FIT_SECONDS + 0.2)
			"timeout":
				mod.weak.step(mod.clock + 100.0)
			"broken":
				mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "hatch_1", "ram")
			"floor gone":
				_drop_floors(mod, 1)
		mod._step_crew()
		var gone := true
		for f in wave:
			gone = gone and (not is_instance_valid(f) or (f.state_name() == "retiring" and f.is_queued_for_deletion()))
		var closed: bool = mod.weak.state("hatch_1") != WeakPoints.OPEN or how == "floor gone"
		_t.check("%s: the hatch closed and every fitter retired" % how, gone and closed and mod.crew().is_empty(), how)
		_t.check("%s: no kill, no kill event, no fit left on the rule" % how, mod.ctx.run.kills == kills and _killed == 0 and mod.weak.fitters("hatch_1") == 0,
				"%d %d %d" % [mod.ctx.run.kills - kills, _killed, mod.weak.fitters("hatch_1")])
		game.free()
		await physics_frame


func _bot() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, 0.1)
	var hatch = mod.weak_part("hatch_1")
	var expert = BotDriver.new(game, "skipper", 1)
	expert.band = SkillBand.make("expert", 1, 1)
	var rng_before: int = expert.rng.state
	expert._read_weak_points(mod, 0.016)
	var pick = expert._open_fitter(mod)
	_t.check("expert: the target is a fitting fitter, not the hatch", pick in two and pick != hatch and expert.rng.state == rng_before, str(pick))
	expert._fight_posture_boss(mod, 0.016)
	_t.check("expert: the fight goal names the fitter", expert._goal.begins_with("fitter"), expert._goal)
	# Both still counted (the clock runs), so only the state can make an inbound one no target.
	for f in two:
		f.fit_state = f.State.INBOUND
	_t.check("expert: an inbound fitter is no target", mod.weak.fitters("hatch_1") >= mod.weak.fit_min and expert._open_fitter(mod) == null,
			"fitters %d, %s" % [mod.weak.fitters("hatch_1"), str(expert._open_fitter(mod))])
	for f in two:
		f.fit_state = f.State.FITTING
	_knock_one(mod, two[0])
	_t.check("expert: below fit_min the clock stops, and the hatch is the target", mod.weak.fitters("hatch_1") < mod.weak.fit_min
			and expert._open_fitter(mod) == null and expert._open_part(mod) == hatch, "fitters %d, %s" % [mod.weak.fitters("hatch_1"), str(expert._open_fitter(mod))])
	for f in two:
		f.remove_for_test()
	mod._step_crew()
	expert._read_weak_points(mod, 0.016)
	_t.check("expert: with the crew gone the hatch is the target again", expert._open_fitter(mod) == null and expert._open_part(mod) == hatch, "")
	game.free()
	await physics_frame
	var nov = await _boot({"waking.weak_points": 1.0})
	var nmod = nov[1]
	_open_two(nmod)
	await _step_until(nmod, 0.1)
	var novice = BotDriver.new(nov[0], "skipper", 1)
	novice.band = SkillBand.make("novice", 1, 1)
	var state_before: int = novice.rng.state
	novice._read_weak_points(nmod, 0.016)
	novice._fight_posture_boss(nmod, 0.016)
	_t.check("novice: targets neither a fitter nor the hatch and draws nothing", novice._open_fitter(nmod) == null and novice._open_part(nmod) == null
			and not novice._goal.begins_with("fitter") and not novice._goal.begins_with("part") and novice.rng.state == state_before, novice._goal)
	nov[0].free()
	await physics_frame


# L1: weak.step runs before _step_crew, so a fitter that dies on the tick its fit reaches FIT_SECONDS must already
# have given its fit back (the died signal), or the hatch seals with one live fitter.
func _death_on_the_sealing_tick() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, WeakPoints.OPEN_MIN + 0.1)
	_t.check("sealing tick: both fitters are counted before the kill", mod.weak.fitters("hatch_1") == 2, str(mod.weak.fitters("hatch_1")))
	# Shorten the rule's fit so the next tick's weak.step, whatever the tick length, is the one that would seal (past OPEN_MIN, which holds a seal back).
	mod.weak.fit_seconds = mod.clock - _fit_since(mod) + 0.00001
	two[1].remove_for_test()
	# A resumed await runs before that frame's nodes do, so the second one is after the boss's tick.
	await physics_frame
	await physics_frame
	_t.check("sealing tick: a fitter dying on it does not seal the hatch", mod.weak.state("hatch_1") == WeakPoints.OPEN and mod.weak.fit_seals("hatch_1") == 0
			and mod.weak_sealed.is_empty(), str(mod.weak.state("hatch_1")))
	_t.check("sealing tick: its fit is given back exactly once", mod.weak.fitters("hatch_1") == 1 and mod.weak._parts["hatch_1"]["fit_since"] < 0.0, str(mod.weak.fitters("hatch_1")))
	await physics_frame
	_t.check("sealing tick: _step_crew does not take it a second time", mod.weak.fitters("hatch_1") == 1, str(mod.weak.fitters("hatch_1")))
	game.free()
	await physics_frame


# L2: the seal record and the counts outlive the crew's retirement and the Warden's death, and the next entry clears them.
func _record_survives() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	_open_two(mod)
	await _step_until(mod, WeakPoints.FIT_SECONDS + 0.3)
	_t.check("record: the crew sealed the hatch", mod.weak_sealed.size() == 1 and mod.weak_stats["sealed"] == {"1": 1}, str(mod.weak_sealed))
	mod._on_warden_died(Vector3.ZERO, 0)
	_t.check("record: the seal and the counts survive the Warden's death", mod.weak_sealed.size() == 1 and mod.weak_stats["sealed"] == {"1": 1}
			and mod.weak_stats["opened"] == {"1": 1} and mod.crew().is_empty(), str(mod.weak_stats))
	mod.exit_arena()
	_t.check("record: and leaving the arena", mod.weak_sealed.size() == 1 and mod.weak_stats["sealed"] == {"1": 1}, str(mod.weak_stats))
	mod.enter_arena(Vector3.ZERO)
	_t.check("record: the next arena entry clears it", mod.weak_sealed.is_empty() and mod.weak_stats["sealed"].is_empty()
			and mod.weak_stats["opened"].is_empty() and mod.weak_stats["crew_waves"].is_empty(), str(mod.weak_stats))
	game.free()
	await physics_frame


# N7: only a reel impact moves a fitter off its plate. A plain shove (enemy.knock), with no re-seat helper at work,
# leaves a fitting fitter on its slot and its fit counted; dislodge still takes it off.
func _plain_shove() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await physics_frame
	await physics_frame
	var f = two[0]
	_t.check("shove: the fitter is fitting and counted", f.state_name() == "fitting" and mod.weak.fitters("hatch_1") == 2, f.state_name())
	f.knock(Vector3(1.0, 0.0, 0.0), 40.0)
	var off := 0.0
	var until: float = mod.clock + 0.3
	while mod.clock < until:
		await physics_frame
		off = maxf(off, f.global_position.distance_to(f.slot))
	_t.check("shove: a plain knock leaves it seated, still fitting and still counted", f.state_name() == "fitting" and off <= 0.25
			and mod.weak.fitters("hatch_1") == 2, "%s %.2f %d" % [f.state_name(), off, mod.weak.fitters("hatch_1")])
	mod._crew_struck(f, "ram")
	_t.check("shove: a plain contact event does not either", f.state_name() == "fitting" and mod.weak.fitters("hatch_1") == 2, f.state_name())
	game.free()
	await physics_frame


# L3: the Learner goes for a fitter after the hatch has been open 0.6 s and only when its one roll is under 0.5.
func _learner() -> void:
	var seeds := {}
	for s in 200:
		var probe := RandomNumberGenerator.new()
		probe.seed = s
		seeds["go" if probe.randf() < 0.5 else "skip"] = s
		if seeds.size() == 2:
			break
	for how in ["go", "skip"]:
		var booted = await _boot({"waking.weak_points": 1.0})
		var game = booted[0]
		var mod = booted[1]
		var two := _open_two(mod)
		await _step_until(mod, 0.1)
		var learner = BotDriver.new(game, "skipper", 1)
		learner.band = SkillBand.make("learner", 1, 1)
		learner.rng.seed = int(seeds[how])
		learner._read_weak_points(mod, 0.3)
		var early = learner._open_fitter(mod)
		learner._read_weak_points(mod, 0.31)
		var late = learner._open_fitter(mod)
		learner._fight_posture_boss(mod, 0.016)
		if how == "go":
			_t.check("learner (roll under 0.5): no fitter before 0.6 s", early == null, str(early))
			_t.check("learner (roll under 0.5): after 0.6 s it targets a fitting fitter before the hatch", late in two and learner._goal.begins_with("fitter"), learner._goal)
		else:
			_t.check("learner (roll skipped): it never targets the fitter", early == null and late == null and not learner._goal.begins_with("fitter"), learner._goal)
		game.free()
		await physics_frame


# The record the sweep reads: one seal and one timeout in a dial 1 fight, counted per floor phase.
func _stats() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, WeakPoints.FIT_SECONDS + 0.3)
	mod._open_point("hatch_2")
	mod.weak.step(mod.clock + 100.0)
	await physics_frame
	var bot = BotDriver.new(game, "skipper", 1)
	bot._on_boss_entered()
	_t.check("record shape: the weak fields start null", bot.boss_note.has("weak_opened") and bot.boss_note["weak_opened"] == null and bot.boss_note["weak_sealed"] == null
			and bot.boss_note["weak_timed_out"] == null and bot.boss_note["weak_broken"] == null and bot.boss_note["crew_waves"] == null
			and bot.boss_note.has("weak_open_at_end") and bot.boss_note["weak_open_at_end"] == null, str(bot.boss_note.keys()))
	bot._boss_weak_note(mod)
	var n: Dictionary = bot.boss_note
	_t.check("record: two openings, one seal, one timeout, no break, two waves, all on phase 1",
			n["weak_opened"] == {"1": 2} and n["weak_sealed"] == {"1": 1} and n["weak_timed_out"] == {"1": 1}
			and (n["weak_broken"] as Dictionary).is_empty() and n["crew_waves"] == {"1": 2}, str(n))
	mod._open_point("hatch_3")
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "hatch_3", "ram")
	await physics_frame
	_t.check("record: a broken seal counts as broken, not as a timeout", mod.weak_stats["broken"] == {"1": 1} and mod.weak_stats["timed_out"] == {"1": 1}, str(mod.weak_stats))
	game.free()
	await physics_frame
	var off = await _boot({"waking.weak_points": 0.0})
	var obot = BotDriver.new(off[0], "skipper", 1)
	obot._on_boss_entered()
	obot._boss_weak_note(off[1])
	_t.check("dial 0: the weak fields stay null and nothing is counted", obot.boss_note["weak_opened"] == null and obot.boss_note["crew_waves"] == null and obot.boss_note["weak_open_at_end"] == null
			and off[1].weak_stats["opened"].is_empty(), "")
	off[0].free()
	await physics_frame


# The fitting cue (step 2c): the seam brightens with the fit clock, the plate is held then fitted or dropped, and the
# seal tick sounds only while fit_min fitters fit. Evidence limit: material energies and node state, not a render.
func _cue_and_plate() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	mod._open_hatch(1)
	var all := _fitters(mod)
	for i in range(2, all.size()):
		all[i].remove_for_test()
	var two := all.slice(0, 2)
	await physics_frame
	await physics_frame
	_t.check("inbound: the seam stays at its normal lit state, no spark, no plate, no seal tick",
			is_equal_approx(two[0].seam_energy(), CrewFitter.SEAM_LIT) and not two[0].spark_visible() and mod._plates.is_empty() and mod.seal_cue_log.is_empty(),
			"%s" % two[0].seam_energy())
	_seat(two[0])
	await _step_until(mod, 0.2)
	_t.check("one fitting fitter shows the plate at fit start but sounds no seal tick (below fit_min)", mod._plates.has("hatch_1") and mod.seal_cue_log.is_empty(), str(mod.seal_cue_log.size()))
	_seat(two[1])
	var last := 0.0
	var rising := true
	var seen_on := false
	var seen_off := false
	var ticks_before: int = mod.seal_cue_log.size()
	var until: float = mod.clock + 3.0
	while mod.clock < until:
		for f in two:
			if f.fit_state == f.State.FITTING:
				_seat(f)
		await physics_frame
		var e: float = two[0].seam_energy()
		rising = rising and e >= last - 0.0001 and e >= CrewFitter.SEAM_LIT - 0.0001
		last = e
		seen_on = seen_on or two[0].spark_visible()
		seen_off = seen_off or (two[0].fit_state == two[0].State.FITTING and not two[0].spark_visible())
	_t.check("fitting: the seam is lit and its brightness never falls as progress rises", rising and last > lerpf(CrewFitter.SEAM_LIT, CrewFitter.SEAM_SEALING, 0.5), "%s" % last)
	_t.check("fitting: a weld spark flickers at the hatch contact (seen both lit and dark)", seen_on and seen_off, "%s %s" % [seen_on, seen_off])
	var ticks_log: Array = mod.seal_cue_log
	var climbs := ticks_log.size() - ticks_before >= 3 and float(ticks_log[-1][1]) > float(ticks_log[ticks_before][1]) and float(ticks_log[-1][0]) > float(ticks_log[ticks_before][0])
	_t.check("two fitting: the seal tick repeats and its pitch rises with progress", climbs, str(ticks_log.slice(ticks_before)))
	_t.check("the seal tick plays its own seal_ratchet cue, not the harpoon's lock_tick", mod.SEAL_SOUND == "seal_ratchet" and mod.SEAL_SOUND != "lock_tick", str(mod.SEAL_SOUND))
	# A missing recipe still bakes (a 0.12 s fallback blip), so the real two-click ratchet is the shorter buffer.
	var ratchet: PackedFloat32Array = SfxBank.new()._bake("seal_ratchet")
	_t.check("seal_ratchet has a recipe and bakes a non-empty buffer", SfxBank.has_recipe("seal_ratchet") and ratchet.size() > 0 and ratchet.size() < SfxBank.new()._bake("no_such_recipe_probe").size(), str(ratchet.size()))
	var plate = mod._plates.get("hatch_1")
	_t.check("the plate is held clear of the hatch, sized to its seat, inert",
			plate != null and plate is MeshInstance3D and plate.find_children("*", "CollisionObject3D", true, false).is_empty()
			and plate.get_groups().is_empty() and not (plate as MeshInstance3D).mesh.get_aabb().size.x < 3.0, "")
	_t.check("before the knock the plate_drop codex row is not found", not "plate_drop" in game.ctx.codex.discovered_this_run(), "")
	_strike(mod, two[0], "ram", true)
	await physics_frame
	_t.check("the reel knock-off finds the plate_drop codex row", "plate_drop" in game.ctx.codex.discovered_this_run(), str(game.ctx.codex.discovered_this_run()))
	_t.check("knocked: the seam goes dark and the spark stops", is_equal_approx(two[0].seam_energy(), CrewFitter.SEAM_DIM) and not two[0].spark_visible(), "%s" % two[0].seam_energy())
	var fallen: Array = mod._fallen
	_t.check("a knock below fit_min drops the plate: inert, no collision layer, not a target, not in any group",
			fallen.size() == 1 and not mod._plates.has("hatch_1") and not (fallen[0]["node"] is CollisionObject3D)
			and fallen[0]["node"].find_children("*", "CollisionObject3D", true, false).is_empty() and fallen[0]["node"].get_groups().is_empty(), str(fallen.size()))
	var ticks: int = mod.seal_cue_log.size()
	await _step_until(mod, 0.6)
	_t.check("the seal tick stops when fewer than fit_min fit", mod.seal_cue_log.size() == ticks, "%d -> %d" % [ticks, mod.seal_cue_log.size()])
	await _step_until(mod, 0.2)
	_t.check("the fallen plate lies still and a lone fitter does not pick up a new one", mod._fallen.size() == 1 and not mod._plates.has("hatch_1"), "")
	var guard := 0
	while two[0].state_name() == "knocked" and guard < 300:
		await physics_frame
		guard += 1
	_t.check("the frame KNOCKED ends the seam is back at its normal lit state, not stuck dim", two[0].state_name() == "inbound"
			and is_equal_approx(two[0].seam_energy(), CrewFitter.SEAM_LIT), "%s %s" % [two[0].state_name(), two[0].seam_energy()])
	_seat(two[0])
	await _step_until(mod, 0.3)
	_t.check("with fit_min fitters back a new plate is carried", mod._plates.has("hatch_1"), "")
	game.free()
	await physics_frame
	booted = await _boot({"waking.weak_points": 1.0})
	game = booted[0]
	mod = booted[1]
	two = _open_two(mod)
	await _step_until(mod, 0.5)
	_t.check("a fresh fit carries the plate", mod._plates.has("hatch_1"), "")
	await _step_until(mod, WeakPoints.FIT_SECONDS + 0.2)
	_t.check("on seal the plate is fitted: the hatch is SHUT and no plate is held", mod.weak.state("hatch_1") == WeakPoints.SHUT and not mod._plates.has("hatch_1"), "")
	var part = mod.weak_part("hatch_1")
	_t.check("and the shut hatch shows its cover", part._cover.visible and part.lit_colors().is_empty(), "")
	game.free()
	await physics_frame


func _total(stats: Dictionary, key: String) -> int:
	var n := 0
	for phase in stats[key]:
		n += int(stats[key][phase])
	return n


# Outcomes are filed under the floor phase the point opened in, not the phase live when the change is noticed, and
# the killing blow's outcome and the hatches still open at the end close the books exactly.
func _outcome_phase() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	mod._open_hatch(1)
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "hatch_1", "ram")
	mod.floors.chunks_shattered(1)
	await physics_frame
	await physics_frame
	_t.check("a break that costs a chunk files opened and broken under the opening phase 1", mod.phase == 2 and mod.weak_stats["opened"] == {"1": 1}
			and mod.weak_stats["broken"] == {"1": 1} and mod.weak_stats["timed_out"].is_empty(), "%d %s" % [mod.phase, str(mod.weak_stats)])
	game.free()
	await physics_frame
	booted = await _boot({"waking.weak_points": 1.0})
	game = booted[0]
	mod = booted[1]
	mod._open_hatch(1)
	mod.floors.chunks_shattered(1)
	mod.weak.step(mod.clock + 100.0)
	await physics_frame
	await physics_frame
	_t.check("a timeout after the floor drops files under the opening phase 1", mod.phase == 2 and mod.weak_stats["timed_out"] == {"1": 1}
			and mod.weak_stats["opened"] == {"1": 1}, "%d %s" % [mod.phase, str(mod.weak_stats)])
	game.free()
	await physics_frame
	booted = await _boot({"waking.weak_points": 1.0})
	game = booted[0]
	mod = booted[1]
	mod._open_hatch(1)
	mod._open_point("hatch_2")
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "hatch_1", "ram")
	mod._on_warden_died(Vector3.ZERO, 0)
	var s: Dictionary = mod.weak_stats
	_t.check("the killing blow's break is counted before the defeat", s["broken"] == {"1": 1}, str(s))
	_t.check("opened = sealed + timed_out + broken + open_at_end at fight end", _total(s, "opened") == 2 and _total(s, "opened")
			== _total(s, "sealed") + _total(s, "timed_out") + _total(s, "broken") + _total(s, "open_at_end") and mod.weak_open_at_end == {"1": 1}, str(s))
	game.free()
	await physics_frame


# A fitter node freed without emitting died still gives its fit back, so a wave can refill; the carried plate falls
# when fewer than fit_min remain.
func _freed_without_died() -> void:
	var booted = await _boot({"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var two := _open_two(mod)
	await _step_until(mod, 0.3)
	_t.check("two fitters fitting hold the plate", mod.weak.fitters("hatch_1") == 2 and mod._plates.has("hatch_1"), str(mod.weak.fitters("hatch_1")))
	two[0].queue_free()
	await physics_frame
	await physics_frame
	_t.check("freed without died: the fit count drops and the clock stops", mod.weak.fitters("hatch_1") == 1 and _fit_since(mod) < 0.0, str(mod.weak.fitters("hatch_1")))
	_t.check("and the carried plate falls", not mod._plates.has("hatch_1") and mod._fallen.size() == 1, str(mod._fallen.size()))
	game.free()
	await physics_frame
