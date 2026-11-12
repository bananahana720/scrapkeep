extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")

# The melodic payoff (AUDIO-V3 section 5), through the real game. A climb never leaves the reward
# ladder: the chain bite and the multi-kill pop. The tune lands on the band's grid: a kill chain
# resolves on a chord tone on the next beat (a long one on the bar line under a crash), the near
# miss's whip notes and the dunk's banked and paid notes land on sixteenths, and a death ends the
# band, synth or recorded, on the next beat with the fall in time. The contact itself still
# sounds on its frame. A completed part set's chime plays as its banner comes up: three notes on
# the band's eighths, an arc set on the clavinet and a frost set on the bell, both ending on the
# appliance beep's high D, with the band dipped under them; no other banner chimes, and no band
# means no chime. A long chain is answered by name: the pilot's motif on the sax a beat after the
# landing, made for the sounding band's step, and not again inside its gap.

var t := T.new("audio_melodic_payoff_test")
var _clock_ms := 0


# The production streak rule on a clock the test steps (audio passes wall time).
class ClockedStreak extends "res://src/presentation/streak.gd":
	var now: Callable

	func bump(_now_ms: int) -> int:
		return super.bump(int(now.call()))

	func live(_now_ms: int) -> bool:
		return super.live(int(now.call()))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_ladders()
	Rows.stem_dir = "user://ace_stem_none"
	var game := _start_game()
	var audio = game.presentation.audio
	_pump_to(audio, audio.engine.clock + Harmony.BAR * 2)
	_chain_bite(game, audio)
	_multi_kill(game, audio)
	_streaks(game, audio)
	await _landing_ahead(game, audio)
	_pilot_quote(game, audio)
	_near_miss(game, audio)
	_dunk(game, audio)
	_set_chime(game, audio)
	_death_synth(game, audio)
	t.check("set chime: no band, no chime", audio.engine.mode != Music.PLAY and audio.set_complete("arc") == -1,
		"band mode %d" % audio.engine.mode)
	game.queue_free()
	await process_frame
	Rows.stem_dir = ""
	await _death_recorded()
	quit(t.verdict())


func _ladders() -> void:
	var bite: Array = range(1, 6).map(func(steps: int): return _semitones(Harmony.ladder_ratio(Bank.BITE_MIDI, steps)))
	t.eq("the bite's ladder from A is C D F G A", bite, [3, 5, 8, 10, 12])
	var pops: Array = [2, 4, 8].map(func(mark: int): return _semitones(Harmony.snapped_ratio(Bank.KILL_POP_MIDI, 12.0 + 1.5 * mark)))
	t.eq("multi-kill pops over D are F G D", pops, [15, 17, 24])
	t.eq("a line on G falls to F over Dm9", Harmony.tone_below(91, Harmony.PROGRESSION[0]["tones"]), 89)
	t.eq("a line on a chord tone still falls", Harmony.tone_below(93, [62, 65, 69]), 89)
	t.eq("a line on D falls to A over home", Harmony.tone_below(98, [62, 65, 69]), 93)


func _chain_bite(game: Node, audio) -> void:
	audio.cue_log.clear()
	for links in range(2, 9):
		game.player.chain.links = links
		audio._last_start.clear()
		audio._on_chain_state("chain_link", "")
	game.player.chain.links = 0
	var rungs: Array = audio.cue_log.filter(func(e: Array): return e[1] == "line_bite").map(func(e: Array): return _semitones(float(e[4])))
	var on_ladder: bool = rungs.all(func(st: int): return posmod(Bank.BITE_MIDI + st - Harmony.HOME, 12) in Harmony.PENTATONIC)
	t.check("chain bite climbs the ladder", rungs == [3, 5, 8, 10, 12, 12, 12] and on_ladder,
		"links 2 to 8 bite at %s semitones over A, every one on D F G A C" % [rungs])


