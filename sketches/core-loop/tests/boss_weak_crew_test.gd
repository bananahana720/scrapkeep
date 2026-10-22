extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const Waking := preload("res://src/boss/waking.gd")
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
	await _retire()
	await _death_on_the_sealing_tick()
	await _record_survives()
	await _plain_shove()
	await _bot()
	await _learner()
	await _stats()
	await _outcome_phase()
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
	var booted = await _boot({})
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
	_fitters(cmod)[0].take_damage(1000.0)
	cmod.weak.step(cmod.clock + 100.0)
	cmod._open_point("override")
	_t.check("with one dead the next wave is 6 - alive = 1", _fitters(cmod).size() == 6 and cmod._crew_alive() == 6, str(_fitters(cmod).size()))
	capped[0].free()
	await physics_frame


func _open_two(mod) -> Array:
	mod._open_hatch(1)
	var all := _fitters(mod)
	for i in range(2, all.size()):
		all[i].take_damage(1000.0)
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
	pair[1].take_damage(1000.0)
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
	for f in two:
		f.take_damage(1000.0)
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
	two[1].take_damage(1000.0)
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
			and bot.boss_note["weak_timed_out"] == null and bot.boss_note["weak_broken"] == null and bot.boss_note["crew_waves"] == null, str(bot.boss_note.keys()))
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
	var off = await _boot({})
	var obot = BotDriver.new(off[0], "skipper", 1)
	obot._on_boss_entered()
	obot._boss_weak_note(off[1])
	_t.check("dial 0: the weak fields stay null and nothing is counted", obot.boss_note["weak_opened"] == null and obot.boss_note["crew_waves"] == null
			and off[1].weak_stats["opened"].is_empty(), "")
	off[0].free()
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
