extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
# The transport's sample rate (ace_sequencer.gd RATE).
const RATE := 44100.0

# A headless audio bounce of a bot run: the Master bus recorded while a bot plays, so the
# ACE music can be heard in context with every SFX and stinger the run fires. The Dummy
# driver mixes in real time on its own thread, so the players are forced live and the run
# plays at wall-clock speed.
#
#   godot --headless --path sketches/core-loop --script res://tools/ace_bounce.gd -- \
#     --out=<absolute .wav> [--seconds=80] [--tail=3] [--policy=skipper] [--seed=1] --music=ace
#
# The recording runs --tail seconds past the tick the run ends on (a death, a win, a stall), so
# what the music does after the end is in the WAV: the band stop and brass fall after a death,
# the cadence after a kill. The bot is not ticked in the tail. --seconds stays the hard cap.
#
# Beside the WAV, <out>.json lists the game facts the music follows (Warden states,
# drops, the commit, the break) and the ACE sections entered, both in seconds of the WAV,
# with the music ring's skip count. Two facts carry more:
#   [s, "player_died", transport sample, ACE section origin sample, ACE beat in samples]
#     samples count from the recording's start; origin and beat are null on the synth band.
#     (stop sample - origin) mod beat says where in the beat the band stopped.
#   [s, "run_over", outcome]   the tick the tail starts on
# cue_rows lists every cue with a start sample since the recording began, in order:
# [seconds of the WAV, kind, sound, "now" | "beat" | "music" | ...].

var _settings := {}
var _game
var _driver
var _record: AudioEffectRecord
var _started := -1
var _seconds := 80.0
var _facts: Array = []
var _base_sample := 0
var _mix_states: Array = []
var _tail := 3.0
var _end_at := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if not _settings.has("out"):
		printerr("ace_bounce: needs -- --out=<absolute .wav>")
		quit(2)
		return
	_seconds = float(_settings.get("seconds", "80"))
	_tail = maxf(float(_settings.get("tail", "3")), 0.0)
	seed(int(_settings.get("seed", "1")))
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _now() -> float:
	return (Time.get_ticks_msec() - _started) / 1000.0 if _started >= 0 else -1.0


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null or _game.presentation == null:
		return false
	var audio = _game.presentation.audio
	if _driver == null:
		if not audio.sound_ready:
			# Before the bake lands, so _on_ready starts the players on the Dummy driver; the
			# recorder goes last on Master, after the limiter audio.gd put there.
			audio.live_output = true
			if _record == null:
				_record = AudioEffectRecord.new()
				AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _record)
			return false
		if not audio.live_output:
			printerr("ace_bounce: the audio started before the players could be forced live")
			quit(3)
			return false
		_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), int(_settings.get("seed", "1")))
		_driver.start()
		_record.set_recording_active(true)
		_started = Time.get_ticks_msec()
		_base_sample = audio.engine.clock
		var events = _game.events
		events.stage_entered.connect(func(stage: int, retry: bool): _facts.append([_now(), "stage_entered", stage, retry]))
		events.player_died.connect(_on_player_died)
		events.warden_engaged.connect(func(stage: int): _facts.append([_now(), "warden_engaged", stage]))
		events.beacon_unsealed.connect(func(stage: int): _facts.append([_now(), "warden_broken", stage]))
		events.world_fact.connect(func(kind: String, _at: Vector3):
			if kind.begins_with("steam_lift") or kind.begins_with("ride_"):
				_facts.append([_now(), "world_fact", kind]))
		return false
	if audio.has_method("mix_state"):
		var state: String = audio.mix_state()
		if _mix_states.is_empty() or _mix_states.back()[1] != state:
			_mix_states.append([snappedf(_now(), 0.01), state])
	if _end_at < 0.0 and _driver.tick(delta):
		_end_at = _now() + _tail
		_facts.append([_now(), "run_over", _driver.outcome])
	if (_end_at >= 0.0 and _now() >= _end_at) or _now() >= _seconds:
		_finish()
	return false


func _on_player_died() -> void:
	var audio = _game.presentation.audio
	var ace = audio.ace
	_facts.append([_now(), "player_died", audio.engine.clock - _base_sample,
		ace.origin - _base_sample if ace != null else null, ace.grid_beat if ace != null else null])


# Cues started now, by sound, over the whole session (title included): what stacks into the mix.
static func _cue_counts(rows: Array) -> Dictionary:
	var counts := {}
	for row in rows:
		if row.size() > 2 and row[2] == "now":
			counts[row[1]] = int(counts.get(row[1], 0)) + 1
	return counts


# Cues with a start sample inside the recording, timed in seconds of the WAV.
func _cue_rows(rows: Array) -> Array:
	var out := []
	for row in rows:
		if row.size() > 3 and int(row[3]) >= _base_sample:
			out.append([snappedf((int(row[3]) - _base_sample) / RATE, 0.001), row[0], row[1], row[2]])
	return out


func _finish() -> void:
	var audio = _game.presentation.audio
	_record.set_recording_active(false)
	var wav: AudioStreamWAV = _record.get_recording()
	var out: String = _settings["out"]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	wav.save_to_wav(out)
	var sections := []
	var ace = audio.ace
	if ace != null:
		for e in ace.events_log:
			sections.append([snappedf((int(e[1]) - _base_sample) / RATE, 0.01), e[0], e[2]])
	var info := {"wav": out, "seconds": snappedf(_now(), 0.1), "mix_rate": AudioServer.get_mix_rate(), "driver": AudioServer.get_driver_name(),
		"music": _game.tuning.option("music"), "breath": _game.tuning.option("breath"),
		"policy": _driver.policy, "outcome": _driver.outcome, "stage": _game.run.stage, "tail": _tail,
		"ace_loaded": ace != null, "ace_missing": audio.ace_missing, "music_skips": audio._music_pb.get_skips() if audio._music_pb != null else -1,
		"ace_misses": ace.misses if ace != null else -1, "ace_short_reads": ace.short_reads if ace != null else -1,
		"ace_render_ms_per_second": snappedf(ace.render_usec / 1000.0 / maxf(ace.rendered / RATE, 0.001), 0.01) if ace != null else -1.0,
		"note": "section times are the render head in seconds from the recording's start; the ring and device add about 75 ms",
		"facts": _facts, "ace_sections": sections, "mix_states": _mix_states, "cue_counts": _cue_counts(audio.cue_log), "cue_rows": _cue_rows(audio.cue_log)}
	var file := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "  "))
	file.close()
	print("ace_bounce: %.1f s, %d facts, %d ACE entries, music skips %s -> %s" % [_now(), _facts.size(), sections.size(), info["music_skips"], out])
	quit(0)
