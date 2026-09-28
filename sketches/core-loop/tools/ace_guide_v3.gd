extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const AudioBoard := preload("res://tools/audio_board.gd")

# The engine side of the hybrid bed test: Spillway at one fixed pressure, 16 bars on
# the band's grid after a pre-roll phrase, rendered once per solo from identically
# seeded engines. "above" is every layer the engine would keep live over a cover's keys
# and drums; "full" is the synth control; "keys", "drums" and "kick" say where the
# engine's own parts sit, so the cover stems can be placed at those levels and the
# cover's kicks can be checked against the engine's. Every file shares the full mix's
# gain to -14 LUFS, and engine.json records the grid and each solo's level.
#
#   godot --headless --path sketches/core-loop --script res://tools/ace_guide_v3.gd -- --out=/abs/dir
#
# --guides writes ACE-Step cover guides instead: guide-full (every layer), guide-drums-bass
# (hats, kick, snare, sub, bass) and guide-drums, plus the engine's kick, bass and keys solos,
# all BARS + 1 bars long (the extra bar is the cover's loop tail) at the full guide's shared
# gain. --pressure=<p> sets the pressure (default PRESSURE).
#
# --parent=calm|warden writes one Slice 0 parent guide (ACE-MUSIC-REVIEW §2): guide-full,
# guide-drums, engine-kick and engine-bass over the whole parent, and guide.json with the
# section map, the cues, the screen region, the events log and each bar's note starts per
# layer. --engine=<abs path> drives a different music_engine.gd with the same layer enum,
# for the AU1 engine (the held breath and hold_dominant):
#   git show c818fd1:sketches/core-loop/src/presentation/music_engine.gd > <path>

const THEME := 0
const PRESSURE := 0.9
const PREROLL_BARS := 8
const BARS := 16
const SEED := 172
const DRUMS := [MusicEngine.HATS, MusicEngine.KICK, MusicEngine.SNARE]
const UNDER := [MusicEngine.KEYS, MusicEngine.HATS, MusicEngine.KICK, MusicEngine.SNARE]
const DEFAULT_OUT := "../../artifacts/local/v3-audio/hybrid/engine"
const BAR_129 := Harmony.BOSS_STEP * Harmony.STEPS_PER_BAR
const CLASS_MOTIF := "sable"
const CALM_PRESSURE := 0.6
const TRAVEL_PRESSURE := 0.9
const WARDEN_PRESSURE := 0.6


static func above() -> Array:
	var layers := []
	for layer in MusicEngine.LAYER_NAMES.size():
		if not layer in UNDER:
			layers.append(layer)
	return layers


static func render(solo: Array, pressure := PRESSURE, bars := BARS) -> Dictionary:
	var engine := MusicEngine.new()
	engine._rng.seed = SEED
	engine.schedule_restart(0, MusicEngine.PLAY, THEME)
	engine.set_pressure(pressure)
	engine.solo = solo
	var take := AudioBoard.Take.new()
	var bar := engine.bar_len()
	var start := PREROLL_BARS * bar
	var total := start + bars * bar
	take.left.resize(bars * bar)
	take.right.resize(bars * bar)
	var gains := {}
	var clock := 0
	while clock < total:
		var n := mini(2048, total - clock)
		if clock < start:
			n = mini(n, start - clock)
		if clock == start:
			for layer in MusicEngine.LAYER_NAMES.size():
				gains[MusicEngine.LAYER_NAMES[layer]] = snappedf(engine.layer_gain(layer), 0.0001)
		engine.render(n)
		if clock >= start:
			var music := engine.out_music
			for i in n:
				take.left[clock - start + i] = music[i].x
				take.right[clock - start + i] = music[i].y
		clock += n
	return {"take": take, "gains": gains, "bpm": engine.bpm(), "bar": bar, "rate": Harmony.RATE, "theme": engine.theme}


static func scaled(take: AudioBoard.Take, gain_db: float) -> float:
	var g := db_to_linear(gain_db)
	for i in take.left.size():
		take.left[i] *= g
		take.right[i] *= g
	return AudioBoard._limit(take.left, take.right)


static func names(layers: Array) -> Array:
	return layers.map(func(layer): return MusicEngine.LAYER_NAMES[layer])