func _multi_kill(game: Node, audio) -> void:
	var juice = game.presentation.juice
	juice.set_process(false)
	audio.cue_log.clear()
	audio._last_start.clear()
	var at: Vector3 = game.player.ball_position() + Vector3(0.0, 0.0, -5.0)
	for i in 3:
		game.events.enemy_killed.emit("chaser", at, 1)
	audio._last_start.clear()
	juice.flush()
	var pops: Array = audio.cue_log.filter(func(e: Array): return e[1] == "kill_pop" and e[2] == "now").map(func(e: Array): return _semitones(float(e[4])))
	t.check("multi-kill pop is on the ladder", pops.size() >= 2 and pops.back() == 15,
		"three kills in a frame: pops at %s semitones over D, the extra beat on F" % [pops])
	audio.kill_streak.reset()
	audio._streak_landed_ms = audio.kill_streak.last_ms


func _streaks(game: Node, audio) -> void:
	var engine: Music = audio.engine
	var streak := ClockedStreak.new()
	var row := EventKinds.juice("enemy_killed")
	streak.window_ms = int(row["chain_ms"])
	streak.cap = int(row["chain_cap"])
	streak.now = func() -> int: return _clock_ms
	audio.kill_streak = streak
	var window: int = streak.window_ms
	# Two kills: nothing lands.
	_kills(game, audio, 2)
	audio.cue_log.clear()
	_clock_ms += window + 50
	audio._tend_kill_streak()
	t.eq("a chain of two just stops", _grid(audio, "enemy_killed").size(), 0)
	# Three kills: the line falls from G to the chord tone under it, on the next beat, once.
	_kills(game, audio, 3)
	audio.cue_log.clear()
	audio._tend_kill_streak()
	t.eq("nothing lands while the chain is live", _grid(audio, "enemy_killed").size(), 0)
	_clock_ms += window + 50
	var beat := engine.next_beat()
	var tones: Array = engine.chord_at(beat)["tones"]
	audio._tend_kill_streak()
	audio._tend_kill_streak()
	var landed := _grid(audio, "enemy_killed")
	var last: int = Bank.KILL_POP_MIDI + Harmony.pentatonic_step(2)
	var want := Harmony.tone_below(last, tones)
	var ids: Array = landed.map(func(e: Array): return e[1])
	var on_beat: bool = landed.size() == 2 and landed.all(func(e: Array): return int(e[3]) == beat) and posmod(beat - engine.grid_origin, engine.beat_len()) == 0 and beat >= engine.clock
	t.check("a chain of three lands on the beat, once", on_beat and ids == [Bank.grid_note_id("bell", want), Bank.grid_note_id("keys", want - 12)],
		"last note %d, landing %s at sample %d (next beat %d), chord tones %s" % [last, ids, int(landed[0][3]) if not landed.is_empty() else -1, beat, tones])
	t.check("the landing is a chord tone under the last note", want < last and tones.any(func(tone: int): return posmod(tone - want, 12) == 0),
		"%d under %d, tones %s" % [want, last, tones])
	var starts_before: int = engine.stinger_starts.size()
	_pump_to(audio, beat + 64)
	var sounded: Array = engine.stinger_starts.slice(starts_before).filter(func(s: Array): return String(s[0]).begins_with(Bank.GRID_NOTE))
	t.check("the landing sounds in the stinger lane on its sample", sounded.size() == 2 and sounded.all(func(s: Array): return int(s[1]) == beat), "%s" % [sounded])
	# Six kills: the last note sounds again on the next sixteenth and the landing takes the bar line under a crash.
	_kills(game, audio, 6)
	audio.cue_log.clear()
	_clock_ms += window + 50
	# A sixteenth past a bar line, so the hold has room before the next one.
	_pump_to(audio, engine.next_bar() + engine.step_len + 7)
	var bar := engine.next_bar()
	var sixteenth: int = audio.next_grid(4)
	audio._tend_kill_streak()
	var long := _grid(audio, "enemy_killed")
	var top: int = Bank.KILL_POP_MIDI + Harmony.pentatonic_step(5)
	var crash: Array = audio.cue_log.filter(func(e: Array): return e[1] == audio.CHAIN_CRASH)
	var held: bool = long.size() == 3 and long[0][1] == Bank.grid_note_id("bell", top) and int(long[0][3]) == sixteenth and posmod(sixteenth - engine.grid_origin, engine.step_len) == 0
	var resolved: bool = long.size() == 3 and int(long[1][3]) == bar and int(long[2][3]) == bar and crash.size() == 1 and int(crash[0][3]) == bar
	t.check("a long chain restates its last note, then lands on the bar under a crash", held and resolved,
		"hold %s at %d (next sixteenth %d), landing at %d and crash at %d (next bar %d)" % [long[0][1] if not long.is_empty() else "", int(long[0][3]) if not long.is_empty() else -1, sixteenth,
			int(long[1][3]) if long.size() > 1 else -1, int(crash[0][3]) if not crash.is_empty() else -1, bar])
	# No landing is made on its beat. Over the home triad every one is in the boot bake.
	var home: Array = audio._home_landing_ids()
	var booted: Array = audio._sound_ids()
	t.check("the home landings are in the boot bake", home.size() >= 8 and home.all(func(id: String): return id in booted and Bank.cached_at(id, Harmony.STEP)),
		"%d notes: %s" % [home.size(), home])
	audio.kill_streak.reset()
	audio._streak_landed_ms = audio.kill_streak.last_ms


