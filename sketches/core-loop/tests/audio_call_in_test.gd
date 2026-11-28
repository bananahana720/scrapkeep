extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const Synth := preload("res://src/presentation/synth.gd")
const T := preload("res://tests/support/t.gd")

# Call-ins (SOUND-STORY section 8, "Who talks on what"). Every caller has a voice of their own:
# a pilot talks in the notes of their own motif, chirped on their own instrument and said
# through a mouth, bent; a site crew is two talkers trading words; Brindle ends each sentence held on the flat second; the Foreman is
# one pure note with every letter on the band's thirty-second grid and nothing bent or left to
# chance; Moss rings his bell and talks as he does at his bench. A line is laid out the same way
# every time. Through the game, one call books the line a moment ahead in the band's cue lane
# (the Foreman's on a sixteenth), dips the band, and returns how long the voice lasts; an unknown
# caller gets Moss's voice, and a call while the last caller is still talking stays silent.

const LINE := "Pump two is up. Mind the green seams, keeper."
# A line nothing has said before the call that books it.
const FRESH := "Relay's lit. We see you from here."

var t := T.new("audio_call_in_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_voices()
	_mouths()
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
	_call_end(audio)
	game.queue_free()
	await process_frame
	Rows.stem_dir = ""
	quit(t.verdict())


func _voices() -> void:
	var heard := {}
	var quiet: Array = []
	for speaker in VoiceSynth.CALLERS:
		var id: String = VoiceSynth.say_id(speaker, LINE)
		var buf: PackedFloat32Array = VoiceSynth.samples(id)
		if Synth.peak(buf) < 0.5 or absf(float(buf.size()) / Harmony.RATE - VoiceSynth.say_seconds(speaker, LINE)) > 0.01:
			quiet.append(speaker)
		heard[buf] = speaker
	t.check("every caller says a line in a voice of their own, as long as the bank says it is", quiet.is_empty() and heard.size() == VoiceSynth.CALLERS.size()
		and VoiceSynth.has_recipe(VoiceSynth.say_id("sable", LINE)), "%d callers, %d different renders, quiet or mistimed %s" % [VoiceSynth.CALLERS.size(), heard.size(), quiet])
	t.check("a line is said the same way twice", VoiceSynth._say_plan("sable", LINE) == VoiceSynth._say_plan("sable", LINE)
		and VoiceSynth._say_plan("sable", LINE) != VoiceSynth._say_plan("sable", LINE + " Go."), "sable, twice")
	var levels: Array = VoiceSynth.CALLERS.keys().map(func(speaker: String): return VoiceSynth.trim_db(VoiceSynth.say_id(speaker, LINE)))
	t.check("each voice is levelled against Moss's bench voice", VoiceSynth.trim_db(VoiceSynth.say_id("cannon", LINE)) == VoiceSynth.BABBLE_TRIM_DB
		and levels.min() >= VoiceSynth.BABBLE_TRIM_DB - 3.0 and levels.max() <= VoiceSynth.BABBLE_TRIM_DB + 7.0, "trims %s" % [levels])


# Everyone alive has a mouth (Andrew, 10 November 2026); the Foreman has none, and the Cannon,
# a machine on the crew's side, keeps its bent chime. Moss and Brindle, the low voices, are
# said high so they do not turn into the talking growls he ruled out.
func _mouths() -> void:
	var mouthed: Array = VoiceSynth.CALLERS.keys().filter(func(speaker: String): return VoiceSynth.CALLERS[speaker].has("mouth"))
	t.eq("everyone alive talks through a mouth; the Cannon and the Foreman do not",
		VoiceSynth.CALLERS.keys().filter(func(speaker: String): return not speaker in mouthed), ["cannon", "mind"])
	var unsaid: Array = mouthed.filter(func(speaker: String): return not _said_by_mouth(speaker))
	t.check("a mouthed caller's line is its letters said by its own mouth, and the Cannon's is not", unsaid.is_empty() and mouthed.size() == 10
		and not _said_by_mouth("cannon"), "not said by the mouth: %s" % [unsaid])
	var plan: Array = VoiceSynth._say_plan("sable", "Go on")[0]
	t.check("the chirp stays on the instrument and each letter after it is said", plan.slice(0, 2).all(func(blip: Array): return blip[6] == "" and blip[5] == "bell")
		and plan.slice(2).map(func(blip: Array): return blip[6]) == ["g", "o", "o", "n"], "letters %s" % [plan.map(func(blip: Array): return blip[6])])
	var ee: PackedFloat32Array = VoiceSynth._mouth(69, 0.08, 0.0, "i", 1.0)
	var oh: PackedFloat32Array = VoiceSynth._mouth(69, 0.08, 0.0, "o", 1.0)
	var high := [_partial(ee, 6), _partial(oh, 6)]
	var low := [_partial(ee, 2), _partial(oh, 2)]
	t.check("a mouth shapes its vowels: ee rings high where oh rings low", high[0] > high[1] * 2.0 and low[1] > low[0] * 2.0,
		"sixth partial %.3f against %.3f, second %.3f against %.3f" % [high[0], high[1], low[0], low[1]])
	var pitched := [_pitched(VoiceSynth._mouth(76, 0.08, 0.0, "s", 1.0)), _pitched(VoiceSynth._mouth(76, 0.08, 0.0, "m", 1.0))]
	t.check("a breathed letter opens on breath and a hummed one on its note", pitched[0] < pitched[1] * 0.75 and pitched[1] > 0.8, "pitched %.2f against %.2f" % pitched)
	var small: PackedFloat32Array = VoiceSynth._mouth(69, 0.08, 0.0, "a", 1.4)
	var grown: PackedFloat32Array = VoiceSynth._mouth(69, 0.08, 0.0, "a", 1.0)
	t.check("a smaller mouth is brighter, a letter is said the same way twice, and a vowel is level with the chirp", _edge(small) > _edge(grown)
		and VoiceSynth._mouth(69, 0.04, 0.0, "s", 1.4) == VoiceSynth._mouth(69, 0.04, 0.0, "s", 1.4) and absf(Synth.peak(small) - VoiceSynth.MOUTH_PEAK) < 0.05
		and Synth.peak(VoiceSynth._mouth(69, 0.04, 0.0, "t", 1.4)) < Synth.peak(small), "edge %.3f over %.3f, peak %.2f" % [_edge(small), _edge(grown), Synth.peak(small)])


# Whether a caller's line as the bank says it (before the bake levels it) holds, where its
# first letter falls, that letter said by a mouth of the caller's size at the caller's height.
# The chirp before it has rung out and the next letter has not started, so the line there is
# the one piece.
func _said_by_mouth(speaker: String) -> bool:
	var row: Dictionary = VoiceSynth.CALLERS[speaker]
	var letters: Array = VoiceSynth._say_plan(speaker, LINE)[0].filter(func(blip: Array): return blip[6] != "")
	var blip: Array = letters[0]
	var piece: PackedFloat32Array = VoiceSynth._mouth(int(blip[1]) + int(row.get("drop", 0)), float(blip[2]), float(blip[4]), blip[6], float(row.get("mouth", 1.0)))
	var baked: PackedFloat32Array = VoiceSynth._say(speaker, LINE)
	var from := roundi(float(blip[0]) * Harmony.RATE)
	for i in Synth.seconds(float(blip[2])):
		if absf(baked[from + i] - piece[i] * float(blip[3])) > 0.001:
			return false
	return true


# How much of a buffer sits on one partial of A4, the note the mouth checks are said on.
func _partial(buf: PackedFloat32Array, partial: int) -> float:
	var turn := TAU * Bank._hz(69) * partial / Harmony.RATE
	var across := 0.0
	var along := 0.0
	var level := 0.0
	for i in buf.size():
		across += buf[i] * cos(turn * i)
		along += buf[i] * sin(turn * i)
		level += absf(buf[i])
	return sqrt(across * across + along * along) / maxf(level, 0.000001)


# How far a buffer's opening fifth repeats at the period of E5, clear of the shut mouth's own
# ring: near 1 for a note, low for breath.
func _pitched(buf: PackedFloat32Array) -> float:
	var period := int(round(Harmony.RATE / Bank._hz(76)))
	var same := 0.0
	var level := 0.0
	for i in range(period, buf.size() / 5):
		same += buf[i] * buf[i - period]
		level += buf[i] * buf[i]
	return same / maxf(level, 0.000001)


# How bright a buffer is: the size of its sample-to-sample steps against its level.
func _edge(buf: PackedFloat32Array) -> float:
	var steps := 0.0
	var level := 0.0
	for i in range(1, buf.size()):
		steps += absf(buf[i] - buf[i - 1])
		level += absf(buf[i])
	return steps / maxf(level, 0.000001)


func _pilots() -> void:
	var off: Array = []
	for speaker in Harmony.CLASS_MOTIFS:
		var own: Array = Harmony.motif_notes(speaker).map(func(midi: int): return midi + 12)
		var plan: Array = VoiceSynth._say_plan(speaker, LINE)[0]
		var body: Array = plan.slice(2).filter(func(blip: Array): return not (int(blip[1]) in own))
		var chirp := [int(plan[0][1]), int(plan[1][1])]
		if not VoiceSynth.CALLERS.has(speaker) or not body.is_empty() or chirp != [own[0], own[own.size() - 1]]:
			off.append(speaker)
	t.check("a pilot talks in the notes of their own motif, and chirps its first and last", off.is_empty(), "off their motif: %s" % [off])
	var voices: Array = Harmony.CLASS_MOTIFS.map(func(speaker: String): return VoiceSynth._caller_voice(speaker))
	t.eq("each pilot on an instrument of their own", voices, ["bell", "clav", "tom", "fbass", "keys", "chime"])
	var bends: Array = Harmony.CLASS_MOTIFS.map(func(speaker: String): return VoiceSynth._say_plan(speaker, LINE)[0].filter(func(blip: Array): return float(blip[4]) != 0.0).size())
	t.check("the crew bend their notes", bends.min() > 5, "bent letters per pilot %s" % [bends])
	var gaps: Array = ["rivet", "kest"].map(func(speaker: String):
		var plan: Array = VoiceSynth._say_plan(speaker, "Go now go")[0]
		return float(plan[4][0]) - float(plan[3][0]) - float(plan[3][2]))
	t.check("Rivet never stops between words, and Kest does", absf(gaps[0]) < 0.0001 and gaps[1] > 0.02, "gap after the first word: Rivet %.4f s, Kest %.4f s" % gaps)
	var lengths := {}
	for blip in VoiceSynth._say_plan("tally", "aaaa aaaa aaaa")[0].slice(2):
		lengths[snappedf(float(blip[2]), 0.0001)] = true
	var strays := {}
	for blip in VoiceSynth._say_plan("sable", "aaaa aaaa aaaa")[0].slice(2):
		strays[snappedf(float(blip[2]), 0.0001)] = true
	t.check("Tally counts evenly while the others stray", lengths.size() == 1 and strays.size() > 4, "letter lengths: Tally %d, Sable %d" % [lengths.size(), strays.size()])


func _crew() -> void:
	var plan: Array = VoiceSynth._say_plan("pump_crew", "Pump two is up")[0].slice(2)
	var first := [62, 65, 69]
	var second := first.map(func(midi: int): return Harmony.scale_shift(midi, -3, Harmony.DORIAN))
	var words := [plan.slice(0, 4), plan.slice(4, 7), plan.slice(7, 9), plan.slice(9, 11)]
	var sides: Array = words.map(func(word: Array): return _talker(word, first, second))
	var overlap := float(plan[3][0]) + float(plan[3][2]) - float(plan[4][0])
	t.check("a site crew is two talkers trading words, the second in before the first is done",
		sides == ["first", "second", "first", "second"] and is_equal_approx(overlap, VoiceSynth.CALL_OVERLAP_S),
		"words by %s, overlap %.3f s" % [sides, overlap])
	var dashes: Array = VoiceSynth._say_plan("pump_crew", "Pump - - two is up")[0].slice(2)
	var turns: Array = [dashes.slice(0, 4), dashes.slice(4, 7), dashes.slice(7, 9), dashes.slice(9, 11)].map(func(word: Array): return _talker(word, first, second))
	t.check("a word with no letters is not a turn at the radio", dashes.size() == plan.size() and turns == sides, "%d letters with the dashes, %d without, turns %s" % [dashes.size(), plan.size(), turns])
	var rested: Array = VoiceSynth._say_plan("pump_crew", "Pump, two")[0].slice(2)
	t.check("the second talker waits out a comma", is_equal_approx(float(rested[4][0]) - float(rested[3][0]) - float(rested[3][2]), 0.12),
		"gap %.3f s" % (float(rested[4][0]) - float(rested[3][0]) - float(rested[3][2])))
	var roots: Array = ["pump_crew", "flume_crew", "signal_crew"].map(func(speaker: String): return VoiceSynth._caller_notes(speaker)[0])
	t.eq("each post sits on its own note", roots, [62, 64, 67])


func _talker(word: Array, first: Array, second: Array) -> String:
	if word.all(func(blip: Array): return int(blip[1]) in first):
		return "first"
	return "second" if word.all(func(blip: Array): return int(blip[1]) in second) else "mixed"


func _brindle() -> void:
	var plan: Array = VoiceSynth._say_plan("brindle", "Nine parts taken. I make that ten.")[0].slice(2)
	var ends: Array = [plan[13], plan[plan.size() - 1]].map(func(blip: Array): return [int(blip[1]), snappedf(float(blip[2]), 0.01)])
	t.check("Brindle ends each sentence held on the flat second, on brass", ends == [[63, 0.28], [63, 0.28]] and VoiceSynth._caller_voice("brindle") == "brass"
		and plan.all(func(blip: Array): return int(blip[1]) in [62, 63]), "sentence ends %s" % [ends])


func _foreman() -> void:
	var step := Harmony.STEP * 4 / 3
	var plan: Array = VoiceSynth._say_plan("mind", "Quick sync? No action is required.", step)[0]
	var half := float(step) / Harmony.RATE / 2.0
	var off: Array = plan.filter(func(blip: Array): return absf(float(blip[0]) / half - roundf(float(blip[0]) / half)) > 0.0001)
	var body: Array = plan.slice(2)
	var uneven: Array = body.filter(func(blip: Array): return blip.slice(1, 6) != [74, half * 0.7, 1.0, 0.0, VoiceSynth.PURE])
	t.check("the Foreman is one pure note, every letter on the thirty-second grid, nothing bent, no rise on a question",
		off.is_empty() and uneven.is_empty()
		and [int(plan[0][1]), int(plan[1][1])] == [74, 81] and VoiceSynth.caller_on_grid("mind") and not VoiceSynth.caller_on_grid("sable"),
		"%d letters, %d off the grid, chirp %s" % [body.size(), off.size(), [plan[0][1], plan[1][1]]])
	var id: String = VoiceSynth.say_id("mind", "Quick sync.")
	var slow: int = VoiceSynth.samples_at(id, step).size()
	var fast: int = VoiceSynth.samples_at(id, Harmony.STEP).size()
	t.check("its line is made for the band's step", slow > fast and VoiceSynth.say_seconds("mind", "Quick sync.", step) > VoiceSynth.say_seconds("mind", "Quick sync."),
		"%d samples at the roaming step, %d at a step a third longer" % [fast, slow])
	var letter: PackedFloat32Array = VoiceSynth._letter(VoiceSynth.PURE, 74, 0.05, 0.0)
	t.check("the pure voice starts, holds and stops", absf(Synth.peak(letter) - 1.0) < 0.01 and absf(letter[0]) < 0.001 and absf(letter[letter.size() - 1]) < 0.001,
		"peak %.3f" % Synth.peak(letter))


func _moss() -> void:
	var plan: Array = VoiceSynth._say_plan("moss", LINE)[0]
	var bench: Array = VoiceSynth._babble_blips(LINE, VoiceSynth.BABBLE_LEVEL)[0]
	var body: Array = plan.slice(2)
	var same: Array = range(mini(body.size(), bench.size())).filter(func(i: int): return body[i][5] == "" and int(body[i][1]) == int(bench[i][1]) and is_equal_approx(float(body[i][0]), float(bench[i][0]) + VoiceSynth.CALL_TALK_S))
	t.check("Moss rings his bell twice and talks as he does at his bench", body.size() == bench.size()
		and [plan[0][1], plan[1][1], plan[0][5]] == [86, 86, "mallet"] and same.size() == body.size(),
		"%d letters after the bell, %d at the bench" % [body.size(), bench.size()])
	# One Moss everywhere: his bench line is his caller row's mouth too, an octave up.
	var first: Array = bench[0]
	var row: Dictionary = VoiceSynth.CALLERS[VoiceSynth.MOSS]
	var said: PackedFloat32Array = VoiceSynth._mouth(int(first[1]) + int(row["drop"]), float(first[2]), float(first[4]), first[6], float(row["mouth"]))
	var blipped: PackedFloat32Array = VoiceSynth._blip(int(first[1]), float(first[2]), false, float(first[4]))
	var line: PackedFloat32Array = VoiceSynth.babble(LINE, VoiceSynth.BABBLE_LEVEL)
	t.check("at his bench Moss says his letters through the same mouth, levelled as on a call", _fit(line, said) < 0.02 and _fit(line, blipped) > 0.2
		and VoiceSynth.trim_db("babble") == VoiceSynth.trim_db(VoiceSynth.say_id("moss", LINE)) and Synth.peak(VoiceSynth.babble(LINE, VoiceSynth.BABBLE_RELENT)) < Synth.peak(line),
		"first letter off his mouth by %.3f, off his old blip by %.3f" % [_fit(line, said), _fit(line, blipped)])
	VoiceSynth.unknown_callers.clear()
	var stranger: String = VoiceSynth.say_id("nobody", LINE)
	t.check("a caller with no row gets Moss's voice and one warning", VoiceSynth._say_plan("nobody", LINE) == VoiceSynth._say_plan("moss", LINE)
		and VoiceSynth.unknown_callers.keys() == ["nobody"] and VoiceSynth.trim_db(stranger) == VoiceSynth.trim_db(VoiceSynth.say_id("moss", LINE)) and not VoiceSynth.caller_on_grid("nobody"),
		"warned about %s" % [VoiceSynth.unknown_callers.keys()])
	t.check("an id with no line is a chirp and no crash", VoiceSynth.parse_said("say|sable") == ["sable", ""] and VoiceSynth.parse_said("say|sable|a|b") == ["sable", "a|b"]
		and VoiceSynth.samples("say|sable").size() > 0, "%s" % [VoiceSynth.parse_said("say|sable")])


func _call(audio) -> void:
	var engine = audio.engine
	var lead := int(audio.CALL_LEAD_S * Harmony.RATE)
	audio.cue_log.clear()
	engine.stinger_starts.clear()
	audio._last_start.clear()
	engine.warm_stingers = true
	var booked: int = engine.clock
	var id: String = VoiceSynth.say_id("pump_crew", FRESH)
	var before := [VoiceSynth.cached_at(id, audio.grid_unit(4), engine.stinger_key(booked + lead)), VoiceSynth.cached_at(VoiceSynth.say_id("sable", LINE), audio.grid_unit(4), 0)]
	var seconds: float = audio.call_in("call_in", "pump_crew", FRESH)
	engine.settle_stingers()
	var made: bool = VoiceSynth.cached_at(id, audio.grid_unit(4), engine.stinger_key(booked + lead))
	var dropped: bool = not VoiceSynth.cached_at(VoiceSynth.say_id("sable", LINE), audio.grid_unit(4), 0)
	engine.warm_stingers = false
	var calls: Array = audio.cue_log.filter(func(e: Array): return e[2] == "call")
	var at: int = int(calls[0][3]) if not calls.is_empty() else -1
	t.check("a call is booked a moment ahead and says how long the voice lasts", calls.size() == 1 and at == booked + lead
		and is_equal_approx(seconds, audio.CALL_LEAD_S + VoiceSynth.say_seconds("pump_crew", FRESH)), "at %d (clock %d), %.2f s" % [at, booked, seconds])
	var over: float = audio.call_in("call_in", "sable", LINE)
	t.check("a call while the last caller is still talking stays silent", over == 0.0
		and audio.cue_log.filter(func(e: Array): return e[2] == "call").size() == 1, "returned %.2f" % over)
	_pump_to(audio, at + 64)
	var sounded: Array = engine.stinger_starts.filter(func(s: Array): return s[0] == id).map(func(s: Array): return int(s[1]))
	t.check("a worker makes the line before its sample, and the last caller's line is let go", before == [false, true] and made and dropped and sounded == [at],
		"in memory before the call [this line, another caller's] %s, made ahead %s, the other line dropped %s, sounded at %s" % [before, made, dropped, sounded])
	audio.clock += seconds
	audio.cue_log.clear()
	var empty: float = audio.call_in("call_in", "mind", "")
	var from: int = engine.clock
	var memo: float = audio.call_in("call_in", "mind", "Quick sync.")
	var grid_at: int = int(audio.cue_log.filter(func(e: Array): return e[2] == "call")[0][3])
	var unit: int = audio.grid_unit(4)
	t.check("the Foreman's call starts on the band's sixteenth", posmod(grid_at - audio.next_grid(4), unit) == 0 and grid_at >= from + lead
		and grid_at < from + lead + unit and memo > VoiceSynth.say_seconds("mind", "Quick sync.", unit) and empty == 0.0, "at %d, %d past a sixteenth of %d" % [grid_at, posmod(grid_at - audio.next_grid(4), unit), unit])


# The card closing early stops its caller: a line still booked never sounds, one sounding is
# let go, the band comes back up and the next caller may talk at once.
func _call_end(audio) -> void:
	var engine = audio.engine
	audio.clock += 60.0
	audio.cue_log.clear()
	engine.stinger_starts.clear()
	audio.call_end()
	t.check("ending a call when nobody is talking does nothing", audio.cue_log.is_empty(), "%d rows" % audio.cue_log.size())
	var early: String = VoiceSynth.say_id("kest", LINE)
	audio.call_in("call_in", "kest", LINE)
	var at: int = int(audio.cue_log.filter(func(e: Array): return e[2] == "call")[0][3])
	audio.call_end()
	var booked: Array = engine._actions.filter(func(a: Dictionary): return a.get("id", "") == early)
	var next: float = audio.call_in("call_in", "tarn", LINE)
	_pump_to(audio, at + 4096)
	t.check("a call ended before its voice starts never sounds, and the next caller talks at once", booked.is_empty() and next > 0.0
		and engine.stinger_starts.filter(func(s: Array): return s[0] == early).is_empty(), "%d bookings left, next caller %.2f s" % [booked.size(), next])
	var late: String = VoiceSynth.say_id("tarn", LINE)
	var sounding: Array = engine._voices.filter(func(v): return v.stinger == late)
	var left: int = sounding[0].end - sounding[0].pos if sounding.size() == 1 else -1
	audio.call_end()
	var after: int = sounding[0].end - sounding[0].pos if sounding.size() == 1 else -1
	t.check("a call ended while its voice sounds lets the voice go and brings the band back up", left > engine.RELEASE * 10 and after >= 0 and after <= engine.RELEASE
		and engine._duck_until <= engine.clock and engine._duck_target == 1.0 and audio.call_in("call_in", "sable", LINE) > 0.0,
		"%d samples left before, %d after, duck until %d at clock %d" % [left, after, engine._duck_until, engine.clock])
	audio.call_end()


# How far the opening of a buffer is from being a scaled copy of a piece: 0 when it is one
# (a line levelled as a whole keeps each letter's shape), near 1 when they are unrelated.
func _fit(buf: PackedFloat32Array, piece: PackedFloat32Array) -> float:
	var n := mini(piece.size(), 1600)
	var cross := 0.0
	var own := 0.0
	var other := 0.0
	for i in n:
		cross += buf[i] * piece[i]
		own += piece[i] * piece[i]
		other += buf[i] * buf[i]
	return 1.0 - cross * cross / maxf(own * other, 0.000000001)


func _pump_to(audio, until: int) -> void:
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))
