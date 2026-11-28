extends SceneTree

const T := preload("res://tests/support/t.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const Synth := preload("res://src/presentation/synth.gd")

# S1-HITCH: a note the band renders on first use costs 35 to 85 ms in one frame. With the
# startup bake and the opening bake done, Spillway's band renders no new note through stage
# 1's arrangements it drives here: three pressures, the Warden's lift and break, the reactor
# pedal and each pilot's counter-line.

var _t := T.new("presentation_opening_bake_test")
var _seen := 0


func _initialize() -> void:
	MusicPrebake.prepare()
	MusicPrebake.prepare_opening()
	var baked := Synth._notes.size()
	_seen = baked
	var late: Array = []
	for p in [0.0, 0.5, 1.0]:
		var engine := MusicEngine.new()
		engine.schedule_restart(0, MusicEngine.PLAY, 0)
		engine.set_pressure(p)
		engine.render(1)
		engine.render(Harmony.BAR * 16)
		late.append_array(_new_notes("level p%.1f" % p))
	for motif in Harmony.CLASS_MOTIFS + ["reactor"]:
		var engine := MusicEngine.new()
		engine.schedule_restart(0, MusicEngine.PLAY, 0)
		engine.set_class_motif(motif)
		engine.set_reactor_pedal(motif == "reactor")
		engine.set_pressure(1.0)
		engine.render(1)
		engine.render(Harmony.BAR * 8)
		late.append_array(_new_notes("motif %s" % motif))
	var warden := MusicEngine.new()
	warden.force_track("warden", 0)
	warden.render(1)
	warden.warden_charge(1.0)
	warden.render(warden.bar_len() * 8)
	late.append_array(_new_notes("warden lift"))
	_t.check("stage 1 band is baked", late.is_empty(), "%d notes baked; rendered on first use after it: %s" % [baked, late])
	quit(_t.verdict())


# The notes rendered since the last call, named with the arrangement that asked for them.
func _new_notes(where: String) -> Array:
	var out: Array = []
	var keys: Array = Synth._notes.keys()
	for i in range(_seen, keys.size()):
		out.append("%s (%s)" % [keys[i], where])
	_seen = keys.size()
	return out

