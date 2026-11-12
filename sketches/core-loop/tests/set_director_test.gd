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
	_deterministic()
	_book()
	_band_trims()
	t.eq("the switch is off by default", Tuning.new().option(Tuning.SET_DIRECTOR_KEY), "off")
	await _in_game()
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
	for room in [{"pressure": 0.35, "warning": true}, {"pressure": 0.35, "busy": true}, {"fight": "open"}, {"fight": "drop"}, {"fight": "piece"}]:
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
	var e := SetDirector.new()
	t.eq("a set piece one bar out swaps the bass", e.read({"pressure": 0.1, "incoming_bars": 1}).move, "bass_swap")
	t.eq("not inside a fight", SetDirector.new().read({"fight": "closed", "incoming_bars": 1}).move, "hold")
	var b := SetDirector.new()
	var plans := _run(b, {"pressure": 0.0, "warning": true}, SetDirector.PHRASE_BARS * (SetDirector.BREATH_PHRASES + 1))
	var breaths := plans.filter(func(p): return p.move == "breath")
	t.eq("a long lull takes one breath on a turnaround", breaths.map(func(p): return [p.bar % SetDirector.PHRASE_BARS, p.trims]),
		[[SetDirector.PHRASE_BARS - 1, {"drums": 0.0}]])


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
	a.reset()
	t.eq("reset starts the set again", [a.bar, a.mood, a.plans.size()], [-1, "lull", 0])


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
