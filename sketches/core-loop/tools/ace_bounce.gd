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
#     --out=<absolute .wav> [--seconds=80] [--tail=3] [--policy=skipper] [--seed=1] --music=ace \
#     [--slow-at=<seconds> | --slow-at=boss] [--slow-for=2.3] [--slow-scale=0.3] [--only=music|effects]
#
# --slow-at slows the world at that second of the WAV the way the close-up at Brindle's entrance
# does (game.slow_motion; flourish_rows.gd asks for 0.3 of the world's speed, about 2.3 s of
# wall time), so the falling sweep, the held music and the rising sweep are recorded over
# whatever the run is playing. No bot's run slows the world on its own. --slow-at=boss slows it
# where the game does: 0.15 s after the boss's arena is entered (boss_arena_entered, the
# arrival row's own "at"), so the sweeps are heard at Brindle's entrance over his anthem.
#
# --only records one side of the mix from the same bot and seed: music turns the effects, UI and
# ambience volumes to nothing, effects turns the music's to nothing (audio.set_volume, the pause
# menu's own rows). The split is by bus: the band's stingers ride the effects bus, so they are on
# the effects side. Each is its own run, so times differ a little. The Master compressor then works on less, so the two do not sum to the whole
# mix; they say which side sets the level at a moment and how far the music moves on its own.
#
# The recording runs --tail seconds past the tick the run ends on (a death, a win, a stall), so
# what the music does after the end is in the WAV: the band stop and brass fall after a death,
# the cadence after a kill. The bot is not ticked in the tail. --seconds stays the hard cap.
#
# Beside the WAV, <out>.json lists the game facts the music follows (Warden states,
# drops, the commit, the break) and the ACE sections entered, both in seconds of the WAV,
# with the music ring's skips. music_skips counts from the recording's start, music_skip_rows
# lists [seconds of the WAV, skips since the last physics tick] wherever the ring ran dry (a gap
# in the music you can hear), and music_skips_before is what setup and the bot's start cost
# before the recording began. ace_sections covers every pack the run played; each row ends with
# its pack. Two facts carry more:
#   [s, "player_died", transport sample, ACE section origin sample, ACE beat in samples]
#     samples count from the recording's start; origin and beat are null on the synth band.
#     (stop sample - origin) mod beat says where in the beat the band stopped.
#   [s, "run_over", outcome]   the tick the tail starts on
#   [s, "slow_motion", true | false]   --slow-at's window opening and closing (it closes with
#     the recording if the recording ends first)
# cue_rows lists every cue with a start sample since the recording began, in order:
# [seconds of the WAV, kind, sound, "now" | "beat" | "music" | ..., pitch, level in dB or null].

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
var _slow_at := -1.0
var _slow_for := 2.3
var _slow_scale := 0.3
var _slowing := false
var _slow_on_boss := false
# The arrival row's slow starts this long after the arena is entered (flourish_rows.gd
# brindle_arrival, "at": 0.15 of the row's seconds, before the world slows).
const BOSS_SLOW_AFTER := 0.15
# Every recorded band the run played, in order: a change of pack makes a new sequencer
# (audio.gd ace_ready), and each keeps its own log and counters. Looked for once a physics tick.
var _bands: Array = []
var _skips_before := 0
var _skips_seen := 0
var _skip_rows: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if not _settings.has("out"):
		printerr("ace_bounce: needs -- --out=<absolute .wav>")
		quit(2)
		return
	if not String(_settings.get("only", "")) in ["", "music", "effects"]:
		printerr("ace_bounce: --only takes music or effects")
		quit(2)
		return
	_seconds = float(_settings.get("seconds", "80"))
	_tail = maxf(float(_settings.get("tail", "3")), 0.0)
	_slow_on_boss = String(_settings.get("slow-at", "")) == "boss"
	_slow_at = -1.0 if _slow_on_boss else float(_settings.get("slow-at", "-1"))
	_slow_for = float(_settings.get("slow-for", "2.3"))
	_slow_scale = clampf(float(_settings.get("slow-scale", "0.3")), Game.SLOW_MOTION_FLOOR, 1.0)
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
		_skips_before = _skips(audio)
		_skips_seen = _skips_before
		match String(_settings.get("only", "")):
			"music":
				audio.set_volume("SFX", 0.0)
			"effects":
				audio.set_volume("Music", 0.0)
		var events = _game.events
		events.stage_entered.connect(func(stage: int, retry: bool): _facts.append([_now(), "stage_entered", stage, retry]))
		events.player_died.connect(_on_player_died)
		events.warden_engaged.connect(func(stage: int): _facts.append([_now(), "warden_engaged", stage]))
		events.beacon_unsealed.connect(func(stage: int): _facts.append([_now(), "warden_broken", stage]))
		events.boss_arena_entered.connect(_on_boss_arena)
		events.world_fact.connect(func(kind: String, _at: Vector3):
			if kind.begins_with("steam_lift") or kind.begins_with("ride_"):
				_facts.append([_now(), "world_fact", kind]))
		return false
	if audio.has_method("mix_state"):
		var state: String = audio.mix_state()
		if _mix_states.is_empty() or _mix_states.back()[1] != state:
			_mix_states.append([snappedf(_now(), 0.01), state])
	_keep_band(audio.ace)
	var skips := _skips(audio)
	if skips > _skips_seen:
		_skip_rows.append([snappedf(_now(), 0.01), skips - _skips_seen])
		_skips_seen = skips
	_slow_window()
	if _end_at < 0.0 and _driver.tick(delta):
		_end_at = _now() + _tail
		_facts.append([_now(), "run_over", _driver.outcome])
	if (_end_at >= 0.0 and _now() >= _end_at) or _now() >= _seconds:
		_finish()
	return false


