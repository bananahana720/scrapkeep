extends SceneTree

const SetDirector := preload("res://src/presentation/set_director.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# The set director (set_director.gd, SOUND-BIBLE "The set"): the DJ reads the room once a bar.
# A mood climbs on the next bar and falls only after holding low; a peak falls through release.
# June answers on each phrase's last bar, walking her book in order, never twice the same in a
# row, never over a warning, another melody or a fight section that owns the lead, and never on
# a threat note. The bass steps out the bar before a peak or an announced set piece. The same
# rooms give the same set. The recorded band applies trims only to undirected sections and
# clears them when it stops. The switch is off by default.

var t := T.new("set_director_test")


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_moods()
	_answers()
	_gates()
	_colours()
	_swap_and_breath()
	_move_rate()
	_deterministic()
	_book()
	_band_trims()
	t.eq("the switch is off by default", Tuning.new().option(Tuning.SET_DIRECTOR_KEY), "off")
	await _in_game()
	_trims_on_joins()
	quit(t.verdict())


func _run(d: SetDirector, room: Dictionary, bars: int) -> Array:
	var plans: Array = []
	for i in bars:
		plans.append(d.read(room))
	return plans


func _moods() -> void:
	var d := SetDirector.new()
	t.eq("a quiet room is a lull", _run(d, {"pressure": 0.0}, 1)[0].mood, "lull")
	t.eq("pressure over the build line builds on the next bar", d.read({"pressure": 0.35}).mood, "build")
	t.eq("over the peak line peaks on the next bar", d.read({"pressure": 0.7}).mood, "peak")
	t.eq("a dip under the peak line holds the peak for a bar", d.read({"pressure": 0.4}).mood, "peak")
	t.eq("held low, the peak falls into release", d.read({"pressure": 0.4}).mood, "release")
	t.eq("release lasts its bars", d.read({"pressure": 0.4}).mood, "release")
	t.eq("then the room's own mood", d.read({"pressure": 0.4}).mood, "build")
	t.eq("hovering between the build lines keeps the build", d.read({"pressure": 0.22}).mood, "build")
	var f := SetDirector.new()
	t.eq("the guard holding is a build", f.read({"fight": "closed"}).mood, "build")
	t.eq("the guard cracking is the peak", f.read({"fight": "telegraph"}).mood, "peak")
	t.eq("the breath is release at once", f.read({"fight": "open"}).mood, "release")
	t.eq("the drop is the peak", f.read({"fight": "drop"}).mood, "peak")


func _answers() -> void:
	var d := SetDirector.new()
	var plans := _run(d, {"pressure": 0.35}, 32)
	var answers: Array = []
	for p in plans:
		if p.answer != "":
			answers.append([p.bar, p.answer])
			t.check("an answer gives the lead room", is_equal_approx(float(p.trims.get("other", 1.0)), SetDirector.LEAD_SPACE), str(p))
	t.eq("an answer on each phrase's last bar", answers.map(func(a): return a[0]), [7, 15, 23, 31])
	t.eq("the build book is walked in order", answers.map(func(a): return a[1]), ["build_a", "build_b", "build_c", "build_d"])
	for i in range(1, answers.size()):
		t.check("never the same answer twice in a row", answers[i][1] != answers[i - 1][1], str(answers))


func _gates() -> void:
	for room in [{"pressure": 0.35, "warning": true}, {"pressure": 0.35, "busy": true}, {"fight": "open"}, {"fight": "drop"}, {"fight": "piece"}, {"fight": "anthem"}]:
		var plans := _run(SetDirector.new(), room, 8)
		t.eq("no answer over %s" % [room], plans[7].answer, "")
	t.check("the guard holding still gets an answer", _run(SetDirector.new(), {"fight": "closed"}, 8)[7].answer.begins_with("build"))


func _colours() -> void:
	t.check("a hot shell answers hot", _run(SetDirector.new(), {"pressure": 0.35, "heat": 2}, 8)[7].answer.begins_with("hot"))
	t.check("overtime answers with the shift", _run(SetDirector.new(), {"pressure": 0.35, "heat": 3, "overtime": true}, 8)[7].answer.begins_with("overtime"))
	t.check("hanging on outranks everything", _run(SetDirector.new(), {"pressure": 0.35, "overtime": true, "armour": 0.2}, 8)[7].answer.begins_with("hanging"))
	t.check("a cool shell answers by mood", _run(SetDirector.new(), {"pressure": 0.0, "heat": 1}, 8)[7].answer.begins_with("lull"))
	var d := SetDirector.new()
	_run(d, {"pressure": 0.7}, 4)
	var home := _run(d, {"pressure": 0.4}, 2)
	t.eq("the fall from a peak plays home", [home[1].move, home[1].answer.begins_with("release")], ["home", true])


func _swap_and_breath() -> void:
	var d := SetDirector.new()
	d.read({"pressure": 0.35})
	d.read({"pressure": 0.45})
	var swap := d.read({"pressure": 0.56})
	t.eq("rising toward the peak, the bass steps out", [swap.move, swap.trims], ["bass_swap", {"bass": 0.0}])
	t.eq("then the peak slams it back", d.read({"pressure": 0.7}).trims, {})
	var c := SetDirector.new()
	c.read({"pressure": 0.35})
	c.read({"pressure": 0.45})
	var climb := [0.53, 0.55, 0.57, 0.59, 0.6, 0.61].map(func(p): return c.read({"pressure": p}).move)
	t.eq("a long climb swaps the bass once", climb.count("bass_swap"), 1)
	c.read({"pressure": 0.35})
	t.eq("falling well back re-arms the swap", c.read({"pressure": 0.56}).move, "bass_swap")
	var h := SetDirector.new()
	h.read({"pressure": 0.35})
	h.read({"pressure": 0.45})
	var hover := [0.53, 0.51, 0.53, 0.51, 0.53].map(func(p): return h.read({"pressure": p}).move)
	t.eq("hovering under the peak line swaps once", hover.count("bass_swap"), 1)
	var l := SetDirector.new()
	var landing := [1, 1, 1].map(func(n): return l.read({"pressure": 0.1, "incoming_bars": n}).move)
	t.eq("one swap per announcement", landing.count("bass_swap"), 1)
	var e := SetDirector.new()
	e.read({"pressure": 0.1})
	t.eq("a set piece one bar out swaps the bass", e.read({"pressure": 0.1, "incoming_bars": 1}).move, "bass_swap")
	var f := SetDirector.new()
	f.read({"fight": "closed"})
	var roll := f.read({"fight": "closed", "incoming_bars": 1})
	t.eq("inside a fight the band rolls under the filter instead", [roll.move, roll.sweep, roll.trims], ["filter_roll", SetDirector.SWEEP_DEPTH, {}])
	var g := SetDirector.new()
	var guard := [0.45, 0.53, 0.47, 0.53, 0.46, 0.53, 0.47, 0.53].map(func(p): return g.read({"fight": "closed", "pressure": p}).move)
	var climbs := range(guard.size()).filter(func(i): return not i in [3, 7] and guard[i] == "filter_roll")
	t.eq("a guard flickering near the peak line rolls once on the climb", climbs.size(), 1)
	t.eq("the band's own directed sections hold", SetDirector.new().read({"fight": "directed", "incoming_bars": 1}).move, "hold")
	t.eq("the Warden's breath is its own move", SetDirector.new().read({"fight": "open", "incoming_bars": 1}).move, "hold")
	# Every phrase ends on a move: with June held out by a warning, the turnarounds walk the moves.
	var b := SetDirector.new()
	var plans := _run(b, {"pressure": 0.5, "fight": "closed", "warning": true}, SetDirector.PHRASE_BARS * 4)
	var turns := plans.filter(func(p): return p.bar % SetDirector.PHRASE_BARS == SetDirector.PHRASE_BARS - 1)
	t.eq("under a warning the turnarounds walk the moves", turns.map(func(p): return p.move), ["dub", "filter_roll", "breakdown", "dub"])
	var halves := plans.filter(func(p): return p.bar % SetDirector.PHRASE_BARS == SetDirector.PHRASE_BARS / 2 - 1)
	t.eq("in a fight the band turns at the half phrase too", halves.map(func(p): return p.move), ["filter_roll", "breakdown", "dub", "filter_roll"])
	var moved := plans.filter(func(p): return p.move != "hold")
	t.check("each takes sound away", moved.all(func(p): return p.answer == "" and (p.sweep > 0.0 or p.trims.values().all(func(g): return g < 1.0)) and not p.trims.is_empty() != (p.sweep > 0.0)), str(moved))
	var quiet := SetDirector.new()
	t.eq("a lull turns only at the phrase's end", _run(quiet, {"pressure": 0.0, "busy": true}, 8).map(func(p): return p.move).count("hold"), 7)
	t.check("never an answer under a warning", plans.all(func(p): return p.answer == ""))


# The move rate (assumption, 12 November 2026): a player hears at least one DJ move in every
# phrase the band plays outside a directed section. A scripted stretch of play: explore, a
# climb, a Warden fight under warnings, its breath and drop, then a boss anthem.
func _move_rate() -> void:
	var d := SetDirector.new()
	var stretch: Array = []
	for i in 24:
		stretch.append({"pressure": 0.1 + 0.02 * i})
	for i in 32:
		stretch.append({"fight": "closed", "pressure": 0.5, "warning": i % 3 == 0})
	for i in 4:
		stretch.append({"fight": "open"})
	for i in 2:
		stretch.append({"fight": "drop"})
	for i in 34:
		stretch.append({"fight": "anthem", "pressure": 0.7, "warning": i % 2 == 0})
	var plans := stretch.map(func(room): return d.read(room))
	var quiet := []
	for start in range(0, plans.size() - SetDirector.PHRASE_BARS + 1, SetDirector.PHRASE_BARS):
		var phrase: Array = plans.slice(start, start + SetDirector.PHRASE_BARS)
		var free := phrase.filter(func(p): return not String(d.plans[p.bar][6]) in SetDirector.OWN_FORM)
		if free.size() == SetDirector.PHRASE_BARS and free.all(func(p): return p.move == "hold"):
			quiet.append(start)
	t.eq("every phrase outside a directed section has a move", quiet, [])
	var heard := plans.filter(func(p): return p.move != "hold").size()
	t.check("about one move a phrase or more", heard >= plans.size() / SetDirector.PHRASE_BARS, "%d moves in %d bars" % [heard, plans.size()])


func _deterministic() -> void:
	var rooms: Array = []
	for i in 64:
		rooms.append({"pressure": fmod(i * 0.137, 1.0), "heat": i % 4, "speed": fmod(i * 0.31, 1.0), "warning": i % 11 == 0})
	var a := SetDirector.new()
	var b := SetDirector.new()
	for room in rooms:
		a.read(room)
		b.read(room)
	t.eq("the same rooms give the same set", a.plans, b.plans)
	var helds := a.plans.filter(func(p): return p[0] % SetDirector.PHRASE_BARS == SetDirector.PHRASE_BARS - 1 and p[3] == "").map(func(p): return p[5])
	t.check("a turnaround with no answer says why", not helds.is_empty() and not "" in helds, str(helds))
	a.reset()
	t.eq("reset starts the set again and keeps the run's plans", [a.bar, a.mood, a.plans.size()], [-1, "lull", 64])


func _book() -> void:
	for book in SetDirector.BOOK:
		for row in SetDirector.BOOK[book]:
			var id := String(row.id)
			var score := SetDirector.answer_score(id)
			t.check("%s has notes" % id, not score.is_empty())
			for cell in score:
				t.check("%s stays off the threat notes" % id, not posmod(int(cell[1]), 12) in SetDirector.THREAT_PITCH_CLASSES, str(cell))
				t.check("%s fits one bar" % id, int(cell[0]) < 16, str(cell))
			t.check("%s has a recipe" % id, Bank.has_recipe(Bank.SET_ANSWER + id))
	t.check("an unknown answer has no recipe", not Bank.has_recipe(Bank.SET_ANSWER + "nope"))


func _band_trims() -> void:
	var ace := AceSequencer.new()
	ace.mode = "level"
	ace.section = "travel"
	ace.trims = {"bass": 0.0, "other": 0.35, "drums": 1.7}
	t.eq("a trim pulls a stem", ace.trim_of("bass"), 0.0)
	t.eq("a trim never pushes a stem", ace.trim_of("drums"), 1.0)
	for name in ["pivot", "drop", "open", "break", "return", "home"]:
		t.eq("%s ignores trims" % name, ace.trim_of("bass", name), 1.0)
	ace.mode = "piece"
	t.eq("the directed piece ignores trims", ace.trim_of("bass", "travel"), 1.0)
	ace.mode = "level"
	ace.trim_at(0, {"bass": 0.5}, 10)
	t.eq("a trim is booked on the grid", ace.actions.back().type, "trim")
	ace.stop()
	t.eq("stopping the band clears its trims", ace.trims, {})


# A trim or its lift that fires inside a section change levels the voices by the section they
# belong to: a begun join's incoming section, and a join not yet begun by its own.
func _trims_on_joins() -> void:
	var ace := AceSequencer.new()
	if not t.check("the stage's band loads", ace.ready(), ace.missing):
		return
	ace.mode = "level"
	ace.section = "travel"
	var bass := AceSequencer.Voice.new()
	bass.stem = "bass"
	var pivot_bass: float = ace._gain_of(ace._profile("pivot")["bass"], "bass", "pivot")
	bass.target = pivot_bass
	bass.step = 0.002
	ace.voices = [bass]
	ace.pending = {"section": "pivot", "begun": true, "voices": [bass], "serial": 1}
	ace._run({"type": "trim", "trims": {"bass": 0.0}, "frames": 10})
	t.eq("a cut on the pivot's entry leaves its bass and its ramp alone", [bass.target, bass.step], [pivot_bass, 0.002])
	var step := bass.step
	ace._run({"type": "trim", "trims": {}, "frames": 10})
	t.eq("the pivot's own entry ramp keeps its pace through the lift", bass.step, step)
	var opened := AceSequencer.Voice.new()
	opened.stem = "bass"
	ace.pending = {"section": "build", "begun": false, "voices": [opened], "serial": 2, "ramp": 441}
	ace._run({"type": "trim", "trims": {"bass": 0.0}, "frames": 10})
	t.eq("a voice opened for a coming build takes the cut", opened.target, 0.0)
	ace._run({"type": "trim", "trims": {}, "frames": 10})
	t.check("and comes back with the lift", opened.target > 0.0, str(opened.target))
	t.check("at the join's own pace", is_equal_approx(opened.step, opened.target / 441.0), str(opened.step))
	var drums := AceSequencer.Voice.new()
	drums.stem = "drums"
	drums.target = 0.25
	drums.step = 0.001
	ace.pending = {}
	ace.voices = [drums]
	ace._run({"type": "trim", "trims": {"bass": 0.0}, "frames": 10})
	t.eq("a trim leaves an untouched stem's ramp alone", [drums.target, drums.step], [0.25, 0.001])
	var lead := AceSequencer.Voice.new()
	lead.stem = "other"
	ace.voices = [lead]
	ace._run({"type": "sweep", "depth": 0.85, "frames": 100})
	t.eq("a filter roll sweeps the voice under the low-pass", [lead.wet_target, lead.lp.is_empty()], [0.85, false])
	ace._run({"type": "trim", "trims": {}, "frames": 10, "sweep": 0.0})
	t.eq("and the bar line lifts it", [lead.wet_target, ace.sweep], [0.0, 0.0])
	ace._run({"type": "sweep", "depth": 0.85, "frames": 100})
	var pace := lead.wet_step
	ace._retarget(441)
	t.eq("a retarget mid-roll keeps the roll's pace", [lead.wet_target, lead.wet_step], [0.85, pace])
	ace._run({"type": "trim", "trims": {}, "frames": 10, "sweep": 0.0})
	ace.section = "pivot"
	ace._run({"type": "sweep", "depth": 0.85, "frames": 100})
	t.eq("a directed section is never swept", lead.wet_target, 0.0)
	ace.section = "travel"
	ace.trim_bar(ace.clock + 1000, {}, 400, 20, 0.85)
	t.eq("a roll books its sweep on the bar and its lift a sixteenth before the next", ace.actions.slice(-2).map(func(a): return [a.type, a.at - ace.clock]),
		[["sweep", 1000], ["trim", 1380]])


# Through the real game on the stage's recorded band (the stub tone in the cloud): off, the
# director books nothing; on, every plan lands on the band's bar line, June's answers sound on
# the stinger lane at the bar, and the lead's trim is booked and lifted a bar later.
func _in_game() -> void:
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	if t.check("the stage's recorded band plays", audio.ace_playing()):
		_bars(audio, 10)
		t.eq("switched off, the director books nothing", _set_log(audio), [])
		game.ctx.tuning.set_option(Tuning.SET_DIRECTOR_KEY, "on")
		var from: int = audio.ace.clock
		_bars(audio, 17)
		var answers := _set_log(audio).filter(func(e): return e[0] == "set_answer")
		t.check("switched on, June answers each phrase", answers.size() >= 2, str(answers))
		for e in answers:
			t.eq("an answer starts on the band's bar line", posmod(int(e[3]) - audio.ace.origin, audio.ace.grid_bar), 0)
			t.check("an answer is booked ahead of its bar", int(e[3]) > from)
		t.eq("every plan is one bar apart", _bar_steps(audio.set_director.plans), [1])
		var off_grid: Array = audio.set_director.plans.filter(func(p): return posmod(int(p[4]) - audio.ace.origin, audio.ace.grid_bar) != 0)
		t.eq("every plan carries its bar line's sample", off_grid, [])
		audio._gates["call_in"] = audio.clock + 1.0
		t.check("a caller talking keeps June out", audio._set_busy())
		audio._gates["call_in"] = audio.clock - 0.1
		t.check("a caller who finished does not", not audio._set_busy())
		audio._set_answer = "set_answer_build_0"
		audio._set_answer_at = audio.ace.next_bar()
		audio._focus_until = audio.clock + 1.0
		audio._tend_set()
		t.eq("a warning after the booking takes June's answer back", audio._set_answer, "")
		t.check("and logs it", _set_log(audio).any(func(e): return e[0] == "set_answer_dropped"))
		audio._focus_until = audio.clock
		audio._set_answer = "set_answer_build_0"
		audio._set_answer_at = audio.ace.clock - audio.ace.grid_bar / 4
		audio._gates["call_in"] = audio.clock + 1.0
		audio._tend_set()
		t.eq("a caller in the second half of June's bar takes her answer back too", audio._set_answer, "")
		audio._gates["call_in"] = audio.clock - 0.1
		game.ctx.tuning.set_option(Tuning.SET_DIRECTOR_KEY, "off")
		_bars(audio, 1)
		t.eq("switched off again, the director rests", audio.set_director.bar, -1)
	game.queue_free()
	await process_frame


func _bars(audio, count: int) -> void:
	for i in count * 4:
		audio._tend_set()
		var until: int = audio.engine.clock + audio.ace.grid_bar / 4
		while audio.engine.clock < until:
			audio._pump(mini(4096, until - audio.engine.clock))


func _set_log(audio) -> Array:
	return audio.cue_log.filter(func(e): return String(e[0]).begins_with("set_"))


func _bar_steps(plans: Array) -> Array:
	var steps := {}
	for i in range(1, plans.size()):
		steps[int(plans[i][0]) - int(plans[i - 1][0])] = true
	return steps.keys()
