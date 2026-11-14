extends "res://tools/ace_bounce_tail.gd"
# Scratch only, never committed (job 6 step 5): during an ACE bounce, once the recorded band's grid runs at
# --crash-bpm (within 2%) and the run is at least --crash-after seconds old, call Audio.land_streak(5) once,
# the 6-kill chain landing: a held note, then the chain crash on the next bar line.
# Logs a crash_probe fact: [t, "crash_probe", landing sample from bounce start, grid origin from bounce start,
# grid_beat samples, grid bpm, mix state].

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

var _crash_bpm := 0.0
var _crash_after := 20.0
var _crash_done := false


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _crash_done or _driver == null or _game == null or _game.presentation == null:
		return out
	if _crash_bpm <= 0.0:
		_crash_bpm = float(_settings.get("crash-bpm", "0"))
		_crash_after = float(_settings.get("crash-after", "20"))
		if _crash_bpm <= 0.0:
			return out
	var audio = _game.presentation.audio
	if _now() < _crash_after or not audio._on_ace_grid() or audio.engine.mode != MusicEngine.PLAY:
		return out
	var bpm: float = 60.0 * Harmony.RATE / float(audio.ace.grid_beat)
	if absf(bpm - _crash_bpm) / _crash_bpm > 0.02:
		return out
	_crash_done = true
	var at: int = audio.land_streak(5)
	_facts.append([_now(), "crash_probe", at - _base_sample, audio.ace.origin - _base_sample, audio.ace.grid_beat,
		snappedf(bpm, 0.1), audio.mix_state()])
	return out
