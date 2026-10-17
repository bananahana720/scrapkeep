extends SceneTree

const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# The kill-first specials' 17 rendered cues and the hype drop (INTEGRATION.md section 7,
# items 5 and 7): each has a recipe, bakes to a non-silent mono 44.1 kHz buffer, the four
# presence cues loop seamlessly at two bars of 129 BPM, and the drop lands where the
# file says it does.

var _t := T.new("special_sfx_test")


func _initialize() -> void:
	var ids: Array = SfxBank.FILE_SOUNDS.keys()
	_t.eq("17 specials, the hype drop, 5 jolt layer, 4 crown layer and 8 arrival sounds", ids.size(), 35)
	for id in ids:
		_t.check("%s has a recipe" % id, SfxBank.has_recipe(id))
		_t.check("%s has a trim" % id, SfxBank.TRIM_DB.has(id))
		var buf: PackedFloat32Array = SfxBank.samples(id)
		_t.check("%s is not silent" % id, Synth.peak(buf) > 0.5, "peak %.2f, %d samples" % [Synth.peak(buf), buf.size()])
		_t.check("%s is under 4 s" % id, buf.size() < Synth.seconds(4.0))
	for name in SfxBank.SPECIALS:
		var loop: PackedFloat32Array = SfxBank.samples(name + "_presence")
		var expect := roundi(8.0 * 60.0 / 129.0 * 44100.0)
		_t.check("%s_presence is two bars at 129 BPM" % name, absi(loop.size() - expect) <= 2, "%d samples, want %d" % [loop.size(), expect])
		var wav := SfxBank.loop_stream(name + "_presence")
		_t.check("%s_presence loops forward over the whole file" % name, wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_begin == 0 and wav.loop_end == loop.size())
		var step := 0.0
		for i in range(1, loop.size()):
			step = maxf(step, absf(loop[i] - loop[i - 1]))
		var wrap := absf(loop[0] - loop[loop.size() - 1])
		_t.check("%s_presence wraps without a click" % name, wrap <= step, "wrap %.4f, largest step %.4f" % [wrap, step])
	_t.check("a splitter has both breaks", SfxBank.has_recipe("splitter_break_split") and SfxBank.has_recipe("splitter_break_clean"))
	var drop: PackedFloat32Array = SfxBank.samples("hype_drop")
	var seconds := drop.size() / 44100.0
	_t.check("hype_drop runs past its drop", seconds > SfxBank.HYPE_DROP_LEAD_SECONDS + 0.5, "%.2f s, drop at %.1f s" % [seconds, SfxBank.HYPE_DROP_LEAD_SECONDS])
	var before := 0.0
	var after := 0.0
	var at := Synth.seconds(SfxBank.HYPE_DROP_LEAD_SECONDS)
	for i in range(at - 2205, at):
		before = maxf(before, absf(drop[i]))
	for i in range(at, at + 2205):
		after = maxf(after, absf(drop[i]))
	_t.check("the drop hits harder than the beat of silence before it", after > before * 2.0, "before %.2f, after %.2f" % [before, after])
	quit(_t.verdict())