# Elsewhere (another key here) a worker makes the landing while the chain is live, a window ahead.
func _landing_ahead(game: Node, audio) -> void:
	var engine: Music = audio.engine
	var window: int = audio.kill_streak.window_ms
	_clock_ms += window + 50
	engine.warm_stingers = true
	engine._set_key(3)
	_kills(game, audio, 3)
	var due: int = engine.clock + window * Harmony.RATE / 1000
	var ahead: Array = audio._landing_ids(2, audio._landing_tones(due))
	for id in audio._landing_ids(2, audio._landing_tones(due + 4 * audio.grid_unit(1))):
		if not id in ahead:
			ahead.append(id)
	var frames := 0
	while frames < 600 and not ahead.all(func(id: String): return Bank.cached_at(id, engine.step_len, 3)):
		await process_frame
		frames += 1
	t.check("a climbing chain makes its landing a window ahead", frames < 600 and audio.kill_streak.live(0),
		"%s in key 3 after %d frames, the chain still live" % [ahead, frames])
	engine._set_key(0)
	engine.warm_stingers = false
	audio.kill_streak.reset()
	audio._streak_landed_ms = audio.kill_streak.last_ms


func _pilot_quote(game: Node, audio) -> void:
	var engine: Music = audio.engine
	var window: int = audio.kill_streak.window_ms
	t.eq("sable's quote: D F A C E on the sax in eighths, brass and kick under the E", Bank.pilot_quote_score("sable"),
		[[0, 62, 2, "lead", 0.8], [2, 65, 2, "lead", 0.8], [4, 69, 2, "lead", 0.8], [6, 72, 2, "lead", 0.8], [8, 76, 4, "lead", 0.8],
			[8, 64, 4, "brass", 0.45], [8, 0, 1, "kick", 0.6]])
	t.eq("tarn's quote goes up an octave so the sax sings it", Bank.pilot_quote_score("tarn").slice(0, 4).map(func(row: Array): return row[1]),
		[62, 62, 63, 69])
	var id: String = Bank.pilot_quote_id(audio._motif)
	var slow: int = Bank.samples_at(id, Harmony.STEP * 4 / 3).size()
	var fast: int = Bank.samples_at(id, Harmony.STEP).size()
	t.check("the quote is made for the step it sounds at", Bank.has_recipe(id) and slow > fast and fast > Harmony.STEP * 8,
		"%d samples at the roaming step, %d at a step a third longer" % [fast, slow])
	# The last chain ended and the gap since any earlier quote has passed.
	_clock_ms += window + 50
	audio._tend_kill_streak()
	audio.clock += audio.pilot_quote_gap() + 1.0
	_kills(game, audio, 6)
	audio.cue_log.clear()
	_clock_ms += window + 50
	_pump_to(audio, engine.next_bar() + engine.step_len + 7)
	# Past the quote the streak checks above booked, so only this chain's can sound.
	_pump_to(audio, engine.next_bar() + engine.beat_len() + engine.step_len + 7)
	engine.stinger_starts.clear()
	var bar := engine.next_bar()
	audio._tend_kill_streak()
	var quotes: Array = audio.cue_log.filter(func(e: Array): return e[2] == "quote")
	var at: int = int(quotes[0][3]) if not quotes.is_empty() else -1
	_pump_to(audio, bar + engine.beat_len() + 64)
	var sounded: Array = engine.stinger_starts.filter(func(s: Array): return s[0] == id).map(func(s: Array): return int(s[1]))
	t.check("a long chain is answered by name, a beat after it lands", quotes.size() == 1 and quotes[0][1] == id and at == bar + engine.beat_len()
		and sounded == [at] and _grid(audio, "enemy_killed").size() == 3,
		"%s at %d (bar %d, beat %d), sounded at %s, landing notes %d" % [quotes.map(func(e: Array): return e[1]), at, bar, engine.beat_len(), sounded,
			_grid(audio, "enemy_killed").size()])
	# A second long chain inside the gap lands as before and is not answered again.
	_kills(game, audio, 6)
	audio.cue_log.clear()
	_clock_ms += window + 50
	audio._tend_kill_streak()
	t.check("no second quote inside eight bars", audio.cue_log.filter(func(e: Array): return e[2] == "quote").is_empty()
		and _grid(audio, "enemy_killed").size() >= 2 and is_equal_approx(audio.pilot_quote_gap(), 32.0 * engine.beat_len() / Harmony.RATE), "cues %s" % [audio.cue_log.map(func(e: Array): return [e[1], e[2]])])
	# A short chain is never answered, whatever the gap.
	audio.clock += audio.pilot_quote_gap() + 1.0
	_kills(game, audio, 3)
	audio.cue_log.clear()
	_clock_ms += window + 50
	audio._tend_kill_streak()
	t.check("a short chain is not answered", audio.cue_log.filter(func(e: Array): return e[2] == "quote").is_empty()
		and _grid(audio, "enemy_killed").size() == 2, "cues %s" % [audio.cue_log.map(func(e: Array): return [e[1], e[2]])])
	audio.kill_streak.reset()
	audio._streak_landed_ms = audio.kill_streak.last_ms