func guides(out: String, pressure: float) -> int:
	var bars := BARS + 1
	var full := render([], pressure, bars)
	var mix: AudioBoard.Take = full["take"]
	var stats := AudioBoard.master(mix)
	var parts := {"guide-full": mix}
	var solos := {"guide-full": {"layers": names(range(MusicEngine.LAYER_NAMES.size())), "lufs_after": stats["lufs"],
		"peak_db": stats["peak_db"], "limit_db": stats["limit_db"]}}
	var bass := [MusicEngine.SUB, MusicEngine.REESE]
	for part in [["guide-drums-bass", DRUMS + bass], ["guide-drums", DRUMS], ["engine-kick", [MusicEngine.KICK]],
			["engine-bass", bass], ["engine-keys", [MusicEngine.KEYS]]]:
		var take: AudioBoard.Take = render(part[1], pressure, bars)["take"]
		var limit := scaled(take, stats["gain_db"])
		parts[part[0]] = take
		solos[part[0]] = {"layers": names(part[1]), "lufs_after": AudioBoard.loudness(take.left, take.right),
			"peak_db": linear_to_db(AudioBoard.peak(take.left, take.right)), "limit_db": limit}
	var failed := 0
	for name in parts:
		if AudioBoard.to_wav(parts[name]).save_to_wav(out.path_join(name + ".wav")) != OK:
			failed += 1
			push_error("could not write %s.wav" % name)
	var info := {
		"theme": "spillway", "theme_index": full["theme"], "pressure": pressure, "seed": SEED,
		"preroll_bars": PREROLL_BARS, "bars": BARS, "rendered_bars": bars, "bpm": full["bpm"],
		"sample_rate": full["rate"], "samples_per_bar": full["bar"], "samples_per_beat": full["bar"] / 4,
		"total_frames": mix.left.size(), "layer_gains": full["gains"], "mix_master": stats, "solos": solos,
	}
	var file := FileAccess.open(out.path_join("guide.json"), FileAccess.WRITE)
	if file == null:
		return failed + 1
	file.store_string(JSON.stringify(info, " "))
	file.close()
	print(JSON.stringify(info, " "))
	return failed


# A parent: sections [name, start, bars, bar_len] and cues [at, engine method, args], both
# in output samples (a negative cue lands in the pre-roll). The calm parent is calm-a at
# 0.6 (pack 2's guide), then travel at 0.9 (the class counter's pressure), ending in the
# pivot bar on the held dominant. The Warden parent opens on the same pivot (three 129
# quarters), releases the dominant for the build, holds it again for the telegraph (the
# build with its kick and the riser), thins to the kickless open with the bass ducked,
# drops on the next bar line after an eighth's gap, and cadences home. Screen regions skip
# the pivot: its three hits are not on the kick layer, so the kick solo cannot place them.
static func plan(which: String) -> Dictionary:
	var bar := Harmony.BAR
	var pre := -PREROLL_BARS * bar
	if which == "calm":
		return {"bpm": 172, "frames": 32 * bar, "screen": [0, 31, bar],
			"sections": [["calm", 0, 16, bar], ["travel", 16 * bar, 15, bar], ["pivot", 31 * bar, 1, bar]],
			"cues": [[pre, "set_pressure", [CALM_PRESSURE]], [pre, "set_class_motif", [CLASS_MOTIF]],
				[16 * bar, "set_pressure", [TRAVEL_PRESSURE]],
				[31 * bar, "hold_dominant", [true]], [31 * bar, "begin_boss", ["warden"]]]}
	var build := bar
	var telegraph := build + 16 * BAR_129
	var open := telegraph + 4 * BAR_129
	var drop := open + 4 * BAR_129
	var cadence := drop + 4 * BAR_129
	var tail := cadence + 2 * BAR_129
	var four := 4.0 * BAR_129 / Harmony.RATE
	return {"bpm": 129, "frames": tail + bar, "screen": [build, 28, BAR_129],
		"sections": [["pivot", 0, 1, bar], ["build", build, 16, BAR_129], ["telegraph", telegraph, 4, BAR_129],
			["open", open, 4, BAR_129], ["drop", drop, 4, BAR_129], ["cadence", cadence, 2, BAR_129], ["tail", tail, 1, bar]],
		"cues": [[pre, "set_pressure", [TRAVEL_PRESSURE]], [pre, "set_class_motif", [CLASS_MOTIF]],
			[0, "hold_dominant", [true]], [0, "begin_boss", ["warden"]],
			[build, "hold_dominant", [false]], [build, "set_pressure", [WARDEN_PRESSURE]],
			[telegraph, "hold_dominant", [true]], [telegraph, "start_build", [four]],
			[open, "warden_section", ["open"]], [open, "duck_bass", [0.3, four]],
			[drop - 2 * Harmony.BOSS_STEP, "drop_now", [4, 1.0]], [drop - 2 * Harmony.BOSS_STEP, "free_bass", []],
			[cadence, "end_boss", []]]}


