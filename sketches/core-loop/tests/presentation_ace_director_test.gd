# smoke: solo (verdict reads wall time: no main-thread frame over 50 ms)
extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Ctx := preload("res://src/core/context.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The audio director's side of the ACE band (src/presentation/audio.gd), on the dummy
# driver: the director's own pump renders the band against a controlled transport, so the
# handover between the ACE band and the synth is checked in transport samples and output.
#   - title to run: no main-thread frame over 50 ms while the stems load and stage 1 starts;
#   - a launch out of the Warden's break plays the piece through the flight and hands to the
#     synth on the landing's beat, with no silent stretch (Andrew's ruling, 2026-09-28);
#   - a launch out of a level or Warden mode (an unsealed stage's gate) hands to the synth
#     at once, so the launch riser sounds;
#   - the synth band fades in when it un-mutes instead of stepping;
#   - engine.grid is released in the same call that ends the band;
#   - the ring deepens by a step per skip, and only when the ring is deep enough.
# Transport truth and measured levels only; the feel is Andrew's to judge in play.

const FRAME_LIMIT_MS := 50.0
const BEAT := 20512

var _failures := 0
var _events
var _ctx
var _audio
var _step := 0
var _last_us := 0
var _frame_ms: Array = []
var _timing_rows := ""
var _main_thread_load_ms := 0.0


func _initialize() -> void:
	var probe := Ace.new()
	if not probe.ready():
		print("[ace package] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
		print("presentation_ace_director_test: PASS (0.0 s, 1 skipped)")
		quit(0)
		return
	var t0 := Time.get_ticks_usec()
	var loaded := Ace.new()
	_main_thread_load_ms = (Time.get_ticks_usec() - t0) / 1000.0
	loaded = null
	_events = GameEvents.new()
	root.add_child(_events)
	_ctx = Ctx.new()
	_ctx.events = _events
	_ctx.run = RunState.new(_events)
	_ctx.tuning = Tuning.new()
	_ctx.tuning.set_option(Tuning.MUSIC_KEY, "ace")
	_audio = Audio.new()
	root.add_child(_audio)
	_audio.setup(_ctx)
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	if _audio == null:
		return true
	var now := Time.get_ticks_usec()
	if _step <= 2:
		_frame_ms.append((now - _last_us) / 1000.0)
	_last_us = now
	match _step:
		0:
			if _audio.sound_ready and _audio.ace != null and _audio.ace.mode == "menu":
				_step = 1
		1:
			# The title's worker result has already been adopted by the menu. With the title_a pack on disk the title row resolves to it (audio.gd), so any title variant counts.
			var preloaded: bool = _audio.ace.ready() and _audio.ace.manifest.get("theme") in ["title", "title_a", "title_b"] \
				and _audio._ace_loaded_from == _audio._ace_from and _audio._ace_task == -1
			_events.run_started.emit("arc_caster")
			_step = 2
			_last_us = Time.get_ticks_usec()
			_check("stems loaded off the main thread", preloaded, "the worker's package was ready before run_started (%s)" % preloaded)
		2:
			if _audio.ace != null:
				_step = 3
				var worst := 0.0
				for ms: float in _frame_ms:
					worst = maxf(worst, ms)
				_check("no frame over 50 ms, title to run", worst < FRAME_LIMIT_MS and _audio.ace.mode == "level",
					"%d main-thread frames from setup to stage 1's ACE start, the longest %.1f ms (limit %.0f); building the same package on the main thread takes %.0f ms" % [
					_frame_ms.size(), worst, FRAME_LIMIT_MS, _main_thread_load_ms])
		3:
			_audio.set_process(false)
			_run_checks()
			print("presentation_ace_director_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
	return false


func _run_checks() -> void:
	_advance_to(_audio.ace.grid_bar * 3, 512)
	_launch_out_of_the_break()
	_launch_out_of_the_level()
	_unmute_fade()
	_grid_release()
	_deepen()


# Renders the director's pump in blocks; every block's ACE and synth output is appended to
# acc when it is given. Returns the transport sample reached.
func _advance(frames: int, block := 512, acc: PackedVector2Array = PackedVector2Array(), collect := false) -> PackedVector2Array:
	var left := frames
	while left > 0:
		var n := mini(block, left)
		_audio._virtual_usec = Time.get_ticks_usec() - int(n * 1e6 / 44100.0)
		var ace_live: bool = _audio.ace != null and _audio.ace.active()
		_audio._pump()
		if collect:
			var got: int = _audio.engine.out_music.size()
			for i in got:
				var f: Vector2 = _audio.engine.out_music[i]
				if ace_live and i < _audio.ace.out.size():
					f += _audio.ace.out[i]
				acc.append(f)
		left -= n
	return acc


func _advance_to(sample: int, block := 512) -> void:
	while _audio.engine.clock < sample:
		_advance(mini(block, sample - _audio.engine.clock), block)


func _flush() -> void:
	_audio._flush_flow()


func _longest_silence(buf: PackedVector2Array) -> int:
	var run := 0
	var longest := 0
	for f in buf:
		if absf(f.x) < 1e-5 and absf(f.y) < 1e-5:
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	return longest


func _peak(buf: PackedVector2Array, from: int, to: int) -> float:
	var m := 0.0
	for i in range(from, mini(to, buf.size())):
		m = maxf(m, maxf(absf(buf[i].x), absf(buf[i].y)))
	return m


# The unseal breaks the Warden mid-run; a bot's launch comes before the piece ends.
func _launch_out_of_the_break() -> void:
	var ace: Ace = _audio.ace
	var engine = _audio.engine
	_events.beacon_unsealed.emit(1)
	_flush()
	var piece: bool = ace.mode == "piece"
	_advance(ace.grid_bar * 2, 512)
	var in_break: bool = ace.section == "break"
	_events.launched.emit(Vector3(0.0, 12.0, -30.0))
	var held: bool = _audio._ace_flight and ace.mode == "piece" and _audio._launch_armed
	_events.stage_entered.emit(2, false)
	_flush()
	var kept: bool = ace.mode == "piece" and engine.band_muted
	var flight := PackedVector2Array()
	flight = _advance(BEAT * 6, 512, flight, true)
	var through: bool = ace.mode == "piece" and _peak(flight, 0, flight.size()) > 0.05 and _longest_silence(flight) < 64
	_events.landed.emit(20.0)
	var touchdown: int = engine.clock
	var entry: Array = _audio.drop_log[-1] if not _audio.drop_log.is_empty() else [-1, -1]
	var at := int(entry[1])
	var on_beat: bool = at > touchdown and at - touchdown <= BEAT + 441 and posmod(at - ace.origin, ace.grid_beat) == 0
	var pending_stop: bool = _audio._handover_at == at and ace.mode == "piece"
	var handover := PackedVector2Array()
	var muted_until_ramp := true
	var mode_until_at := true
	while engine.clock < at + BEAT * 2:
		handover = _advance(256, 256, handover, true)
		if engine.clock + 256 <= at - _audio.UNMUTE_RAMP and not engine.band_muted:
			muted_until_ramp = false
		if engine.clock < at and ace.mode != "piece":
			mode_until_at = false
	var after_at: int = handover.size() - (int(engine.clock) - at)
	var drop_peak := _peak(handover, maxi(after_at, 0), maxi(after_at, 0) + 4410)
	var silent := _longest_silence(handover)
	var done: bool = ace.mode == "off" and not _audio._ace_flight and _audio._handover_at == -1 and engine.grid == null and not engine.band_muted
	_check("break plays through the launch flight, hands over on the landing", piece and in_break and held and kept and through and on_beat and pending_stop \
		and muted_until_ramp and mode_until_at and drop_peak > 0.02 and silent < 64 and done,
		"piece %s, in the break %s; launched: flight holds the band %s; stage_entered leaves it (synth muted) %s; %d frames of flight, ACE audible and unbroken (longest silence %d) %s; landing at %d drops on the beat %d (%d frames on, ACE grid beat %s); stop scheduled on it %s; synth muted until its ramp %s, ACE played to the beat %s; the synth drop peaks %.3f in the 4410 frames from the beat; longest silence touchdown to a beat and a half after %d frames; band handed over %s" % [
		piece, in_break, held, kept, flight.size(), _longest_silence(flight), through, touchdown, at, at - touchdown, on_beat, pending_stop,
		muted_until_ramp, mode_until_at, drop_peak, silent, done])
	_advance(BEAT * 20, 512)
	_check("destination ACE starts after the synth landing drop", _audio.ace != ace \
		and _audio.ace.manifest.get("theme") == "cable_reach" and _audio.ace.mode == "level" \
		and engine.grid == _audio.ace and engine.band_muted and not engine.in_drop(),
		"the directed flight and synth landing finish before Cable Reach's recorded bed")


# The unsealed stage's gate: no piece, so the launch riser is the flight's music.
func _launch_out_of_the_level() -> void:
	_events.run_started.emit("arc_caster")
	_flush()
	var ace: Ace = _audio.ace
	var engine = _audio.engine
	_advance(ace.grid_bar * 3, 512)
	var level: bool = ace.mode == "level" and engine.band_muted
	_events.launched.emit(Vector3(0.0, 12.0, -30.0))
	var riser: bool = engine._build_riser != null
	_check("a launch out of the level keeps its riser", level and ace.mode == "off" and not _audio._ace_flight and not engine.band_muted and riser,
		"ACE in %s with the synth muted %s; after the launch the band is %s, un-muted %s, riser sounding %s (it was dropped while muted before the fix)" % [
		"level" if level else "another mode", level, ace.mode, not engine.band_muted, riser])
	_advance(BEAT * 4, 512)
	_events.stage_entered.emit(2, false)
	_events.landed.emit(10.0)
	_advance(BEAT * 3, 512)
	_flush()


func _unmute_fade() -> void:
	var engine = _audio.engine
	engine.band_muted = true
	_audio._ace_end()
	var from: int = engine.clock
	var out := PackedVector2Array()
	out.resize(2000)
	out.fill(Vector2(1.0, 1.0))
	engine.out_music = out
	_audio._fade_in_band(from, 2000)
	var got: PackedVector2Array = engine.out_music
	var ramp: int = _audio.UNMUTE_RAMP
	var monotone := true
	for i in range(1, ramp):
		monotone = monotone and got[i].x >= got[i - 1].x
	var ok: bool = got[0].x < 0.01 and absf(got[ramp / 2].x - 0.5) < 0.02 and got[ramp].x == 1.0 and got[1999].x == 1.0 and monotone
	var out2 := PackedVector2Array()
	out2.resize(100)
	out2.fill(Vector2(1.0, 1.0))
	engine.out_music = out2
	_audio._fade_in_band(from + ramp + 5000, 100)
	ok = ok and _audio._unmute_at == -1 and engine.out_music[0].x == 1.0
	_check("synth un-mute fades in", ok, "first frame %.3f, mid-ramp %.3f, frame %d %.3f, monotone %s; the ramp clears once passed %s" % [
		got[0].x, got[ramp / 2].x, ramp, got[ramp].x, monotone, _audio._unmute_at == -1])


func _grid_release() -> void:
	var engine = _audio.engine
	_events.run_started.emit("arc_caster")
	_flush()
	_advance(BEAT * 2, 512)
	var was: bool = engine.grid != null
	_audio._flow_queue.append(["dead"])
	_flush()
	_check("engine.grid released with the band", was and engine.grid == null and _audio.ace.mode == "off",
		"grid held during stage 1 %s; after the death burst %s" % [was, "released" if engine.grid == null else "still the ACE band"])


func _deepen() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.1
	var capacity: int = (gen.instantiate_playback() as AudioStreamGeneratorPlayback).get_frames_available()
	_audio._ring_capacity = capacity
	_audio.queue_target = Ace.QUEUE_TARGET
	_audio._skips_seen = 0
	var steps := []
	for skips in [1, 1, 2, 3, 4, 5, 6]:
		_audio._deepen_for(skips)
		steps.append(_audio.queue_target)
	var capped: bool = int(steps[-1]) <= capacity - 1024
	var ok: bool = steps[0] == Ace.QUEUE_TARGET + 1024 and steps[1] == steps[0] and steps[2] == steps[0] + 1024 and capped
	# A ring of the nominal 4410 frames leaves no room to deepen: the guard holds the target.
	_audio._ring_capacity = 4410
	_audio.queue_target = Ace.QUEUE_TARGET
	_audio._skips_seen = 0
	_audio._deepen_for(3)
	ok = ok and _audio.queue_target == Ace.QUEUE_TARGET
	_check("ring deepens per skip", ok, "a 0.1 s generator at 44.1 kHz reports %d frames available when empty; a skip each deepens the target %s (capped at %d); a 4410-frame ring stays at %d" % [
		capacity, steps, capacity - 1024, _audio.queue_target])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