func _near_miss(game: Node, audio) -> void:
	var engine: Music = audio.engine
	_pump_to(audio, engine.clock + 1000)
	audio.cue_log.clear()
	audio._last_start.clear()
	var sixteenth: int = audio.next_grid(4)
	game.events.near_miss.emit("threat_lane", game.player.ball_position())
	var air: Array = audio.cue_log.filter(func(e: Array): return e[0] == "near_miss" and e[2] == "now")
	var notes := _grid(audio, "near_miss")
	var whip := Bank.whip_notes(audio._motif)
	var ids: Array = notes.map(func(e: Array): return e[1])
	var times: Array = notes.map(func(e: Array): return int(e[3]))
	t.check("near miss: the air on its frame, the class whip on the next two sixteenths",
		air.size() == 1 and ids == [Bank.grid_note_id(whip[0], whip[1]), Bank.grid_note_id(whip[0], whip[2])] and times == [sixteenth, sixteenth + engine.step_len]
			and sixteenth >= engine.clock and sixteenth - engine.clock < engine.step_len and posmod(sixteenth - engine.grid_origin, engine.step_len) == 0,
		"%s's whip %s at %s, play head %d, sixteenth %d" % [audio._motif, ids, times, engine.clock, engine.step_len])


func _dunk(game: Node, audio) -> void:
	var engine: Music = audio.engine
	var dunk = game.player.dunk
	audio.cue_log.clear()
	audio._last_start.clear()
	var sixteenth: int = audio.next_grid(4)
	dunk.stored.emit({})
	audio._last_start.clear()
	dunk.spent.emit({}, null)
	var now: Array = audio.cue_log.filter(func(e: Array): return e[0] == "slammed" and e[2] == "now").map(func(e: Array): return e[1])
	var notes := _grid(audio, "slammed")
	t.check("dunk: whistle and crack on their frames, the fifth then home on the sixteenth",
		now == ["smash_whistle", "smash_crack"] and notes.map(func(e: Array): return e[1]) == [Bank.grid_note_id("mallet", 81), Bank.grid_note_id("mallet", 74)]
			and notes.all(func(e: Array): return int(e[3]) == sixteenth),
		"now %s, notes %s at %s (next sixteenth %d)" % [now, notes.map(func(e: Array): return e[1]), notes.map(func(e: Array): return int(e[3])), sixteenth])


