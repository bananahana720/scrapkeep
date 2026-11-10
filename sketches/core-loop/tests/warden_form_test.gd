extends SceneTree

const Game := preload("res://src/game.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# The Warden's fight plays the recorded band as a form, not one loop (audio.gd
# _follow_warden_form, ace_sequencer.gd follow_guard): the guard near breaking is the tight build, a stagger the held
# breath, and the hit that shatters a chunk lands the drop. The real Game with the stage's
# recorded band (the stub tone tree in a checkout with no Oggs) and a stand-in for the
# Warden so each guard reading is exact, handed to the director's own posture listener
# (warden_posture_sound_test covers the real Warden reaching it). Sections are read from
# the sequencer, not from speakers.

class Guard extends Node3D:
	var chunks := 4

	func chunks_left() -> int:
		return chunks

var t := T.new("warden_form_test")
var _game
var _audio
var _ace
var _guard


func _initialize() -> void:
	_run.call_deferred()


func _pump(frames: int) -> void:
	var until: int = _audio.engine.clock + frames
	while _audio.engine.clock < until:
		_audio._pump(mini(4096, until - _audio.engine.clock))


func _bars(count: float) -> void:
	_pump(int(_audio.engine.bar_len() * count))


func _guard_reads(posture: float, staggered: bool, chunks := -1) -> void:
	if chunks >= 0:
		_guard.chunks = chunks
	_audio._on_posture_changed(_guard, posture, staggered)


func _drops() -> Array:
	return _audio.cue_log.filter(func(entry): return entry[0] == "warden_form").map(func(entry): return entry[3])


func _run() -> void:
	_table()
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.player.set_frozen(true)
	_audio = _game.presentation.audio
	_audio.bake_now()
	_audio.set_process(false)
	_audio._flush_flow()
	if not t.check("the stage's recorded band plays", _audio.ace_playing()):
		_game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	_ace = _audio.ace
	_guard = Guard.new()
	root.add_child(_guard)
	_bars(2)
	_on_the_shelf()
	_game.flow.warden = _guard
	_game.events.warden_engaged.emit(1)
	_bars(4)
	t.check("engaging the Warden reaches the build", _ace.mode == "warden" and _ace.section == "build", "mode=%s section=%s" % [_ace.mode, _ace.section])
	_tight_build()
	_breath_and_drop()
	_unhit_stagger()
	_others_and_switch()
	_last_chunk()
	_game.flow.warden = null
	_game.queue_free()
	await process_frame
	quit(t.verdict())


func _table() -> void:
	t.eq("a fresh guard is the build", Ace.guard_state("closed", 30.0, false), "closed")
	t.eq("three quarters broken is the tight build", Ace.guard_state("closed", Ace.GUARD_TIGHT, false), "telegraph")
	t.eq("just under three quarters is not", Ace.guard_state("closed", Ace.GUARD_TIGHT - 1.0, false), "closed")
	t.eq("the tight build holds while the guard drains to half", Ace.guard_state("telegraph", Ace.GUARD_LOOSE, false), "telegraph")
	t.eq("under half it lets go", Ace.guard_state("telegraph", Ace.GUARD_LOOSE - 1.0, false), "closed")
	t.eq("a stagger is the held breath", Ace.guard_state("telegraph", 100.0, true), "open")
	t.eq("the end of a stagger is the build", Ace.guard_state("open", 0.0, false), "closed")


# Before the Warden is engaged the band is on the shelf: a guard reading changes nothing,
# and a shatter must not pull the shelf into the fight's sections.
func _on_the_shelf() -> void:
	_game.flow.warden = _guard
	_guard_reads(100.0, true)
	_guard_reads(0.0, false, 3)
	t.check("on the shelf a guard reading does nothing", _ace.mode == "level" and _ace.warden_state == "closed" and _drops().is_empty(),
		"mode=%s state=%s drops=%s" % [_ace.mode, _ace.warden_state, _drops()])
	_guard.chunks = 4
	_audio._posture_seen.clear()


func _tight_build() -> void:
	_audio.cue_log.clear()
	_guard_reads(30.0, false)
	t.check("a guard a third broken keeps the build", _ace.warden_state == "closed")
	_guard_reads(80.0, false)
	_bars(2)
	t.check("a guard near breaking enters the tight build", _ace.section == "telegraph", "section=%s" % _ace.section)
	_guard_reads(60.0, false)
	_bars(1)
	t.check("it holds while the guard drains toward half", _ace.section == "telegraph" and _ace.warden_state == "telegraph", "section=%s state=%s" % [_ace.section, _ace.warden_state])
	_guard_reads(40.0, false)
	_bars(2)
	t.check("a guard left to drain goes back to the build", _ace.section == "build" and _ace.warden_state == "closed" and _drops().is_empty(), "section=%s state=%s drops=%s" % [_ace.section, _ace.warden_state, _drops()])


# The lead's level in the section sounding, or -1 with no lead voice.
func _lead() -> float:
	for v in _ace.voices:
		if v.stem == "other":
			return v.target
	return -1.0


func _breath_and_drop() -> void:
	_audio.cue_log.clear()
	# The worst feed for the lead: no threat, no fight floor and armour nearly gone. The build
	# loses its lead to it; the breath (the lead alone) and the drop must not.
	var fed: Dictionary = _ace.parameters.duplicate()
	var floor_was: float = _ace.fight_floor
	_ace.parameters = {"threat": 0.0, "armour": 0.1}
	_ace.pressure = 0.0
	_ace.fight_floor = 0.0
	t.check("low armour still strips the build's lead", _ace.parameter_gain("other", "build") == 0.0, "gain=%s" % _ace.parameter_gain("other", "build"))
	t.check("the breath and the drop carry the lead whole", _ace.parameter_gain("other", "open") == 1.0 and _ace.parameter_gain("other", "drop") == 1.0,
		"open=%s drop=%s" % [_ace.parameter_gain("other", "open"), _ace.parameter_gain("other", "drop")])
	_ace.parameters = fed
	_ace.fight_floor = floor_was
	_guard_reads(100.0, true)
	_bars(1)
	t.check("a stagger is the held breath", _ace.section == "open", "section=%s" % _ace.section)
	t.check("the breath is not silence", _lead() > 0.0, "lead=%s" % _lead())
	var asked: int = _ace.clock
	var opened: int = _ace.opened
	_guard_reads(0.0, false, 3)
	var at: int = _drops()[0] if _drops().size() == 1 else -1
	t.check("the shattering hit books the drop on a coming beat", at > asked and at == _ace.next_beat(at), "asked=%d drop=%d" % [asked, at])
	# One section's stems on the hit's frame: the build is not opened only to be thrown away.
	t.eq("the hit opens the drop's stems and nothing else", _ace.opened - opened, _ace.stems.size())
	_pump(at - _ace.clock + 4096)
	t.check("the drop plays", _ace.section == "drop", "section=%s" % _ace.section)
	t.check("the drop carries the lead", _lead() > 0.0, "lead=%s" % _lead())
	# The drop is four bars, and the build waits for its end.
	_bars(6)
	t.check("the build comes back after the drop", _ace.section == "build" and _ace.mode == "warden", "section=%s mode=%s" % [_ace.section, _ace.mode])


func _unhit_stagger() -> void:
	_audio.cue_log.clear()
	_guard_reads(100.0, true)
	_bars(1)
	_guard_reads(0.0, false)
	_bars(2)
	t.check("a stagger nobody lands goes back to the build with no drop", _ace.section == "build" and _ace.warden_state == "closed" and _drops().is_empty(), "section=%s state=%s drops=%s" % [_ace.section, _ace.warden_state, _drops()])


func _others_and_switch() -> void:
	_audio.cue_log.clear()
	var other := Guard.new()
	root.add_child(other)
	_audio._on_posture_changed(other, 100.0, true)
	other.chunks = 3
	_audio._on_posture_changed(other, 0.0, false)
	t.check("another posture enemy does not move the band", _ace.warden_state == "closed" and _drops().is_empty(), "state=%s drops=%s" % [_ace.warden_state, _drops()])
	other.queue_free()
	# The switch thrown in the middle of a held breath lets the band go at the next reading.
	_guard_reads(100.0, true)
	_bars(1)
	_game.tuning.set_option(Tuning.WARDEN_FORM_KEY, "loop")
	_guard_reads(100.0, true)
	_bars(2)
	t.check("the switch thrown mid-breath returns the build", _ace.section == "build" and _ace.warden_state == "closed", "section=%s state=%s" % [_ace.section, _ace.warden_state])
	_guard_reads(0.0, false, 2)
	_guard_reads(80.0, false)
	_bars(2)
	t.check("with the form off the build loops as before", _ace.section == "build" and _ace.warden_state == "closed" and _drops().is_empty(),
		"section=%s state=%s drops=%s" % [_ace.section, _ace.warden_state, _drops()])
	_game.tuning.set_option(Tuning.WARDEN_FORM_KEY, "form")


# The chunk that breaks the Warden lands no drop: the break and the kill cadence answer it.
func _last_chunk() -> void:
	_guard_reads(0.0, false, 1)
	_bars(6)
	_audio.cue_log.clear()
	_guard_reads(100.0, true)
	_bars(1)
	_guard_reads(0.0, false, 0)
	t.check("the last chunk books no drop", _drops().is_empty() and _ace.warden_state == "closed", "drops=%s state=%s" % [_drops(), _ace.warden_state])
	_ace.warden_broken()
	_bars(2)
	t.check("the break answers it", _ace.mode == "piece" and _ace.section == "break", "mode=%s section=%s" % [_ace.mode, _ace.section])
