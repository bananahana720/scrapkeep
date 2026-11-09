extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const T := preload("res://tests/support/t.gd")

# Call-ins (SOUND-STORY section 8, "Who talks on what"). Every caller has a voice of their own:
# a pilot talks in the notes of their own motif on their own instrument, bent; a site crew is
# two talkers trading words; Brindle ends each sentence held on the flat second; the Foreman is
# one pure note with every letter on the band's thirty-second grid and nothing bent or left to
# chance; Moss rings his bell and talks as he does at his bench. A line is laid out the same way
# every time. Through the game, one call books the line a moment ahead in the band's cue lane
# (the Foreman's on a sixteenth), dips the band, and returns how long the voice lasts; an unknown
# caller gets Moss's voice, and a call while the last caller is still talking stays silent.

const LINE := "Pump two is up. Mind the green seams, keeper."

var t := T.new("audio_call_in_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_voices()
	_pilots()
	_crew()
	_brindle()
	_foreman()
	_moss()
	Rows.stem_dir = "user://ace_stem_none"
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	_pump_to(audio, audio.engine.clock + Harmony.BAR)
	_call(audio)
	game.queue_free()
	await process_frame
	Rows.stem_dir = ""
	quit(t.verdict())


func _voices() -> void:
	var heard := {}
	var quiet: Array = []
	for speaker in Bank.CALLERS:
		var id: String = Bank.say_id(speaker, LINE)
		var buf: PackedFloat32Array = Bank.samples(id)
		if Synth.peak(buf) < 0.5 or absf(float(buf.size()) / Harmony.RATE - Bank.say_seconds(speaker, LINE)) > 0.01:
			quiet.append(speaker)
		heard[buf] = speaker
	t.check("every caller says a line in a voice of their own, as long as the bank says it is", quiet.is_empty() and heard.size() == Bank.CALLERS.size()
		and Bank.has_recipe(Bank.say_id("sable", LINE)), "%d callers, %d different renders, quiet or mistimed %s" % [Bank.CALLERS.size(), heard.size(), quiet])
	t.check("a line is said the same way twice", Bank.say_plan("sable", LINE) == Bank.say_plan("sable", LINE)
		and Bank.say_plan("sable", LINE) != Bank.say_plan("sable", LINE + " Go."), "sable, twice")
	var levels: Array = Bank.CALLERS.keys().map(func(speaker: String): return Bank.trim_db(Bank.say_id(speaker, LINE)))
	t.check("each voice is levelled against Moss's", Bank.trim_db(Bank.say_id("moss", LINE)) == Bank.TRIM_DB["babble"]
		and levels.min() >= Bank.TRIM_DB["babble"] - 3.0 and levels.max() <= Bank.TRIM_DB["babble"] + 5.0, "trims %s" % [levels])


func _pilots() -> void:
	var off: Array = []
	for speaker in Harmony.CLASS_MOTIFS:
		var own: Array = Harmony.motif_notes(speaker).map(func(midi: int): return midi + 12)
		var plan: Array = Bank.say_plan(speaker, LINE)[0]
		var body: Array = plan.slice(2).filter(func(blip: Array): return not (int(blip[1]) in own))
		var chirp := [int(plan[0][1]), int(plan[1][1])]
		if not Bank.CALLERS.has(speaker) or not body.is_empty() or chirp != [own[0], own[own.size() - 1]]:
			off.append(speaker)
	t.check("a pilot talks in the notes of their own motif, and chirps its first and last", off.is_empty(), "off their motif: %s" % [off])
	var voices: Array = Harmony.CLASS_MOTIFS.map(func(speaker: String): return Bank.caller_voice(speaker))
	t.eq("each pilot on an instrument of their own", voices, ["bell", "clav", "tom", "fbass", "keys", "chime"])
	var bends: Array = Harmony.CLASS_MOTIFS.map(func(speaker: String): return Bank.say_plan(speaker, LINE)[0].filter(func(blip: Array): return float(blip[4]) != 0.0).size())
	t.check("the crew bend their notes", bends.min() > 5, "bent letters per pilot %s" % [bends])
	var rivet: Array = Bank.say_plan("rivet", "Go now go")[0]
	var gap := float(rivet[5][0]) - float(rivet[4][0]) - float(rivet[4][2])
	t.check("Rivet never stops between words", absf(gap) < 0.0001, "gap after his first word %.4f s" % gap)


func _crew() -> void:
	var plan: Array = Bank.say_plan("pump_crew", "Pump two is up")[0].slice(2)
	var first := [62, 65, 69]
	var second := first.map(func(midi: int): return Harmony.scale_shift(midi, -3, Harmony.DORIAN))
	var words := [plan.slice(0, 4), plan.slice(4, 7), plan.slice(7, 9), plan.slice(9, 11)]
	var sides: Array = words.map(func(word: Array): return _talker(word, first, second))
	var overlap := float(plan[3][0]) + float(plan[3][2]) - float(plan[4][0])
	t.check("a site crew is two talkers trading words, the second in before the first is done",
		sides == ["first", "second", "first", "second"] and is_equal_approx(overlap, Bank.CALL_OVERLAP_S),
		"words by %s, overlap %.3f s" % [sides, overlap])
	var roots: Array = ["pump_crew", "flume_crew", "signal_crew"].map(func(speaker: String): return Bank.caller_notes(speaker)[0])
	t.eq("each post sits on its own note", roots, [62, 64, 67])


func _talker(word: Array, first: Array, second: Array) -> String:
	if word.all(func(blip: Array): return int(blip[1]) in first):
		return "first"
	return "second" if word.all(func(blip: Array): return int(blip[1]) in second) else "mixed"


func _brindle() -> void:
	var plan: Array = Bank.say_plan("brindle", "Nine parts taken. I make that ten.")[0].slice(2)
	var ends: Array = [plan[13], plan[plan.size() - 1]].map(func(blip: Array): return [int(blip[1]), snappedf(float(blip[2]), 0.01)])
	t.check("Brindle ends each sentence held on the flat second, on brass", ends == [[63, 0.28], [63, 0.28]] and Bank.caller_voice("brindle") == "brass"
		and plan.all(func(blip: Array): return int(blip[1]) in [62, 63]), "sentence ends %s" % [ends])


func _foreman() -> void:
	var step := Harmony.STEP * 4 / 3
	var plan: Array = Bank.say_plan("mind", "Quick sync? No action is required.", step)[0]
	var half := float(step) / Harmony.RATE / 2.0
	var off: Array = plan.filter(func(blip: Array): return absf(float(blip[0]) / half - roundf(float(blip[0]) / half)) > 0.0001)
	var body: Array = plan.slice(2)
	var uneven: Array = body.filter(func(blip: Array): return blip.slice(1) != [74, half * 0.7, 1.0, 0.0, Bank.PURE])
	t.check("the Foreman is one pure note, every letter on the thirty-second grid, nothing bent, no rise on a question",
		off.is_empty() and uneven.is_empty()
		and [int(plan[0][1]), int(plan[1][1])] == [74, 81] and Bank.caller_on_grid("mind") and not Bank.caller_on_grid("sable"),
		"%d letters, %d off the grid, chirp %s" % [body.size(), off.size(), [plan[0][1], plan[1][1]]])
	var id: String = Bank.say_id("mind", "Quick sync.")
	var slow: int = Bank.samples_at(id, step).size()
	var fast: int = Bank.samples_at(id, Harmony.STEP).size()
	t.check("its line is made for the band's step", slow > fast and Bank.say_seconds("mind", "Quick sync.", step) > Bank.say_seconds("mind", "Quick sync."),
		"%d samples at the roaming step, %d at a step a third longer" % [fast, slow])
	var letter: PackedFloat32Array = Bank._letter(Bank.PURE, 74, 0.05, 0.0)
	t.check("the pure voice starts, holds and stops", absf(Synth.peak(letter) - 1.0) < 0.01 and absf(letter[0]) < 0.001 and absf(letter[letter.size() - 1]) < 0.001,
		"peak %.3f" % Synth.peak(letter))


func _moss() -> void:
	var plan: Array = Bank.say_plan("moss", LINE)[0]
	var bench: Array = Bank._babble_blips(LINE, Bank.BABBLE_LEVEL)[0]
	var body: Array = plan.slice(2)
	var same: Array = range(mini(body.size(), bench.size())).filter(func(i: int): return body[i][5] == "" and int(body[i][1]) == int(bench[i][1]) and is_equal_approx(float(body[i][0]), float(bench[i][0]) + Bank.CALL_TALK_S))
	t.check("Moss rings his bell twice and talks as he does at his bench", body.size() == bench.size()
		and [plan[0][1], plan[1][1], plan[0][5]] == [86, 86, "mallet"] and same.size() == body.size(),
		"%d letters after the bell, %d at the bench" % [body.size(), bench.size()])
	Bank.unknown_callers.clear()
	t.check("a caller with no row gets Moss's voice", Bank.say_plan("nobody", LINE) == Bank.say_plan("moss", LINE) and Bank.unknown_callers.has("nobody"),
		"warned about %s" % [Bank.unknown_callers.keys()])


func _call(audio) -> void:
	var engine = audio.engine
	var lead := int(audio.CALL_LEAD_S * Harmony.RATE)
	audio.cue_log.clear()
	engine.stinger_starts.clear()
	audio._last_start.clear()
	var booked: int = engine.clock
	var seconds: float = audio.call_in("call_in", "pump_crew", LINE)
	var id: String = Bank.say_id("pump_crew", LINE)
	var calls: Array = audio.cue_log.filter(func(e: Array): return e[2] == "call")
	var at: int = int(calls[0][3]) if not calls.is_empty() else -1
	t.check("a call is booked a moment ahead and says how long the voice lasts", calls.size() == 1 and at == booked + lead
		and is_equal_approx(seconds, audio.CALL_LEAD_S + Bank.say_seconds("pump_crew", LINE)), "at %d (clock %d), %.2f s" % [at, booked, seconds])
	var over: float = audio.call_in("call_in", "sable", LINE)
	t.check("a call while the last caller is still talking stays silent", over == 0.0
		and audio.cue_log.filter(func(e: Array): return e[2] == "call").size() == 1, "returned %.2f" % over)
	_pump_to(audio, at + 64)
	var sounded: Array = engine.stinger_starts.filter(func(s: Array): return s[0] == id).map(func(s: Array): return int(s[1]))
	t.check("the line sounds at that sample, already made", sounded == [at] and Bank.cached_at(id, audio.grid_unit(4), engine.stinger_key(at)),
		"sounded at %s" % [sounded])
	audio.clock += seconds
	audio.cue_log.clear()
	var empty: float = audio.call_in("call_in", "mind", "")
	var from: int = engine.clock
	var memo: float = audio.call_in("call_in", "mind", "Quick sync.")
	var grid_at: int = int(audio.cue_log.filter(func(e: Array): return e[2] == "call")[0][3])
	var unit: int = audio.grid_unit(4)
	t.check("the Foreman's call starts on the band's sixteenth", posmod(grid_at - audio.next_grid(4), unit) == 0 and grid_at >= from + lead
		and grid_at < from + lead + unit and memo > Bank.say_seconds("mind", "Quick sync.", unit) and empty == 0.0, "at %d, %d past a sixteenth of %d" % [grid_at, posmod(grid_at - audio.next_grid(4), unit), unit])


func _pump_to(audio, until: int) -> void:
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))
