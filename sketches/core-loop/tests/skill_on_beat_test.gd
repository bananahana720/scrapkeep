extends SceneTree

# A pilot's skill cast on the beat is answered by the band (Andrew, 13 Nov 02:17Z to 02:19Z):
# through the real game, the skill's own sound plays when it is cast either way; on the beat the
# pilot's motif joins on the next sixteenths in its own voice, two notes against an ordinary
# foe, the whole motif and a band double against an elite pack's member. Off the beat, and a
# second cast on the same beat, add nothing. Sound only, so the cast deals and costs the same.
# The beat clock is stood in for by audio.beat_offset_hook.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

var t := T.new("skill_on_beat_test")


class BossStandIn extends Node:
	func active() -> bool:
		return true


var _game
var _offset := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(5)
	var audio = _game.presentation.audio
	var events = _game.ctx.events
	audio.bake_now()
	audio.beat_offset_hook = func() -> float: return _offset
	var motif: Dictionary = Harmony.motif_or_first(audio._motif)
	var voice := String(motif["voice"])
	var cells: Array = motif["cells"]
	var heard := []
	audio.skill_on_beat.connect(func(kind: String, big: bool): heard.append([kind, big]))

	# Off the beat: the special's own sound, no answer.
	_offset = 0.3
	_reset(audio)
	events.special_used.emit("test", Vector3.ZERO)
	t.check("off the beat: the special's own sound plays", _count(audio, "special_used") >= 1)
	t.eq("off the beat: no answer", _answers(audio).size(), 0)

	# On the beat against nothing in particular: two motif notes on consecutive cells.
	_offset = -0.04
	_reset(audio)
	var at: int = audio.engine.clock
	events.special_used.emit("test", Vector3.ZERO)
	var notes := _answers(audio)
	t.check("on the beat: the special's own sound still plays now", _count(audio, "special_used") >= 1)
	t.eq("on the beat: the answer is %d notes" % Audio.SKILL_ANSWER_NOTES, notes.size(), Audio.SKILL_ANSWER_NOTES)
	for i in mini(notes.size(), Audio.SKILL_ANSWER_NOTES):
		t.eq("note %d is the motif's own, in its voice" % i, notes[i][1], SfxBank.grid_note_id(voice, int(cells[i][1])))
	if notes.size() >= 2:
		var unit: int = audio.grid_unit(4)
		t.check("the answer starts on the grid at or after the cast", int(notes[0][3]) >= at and int(notes[0][3]) - at <= unit)
		t.eq("the second note follows the motif's step", int(notes[1][3]) - int(notes[0][3]), (int(cells[1][0]) - int(cells[0][0])) * unit)
	t.eq("the fact is told once, not big", heard, [["special_used", false]])

	# A second cast on the same beat stacks nothing.
	audio.cue_log.clear()
	events.gauge_released.emit("test", 1.0)
	t.eq("a second cast on the same beat adds no answer", _answers(audio).size(), 0)

	# One gauge cast tells the gauge release and then the special: one answer between them.
	_reset(audio)
	events.gauge_released.emit("test", 1.0)
	events.special_used.emit("test", Vector3.ZERO)
	t.eq("a gauge release and its special book one answer", _answers(audio).size(), Audio.SKILL_ANSWER_NOTES)

	# In a live boss fight a skill with no foe still earns the whole answer.
	_reset(audio)
	var stand_in := BossStandIn.new()
	var had_boss = _game.ctx.boss if "boss" in _game.ctx else null
	_game.ctx.boss = stand_in
	t.check("a live boss fight is big", audio.big_foe(null))
	events.special_used.emit("test", Vector3.ZERO)
	t.eq("in a boss fight: every motif note, plus the double", _answers(audio).size(), cells.size() + (1 if motif.has("band") else 0))
	_game.ctx.boss = had_boss
	stand_in.free()

	# Against an elite: the whole motif and the band's double of its last note.
	_reset(audio)
	heard.clear()
	var elite := _target()
	elite.set_meta("elite_pack", true)
	events.line_skill_fired.emit("test", elite, elite.global_position, "enemy")
	notes = _answers(audio)
	var double := 1 if motif.has("band") else 0
	t.eq("against an elite: every motif note, plus the band's double", notes.size(), cells.size() + double)
	if double == 1 and notes.size() == cells.size() + 1:
		var last: Array = cells[cells.size() - 1]
		t.eq("the double is the last note in the band voice", notes[-1][1],
			SfxBank.grid_note_id(String(motif["band"]), int(last[1]) + int(motif.get("band_octave", 0))))
		t.eq("the double lands with the last note", notes[-1][3], notes[-2][3])
	t.eq("the fact is told once, big", heard, [["line_skill_fired", true]])
	t.check("an ordinary foe is not big", not audio.big_foe(_target()))
	t.check("a missing foe is not big", not audio.big_foe(null))
	elite.queue_free()

	# No music, no window: a cast is never answered.
	audio.beat_offset_hook = Callable()
	_reset(audio)
	events.special_used.emit("test", Vector3.ZERO)
	t.check("with no band playing there is no answer",
		_answers(audio).is_empty() or audio.engine.mode == audio.MusicEngine.PLAY)
	quit(t.verdict())


func _reset(audio) -> void:
	audio._last_start.clear()
	audio._skill_answer_at = -(1 << 40)
	audio.cue_log.clear()


func _answers(audio) -> Array:
	return audio.cue_log.filter(func(cue: Array): return cue[0] == "skill_on_beat")


# Cues of kind that started now (not refused or booked later).
func _count(audio, kind: String) -> int:
	return audio.cue_log.filter(func(cue: Array): return cue[0] == kind and cue[2] == "now").size()


func _target() -> Node3D:
	var ball: Vector3 = _game.player.shown_position()
	return _game.ctx.spawner.spawn_enemy("chaser", ball + Vector3(4, 0, 0))