func _set_chime(game: Node, audio) -> void:
	var engine: Music = audio.engine
	var banner = game.presentation.banner
	var eighth: int = engine.beat_len() / 2
	var lead := int(audio.SET_CHIME_LEAD_S * Harmony.RATE)
	for case in [["live_wire", "clav"], ["storm_front", "bell"]]:
		var row: Dictionary = Synergies.ROWS[case[0]]
		_pump_to(audio, engine.clock + 3000)
		banner.dismiss(true)
		audio.cue_log.clear()
		engine.stinger_starts.clear()
		var head := engine.clock
		game.presentation._on_set_completed(case[0], row["name"], row["text"], row["color"])
		var ducked: bool = engine._duck_target < 1.0 and engine._duck_until > head
		var notes := _grid(audio, "synergy_discovered")
		var ids: Array = notes.map(func(e: Array): return e[1])
		var times: Array = notes.map(func(e: Array): return int(e[3]))
		var first: int = times[0] if not times.is_empty() else -1
		var want := [Bank.grid_note_id(case[1], 77), Bank.grid_note_id(case[1], 81), Bank.grid_note_id("beep", 86)]
		_pump_to(audio, head + lead + 4 * eighth)
		var started: Array = engine.stinger_starts.filter(func(e: Array): return e[0] in want).map(func(e: Array): return int(e[1]))
		t.check("set chime: %s climbs F A on the %s to the beep's D, on eighths, as its banner comes up" % [row["name"], case[1]],
			banner.showing() and banner.last_title == row["name"] and ids == want and times == [first, first + eighth, first + 2 * eighth]
				and first - head >= lead and first - head < lead + eighth and posmod(first - engine.grid_origin, eighth) == 0
				and started == times and ducked and engine._duck_until >= first + 3 * eighth,
			"banner '%s' showing %s, notes %s at %s, sounded at %s, play head %d, eighth %d, lead %d, band dipped %s" % [banner.last_title, banner.showing(),
				ids, times, started, head, eighth, lead, ducked])
	# A set finished in a fight: the banner is held, and the chime with it.
	var held: Dictionary = Synergies.ROWS["hair_trigger"]
	banner.dismiss(true)
	audio.cue_log.clear()
	# The screen's one gate holds the card (screen_busy.gd, wave 36): a busy source stands in for the fight.
	var fight := [true]
	game.ctx.screen_busy.add_source(func(): return fight[0])
	game.presentation._on_set_completed("hair_trigger", held["name"], held["text"], held["color"])
	var early: int = _grid(audio, "synergy_discovered").size()
	var was_showing: bool = banner.showing()
	fight[0] = false
	game.ctx.screen_busy.step(ScreenBusy.FIND_HOLD)
	banner._next()
	t.check("set chime: a banner held for a calm moment holds its chime", not was_showing and early == 0 and banner.showing()
		and banner.last_title == held["name"] and _grid(audio, "synergy_discovered").size() == 3,
		"held: showing %s, notes %d; released: showing %s '%s', notes %d" % [was_showing, early, banner.showing(), banner.last_title,
			_grid(audio, "synergy_discovered").size()])
	banner.dismiss(true)
	audio.cue_log.clear()
	banner.show_discovery("Arc Coil", "part", "", "Found", "part:arc_coil", "part_gained")
	t.check("set chime: a banner that is no set's stays silent", banner.showing() and _grid(audio, "synergy_discovered").is_empty(),
		"showing %s, notes %s" % [banner.showing(), _grid(audio, "synergy_discovered")])
	banner.dismiss(true)


