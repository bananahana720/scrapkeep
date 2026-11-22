extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SetDirector := preload("res://src/presentation/set_director.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Edges := preload("res://tests/sound_edges_test.gd")
const T := preload("res://tests/support/t.gd")

# Game-wide musical rack, June's expressive answer phrasing, and synth-band pump pocket.

var t := T.new("sound_musical_test")


func _initialize() -> void:
	_rack_voices()
	_sax_warmth()
	_june_phrasing_and_cushions()
	_music_engine_pump_pocket()
	quit(t.verdict())


func _rack_voices() -> void:
	var voiced := ["lead", "sax_lounge", "keys", "brass", "bell", "mallet", "fbass", "reese", "clav", "sub",
		"talk", "choir_ah", "choir_oo", "tom", "sub808", "chime"]
	var bad_peak: Array = []
	var bad_edges: Array = []
	for voice in voiced:
		var a := Synth.note(voice, 62)
		var b := Synth.note(voice, 62)
		var pk := Synth.peak(a)
		if pk < 0.25 or pk > 0.95 or a != b:
			bad_peak.append("%s(peak=%.3f)" % [voice, pk])
		var faults := Edges.faults(a)
		if not faults.is_empty():
			bad_edges.append("%s(%s)" % [voice, ", ".join(faults)])
	for drum in ["kick", "snare", "clap", "hat", "open_hat", "ride", "crash"]:
		var d := Synth.drum(drum)
		var pk := Synth.peak(d)
		if pk < 0.25 or pk > 0.96:
			bad_peak.append("%s(peak=%.3f)" % [drum, pk])
		var faults := Edges.faults(d)
		if not faults.is_empty():
			bad_edges.append("%s(%s)" % [drum, ", ".join(faults)])
	for chord_buf in [Synth.chord(Harmony.PROGRESSION[0]["voicing"]), Synth.pad_chord(Harmony.PROGRESSION[0]["voicing"]),
			Synth.organ_chord(Harmony.PROGRESSION[0]["voicing"]),
			Synth.stab_chord(Harmony.PROGRESSION[0]["voicing"], true), Synth.stab_chord(Harmony.PROGRESSION[0]["voicing"], false)]:
		var pk := Synth.peak(chord_buf)
		if pk < 0.2 or pk > 0.95:
			bad_peak.append("chord(peak=%.3f)" % pk)
		var faults := Edges.faults(chord_buf)
		if not faults.is_empty():
			bad_edges.append("chord(%s)" % ", ".join(faults))
	t.check("every upgraded rack voice is deterministic and peak-safe", bad_peak.is_empty(), str(bad_peak))
	t.check("every upgraded rack voice starts and ends at rest", bad_edges.is_empty(), str(bad_edges))
	t.check("direct uncached synth voices are deterministic",
		Synth.lead(74, 4096) == Synth.lead(74, 4096) and Synth.kick() == Synth.kick() and Synth.clap() == Synth.clap()
		and Synth.talk(62, 4096) == Synth.talk(62, 4096) and Synth.choir(62, "ah", 4096) == Synth.choir(62, "ah", 4096)
		and Synth.ride() == Synth.ride() and Synth.crash() == Synth.crash())
	var bad_cues: Array = []
	for cue_id in ["menu_move", "menu_confirm", "menu_back", "lounge_flip", "bay_lounge_in", "found_twinkle",
			"achievement_chime", "rescue_fanfare", "part_get", "panel_jackpot", "pickup_fountain",
			"gates_open", "warden_gate_release", "overtime_pay", "arena_unlock_bells",
			"synergy_fired", "evolution_fired", "stinger_boss_defeated"]:
		var buf := SfxBank.samples(cue_id)
		var pk := Synth.peak(buf)
		var faults := Edges.faults(buf)
		if pk < 0.2 or pk > 0.95 or not faults.is_empty():
			bad_cues.append("%s(peak=%.3f,faults=%s)" % [cue_id, pk, str(faults)])
	t.check("every enriched UI, camp, reward and boss cue is peak-safe and edge-clean", bad_cues.is_empty(), str(bad_cues))


# Warm alto sax check: high-frequency harshness (first-difference RMS / signal RMS) stays well
# below a harsh unfiltered FM buzz, while keeping healthy fundamental warmth.
func _sax_warmth() -> void:
	var sax := Synth.note("lead", 74)
	var sum_sq := 0.0
	var diff_sq := 0.0
	for i in range(1, sax.size()):
		var x := sax[i]
		var d := x - sax[i - 1]
		sum_sq += x * x
		diff_sq += d * d
	var rms := sqrt(sum_sq / maxf(sax.size(), 1))
	var hf_ratio := sqrt(diff_sq / maxf(sum_sq, 1e-9))
	t.check("synth alto sax is warm and non-harsh", rms > 0.12 and hf_ratio < 0.28,
		"rms=%.3f hf_diff_ratio=%.3f (must be >0.12 and <0.28)" % [rms, hf_ratio])


func _june_phrasing_and_cushions() -> void:
	var bad_notes: Array = []
	var no_cushion: Array = []
	var bad_edges: Array = []
	for book in SetDirector.BOOK:
		for row in SetDirector.BOOK[book]:
			var id := String(row.id)
			var score := SetDirector.answer_score(id)
			var base_cells: Array = row.cells
			if score.size() <= base_cells.size():
				no_cushion.append(id)
			for cell in score:
				var step := int(cell[0])
				var midi := int(cell[1])
				if step < 0 or step >= 16 or posmod(midi, 12) in SetDirector.THREAT_PITCH_CLASSES:
					bad_notes.append("%s:%s" % [id, str(cell)])
			var buf := SfxBank.samples(SfxBank.SET_ANSWER + id)
			var faults := Edges.faults(buf)
			if not faults.is_empty() or Synth.peak(buf) < 0.25:
				bad_edges.append("%s:%s" % [id, str(faults)])
	t.check("every June answer adds an in-key harmonic cushion", no_cushion.is_empty(), str(no_cushion))
	t.check("every June answer note fits 1 bar and stays off Eb/Ab/Bb", bad_notes.is_empty(), str(bad_notes))
	t.check("every baked June answer starts and ends cleanly at rest", bad_edges.is_empty(), str(bad_edges))


func _music_engine_pump_pocket() -> void:
	var eng := MusicEngine.new()
	eng.force_track("warden", 0, "drop", true)
	var beat := eng.beat_len()
	var at_0 := eng._pump_at(eng.grid_origin)
	var at_pocket := eng._pump_at(eng.grid_origin + MusicEngine.PUMP_ATTACK + 10)
	var at_mid := eng._pump_at(eng.grid_origin + beat / 2)
	var at_end := eng._pump_at(eng.grid_origin + int(beat * 0.85))
	t.check("Warden drop sidechain dips into kick pocket and breathes back cleanly",
		at_0 >= 0.99 and at_pocket <= 0.40 and at_mid > at_pocket + 0.25 and at_end >= 0.99,
		"start=%.2f pocket=%.2f mid=%.2f end=%.2f" % [at_0, at_pocket, at_mid, at_end])
	# Verify render() splits at the hold corner so the flat kick pocket reaches the audio mix
	# even when rendered in large chunks (comparing single-beat render vs 64-frame chunks after
	# filter warmup, soloed to pumped layers so the pocket is isolated cleanly).
	var eng_big := MusicEngine.new()
	var eng_fine := MusicEngine.new()
	for e in [eng_big, eng_fine]:
		e.force_track("warden", 0, "drop", true)
		e.solo = [MusicEngine.KEYS, MusicEngine.PAD, MusicEngine.REESE]
		e.render(e.bar_len())
	var hold := int(beat * MusicEngine.PUMP_HOLD_FRAC)
	eng_big.render(beat)
	var big_out: PackedVector2Array = eng_big.out_music.duplicate()
	var fine_out := PackedVector2Array()
	var done := 0
	while done < beat:
		var chunk := mini(64, beat - done)
		eng_fine.render(chunk)
		fine_out.append_array(eng_fine.out_music)
		done += chunk
	var max_hold_err := 0.0
	for i in range(MusicEngine.PUMP_ATTACK, hold):
		max_hold_err = maxf(max_hold_err, absf(big_out[i].x - fine_out[i].x))
		max_hold_err = maxf(max_hold_err, absf(big_out[i].y - fine_out[i].y))
	t.check("Warden drop sidechain hold pocket reaches rendered audio on large chunks",
		max_hold_err < 0.001, "max_hold_err=%.6f across [%d, %d)" % [max_hold_err, MusicEngine.PUMP_ATTACK, hold])
