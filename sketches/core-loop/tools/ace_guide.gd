extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const AudioBoard := preload("res://tools/audio_board.gd")

# The guide for the ACE-Step cover audition: the Spillway theme at one fixed pressure,
# 16 bars on the band's grid, after a pre-roll phrase so the layer gains have settled
# and the loop opens on the tails a looping band would carry. Identically seeded
# engines render the same bars with only the bass and drum layers (the core the engine
# would keep live under a cover) and with only the bass (ground truth for the stem
# bleed measure). Every file shares the full mix's gain to -14 LUFS. Each also gets
# the bar that follows as <name>.overrun.wav, the continuation a loop crossfade needs,
# and guide.json records the grid the cover is trimmed against.
#
#   godot --headless --path sketches/core-loop --script res://tools/ace_guide.gd -- --out=/abs/dir

const THEME := 0
const PRESSURE := 0.6
const PREROLL_BARS := 8
const BARS := 16
const SEED := 172
const CORE := [MusicEngine.SUB, MusicEngine.HATS, MusicEngine.KICK, MusicEngine.SNARE, MusicEngine.REESE]
const BASS := [MusicEngine.SUB, MusicEngine.REESE]
const DEFAULT_OUT := "../../artifacts/local/ace-audition"


static func render(solo: Array) -> Dictionary:
	var engine := MusicEngine.new()
	engine._rng.seed = SEED
	engine.schedule_restart(0, MusicEngine.PLAY, THEME)
	engine.set_pressure(PRESSURE)
	engine.solo = solo
	var take := AudioBoard.Take.new()
	var overrun := AudioBoard.Take.new()
	var bar := engine.bar_len()
	var start := PREROLL_BARS * bar
	var loop_end := start + BARS * bar
	var total := loop_end + bar
	take.left.resize(BARS * bar)
	take.right.resize(BARS * bar)
	overrun.left.resize(bar)
	overrun.right.resize(bar)
	var gains := {}
	var clock := 0
	while clock < total:
		var n := mini(2048, total - clock)
		for edge in [start, loop_end]:
			if clock < edge:
				n = mini(n, edge - clock)
		if clock == start:
			for layer in MusicEngine.LAYER_NAMES.size():
				gains[MusicEngine.LAYER_NAMES[layer]] = snappedf(engine.layer_gain(layer), 0.0001)
		engine.render(n)
		if clock >= start:
			var music := engine.out_music
			var dest := take if clock < loop_end else overrun
			var at := clock - start if clock < loop_end else clock - loop_end
			for i in n:
				dest.left[at + i] = music[i].x
				dest.right[at + i] = music[i].y
		clock += n
	return {"take": take, "overrun": overrun, "gains": gains, "bpm": engine.bpm(), "bar": bar, "rate": Harmony.RATE, "theme": engine.theme}


static func scaled(take: AudioBoard.Take, gain_db: float) -> float:
	var g := db_to_linear(gain_db)
	for i in take.left.size():
		take.left[i] *= g
		take.right[i] *= g
	return AudioBoard._limit(take.left, take.right)


static func names(layers: Array) -> Array:
	return layers.map(func(layer): return MusicEngine.LAYER_NAMES[layer])


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT).simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var started := Time.get_ticks_msec()
	var full := render([])
	var mix: AudioBoard.Take = full["take"]
	var stats := AudioBoard.master(mix)
	var parts := {"guide-spillway-16bar": full}
	var solos := {}
	for part in [["core", CORE], ["bass", BASS]]:
		var rendered := render(part[1])
		var take: AudioBoard.Take = rendered["take"]
		var before := AudioBoard.loudness(take.left, take.right)
		var limit := scaled(take, stats["gain_db"])
		parts["guide-spillway-16bar-" + part[0]] = rendered
		solos[part[0]] = {"layers": names(part[1]), "lufs_before_shared_gain": before,
			"lufs_after": AudioBoard.loudness(take.left, take.right),
			"peak_db": linear_to_db(AudioBoard.peak(take.left, take.right)), "limit_db": limit}
	var failed := 0
	for name in parts:
		scaled(parts[name]["overrun"], stats["gain_db"])
		for suffix in [["take", ".wav"], ["overrun", ".overrun.wav"]]:
			var err := AudioBoard.to_wav(parts[name][suffix[0]]).save_to_wav(out.path_join(name + suffix[1]))
			if err != OK:
				failed += 1
				push_error("could not write %s%s: %d" % [name, suffix[1], err])
	var info := {
		"theme": "spillway", "theme_index": full["theme"], "pressure": PRESSURE, "seed": SEED,
		"preroll_bars": PREROLL_BARS, "bars": BARS, "bpm": full["bpm"], "sample_rate": full["rate"],
		"samples_per_bar": full["bar"], "samples_per_beat": full["bar"] / Harmony.STEPS_PER_BAR * Harmony.STEPS_PER_BEAT,
		"total_frames": mix.left.size(), "seconds": float(mix.left.size()) / full["rate"],
		"layer_gains": full["gains"], "mix_master": stats, "solos": solos,
	}
	var file := FileAccess.open(out.path_join("guide.json"), FileAccess.WRITE)
	if file == null:
		failed += 1
	else:
		file.store_string(JSON.stringify(info, " "))
		file.close()
	print(JSON.stringify(info, " "))
	print("ace_guide: %s to %s in %.1f s" % ["done" if failed == 0 else "FAIL (%d)" % failed, out, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if failed == 0 else 1)
