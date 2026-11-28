extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# SPIL-9's assist stings: one per move, under a second, growing a layer per heft step
# (two layers at class 1-2, the sub at 3-4, the motif sax at 5), sounding in the band's
# key. Buffers, not speakers: each tier must carry more energy than the one under it,
# and a keyed bake must differ from the home bake.

var _t := T.new("assist_sting_test")


func _initialize() -> void:
	_t.eq("tier at heft 1", SfxBank.assist_sting_id("bonk", 1), "companion_assist_bonk_t1")
	_t.eq("tier at heft 4", SfxBank.assist_sting_id("bonk", 4), "companion_assist_bonk_t2")
	_t.eq("tier at heft 5 quotes the pilot", SfxBank.assist_sting_id("anvil", 5, "kest"), "companion_assist_anvil_t3_kest")
	_t.eq("unknown pilot falls back to the first", SfxBank.assist_sting_id("arc", 5, "nobody"), "companion_assist_arc_t3_sable")
	_t.eq("unknown move has no sting", SfxBank.assist_sting_id("tickle", 3), "")
	_t.check("a bad id is no recipe", not SfxBank.has_recipe("companion_assist_bonk_t3"))
	for move in SfxBank.ASSIST_MOVES:
		var ids := [SfxBank.assist_sting_id(move, 1), SfxBank.assist_sting_id(move, 3), SfxBank.assist_sting_id(move, 5, "rivet")]
		var energy: Array = []
		for id in ids:
			_t.check("%s has a recipe" % id, SfxBank.has_recipe(id))
			var buf: PackedFloat32Array = SfxBank.new()._bake(id)
			_t.check("%s is under a second" % id, buf.size() < Synth.seconds(1.0), "%d samples" % buf.size())
			_t.check("%s is not silent" % id, Synth.peak(buf) > 0.1)
			var sum := 0.0
			for x in buf:
				sum += x * x
			energy.append(sum)
		_t.check("%s grows with heft" % move, energy[1] > energy[0] and energy[2] > energy[0], str(energy))
	var home := SfxBank.samples_at("companion_assist_pile_t1", Harmony.STEP, 0)
	var moved := SfxBank.samples_at("companion_assist_pile_t1", Harmony.STEP, 5)
	_t.check("a keyed bake follows the band's key", home != moved)
	quit(_t.verdict())