func _skips(audio) -> int:
	return audio._music_pb.get_skips() if audio._music_pb != null else 0


func _keep_band(ace) -> void:
	if ace != null and not _bands.has(ace):
		_bands.append(ace)


func _on_boss_arena() -> void:
	_facts.append([_now(), "boss_arena_entered"])
	if _slow_on_boss and _slow_at < 0.0:
		_slow_at = _now() + BOSS_SLOW_AFTER


# The world is slow between --slow-at and --slow-at + --slow-for seconds of the recording.
func _slow_window() -> void:
	var on := _slow_at >= 0.0 and _now() >= _slow_at and _now() < _slow_at + _slow_for
	if on == _slowing:
		return
	_slowing = on
	_game.slow_motion(_slow_scale if on else 1.0)
	_facts.append([_now(), "slow_motion", on])


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


# Cues with a start sample inside the recording, timed in seconds of the WAV, each with the
# pitch and the level the game played it at (tools/mix/mixsim.py places them from these).
func _cue_rows(rows: Array) -> Array:
	var out := []
	for row in rows:
		if row.size() > 3 and int(row[3]) >= _base_sample:
			out.append([snappedf((int(row[3]) - _base_sample) / RATE, 0.0001), row[0], row[1], row[2], row[4] if row.size() > 4 else 1.0, row[5] if row.size() > 5 else null])
	return out


# The set director's plans, each with its bar's time in seconds of the WAV (-1 before the recording).
func _plan_rows(plans: Array) -> Array:
	var out := []
	for row in plans:
		var at := int(row[4]) if row.size() > 4 else -1
		out.append(row.duplicate() + [snappedf((at - _base_sample) / RATE, 0.0001) if at >= _base_sample else -1.0])
	return out


func _finish() -> void:
	if _slowing:
		# The recording ended inside the window: the world gets its speed back, and the facts say so.
		_slowing = false
		_game.slow_motion(1.0)
		_facts.append([_now(), "slow_motion", false])
	var audio = _game.presentation.audio
	_record.set_recording_active(false)
	var wav: AudioStreamWAV = _record.get_recording()
	var out: String = _settings["out"]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	wav.save_to_wav(out)
	var ace = audio.ace
	_keep_band(ace)
	var sections := []
	var misses := 0
	var short_reads := 0
	var render_usec := 0
	var rendered := 0
	for band in _bands:
		var pack: String = band.manifest_source.get_base_dir().get_file()
		for e in band.events_log:
			sections.append([snappedf((int(e[1]) - _base_sample) / RATE, 0.01), e[0], e[2], pack, sections.size()])
		misses += band.misses
		short_reads += band.short_reads
		render_usec += band.render_usec
		rendered += band.rendered
	# By time; rows at the same time keep the order they were logged in (a stop, then the next enter).
	sections.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[4] < b[4]))
	for row in sections:
		row.pop_back()
	var info := {"wav": out, "seconds": snappedf(_now(), 0.1), "mix_rate": AudioServer.get_mix_rate(), "driver": AudioServer.get_driver_name(),
		"music": _game.tuning.option("music"), "breath": _game.tuning.option("breath"), "set_director": _game.tuning.option("set_director"),
		"set_plans": _plan_rows(audio.set_director.plans),
		"policy": _driver.policy, "outcome": _driver.outcome, "stage": _game.run.stage, "tail": _tail,
		"ace_loaded": ace != null, "ace_missing": audio.ace_missing, "only": String(_settings.get("only", "")),
		"music_skips": _skips(audio) - _skips_before if audio._music_pb != null else -1, "music_skips_before": _skips_before, "music_skip_rows": _skip_rows,
		"ace_bands": _bands.size(), "ace_misses": misses if ace != null else -1, "ace_short_reads": short_reads if ace != null else -1,
		"ace_render_ms_per_second": snappedf(render_usec / 1000.0 / maxf(rendered / RATE, 0.001), 0.01) if ace != null else -1.0,
		"note": "section times are the render head in seconds from the recording's start; the ring and device add about 75 ms",
		"facts": _facts, "ace_sections": sections, "mix_states": _mix_states, "cue_counts": _cue_counts(audio.cue_log), "cue_rows": _cue_rows(audio.cue_log)}
	var file := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "  "))
	file.close()
	print("ace_bounce: %.1f s, %d facts, %d ACE entries, music skips %s -> %s" % [_now(), _facts.size(), sections.size(), info["music_skips"], out])
	quit(0)