static func bar_starts(p: Dictionary) -> Array:
	var starts := []
	for section in p["sections"]:
		for b in int(section[2]):
			starts.append(int(section[1]) + b * int(section[3]))
	return starts


static func render_parent(script: GDScript, p: Dictionary, solo: Array) -> Dictionary:
	var engine = script.new()
	engine._rng.seed = SEED
	engine.schedule_restart(0, MusicEngine.PLAY, THEME)
	engine.solo = solo
	var pre := PREROLL_BARS * Harmony.BAR
	var total := pre + int(p["frames"])
	var cues: Array = p["cues"]
	var stops := bar_starts(p)
	var take := AudioBoard.Take.new()
	take.left.resize(int(p["frames"]))
	take.right.resize(int(p["frames"]))
	var per_bar := []
	var gains := {}
	var next_cue := 0
	var next_stop := 0
	var clock := 0
	while clock < total:
		while next_cue < cues.size() and pre + int(cues[next_cue][0]) <= clock:
			engine.callv(cues[next_cue][1], cues[next_cue][2])
			next_cue += 1
		if next_stop < stops.size() and pre + int(stops[next_stop]) == clock:
			per_bar.append({"starts": engine.layer_starts.duplicate(), "track": engine.track, "section": engine.section,
				"key": engine.key, "bpm": snappedf(engine.bpm(), 0.01)})
			if next_stop == 0:
				for layer in MusicEngine.LAYER_NAMES.size():
					gains[MusicEngine.LAYER_NAMES[layer]] = snappedf(engine.layer_gain(layer), 0.0001)
			next_stop += 1
		var n := mini(2048, total - clock)
		if next_cue < cues.size():
			n = mini(n, pre + int(cues[next_cue][0]) - clock)
		if next_stop < stops.size():
			n = mini(n, pre + int(stops[next_stop]) - clock)
		if clock < pre:
			n = mini(n, pre - clock)
		engine.render(n)
		if clock >= pre:
			var music: PackedVector2Array = engine.out_music
			for i in n:
				take.left[clock - pre + i] = music[i].x
				take.right[clock - pre + i] = music[i].y
		clock += n
	per_bar.append({"starts": engine.layer_starts, "track": engine.track, "section": engine.section,
		"key": engine.key, "bpm": snappedf(engine.bpm(), 0.01)})
	var planned := []
	for section in p["sections"]:
		for b in int(section[2]):
			planned.append(section[0])
	var notes := []
	for b in stops.size():
		var now: PackedInt32Array = per_bar[b]["starts"]
		var after: Dictionary = per_bar[b + 1]
		var later: PackedInt32Array = after["starts"]
		var counts := {}
		for layer in MusicEngine.LAYER_NAMES.size():
			if later[layer] > now[layer]:
				counts[MusicEngine.LAYER_NAMES[layer]] = later[layer] - now[layer]
		notes.append({"bar": b + 1, "at": stops[b], "planned": planned[b], "engine_at_bar_end": "%s/%s" % [after["track"], after["section"]],
			"key": after["key"], "bpm": after["bpm"], "note_starts": counts})
	var events := []
	for event in engine.events_log:
		events.append([str(event[0]), int(event[1]) - pre, str(event[2])])
	return {"take": take, "gains": gains, "bars": notes, "events": events}


