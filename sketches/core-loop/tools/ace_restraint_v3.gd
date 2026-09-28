extends SceneTree

const Guide := preload("res://tools/ace_guide_v3.gd")
const Board := preload("res://tools/audio_board.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# Offline audition only. The production engine remains unchanged.
class LoggedEngine extends MusicEngine:
	var palette := false
	var rows: Array = []
	var voice_blocks: Array = []

	func _retarget() -> void:
		super._retarget()
		if palette:
			_targets.fill(0.0)
			_targets[REESE] = 1.0
			_targets[LEAD] = 0.6
			_targets[COUNTER] = 0.55
			_targets[CHOIR] = 0.4

	func _mix(offset: int, n: int) -> void:
		var b := clock / bar_len() - Guide.PREROLL_BARS
		if b >= 0 and b < Guide.BARS:
			while rows.size() <= b:
				rows.append({"bar": rows.size() + 1, "layers": {}, "max_voices": 0,
					"max_simultaneous_layers": 0, "voice_samples": 0, "samples": 0})
			var layers := {}
			var count := 0
			for voice: Voice in _voices:
				if voice.layer < 0 or voice.pos >= voice.end:
					continue
				if not solo.is_empty() and not voice.layer in solo:
					continue
				var next := move_toward(_gains[voice.layer], _targets[voice.layer], float(n) / Harmony.BEAT)
				if maxf(_gains[voice.layer], next) <= 0.001:
					continue
				layers[LAYER_NAMES[voice.layer]] = true
				count += 1
			for name in layers:
				rows[b]["layers"][name] = true
			rows[b]["max_voices"] = maxi(rows[b]["max_voices"], count)
			rows[b]["max_simultaneous_layers"] = maxi(rows[b]["max_simultaneous_layers"], layers.size())
			rows[b]["voice_samples"] += count * n
			rows[b]["samples"] += n
			voice_blocks.append([clock - Guide.PREROLL_BARS * bar_len(), n, count])
		super._mix(offset, n)


func render_logged(solo: Array, palette: bool) -> Dictionary:
	var engine := LoggedEngine.new()
	engine.palette = palette
	engine._rng.seed = Guide.SEED
	engine.schedule_restart(0, MusicEngine.PLAY, Guide.THEME)
	engine.set_pressure(0.6 if palette else Guide.PRESSURE)
	engine.solo = solo
	var take := Board.Take.new()
	var bar := engine.bar_len()
	var start := Guide.PREROLL_BARS * bar
	var total := start + Guide.BARS * bar
	take.left.resize(Guide.BARS * bar)
	take.right.resize(Guide.BARS * bar)
	var clock := 0
	while clock < total:
		var n := mini(2048, total - clock)
		if clock < start:
			n = mini(n, start - clock)
		engine.render(n)
		if clock >= start:
			for i in n:
				take.left[clock - start + i] = engine.out_music[i].x
				take.right[clock - start + i] = engine.out_music[i].y
		clock += n
	for row in engine.rows:
		row["layers"] = row["layers"].keys()
		row["mean_voices"] = float(row["voice_samples"]) / row["samples"]
		row.erase("voice_samples")
		row.erase("samples")
	return {"take": take, "per_bar": engine.rows, "voice_blocks": engine.voice_blocks}


func _initialize() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty():
		push_error("--out is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var jobs := {"v1-above": Guide.above(), "v2-engine": [],
		"bass": [MusicEngine.REESE], "lead": [MusicEngine.LEAD],
		"counter": [MusicEngine.COUNTER], "choir": [MusicEngine.CHOIR]}
	var audit := {}
	for name in jobs:
		var palette: bool = not name.begins_with("v")
		var result := render_logged(jobs[name], palette)
		var take: Board.Take = result["take"]
		# Same shared gain as the historical engine render. No per-stem normalization.
		var limited := Guide.scaled(take, -4.28208247506093)
		assert(is_zero_approx(limited))
		assert(Board.to_wav(take).save_to_wav(out.path_join(name + ".wav")) == OK)
		audit[name] = {"pressure": 0.6 if palette else 0.9,
			"per_bar": result["per_bar"], "voice_blocks": result["voice_blocks"],
			"layer_starts_definition": "nonzero-gain scheduled engine voices; chord buffers count as one voice"}
		print("rendered ", name)
	var file := FileAccess.open(out.path_join("layers.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(audit, "  "))
	file.close()
	quit()
