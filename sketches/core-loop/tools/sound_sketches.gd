extends SceneTree

const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")

# The harpoon line's sounds as WAV files, for the owner's ear. Each is written at its bank
# level (peak 0.9 scaled by its trim), so the files sit against each other as they do in the
# game. Variant A of the bite and the crack is the one wired in; B and C are alternatives.
#
#   godot --headless --path sketches/core-loop --script res://tools/sound_sketches.gd
#   ... -- --out=/abs/dir
# The default output is <repo>/artifacts/local/harpoon/sounds (gitignored).

const DEFAULT_OUT := "../../artifacts/local/harpoon/sounds"
const NOTE_GAP := 0.2
const HUM_SECONDS := 3.0


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


# [file name, samples] for every sketch.
func _sketches() -> Array:
	var list: Array = []
	for variant in 3:
		var letter := char(97 + variant)
		list.append(["bite-%s" % letter, _at_level(SfxBank.bite(variant), "grapple_clink")])
		list.append(["crack-%s" % letter, _at_level(SfxBank.crack(variant), "smash_crack")])
	list.append(["clunk", _at_level(SfxBank.clunk(), "anchor_clunk")])
	list.append(["dry-tick", _at_level(SfxBank.samples("dry_tick").duplicate(), "dry_tick")])
	list.append(["zip", _at_level(SfxBank.zip(), "line_zip")])
	list.append(["twang", _at_level(SfxBank.twang(), "line_twang")])
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


# Three seconds of the looped hum at one pitch, then the pitch's octave climb across them.
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