func parent(out: String, which: String, engine_path: String) -> int:
	var script: GDScript = load(engine_path)
	if script == null:
		push_error("could not load engine %s" % engine_path)
		return 1
	var p := plan(which)
	var full := render_parent(script, p, [])
	var mix: AudioBoard.Take = full["take"]
	var stats := AudioBoard.master(mix)
	var parts := {"guide-full": mix}
	var solos := {"guide-full": {"lufs_after": stats["lufs"], "peak_db": stats["peak_db"], "limit_db": stats["limit_db"]}}
	for part in [["guide-drums", DRUMS], ["engine-kick", [MusicEngine.KICK]], ["engine-bass", [MusicEngine.SUB, MusicEngine.REESE]]]:
		var take: AudioBoard.Take = render_parent(script, p, part[1])["take"]
		var limit := scaled(take, stats["gain_db"])
		parts[part[0]] = take
		solos[part[0]] = {"layers": names(part[1]), "lufs_after": AudioBoard.loudness(take.left, take.right),
			"peak_db": linear_to_db(AudioBoard.peak(take.left, take.right)), "limit_db": limit}
	var failed := 0
	for name in parts:
		if AudioBoard.to_wav(parts[name]).save_to_wav(out.path_join(name + ".wav")) != OK:
			failed += 1
			push_error("could not write %s.wav" % name)
	var screen: Array = p["screen"]
	var info := {
		"parent": which, "theme": "spillway", "seed": SEED, "preroll_bars": PREROLL_BARS, "class_motif": CLASS_MOTIF,
		"engine": engine_path, "engine_sha256": FileAccess.get_sha256(engine_path), "bpm": p["bpm"],
		"sample_rate": Harmony.RATE, "total_frames": mix.left.size(),
		"screen_start": screen[0], "bars": screen[1], "samples_per_bar": screen[2], "samples_per_beat": int(screen[2]) / 4,
		"sections": p["sections"], "cues": p["cues"], "layer_gains_bar1": full["gains"], "mix_master": stats, "solos": solos,
		"per_bar": full["bars"], "events": full["events"],
	}
	var file := FileAccess.open(out.path_join("guide.json"), FileAccess.WRITE)
	if file == null:
		return failed + 1
	file.store_string(JSON.stringify(info, " "))
	file.close()
	return failed


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT).simplify_path()
	var guide_mode := false
	var pressure := PRESSURE
	var which := ""
	var engine_path := "res://src/presentation/music_engine.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--guides":
			guide_mode = true
		elif arg.begins_with("--pressure="):
			pressure = float(arg.trim_prefix("--pressure="))
		elif arg.begins_with("--parent="):
			which = arg.trim_prefix("--parent=")
		elif arg.begins_with("--engine="):
			engine_path = arg.trim_prefix("--engine=")
	DirAccess.make_dir_recursive_absolute(out)
	var started := Time.get_ticks_msec()
	if which in ["calm", "warden"]:
		var bad := parent(out, which, engine_path)
		print("ace_guide_v3 parent %s: %s to %s in %.1f s" % [which, "done" if bad == 0 else "FAIL (%d)" % bad, out, (Time.get_ticks_msec() - started) / 1000.0])
		quit(0 if bad == 0 else 1)
		return
	if which != "":
		push_error("--parent must be calm or warden, not %s" % which)
		quit(2)
		return
	if guide_mode:
		var bad := guides(out, pressure)
		print("ace_guide_v3 guides: %s to %s in %.1f s" % ["done" if bad == 0 else "FAIL (%d)" % bad, out, (Time.get_ticks_msec() - started) / 1000.0])
		quit(0 if bad == 0 else 1)
		return
	var full := render([])
	var mix: AudioBoard.Take = full["take"]
	var peak_before := linear_to_db(AudioBoard.peak(mix.left, mix.right))
	var lufs_before := AudioBoard.loudness(mix.left, mix.right)
	var stats := AudioBoard.master(mix)
	var parts := {"full": mix}
	var solos := {"full": {"layers": names(range(MusicEngine.LAYER_NAMES.size())),
		"lufs_before_shared_gain": lufs_before, "peak_db_before_shared_gain": peak_before,
		"lufs_after": stats["lufs"], "peak_db": stats["peak_db"], "limit_db": stats["limit_db"]}}
	for part in [["above", above()], ["keys", [MusicEngine.KEYS]], ["drums", DRUMS], ["kick", [MusicEngine.KICK]]]:
		var take: AudioBoard.Take = render(part[1])["take"]
		var before := AudioBoard.loudness(take.left, take.right)
		var limit := scaled(take, stats["gain_db"])
		parts[part[0]] = take
		solos[part[0]] = {"layers": names(part[1]), "lufs_before_shared_gain": before,
			"lufs_after": AudioBoard.loudness(take.left, take.right),
			"peak_db": linear_to_db(AudioBoard.peak(take.left, take.right)), "limit_db": limit}
	var failed := 0
	for name in parts:
		var err := AudioBoard.to_wav(parts[name]).save_to_wav(out.path_join("engine-" + name + ".wav"))
		if err != OK:
			failed += 1
			push_error("could not write engine-%s.wav: %d" % [name, err])
	var info := {
		"theme": "spillway", "theme_index": full["theme"], "pressure": PRESSURE, "seed": SEED,
		"preroll_bars": PREROLL_BARS, "bars": BARS, "bpm": full["bpm"], "sample_rate": full["rate"],
		"samples_per_bar": full["bar"], "total_frames": mix.left.size(), "seconds": float(mix.left.size()) / full["rate"],
		"layer_gains": full["gains"], "mix_master": stats, "solos": solos,
	}
	var file := FileAccess.open(out.path_join("engine.json"), FileAccess.WRITE)
	if file == null:
		failed += 1
	else:
		file.store_string(JSON.stringify(info, " "))
		file.close()
	print(JSON.stringify(info, " "))
	print("ace_guide_v3: %s to %s in %.1f s" % ["done" if failed == 0 else "FAIL (%d)" % failed, out, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if failed == 0 else 1)
