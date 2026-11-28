extends SceneTree

const Bank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const Cues := preload("res://src/presentation/positional_cue_rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

# Every sound the bank makes starts and ends at rest, and every sound the game loops tiles.
# These are the faults a level meter cannot see and a speaker turns into a tick: a buffer
# that is silent, one whose first sample is already loud, one that stops mid-wave, and a loop
# whose last sample does not meet its first. Clicks inside a sound and flat tops need a
# picture to judge (a ratchet is made of clicks), so they stay in the sound-check tools
# (design-v3/SOUND-BIBLE.md, "How it is checked").
#
# ALLOWED is the whole list of sounds let through, each with why. A row that no longer trips
# fails the test, so the list cannot go stale.

const START_MAX := 0.05
const END_MAX := 0.02
const TAIL_MAX := 0.05
const ALLOWED := {
	"build_riser": "the synth band cuts it to the step and releases it itself (music_engine.gd); this plain bounce never plays",
	"linker_tell": "a rendered twang whose first sample is its pluck; a world 2 file, left as rendered",
	"linker_break": "a rendered clang whose first sample is its strike; a world 2 file, left as rendered",
}
const LINE := "Hold the line, we are nearly through."

var t := T.new("sound_edges_test")


func _initialize() -> void:
	_rule()
	_bank()
	quit(t.verdict())


# What is wrong with a buffer's edges, as words; empty when nothing is.
static func faults(buf: PackedFloat32Array, loop := false) -> Array:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	if peak <= 0.0:
		return ["silent"]
	if loop:
		var step := 0.0
		for i in range(1, buf.size()):
			step = maxf(step, absf(buf[i] - buf[i - 1]))
		var seam := absf(buf[0] - buf[buf.size() - 1])
		return ["seam is a step of %.3f, the largest inside is %.3f" % [seam / peak, step / peak]] if seam > step else []
	var out := []
	if absf(buf[0]) > START_MAX * peak:
		out.append("starts at %d%% of its peak" % roundi(absf(buf[0]) / peak * 100.0))
	elif buf.size() > 3:
		# A start on zero that jumps on the next sample clicks as well: the step into the
		# second sample may not be the largest step in the sound.
		var inner := 0.0
		for i in range(2, buf.size()):
			inner = maxf(inner, absf(buf[i] - buf[i - 1]))
		var first := absf(buf[1] - buf[0])
		if first > START_MAX * peak and first > inner:
			out.append("jumps to %d%% of its peak on its second sample" % roundi(absf(buf[1]) / peak * 100.0))
	var last := mini(buf.size(), Harmony.RATE / 1000)
	var sum := 0.0
	for i in range(buf.size() - last, buf.size()):
		sum += buf[i] * buf[i]
	var tail := sqrt(sum / last)
	if absf(buf[buf.size() - 1]) > END_MAX * peak or tail > TAIL_MAX * peak:
		out.append("ends at %.1f%% of its peak, its last millisecond at %.1f%%" % [absf(buf[buf.size() - 1]) / peak * 100.0, tail / peak * 100.0])
	return out


func _tone(seconds: float, hz: float, fade := 0) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * Harmony.RATE))
	for i in buf.size():
		buf[i] = sin(TAU * hz * i / Harmony.RATE)
	for i in mini(fade, buf.size()):
		buf[buf.size() - 1 - i] *= float(i) / fade
	return buf


# The rule against buffers whose faults are known.
func _rule() -> void:
	var silent := PackedFloat32Array()
	silent.resize(100)
	t.eq("a silent buffer is a fault", faults(silent), ["silent"])
	t.check("a tone stopped mid-wave is a fault", faults(_tone(0.1037, 440.0)).size() == 1, str(faults(_tone(0.1037, 440.0))))
	t.eq("the same tone faded out is clean", faults(_tone(0.1037, 440.0, 600)), [])
	var late := _tone(0.1, 440.0, 600).slice(25)
	t.check("a tone that starts on its crest is a fault", faults(late).size() == 1, str(faults(late)))
	var jump := late.duplicate()
	jump[0] = 0.0
	t.check("so is one that starts on zero and jumps to its crest on the next sample", faults(jump).size() == 1, str(faults(jump)))
	t.eq("whole cycles tile as a loop", faults(_tone(0.1, 440.0), true), [])
	var torn := _tone(0.1, 440.0).slice(0, Harmony.RATE / 10 - 25)
	t.check("a loop cut short of its cycle is a fault", faults(torn, true).size() == 1, str(faults(torn, true)))


func _ids() -> Array:
	var ids: Array = Bank.TRIM_DB.keys()
	for cue in Bank.EVENT_CUES:
		if cue not in ids:
			ids.append(cue)
	ids.append("babble")
	for speaker in VoiceSynth.CALLERS:
		ids.append(VoiceSynth.say_id(speaker, LINE))
	return ids


func _loops() -> Array:
	var loops: Array = Bank.LOOPED.duplicate()
	loops.append_array(Cues.ROWS.keys().filter(func(id): return Cues.ROWS[id].get("loop", false)))
	return loops


func _bank() -> void:
	var loops := _loops()
	var ids := _ids()
	var wrong := []
	var stale: Array = ALLOWED.keys()
	var missing := []
	for id in ids:
		var is_voice: bool = id == "babble" or String(id).begins_with(VoiceSynth.SAY)
		var has_own: bool = VoiceSynth.has_recipe(id) if is_voice else Bank.has_recipe(id)
		if not has_own:
			missing.append(id)
			continue
		var found := faults(VoiceSynth.samples(id) if is_voice else Bank.samples(id), id in loops)
		if found.is_empty():
			continue
		if ALLOWED.has(id):
			stale.erase(id)
		else:
			wrong.append("%s: %s" % [id, "; ".join(found)])
	t.check("every levelled sound has a recipe", missing.is_empty(), str(missing))
	t.check("every looped sound is in the bank", loops.all(func(id): return id in ids), str(loops))
	t.check("each special's presence is listed as a loop", Bank.SPECIALS.all(func(kind): return kind + "_presence" in Bank.LOOPED), str(Bank.LOOPED))
	t.check("%d sounds start and end at rest, and %d loops tile" % [ids.size() - loops.size(), loops.size()], wrong.is_empty(), "\n  ".join(wrong))
	t.check("every allowed sound still needs its row", stale.is_empty(), str(stale))
