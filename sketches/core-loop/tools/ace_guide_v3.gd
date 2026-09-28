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

const THEME := 0
const PRESSURE := 0.9
const PREROLL_BARS := 8
const BARS := 16
const SEED := 172
const DRUMS := [MusicEngine.HATS, MusicEngine.KICK, MusicEngine.SNARE]
const UNDER := [MusicEngine.KEYS, MusicEngine.HATS, MusicEngine.KICK, MusicEngine.SNARE]
const DEFAULT_OUT := "../../artifacts/local/v3-audio/hybrid/engine"


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


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT).simplify_path()
	var guide_mode := false
	var pressure := PRESSURE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--guides":
			guide_mode = true
		elif arg.begins_with("--pressure="):
			pressure = float(arg.trim_prefix("--pressure="))
	DirAccess.make_dir_recursive_absolute(out)
	var started := Time.get_ticks_msec()
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
