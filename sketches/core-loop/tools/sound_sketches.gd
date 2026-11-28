extends SceneTree

const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")


const DEFAULT_OUT := "../../artifacts/local/harpoon/sounds"
const NOTE_GAP := 0.2
const HUM_SECONDS := 3.0
const SHATTER_GAP := 0.38
const HIT_PRIORITY_DB := -3.0
const BREAK_PEAK := 0.95


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT).simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var failed := 0
	for entry in _sketches():
		var path: String = out.path_join(String(entry[0]) + ".wav")
		var err := _wav(entry[1]).save_to_wav(path)
		print("%s %s" % ["wrote" if err == OK else "FAILED", path])
		if err != OK:
			failed += 1
	quit(1 if failed > 0 else 0)


func _sketches() -> Array:
	var list: Array = []
	for variant in 3:
		var letter := char(97 + variant)
		list.append(["bite-%s" % letter, _at_level(SfxBank.new().bite(variant), "line_bite")])
		list.append(["crack-%s" % letter, _at_level(SfxBank.new().crack(variant), "smash_crack")])
	for variant in SfxBank.BREAK_PHRASES.size():
		list.append(["break-%s" % char(97 + variant), _break(variant)])
	list.append(["clunk", _at_level(SfxBank.clunk(), "anchor_clunk")])
	list.append(["dry-tick", _at_level(SfxBank.samples("dry_tick").duplicate(), "dry_tick")])
	list.append(["zip", _at_level(SfxBank.zip(), "line_zip")])
	list.append(["twang", _at_level(SfxBank.new().twang(),"line_twang")])
	list.append(["hum", _hum()])
	for cause in EventKinds.CAUSE_ROWS:
		list.append(["motif-%s" % cause, _motif(cause)])
	return list


static func _at_level(buf: PackedFloat32Array, id: String) -> PackedFloat32Array:
	var scaled := Synth.normalize(buf.duplicate(), 0.9)
	var gain := db_to_linear(SfxBank.trim_db(id))
	for i in scaled.size():
		scaled[i] *= gain
	return scaled


static func _hum() -> PackedFloat32Array:
	var cycle := SfxBank.samples("line_hum")
	var total := Synth.seconds(HUM_SECONDS)
	var buf := Synth.buffer(total)
	var phase := 0.0
	for i in total:
		var ratio := pow(2.0, float(i) / total)
		phase = fposmod(phase + ratio, cycle.size())
		buf[i] = cycle[int(phase)]
	return _at_level(buf, "line_hum")


static func _pitched(buf: PackedFloat32Array, ratio: float) -> PackedFloat32Array:
	var n := int(buf.size() / ratio)
	var out := Synth.buffer(n)
	for i in n:
		var at := i * ratio
		var low := int(at)
		var next := mini(low + 1, buf.size() - 1)
		out[i] = lerpf(buf[low], buf[next], at - low)
	return out


static func _break(variant: int) -> PackedFloat32Array:
	var phrase: Dictionary = SfxBank.BREAK_PHRASES[variant]
	var midis := SfxBank.break_midis(variant)
	var buf := Synth.buffer(Synth.seconds(4.0))
	var at := 0.0
	var thwack := SfxBank.samples("hit_thwack")
	var hit_gain := db_to_linear(SfxBank.trim_db("hit_thwack") + HIT_PRIORITY_DB)
	for i in midis.size():
		Synth.add_into(buf, _pitched(thwack, Harmony.ratio(midis[i] - Harmony.HOME)), Synth.seconds(at), hit_gain)
		if i < midis.size() - 1:
			at += float(phrase["gaps"][i])
	at += float(phrase["chord_gap"])
	for midi in midis:
		var id := SfxBank.cause_note_id(midi)
		Synth.add_into(buf, SfxBank.samples(id), Synth.seconds(at), db_to_linear(SfxBank.trim_db(id)))
	Synth.add_into(buf, SfxBank.samples("boss_weak_hit"), Synth.seconds(at), db_to_linear(SfxBank.trim_db("boss_weak_hit")))
	at += SHATTER_GAP
	for id in ["shatter", "chunk_low"]:
		Synth.add_into(buf, SfxBank.samples(id), Synth.seconds(at), db_to_linear(SfxBank.trim_db(id)))
	var end := buf.size()
	while end > 0 and absf(buf[end - 1]) < 0.0005:
		end -= 1
	var out := buf.slice(0, end)
	var peak := Synth.peak(out)
	if peak > BREAK_PEAK:
		for i in out.size():
			out[i] *= BREAK_PEAK / peak
	return out


static func _motif(cause: String) -> PackedFloat32Array:
	var notes: Array = EventKinds.cause_motif(cause)
	var buf := Synth.buffer(Synth.seconds(NOTE_GAP * (notes.size() - 1) + 0.7))
	var gain := db_to_linear(SfxBank.CAUSE_NOTE_DB)
	for i in notes.size():
		var note := SfxBank.samples(SfxBank.cause_note_id(Harmony.note_midi(String(notes[i]))))
		Synth.add_into(buf, note, Synth.seconds(NOTE_GAP * i), gain)
	return buf


static func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	return Synth.to_wav(buf)
