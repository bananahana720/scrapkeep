extends SceneTree

const T := preload("res://tests/support/t.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const Synth := preload("res://src/presentation/synth.gd")

# A pad chord rendered on first use costs 120 to 215 ms in one frame on the cloud (Synth.HOLD
# samples on the audio's main-thread render). With the whole band bake done, Brindle's fight
# renders no new pad through each phase's half-step lift and its sinister break, nor through
# the chase and the victory.

var _t := T.new("brindle_pad_bake_test")


func _initialize() -> void:
	# Before any bake, phase 2 asks for pads: the check below is not vacuous.
	_drive("2")
	_t.check("Brindle's fight plays pads", not _pads().is_empty(), "no pad rendered driving phase 2 unbaked")
	for key in _pads():
		Synth._notes.erase(key)
	MusicPrebake.prepare_all()
	var baked := _pads()
	var late: Array = []
	for section in ["1", "2", "3", "chase"]:
		_drive(section)
		for key in _pads():
			if not key in baked:
				late.append("%s (phase %s)" % [key, section])
		baked = _pads()
	_t.check("Brindle's pads are baked", late.is_empty(), "rendered on first use after the bake: %s" % [late])
	quit(_t.verdict())


func _drive(section: String) -> void:
	var engine := MusicEngine.new()
	engine.force_track("brindle", 0, section, true)
	engine.render(1)
	engine.render(engine.bar_len() * 4)
	for step in [[0.6, false, 0.0], [1.0, true, 0.2], [1.0, true, 0.6], [1.0, true, 1.0]]:
		if section == "chase":
			engine.chase(step[0])
		else:
			engine.brindle_hp(step[0], step[1], step[2])
		engine.render(engine.bar_len() * 4)
	engine.victory()
	engine.render(engine.bar_len() * 8)


func _pads() -> Array:
	return Synth._notes.keys().filter(func(key: String) -> bool: return key.begins_with("pad:"))