func _death_synth(game: Node, audio) -> void:
	var engine: Music = audio.engine
	_pump_to(audio, engine.clock + 2000)
	# Three kills, then the death inside their window.
	_kills(game, audio, 3)
	audio.cue_log.clear()
	var beat := engine.next_beat()
	var eighth: int = engine.beat_len() / 2
	game.events.player_died.emit()
	audio._flush_flow()
	# The window closes before the boom's beat, while the band still reads PLAY.
	_clock_ms += audio.kill_streak.window_ms + 50
	audio._tend_kill_streak()
	t.check("a chain the death cut short never lands", engine.mode == Music.PLAY and audio.kill_streak.rung == 2 and _grid(audio, "enemy_killed").is_empty(),
		"band mode %d before the boom, rung %d, landings %s" % [engine.mode, audio.kill_streak.rung, _grid(audio, "enemy_killed")])
	var cue: Array = audio.cue_log.filter(func(e: Array): return e[0] == "player_died" and e[2] == "now")
	var fall := _grid(audio, "player_died")
	var want: Array = audio.DEATH_FALL.map(func(midi: int): return Bank.grid_note_id("brass", midi))
	var homes: Array = engine._actions.filter(func(a: Dictionary): return a["type"] == "stinger" and String(a["id"]).begins_with(Bank.GRID_NOTE)).map(func(a: Dictionary): return a["home"])
	t.check("death: the cue on its frame, the fall in eighths from the beat, in D",
		cue.size() == 1 and fall.map(func(e: Array): return e[1]) == want and fall.map(func(e: Array): return int(e[3])) == [beat, beat + eighth, beat + 2 * eighth] and homes == [true, true, true],
		"cue %s, fall %s at %s (next beat %d), home %s" % [cue.map(func(e: Array): return e[1]), fall.map(func(e: Array): return e[1]), fall.map(func(e: Array): return int(e[3])), beat, homes])
	_pump_to(audio, beat + 64)
	t.check("death: the band drops to the keys on that beat", engine.mode == Music.DEAD and engine.events_log.any(func(e: Array): return e[0] == "hit" and int(e[1]) == beat))


# The recorded band (its stub tone tree in a checkout without the Oggs): a death that ends the run
# plays the level pack to the next beat, stops it there, and only then starts the lost summary.
func _death_recorded() -> void:
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
		print("ACE stems: stub tone tree (no Oggs in this checkout)")
	var game := _start_game()
	var audio = game.presentation.audio
	var engine: Music = audio.engine
	if not t.check("the recorded band plays the level", Rows.pack_on_disk(audio.ace_manifest) and audio.ace_playing()):
		game.queue_free()
		await process_frame
		return
	_pump_to(audio, engine.clock + Harmony.BAR * 2 + 3000)
	var level = audio.ace
	var pack: String = audio._ace_from
	t.check("the level pack owns the grid and the synth band is muted", audio._on_ace_grid() and engine.band_muted)
	# The chime over the recorded band rides its grid, not the muted synth band's.
	var head := engine.clock
	var eighth: int = audio.grid_unit(2)
	audio.cue_log.clear()
	var first: int = audio.set_complete("frost")
	var times: Array = _grid(audio, "synergy_discovered").map(func(e: Array): return int(e[3]))
	t.check("set chime: over the recorded band it lands on that band's eighths", eighth == level.grid_beat / 2
		and times == [first, first + eighth, first + 2 * eighth] and posmod(first - level.origin, eighth) == 0
		and first - head >= int(audio.SET_CHIME_LEAD_S * Harmony.RATE) and first - head < int(audio.SET_CHIME_LEAD_S * Harmony.RATE) + eighth,
		"notes at %s, play head %d, the pack's eighth %d (synth eighth %d), origin %d" % [times, head, eighth, engine.beat_len() / 2, level.origin])
	# Whole beats of the pack, so the death below still falls where it did.
	_pump_to(audio, head + 8 * audio.grid_unit(1))
	# The quote over a recorded band is made for that band's sixteenth, not the muted synth band's:
	# a pack half as slow again gets the slower phrase.
	var quote: String = Bank.pilot_quote_id(audio._motif)
	var pack_beat: int = level.grid_beat
	level.grid_beat = pack_beat * 3 / 2
	var slow: int = audio.grid_unit(4)
	var due: int = engine.clock + 2000
	audio.clock += audio.pilot_quote_gap() + 1.0
	audio._quote_pilot(due)
	level.grid_beat = pack_beat
	var made_before: bool = Bank.cached_at(quote, slow, engine.stinger_key(due))
	head = engine.clock
	_pump_to(audio, head + 8 * audio.grid_unit(1))
	t.check("pilot quote: over the recorded band it is made for that band's step", slow == pack_beat * 3 / 8 and slow != engine.step_len
		and not made_before and Bank.cached_at(quote, slow, engine.stinger_key(due)) and engine.stinger_starts.any(func(s: Array): return s[0] == quote and int(s[1]) == due),
		"step %d against the synth band's %d, made before %s, made after %s" % [slow, engine.step_len, made_before, Bank.cached_at(quote, slow, engine.stinger_key(due))])
	var beat := engine.next_beat()
	t.check("the death falls mid-beat", beat - engine.clock > 2000, "play head %d, next beat %d" % [engine.clock, beat])
	audio.cue_log.clear()
	# The real order: audio hears the death, then flow ends the run inside the same frame.
	game.events.player_died.emit()
	game.events.run_ended.emit(false)
	audio._flush_flow()
	t.check("recorded death: the level pack is still the band", audio.ace == level and level.mode != "off" and audio._ace_from == pack and audio._summary_due == beat,
		"mode %s, summary due %d (beat %d)" % [level.mode, audio._summary_due, beat])
	# The synth band un-mutes one ramp before the beat, so read the hold ahead of that.
	_pump_to(audio, beat - 1000)
	t.check("recorded death: it plays to the beat", level.mode != "off" and not level.voices.is_empty() and engine.band_muted,
		"mode %s, %d voices, synth band muted %s" % [level.mode, level.voices.size(), engine.band_muted])
	_pump_to(audio, beat + 16)
	var stops: Array = level.events_log.filter(func(e: Array): return e[0] == "stop")
	t.check("recorded death: it stops on the beat, and the synth band is back for the boom",
		level.mode == "off" and stops.size() == 1 and int(stops[0][1]) == beat and not engine.band_muted and engine.events_log.any(func(e: Array): return e[0] == "hit" and int(e[1]) == beat),
		"stops %s, beat %d, band muted %s" % [stops, beat, engine.band_muted])
	_pump_to(audio, beat + Harmony.BAR)
	var summary_on_disk: bool = Rows.pack_on_disk(Rows.resolve(audio.summary_row(false))["ace_manifest"])
	t.check("recorded death: the lost summary starts after the beat", audio._summary_due == -1 and (not summary_on_disk or (audio.ace != level and audio.ace.mode == "menu")),
		"summary pack on disk %s, sequencer mode %s, pack %s" % [summary_on_disk, audio.ace.mode, audio._ace_from])
	game.queue_free()
	await process_frame


func _start_game() -> Node:
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
	return game


func _pump_to(audio, until: int) -> void:
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _kills(game: Node, audio, count: int) -> void:
	var at: Vector3 = game.player.ball_position() + Vector3(0.0, 0.0, -5.0)
	for i in count:
		_clock_ms += 100
		audio.stop("kill_pop")
		audio._last_start.clear()
		game.events.enemy_killed.emit("chaser", at, 1)


func _grid(audio, kind: String) -> Array:
	return audio.cue_log.filter(func(e: Array): return e[0] == kind and e[2] == "grid")


func _semitones(ratio: float) -> int:
	return roundi(12.0 * log(ratio) / log(2.0))
